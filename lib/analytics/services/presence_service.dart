import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'analytics_identity.dart';

class PresenceService {
  PresenceService({FirebaseDatabase? database})
      : _database = database ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL:
                  'https://aqar-9f3f9-default-rtdb.asia-southeast1.firebasedatabase.app',
            );

  final FirebaseDatabase _database;

  DatabaseReference? _presenceReference;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  Future<void> connect(String sessionId) async {
    await _connectionSubscription?.cancel();

    final visitorId = await AnalyticsIdentity.id();
    final user = FirebaseAuth.instance.currentUser;

    _presenceReference = _database.ref('presence/$visitorId');

    final connectionReference = _database.ref('.info/connected');

    _connectionSubscription = connectionReference.onValue.listen((event) async {
      final isConnected = event.snapshot.value == true;

      if (!isConnected || _presenceReference == null) {
        return;
      }

      await _presenceReference!.onDisconnect().set({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });

      await _presenceReference!.set({
        'online': true,
        'lastSeen': ServerValue.timestamp,
        'sessionId': sessionId,
        'platform': Platform.operatingSystem,
        'isGuest': user?.isAnonymous ?? true,
      });
    });
  }

  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    await _presenceReference?.update({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });

    _presenceReference = null;
  }

  Stream<int> onlineCount() {
    return _database
        .ref('presence')
        .orderByChild('online')
        .equalTo(true)
        .onValue
        .map((event) => event.snapshot.children.length);
  }
}
