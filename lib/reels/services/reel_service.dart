import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/reel_model.dart';

class ReelService {
  ReelService._();
  static final instance = ReelService._();
  final _db = FirebaseFirestore.instance;

  Stream<List<ReelModel>> publicReels() => _db
      .collection('reels')
      .where('status', isEqualTo: 'published')
      .orderBy('isPinned', descending: true)
      .orderBy('sortOrder')
      .orderBy('publishAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map(ReelModel.fromDocument)
          .where((reel) => reel.isCurrentlyVisible)
          .toList());

  Stream<List<ReelModel>> adminReels() => _db
      .collection('reels')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ReelModel.fromDocument).toList());

  Future<void> track(String reelId, String event,
      {Map<String, dynamic>? data}) async {
    await FirebaseFunctions.instance.httpsCallable('recordReelEvent').call({
      'reelId': reelId,
      'event': event,
      'data': data ?? const <String, dynamic>{},
    });
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

  Future<void> toggleLike(String reelId) => _toggle('reel_likes', reelId);
  Future<void> toggleSave(String reelId) => _toggle('reel_saves', reelId);

  Future<void> _toggle(String collection, String reelId) async {
    final id = _interactionId(reelId);
    final ref = _db.collection(collection).doc(id);
    final exists = (await ref.get()).exists;
    if (exists) {
      await ref.delete();
    } else {
      await ref.set({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'reelId': reelId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> report(String reelId, String reason, String details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('AUTH_REQUIRED');
    await _db.collection('reel_reports').doc('${user.uid}_$reelId').set({
      'reelId': reelId,
      'userId': user.uid,
      'reason': reason,
      'details': details.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadVideo(
      {required Uint8List bytes,
      required String fileName,
      required String contentType}) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('createReelUploadUrl')
        .call({
      'fileName': fileName,
      'contentType': contentType,
      'size': bytes.length,
    });
    final payload = Map<String, dynamic>.from(result.data as Map);
    final response = await http.put(Uri.parse(payload['uploadUrl'] as String),
        body: bytes, headers: {'Content-Type': contentType});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('UPLOAD_FAILED');
    }
    return payload['publicUrl'] as String;
  }
}
