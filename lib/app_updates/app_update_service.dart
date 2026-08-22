import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_model.dart';

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();
  static const String collectionName = 'app_updates';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUpdateModel?> getLatestActiveUpdate() async {
    final snapshot = await _firestore
        .collection(collectionName)
        .where('isActive', isEqualTo: true)
        .get();

    final updates = snapshot.docs
        .map(AppUpdateModel.fromDocument)
        .where((update) => update.buildNumber > 0)
        .toList()
      ..sort((a, b) => b.buildNumber.compareTo(a.buildNumber));

    return updates.isEmpty ? null : updates.first;
  }

  Future<AppUpdateModel?> getAvailableUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;
    final latest = await getLatestActiveUpdate();

    if (latest == null || latest.buildNumber <= currentBuild) {
      return null;
    }

    if (latest.storeUrl.trim().isEmpty) {
      return null;
    }

    return latest;
  }

  /// للأدمن: يعرض جميع الإصدارات، المنشورة وغير المنشورة.
  Stream<List<AppUpdateModel>> watchUpdates() {
    return _firestore.collection(collectionName).snapshots().map((snapshot) {
      final items = snapshot.docs.map(AppUpdateModel.fromDocument).toList();
      items.sort((a, b) {
        final byBuild = b.buildNumber.compareTo(a.buildNumber);
        if (byBuild != 0) return byBuild;
        return (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
      return items;
    });
  }

  Future<void> createUpdate(AppUpdateModel update) async {
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    if (update.isActive) {
      final active = await _firestore
          .collection(collectionName)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in active.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'publishedAt': null,
          'updatedAt': now,
        });
      }
    }

    final ref = _firestore.collection(collectionName).doc();

    batch.set(ref, {
      ...update.toMap(),
      'isActive': update.isActive,
      'createdAt': now,
      'updatedAt': now,
      'publishedAt': update.isActive ? now : null,
    });

    await batch.commit();
  }

  Future<void> updateUpdate(AppUpdateModel update) async {
    final batch = _firestore.batch();
    final ref = _firestore.collection(collectionName).doc(update.id);

    if (update.isActive) {
      final active = await _firestore
          .collection(collectionName)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in active.docs) {
        if (doc.id == update.id) continue;

        batch.update(doc.reference, {
          'isActive': false,
          'publishedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    batch.update(ref, {
      ...update.toMap(),
      'isActive': update.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'publishedAt': update.isActive
          ? (update.publishedAt == null
              ? FieldValue.serverTimestamp()
              : Timestamp.fromDate(update.publishedAt!))
          : null,
    });

    await batch.commit();
  }

  Future<void> setActive(String id, bool active) async {
    final batch = _firestore.batch();
    final ref = _firestore.collection(collectionName).doc(id);

    if (active) {
      final current = await _firestore
          .collection(collectionName)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in current.docs) {
        if (doc.id == id) continue;

        batch.update(doc.reference, {
          'isActive': false,
          'publishedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    batch.update(ref, {
      'isActive': active,
      'publishedAt': active ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> deleteUpdate(String id) {
    return _firestore.collection(collectionName).doc(id).delete();
  }
}
