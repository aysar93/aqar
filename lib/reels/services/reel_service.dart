import 'package:aqar/moderation/user_blocks.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/reel_model.dart';

class ReelService {
  ReelService._();
  static final instance = ReelService._();
  final _db = FirebaseFirestore.instance;
  static const _apiBaseUrl = String.fromEnvironment(
    'REELS_API_BASE_URL',
    defaultValue: 'https://aqar-reels-api.aysar-aliraqe.workers.dev',
  );

  Stream<List<ReelModel>> publicReels() => _db
      .collection('reels')
      .where('status', whereIn: ['published', 'scheduled'])
      .orderBy('isPinned', descending: true)
      .orderBy('sortOrder')
      .orderBy('publishAt', descending: true)
      .limit(100)
      .safeSnapshots()
      .asyncMap((snapshot) async {
        final result = await Future.wait(snapshot.docs.map((doc) async {
          final reel = ReelModel.fromDocument(doc);
          return await _visibleToViewer(reel) ? reel : null;
        }));
        return result.whereType<ReelModel>().toList();
      });

  Future<bool> _visibleToViewer(ReelModel reel) async {
    if (!reel.isCurrentlyVisible) return false;
    try {
      for (final entry in {
        'properties': reel.propertyId,
        'offices': reel.officeId
      }.entries) {
        if (entry.value == null || entry.value!.isEmpty) continue;
        final doc = await _db.collection(entry.key).doc(entry.value).get();
        if (!doc.exists) return false;
        UserBlocks.instance.rememberTarget(doc.reference.path, doc.data()!);
        if (UserBlocks.instance.hides(doc.data()!)) return false;
        if (entry.key == 'properties' && doc.data()?['status'] != 'approved')
          return false;
        if (entry.key == 'offices' && doc.data()?['status'] != 'active')
          return false;
      }
      return !UserBlocks.instance.hides({
        'propertySnapshot': reel.propertySnapshot,
        'officeSnapshot': reel.officeSnapshot
      });
    } catch (_) {
      return false;
    }
  }

  Stream<List<ReelModel>> adminReels() => _db
      .collection('reels')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ReelModel.fromDocument).toList());

  Future<void> track(String reelId, String event,
      {Map<String, dynamic>? data}) async {
    if (_apiBaseUrl.isEmpty) return;
    await _post(
        '/event',
        {
          'reelId': reelId,
          'event': event,
          'data': data ?? const <String, dynamic>{}
        },
        authenticated: false);
  }

  String _interactionId(String reelId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('AUTH_REQUIRED');
    return '${uid}_$reelId';
  }

  Stream<bool> liked(String reelId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _db
        .collection('reel_likes')
        .doc('${uid}_$reelId')
        .snapshots()
        .map((d) => d.exists);
  }

  Stream<bool> saved(String reelId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _db
        .collection('reel_saves')
        .doc('${uid}_$reelId')
        .snapshots()
        .map((d) => d.exists);
  }

  Stream<List<ReelModel>> savedReels() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .collection('reel_saves')
        .where('userId', isEqualTo: uid)
        .safeSnapshots()
        .asyncMap((snapshot) async {
      final reels = await Future.wait(snapshot.docs.map((save) async {
        final reelId = (save.data()['reelId'] ?? '').toString();
        if (reelId.isEmpty) return null;
        try {
          final reel = await _db.collection('reels').doc(reelId).get();
          if (!reel.exists) return null;
          final model = ReelModel.fromDocument(reel);
          return await _visibleToViewer(model) ? model : null;
        } catch (_) {
          return null;
        }
      }));
      return reels
          .whereType<ReelModel>()
          .where((reel) => reel.isCurrentlyVisible)
          .toList();
    });
  }

  Future<void> toggleLike(String reelId) => _toggle('like', reelId);
  Future<void> toggleSave(String reelId) => _toggle('save', reelId);

  Future<void> deleteReel(String reelId) async {
    await _post('/delete', {'reelId': reelId});
  }

  Future<void> _toggle(String type, String reelId) async {
    _interactionId(reelId);
    await _post('/interaction', {'reelId': reelId, 'type': type});
  }

  Future<void> report(ReelModel reel, String reason, String details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('AUTH_REQUIRED');
    await _post('/report', {
      'reelId': reel.id,
      'reelTitle': reel.title,
      'thumbnailUrl': reel.thumbnailUrl,
      'reason': reason,
      'details': details.trim()
    });
  }

  Future<String> uploadVideo(
      {required Uint8List bytes,
      required String fileName,
      required String contentType}) async {
    if (_apiBaseUrl.isEmpty) throw StateError('REELS_API_NOT_CONFIGURED');
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw StateError('AUTH_REQUIRED');
    final response = await http.post(
        Uri.parse(
            '$_apiBaseUrl/upload?fileName=${Uri.encodeQueryComponent(fileName)}'),
        body: bytes,
        headers: {
          'Content-Type': contentType,
          'Authorization': 'Bearer $token'
        });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('UPLOAD_FAILED');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['publicUrl'] as String;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {bool authenticated = true}) async {
    if (_apiBaseUrl.isEmpty) throw StateError('REELS_API_NOT_CONFIGURED');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw StateError('AUTH_REQUIRED');
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.post(Uri.parse('$_apiBaseUrl$path'),
        headers: headers, body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('REELS_API_FAILED_${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
