import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/office_follower_model.dart';

/// خدمة متابعة المكاتب.
///
/// مسؤولة عن:
/// - متابعة المكتب.
/// - إلغاء المتابعة.
/// - معرفة هل المستخدم يتابع المكتب.
/// - جلب عدد المتابعين.
/// - جلب قائمة المتابعين لصاحب المكتب.
/// - تحديث followersCount في المكتب.
class OfficeFollowerService {
  OfficeFollowerService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ─────────────────────────────────────────────
  // Collections
  // ─────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _followers {
    return _firestore.collection('office_followers');
  }

  CollectionReference<Map<String, dynamic>> get _offices {
    return _firestore.collection('offices');
  }

  // ═════════════════════════════════════════════
  // متابعة مكتب
  // ═════════════════════════════════════════════

  Future<String> followOffice({
    required String officeId,
    required String userId,
    String userName = '',
    String userImageUrl = '',
  }) async {
    // =====================================================
    // جلب بيانات المستخدم الحقيقية من Firestore
    // =====================================================
    String finalUserName = userName.trim();
    String finalUserImageUrl = userImageUrl.trim();

    try {
      final userSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (userSnapshot.exists) {
        final data = userSnapshot.data() ?? {};

        final firestoreName = (data['name'] ?? '').toString().trim();

        final firestorePhoto =
            (data['photo'] ?? data['photoUrl'] ?? '').toString().trim();

        if (firestoreName.isNotEmpty) {
          finalUserName = firestoreName;
        }

        if (firestorePhoto.isNotEmpty) {
          finalUserImageUrl = firestorePhoto;
        }
      }
    } catch (_) {
      // إذا تعذر جلب بيانات المستخدم،
      // نستخدم البيانات المرسلة كاحتياط.
    }

    // الاسم الاحتياطي النهائي
    if (finalUserName.isEmpty) {
      finalUserName = 'مستخدم عقار';
    }

    // =====================================================
    // البحث عن متابعة سابقة
    // =====================================================
    final existing = await _findFollower(
      officeId: officeId,
      userId: userId,
    );

    // =====================================================
    // إذا كانت هناك متابعة سابقة غير فعالة
    // نعيد تفعيلها مع تحديث بيانات المستخدم
    // =====================================================
    if (existing != null) {
      if (!existing.isActive) {
        await _followers.doc(existing.id).update({
          'isActive': true,
          'userName': finalUserName,
          'userImageUrl': finalUserImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return existing.id;
      }

      // حتى لو كانت المتابعة موجودة وفعالة،
      // نحدّث الاسم والصورة لضمان عدم بقاء بيانات قديمة.
      await _followers.doc(existing.id).update({
        'userName': finalUserName,
        'userImageUrl': finalUserImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return existing.id;
    }

    // =====================================================
    // إنشاء متابعة جديدة
    // =====================================================
    final reference = _followers.doc();

    final follower = OfficeFollowerModel.create(
      id: reference.id,
      officeId: officeId,
      userId: userId,
      userName: finalUserName,
      userImageUrl: finalUserImageUrl,
    );

    await reference.set(
      follower.toFirestore(),
    );

    return reference.id;
  }

  // ═════════════════════════════════════════════
  // إلغاء متابعة مكتب
  // ═════════════════════════════════════════════

  Future<void> unfollowOffice({
    required String officeId,
    required String userId,
  }) async {
    final existing = await _findFollower(
      officeId: officeId,
      userId: userId,
    );

    if (existing == null || !existing.isActive) {
      return;
    }

    await _followers.doc(existing.id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ═════════════════════════════════════════════
  // تبديل حالة المتابعة
  // ═════════════════════════════════════════════

  Future<bool> toggleFollow({
    required String officeId,
    required String userId,
    String userName = '',
    String userImageUrl = '',
  }) async {
    final isFollowing = await isFollowingOffice(
      officeId: officeId,
      userId: userId,
    );

    if (isFollowing) {
      await unfollowOffice(
        officeId: officeId,
        userId: userId,
      );

      return false;
    }

    await followOffice(
      officeId: officeId,
      userId: userId,
      userName: userName,
      userImageUrl: userImageUrl,
    );

    return true;
  }

  // ═════════════════════════════════════════════
  // هل المستخدم يتابع المكتب؟
  // ═════════════════════════════════════════════

  Future<bool> isFollowingOffice({
    required String officeId,
    required String userId,
  }) async {
    final follower = await _findFollower(
      officeId: officeId,
      userId: userId,
    );

    return follower?.isActive ?? false;
  }

  // ═════════════════════════════════════════════
  // جلب علاقة المتابعة
  // ═════════════════════════════════════════════

  Future<OfficeFollowerModel?> getFollower({
    required String officeId,
    required String userId,
  }) {
    return _findFollower(
      officeId: officeId,
      userId: userId,
    );
  }

  // ═════════════════════════════════════════════
  // مراقبة حالة المتابعة
  // ═════════════════════════════════════════════

  Stream<bool> watchFollowingStatus({
    required String officeId,
    required String userId,
  }) {
    return _followers
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .where(
          'userId',
          isEqualTo: userId,
        )
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return false;
      }

      final follower = OfficeFollowerModel.fromFirestore(
        snapshot.docs.first,
      );

      return follower.isActive;
    });
  }

  // ═════════════════════════════════════════════
  // جلب متابعي المكتب
  // ═════════════════════════════════════════════

  Stream<List<OfficeFollowerModel>> watchOfficeFollowers(
    String officeId,
  ) {
    return _followers
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .snapshots()
        .map((snapshot) {
      final followers = snapshot.docs
          .map(
            OfficeFollowerModel.fromFirestore,
          )
          .where(
            (follower) => follower.isActive,
          )
          .toList();

      followers.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;

        if (aDate == null && bDate == null) {
          return 0;
        }

        if (aDate == null) {
          return 1;
        }

        if (bDate == null) {
          return -1;
        }

        return bDate.compareTo(aDate);
      });

      return followers;
    });
  }

  // ═════════════════════════════════════════════
  // جلب متابعي المكتب مرة واحدة
  // ═════════════════════════════════════════════

  Future<List<OfficeFollowerModel>> getOfficeFollowers(
    String officeId,
  ) async {
    final snapshot = await _followers
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .get();

    final followers = snapshot.docs
        .map(
          OfficeFollowerModel.fromFirestore,
        )
        .where(
          (follower) => follower.isActive,
        )
        .toList();

    followers.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;

      if (aDate == null && bDate == null) {
        return 0;
      }

      if (aDate == null) {
        return 1;
      }

      if (bDate == null) {
        return -1;
      }

      return bDate.compareTo(aDate);
    });

    return followers;
  }

  // ═════════════════════════════════════════════
  // عدد متابعي المكتب
  // ═════════════════════════════════════════════

  Future<int> getFollowersCount(
    String officeId,
  ) async {
    final snapshot = await _followers
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .where(
          'isActive',
          isEqualTo: true,
        )
        .get();

    return snapshot.docs.length;
  }

  // ═════════════════════════════════════════════
  // مراقبة عدد المتابعين
  // ═════════════════════════════════════════════

  Stream<int> watchFollowersCount(
    String officeId,
  ) {
    return _followers
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .where(
          'isActive',
          isEqualTo: true,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.length,
        );
  }

  // ═════════════════════════════════════════════
  // جلب المكاتب التي يتابعها مستخدم
  // ═════════════════════════════════════════════

  Stream<List<OfficeFollowerModel>> watchUserFollowing(
    String userId,
  ) {
    return _followers
        .where(
          'userId',
          isEqualTo: userId,
        )
        .where(
          'isActive',
          isEqualTo: true,
        )
        .snapshots()
        .map((snapshot) {
      final following = snapshot.docs
          .map(
            OfficeFollowerModel.fromFirestore,
          )
          .toList();

      following.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;

        if (aDate == null && bDate == null) {
          return 0;
        }

        if (aDate == null) {
          return 1;
        }

        if (bDate == null) {
          return -1;
        }

        return bDate.compareTo(aDate);
      });

      return following;
    });
  }

  // ═════════════════════════════════════════════
  // تحديث بيانات المستخدم في المتابعات
  // ═════════════════════════════════════════════

  Future<void> updateFollowerProfile({
    required String userId,
    required String userName,
    required String userImageUrl,
  }) async {
    final snapshot = await _followers
        .where(
          'userId',
          isEqualTo: userId,
        )
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final document in snapshot.docs) {
      batch.update(
        document.reference,
        {
          'userName': userName,
          'userImageUrl': userImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
  }

  // ═════════════════════════════════════════════
  // إعادة مزامنة عدد المتابعين
  //
  // مفيدة إذا حدث اختلاف بين followersCount
  // الموجود في المكتب والعدد الحقيقي في collection.
  // ═════════════════════════════════════════════

  Future<int> syncFollowersCount(
    String officeId,
  ) async {
    final count = await getFollowersCount(
      officeId,
    );

    await _offices.doc(officeId).update({
      'followersCount': count,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return count;
  }

  // ═════════════════════════════════════════════
  // البحث عن علاقة متابعة
  // ═════════════════════════════════════════════

  Future<OfficeFollowerModel?> _findFollower({
    required String officeId,
    required String userId,
  }) async {
    final snapshot = await _followers
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .where(
          'userId',
          isEqualTo: userId,
        )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return OfficeFollowerModel.fromFirestore(
      snapshot.docs.first,
    );
  }

  // ═════════════════════════════════════════════
  // تحديث عدد المتابعين
  // ═════════════════════════════════════════════
}
