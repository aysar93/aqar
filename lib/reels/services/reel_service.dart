import 'package:aqar/moderation/user_blocks.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../../core/data/paged_query.dart';
import '../../core/data/document_read_cache.dart';

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

  Query<Map<String, dynamic>> get publicQuery => _db
      .collection('reels')
      .where('status', whereIn: ['published', 'scheduled'])
      .orderBy('isPinned', descending: true)
      .orderBy('sortOrder')
      .orderBy('publishAt', descending: true);

  ReelFeedController createFeed() => ReelFeedController(this);

  Future<bool> _visibleToViewer(ReelModel reel) async {
    if (!reel.isCurrentlyVisible) return false;
    try {
      for (final entry in {
        'properties': reel.propertyId,
        'offices': reel.officeId
      }.entries) {
        if (entry.value == null || entry.value!.isEmpty) continue;
        final doc =
            await DocumentReadCache.instance.get('${entry.key}/${entry.value}');
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

/// One bounded subscription survives swipes. More pages are explicit cursor
/// reads, and related-document reads share a short actor-scoped TTL cache.
class ReelFeedController extends ChangeNotifier {
  ReelFeedController(this.service) {
    pages = PagedQueryController(service.publicQuery, pageSize: 20, safe: true);
    pages.addListener(_validate);
    pages.start();
  }
  final ReelService service;
  late final PagedQueryController<Map<String, dynamic>> pages;
  List<ReelModel> reels = [];
  bool loaded = false;
  Object? error;
  ReelModel? _initial;
  Future<void> includeInitial(String id) async {
    try {
      final doc = await DocumentReadCache.instance.get('reels/$id');
      if (!doc.exists || _disposed) return;
      final model = ReelModel.fromDocument(doc);
      if (await service._visibleToViewer(model) && !_disposed) {
        _initial = model;
        await _validate();
      }
    } catch (_) {/* Deleted/inaccessible deep links never widen the feed. */}
  }

  bool _disposed = false;
  int _revision = 0;
  Future<void> _validate() async {
    final revision = ++_revision;
    error = pages.error;
    if (!UserBlocks.instance.ready) {
      if (!_disposed) notifyListeners();
      return;
    }
    if (pages.snapshot.hasData) {
      final result = await Future.wait(pages.documents.map((doc) async {
        final reel = ReelModel.fromDocument(doc);
        return await service._visibleToViewer(reel) ? reel : null;
      }));
      if (_disposed || revision != _revision) return;
      reels = result.whereType<ReelModel>().toList();
      if (_initial != null &&
          !reels.any((r) => r.id == _initial!.id) &&
          await service._visibleToViewer(_initial!) &&
          !_disposed &&
          revision == _revision) {
        reels.insert(0, _initial!);
      }
      if (_disposed || revision != _revision) return;
      loaded = true;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> loadMore() => pages.loadMore();
  Future<void> checkCurrent(ReelModel reel) async {
    // Recheck on activation; the short shared cache avoids repeated reads.
    // No timer, and deleted/blocked targets cannot remain playable forever.
    final visible = await service._visibleToViewer(reel);
    if (!_disposed && !visible) {
      reels.removeWhere((candidate) => candidate.id == reel.id);
      notifyListeners();
    }
  }

  Future<void> loadCategoryCatalog() async {
    // Preserve the old 100-record category catalogue, on demand only.
    while (!_disposed && pages.hasMore && pages.documents.length < 100) {
      if (pages.loadingMore) return;
      await pages.loadMore();
      if (pages.error != null) return;
    }
    await _validate();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    pages.dispose();
    super.dispose();
  }
}
