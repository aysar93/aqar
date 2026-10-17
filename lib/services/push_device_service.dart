import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'push_migration.dart';
import 'push_registration_policy.dart';

class PushDeviceService {
  static Future<void> _queue = Future.value();
  static StreamSubscription<User?>? _authChanges;
  static String? _detachingUser;
  static bool registrationAllowed(String uid) {
    _observeAuth();
    return _detachingUser != uid &&
        FirebaseAuth.instance.currentUser?.uid == uid;
  }

  static String _randomSecret() {
    final random = Random.secure();
    return List.generate(64, (_) => random.nextInt(16).toRadixString(16))
        .join();
  }

  static Future<String> _revokeSecret() async {
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString('push_revoke_secret_v1');
    if (previous != null) return previous;
    final secret = _randomSecret();
    await prefs.setString('push_revoke_secret_v1', secret);
    return secret;
  }

  /// Contains only random, revocation-only capabilities, never Firebase tokens.
  /// A capability remains valid for that registration after Auth signs out.
  static Future<void> flushPendingRevocations() async {
    if (!PushMigration.enabled) return;
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList('pending_push_revocations_v1') ?? [];
    for (final entry in entries) {
      try {
        final response = await FirebaseFunctions.instance
            .httpsCallable('unregisterPushDevice')
            .call(jsonDecode(entry))
            .timeout(const Duration(seconds: 5));
        if (response.data is Map && response.data['detached'] == false) return;
        final remaining =
            prefs.getStringList('pending_push_revocations_v1') ?? [];
        remaining.remove(entry);
        await prefs.setStringList('pending_push_revocations_v1', remaining);
      } catch (_) {
        // Keep the durable item; retry on startup and the next token sync.
        return;
      }
    }
  }

  static void _observeAuth() {
    _authChanges ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      // A fresh sign-in can register again after the old identity has left.
      if (user?.uid != _detachingUser) _detachingUser = null;
    });
  }

  static Future<String> _installationId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('fcm_installation_v1');
    if (id == null) {
      final random = Random.secure();
      id =
          List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
      await prefs.setString('fcm_installation_v1', id);
    }
    return id;
  }

  static Future<void> register(String token, String uid,
      {String? oneSignalId, String? providerToken}) {
    if (!PushMigration.enabled) return Future.value();
    _observeAuth();
    if (_detachingUser == uid) return Future.value();
    return _queue = _queue.catchError((Object _) {}).then((_) async {
      final installationId = await _installationId();
      final prefs = await SharedPreferences.getInstance();
      final generation = prefs.getInt('push_registration_generation_v1') ?? 1;
      await flushPendingRevocations();
      if (_detachingUser == uid ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      final payload = <String, dynamic>{
        'installationId': installationId,
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'revokeSecret': await _revokeSecret(),
        'generation': generation,
      };
      Future<void> send(Map<String, dynamic> data) async {
        await FirebaseFunctions.instance
            .httpsCallable('registerPushDevice')
            .call(data)
            .timeout(const Duration(seconds: 8));
      }

      await registerDeviceWithOptionalFallback(
        registerFcm: () => send(payload),
        bindFallback: oneSignalId == null
            ? null
            : () => send({
                  ...payload,
                  'oneSignalId': oneSignalId,
                  if (providerToken != null) 'providerToken': providerToken
                }),
        stillCurrentAccount: () =>
            _detachingUser != uid &&
            FirebaseAuth.instance.currentUser?.uid == uid,
        onFallbackError: (_) => debugPrint(
            'OneSignal fallback binding unavailable; FCM remains registered'),
      );
    });
  }

  /// Must complete while the previous account is still authenticated.
  static Future<void> detach() {
    if (!PushMigration.enabled) return Future.value();
    _observeAuth();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Future.value();
    // Block refresh callbacks immediately, before waiting for previous writes.
    _detachingUser = uid;
    // Persist before any network wait. Do not put logout behind a potentially
    // stalled registration call; the server's revocation tombstone prevents a
    // late completion from reactivating the same generation.
    return () async {
      final prefs = await SharedPreferences.getInstance();
      final generation =
          (prefs.getInt('push_registration_generation_v1') ?? 1) + 1;
      await prefs.setInt('push_registration_generation_v1', generation);
      final entry = jsonEncode({
        'installationId': await _installationId(),
        'revokeSecret': await _revokeSecret(),
        'generation': generation
      });
      final entries = prefs.getStringList('pending_push_revocations_v1') ?? [];
      if (!entries.contains(entry)) entries.add(entry);
      await prefs.setStringList('pending_push_revocations_v1', entries);
      await prefs.remove('push_revoke_secret_v1');
      await flushPendingRevocations();
    }();
  }
}
