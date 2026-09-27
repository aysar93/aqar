import 'content_policy.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Per-viewer blocks. The original snapshots are retained so an unblock restores
/// content without another network request. An account switch clears all state.
class UserBlocks extends ChangeNotifier {
  UserBlocks._();
  static final instance = UserBlocks._();
  StreamSubscription<User?>? _auth;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Set<String> _users = {}, _offices = {};
  bool ready = false;
  String? _uid;
  void initialize() {
    _auth ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      _subscription?.cancel();
      _uid = user?.uid;
      _users = {};
      _offices = {};
      ready = user == null;
      notifyListeners();
      if (user == null) return;
      final uid = user.uid;
      _subscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('blockedUsers')
          .snapshots()
          .listen((snapshot) {
        if (_uid != uid) return;
        _users = snapshot.docs.map((d) => d.id).toSet();
        _offices = snapshot.docs
            .map((d) => d.data()['officeId']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        ready = true;
        notifyListeners();
      }, onError: (Object error) {
        // Fail closed: never expose a blocked publisher when loading fails.
        ready = false;
        notifyListeners();
      });
    });
  }

  final Map<String, Map<String, dynamic>> _targets = {};
  void rememberTarget(String path, Map<String, dynamic> data) {
    _targets[path] = data;
  }

  bool hides(Map<String, dynamic> data) {
    if (!ready || isBlockedContent(data, _users, _offices)) return true;
    for (final entry in {
      'properties': data['propertyId'],
      'offices': data['officeId']
    }.entries) {
      final target = _targets['${entry.key}/${entry.value}'];
      if (target != null && isBlockedContent(target, _users, _offices))
        return true;
    }
    return false;
  }

  Future<void> block(String targetUid,
      {String targetPath = '', String officeId = ''}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || targetUid.isEmpty || uid == targetUid) {
      throw StateError('سجّل الدخول لحظر مستخدم آخر.');
    }
    final db = FirebaseFirestore.instance;
    final report = db.collection('user_reports').doc();
    final batch = db.batch();
    batch.set(
        db
            .collection('users')
            .doc(uid)
            .collection('blockedUsers')
            .doc(targetUid),
        {
          'targetUid': targetUid,
          'officeId': officeId,
          'reportId': report.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
    batch.set(report, {
      'userId': uid,
      'targetUid': targetUid,
      'targetPath': targetPath,
      'reason': 'حظر مستخدم مسيء',
      'details': '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Optimistic hiding is immediate; a rejected write restores the old state.
    final oldUsers = Set<String>.from(_users),
        oldOffices = Set<String>.from(_offices);
    _users.add(targetUid);
    if (officeId.isNotEmpty) _offices.add(officeId);
    notifyListeners();
    try {
      await batch.commit();
    } catch (_) {
      if (_uid == uid) {
        _users = oldUsers;
        _offices = oldOffices;
        notifyListeners();
      }
      rethrow;
    }
  }
}

Future<void> showBlockUserDialog(BuildContext context, String uid,
    {String targetPath = '', String officeId = ''}) async {
  if (FirebaseAuth.instance.currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول أولاً لحظر المستخدم.')));
    return;
  }
  if (uid.isEmpty || uid == FirebaseAuth.instance.currentUser?.uid) return;
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('حظر المستخدم؟'),
            content: const Text(
                'ستختفي إعلاناته ومحتواه عنك فوراً، وسنرسل بلاغاً للإدارة لمراجعته.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('حظر وإبلاغ الإدارة'))
            ],
          ));
  if (confirmed != true) return;
  try {
    await UserBlocks.instance
        .block(uid, targetPath: targetPath, officeId: officeId);
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحظر وإرسال البلاغ للإدارة.')));
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر حفظ الحظر. تحقق من الاتصال وأعد المحاولة.')));
  }
}

/// Re-emits cached query results on a block, including already mounted feeds.
extension SafeQuery<T extends Object?> on Query<T> {
  Stream<QuerySnapshot<T>> safeSnapshots() {
    late StreamController<QuerySnapshot<T>> controller;
    StreamSubscription<QuerySnapshot<T>>? subscription;
    QuerySnapshot<T>? latest;
    void emit() {
      if (latest != null && !controller.isClosed)
        controller.add(_VisibleSnapshot(latest!));
    }

    controller = StreamController<QuerySnapshot<T>>(
      onListen: () {
        UserBlocks.instance.addListener(emit);
        subscription = snapshots().listen((s) {
          latest = s;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        UserBlocks.instance.removeListener(emit);
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}

class _VisibleSnapshot<T extends Object?> implements QuerySnapshot<T> {
  _VisibleSnapshot(this.source);
  final QuerySnapshot<T> source;
  @override
  List<QueryDocumentSnapshot<T>> get docs => source.docs.where((doc) {
        final data = doc.data();
        return data is! Map ||
            !UserBlocks.instance.hides(Map<String, dynamic>.from(data));
      }).toList();
  @override
  int get size => docs.length;
  @override
  SnapshotMetadata get metadata => source.metadata;
  @override
  List<DocumentChange<T>> get docChanges => []; // Consumers use full snapshots.
}

bool hiddenForViewer(BuildContext context, Map<String, dynamic> data) {
  // InheritedNotifier subscribes even when a detail page holds static route data.
  context.dependOnInheritedWidgetOfExactType<BlockScope>();
  return UserBlocks.instance.hides(data);
}

class BlockScope extends InheritedNotifier<UserBlocks> {
  BlockScope({super.key, required super.child})
      : super(notifier: UserBlocks.instance);
}

Widget blockedContentPage() => Scaffold(
    appBar: AppBar(title: const Text('المحتوى غير متاح')),
    body: const Center(
        child: Text('هذا المحتوى مخفي وفق إعدادات الحظر أو المراجعة.')));

/// Pure policy shared by all feeds, nested reel snapshots and detail pages.
bool isBlockedContent(
    Map<String, dynamic> data, Set<String> users, Set<String> offices) {
  if (data['isHidden'] == true) return true;
  if (['title', 'description', 'text', 'comment', 'ownerReply']
      .any((key) => data[key] is String && ContentPolicy.rejects(data[key])))
    return true;
  if (['userId', 'publisherUid', 'ownerId', 'authorId']
      .any((key) => users.contains(data[key]))) return true;
  if (offices.contains(data['officeId'])) return true;
  for (final key in ['propertySnapshot', 'officeSnapshot']) {
    if (data[key] is Map &&
        isBlockedContent(Map<String, dynamic>.from(data[key]), users, offices))
      return true;
  }
  return false;
}
