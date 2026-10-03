import '../../moderation/content_policy.dart';
import 'package:aqar/moderation/user_blocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/office_review_model.dart';

/// خدمة تقييمات المكاتب.
///
/// مسؤوليتها:
/// - إنشاء التقييمات.
/// - جلب تقييمات المكتب.
/// - تعديل تقييم المستخدم.
/// - حذف تقييم المستخدم.
/// - إضافة رد صاحب المكتب.
/// - إخفاء وإظهار التقييم.
/// - تحديث إحصائيات المكتب المتعلقة بالتقييمات.
class OfficeReviewService {
  OfficeReviewService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ─────────────────────────────────────────────
  // Collections
  // ─────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _reviews {
    return _firestore.collection('office_reviews');
  }

  CollectionReference<Map<String, dynamic>> get _offices {
    return _firestore.collection('offices');
  }

  // ═════════════════════════════════════════════
  // إضافة تقييم
  // ═════════════════════════════════════════════

  Future<String> addReview({
    required String officeId,
    required String userId,
    required double rating,
    String userName = '',
    String userImageUrl = '',
    String comment = '',
  }) async {
    ContentPolicy.validate(comment);
    final normalizedRating = _normalizeRating(rating);

    final existingReview = await _reviews
        .where('officeId', isEqualTo: officeId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (existingReview.docs.isNotEmpty) {
      throw StateError(
        'لا يمكن للمستخدم إضافة أكثر من تقييم واحد لنفس المكتب',
      );
    }

    // Preserve legacy reviews while preventing duplicate first submissions
    // from creating two distinct documents for one user/office relationship.
    final reviewReference = _reviews.doc('${officeId}_$userId');

    final review = OfficeReviewModel.create(
      id: reviewReference.id,
      officeId: officeId,
      userId: userId,
      rating: normalizedRating,
      userName: userName,
      userImageUrl: userImageUrl,
      comment: comment,
    );

    await reviewReference.set(
      review.toFirestore(),
    );

    return reviewReference.id;
  }

  // ═════════════════════════════════════════════
  // جلب تقييمات المكتب
  // ═════════════════════════════════════════════

  Stream<List<OfficeReviewModel>> watchOfficeReviews(
    String officeId, {
    bool includeHidden = false,
  }) {
    return _reviews
        .where('officeId', isEqualTo: officeId)
        .safeSnapshots()
        .map((snapshot) {
      final reviews = snapshot.docs
          .map(
        OfficeReviewModel.fromFirestore,
      )
          .where((review) {
        if (includeHidden) {
          return true;
        }

        return review.isPublished;
      }).toList();

      reviews.sort((a, b) {
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

      return reviews;
    });
  }

  // ═════════════════════════════════════════════
  // جلب تقييمات المكتب مرة واحدة
  // ═════════════════════════════════════════════

  Future<List<OfficeReviewModel>> getOfficeReviews(
    String officeId, {
    bool includeHidden = false,
  }) async {
    final snapshot =
        await _reviews.where('officeId', isEqualTo: officeId).get();

    final reviews = snapshot.docs
        .map(
      OfficeReviewModel.fromFirestore,
    )
        .where((review) {
      if (includeHidden) {
        return true;
      }

      return review.isPublished;
    }).toList();

    reviews.sort((a, b) {
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

    return reviews;
  }

  // ═════════════════════════════════════════════
  // جلب تقييم مستخدم لمكتب معين
  // ═════════════════════════════════════════════

  Future<OfficeReviewModel?> getUserReview({
    required String officeId,
    required String userId,
  }) async {
    final snapshot = await _reviews
        .where('officeId', isEqualTo: officeId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return OfficeReviewModel.fromFirestore(
      snapshot.docs.first,
    );
  }

  // ═════════════════════════════════════════════
  // هل المستخدم قيّم المكتب؟
  // ═════════════════════════════════════════════

  Future<bool> hasUserReviewed({
    required String officeId,
    required String userId,
  }) async {
    final review = await getUserReview(
      officeId: officeId,
      userId: userId,
    );

    return review != null;
  }

  // ═════════════════════════════════════════════
  // تعديل تقييم المستخدم
  // ═════════════════════════════════════════════

  Future<void> updateReview({
    required String reviewId,
    required String userId,
    required double rating,
    String? comment,
  }) async {
    final reference = _reviews.doc(reviewId);

    final snapshot = await reference.get();

    if (!snapshot.exists) {
      throw StateError(
        'التقييم غير موجود',
      );
    }

    final review = OfficeReviewModel.fromFirestore(
      snapshot,
    );

    if (review.userId != userId) {
      throw StateError(
        'لا يمكنك تعديل تقييم مستخدم آخر',
      );
    }

    if (comment != null) ContentPolicy.validate(comment);
    await reference.update({
      'rating': _normalizeRating(rating),
      if (comment != null) 'comment': comment.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Server-maintained rating summary; no child collection recount.
  }

  // ═════════════════════════════════════════════
  // حذف تقييم المستخدم
  // ═════════════════════════════════════════════

  Future<void> deleteReview({
    required String reviewId,
    required String userId,
  }) async {
    final reference = _reviews.doc(reviewId);

    final snapshot = await reference.get();

    if (!snapshot.exists) {
      return;
    }

    final review = OfficeReviewModel.fromFirestore(
      snapshot,
    );

    if (review.userId != userId) {
      throw StateError(
        'لا يمكنك حذف تقييم مستخدم آخر',
      );
    }

    await reference.delete();

    // Server-maintained rating summary; no child collection recount.
  }

  // ═════════════════════════════════════════════
  // رد صاحب المكتب
  // ═════════════════════════════════════════════

  Future<void> addOwnerReply({
    required String reviewId,
    required String officeId,
    required String ownerId,
    required String reply,
  }) async {
    final trimmedReply = reply.trim();

    if (trimmedReply.isEmpty) {
      throw ArgumentError(
        'يجب كتابة الرد قبل إرساله',
      );
    }

    await _verifyOfficeOwner(
      officeId: officeId,
      ownerId: ownerId,
    );

    final reference = _reviews.doc(reviewId);

    final snapshot = await reference.get();

    if (!snapshot.exists) {
      throw StateError(
        'التقييم غير موجود',
      );
    }

    final review = OfficeReviewModel.fromFirestore(
      snapshot,
    );

    if (review.officeId != officeId) {
      throw StateError(
        'هذا التقييم لا يتبع المكتب المحدد',
      );
    }

    ContentPolicy.validate(trimmedReply);
    await reference.update({
      'hasOwnerReply': true,
      'ownerReply': trimmedReply,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ═════════════════════════════════════════════
  // حذف رد صاحب المكتب
  // ═════════════════════════════════════════════

  Future<void> removeOwnerReply({
    required String reviewId,
    required String officeId,
    required String ownerId,
  }) async {
    await _verifyOfficeOwner(
      officeId: officeId,
      ownerId: ownerId,
    );

    final reference = _reviews.doc(reviewId);

    final snapshot = await reference.get();

    if (!snapshot.exists) {
      return;
    }

    final review = OfficeReviewModel.fromFirestore(
      snapshot,
    );

    if (review.officeId != officeId) {
      throw StateError(
        'هذا التقييم لا يتبع المكتب المحدد',
      );
    }

    await reference.update({
      'hasOwnerReply': false,
      'ownerReply': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ═════════════════════════════════════════════
  // إخفاء تقييم
  // ═════════════════════════════════════════════

  Future<void> hideReview({
    required String reviewId,
    required String officeId,
    required String ownerId,
  }) async {
    await _verifyOfficeOwner(
      officeId: officeId,
      ownerId: ownerId,
    );

    final reference = _reviews.doc(reviewId);

    final snapshot = await reference.get();

    if (!snapshot.exists) {
      return;
    }

    final review = OfficeReviewModel.fromFirestore(
      snapshot,
    );

    if (review.officeId != officeId) {
      throw StateError(
        'هذا التقييم لا يتبع المكتب المحدد',
      );
    }

    await reference.update({
      'status': 'hidden',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Rating summaries are maintained atomically by server triggers.
  }

  // ═════════════════════════════════════════════
  // إعادة نشر تقييم
  // ═════════════════════════════════════════════

  Future<void> publishReview({
    required String reviewId,
    required String officeId,
    required String ownerId,
  }) async {
    await _verifyOfficeOwner(
      officeId: officeId,
      ownerId: ownerId,
    );

    final reference = _reviews.doc(reviewId);

    final snapshot = await reference.get();

    if (!snapshot.exists) {
      return;
    }

    final review = OfficeReviewModel.fromFirestore(
      snapshot,
    );

    if (review.officeId != officeId) {
      throw StateError(
        'هذا التقييم لا يتبع المكتب المحدد',
      );
    }

    await reference.update({
      'status': 'published',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Rating summaries are maintained atomically by server triggers.
  }

  // ═════════════════════════════════════════════
  // حذف تقييم بواسطة صاحب المكتب
  // ═════════════════════════════════════════════

  Future<void> deleteReviewByOwner({
    required String reviewId,
    required String officeId,
    required String ownerId,
  }) async {
    await _verifyOfficeOwner(
      officeId: officeId,
      ownerId: ownerId,
    );

    final reference = _reviews.doc(reviewId);

    final snapshot = await reference.get();

    if (!snapshot.exists) {
      return;
    }

    final review = OfficeReviewModel.fromFirestore(
      snapshot,
    );

    if (review.officeId != officeId) {
      throw StateError(
        'هذا التقييم لا يتبع المكتب المحدد',
      );
    }

    await reference.delete();

    // Rating summaries are maintained atomically by server triggers.
  }

  // ═════════════════════════════════════════════
  // حساب متوسط التقييم
  // ═════════════════════════════════════════════

  Future<double> calculateAverageRating(
    String officeId,
  ) async {
    final snapshot =
        await _reviews.where('officeId', isEqualTo: officeId).get();

    final publishedReviews = snapshot.docs
        .map(
          OfficeReviewModel.fromFirestore,
        )
        .where((review) => review.isPublished)
        .toList();

    if (publishedReviews.isEmpty) {
      return 0;
    }

    double total = 0;

    for (final review in publishedReviews) {
      total += review.rating;
    }

    return total / publishedReviews.length;
  }

  // ═════════════════════════════════════════════
  // إعادة حساب تقييم المكتب بالكامل
  // ═════════════════════════════════════════════

  Future<void> _verifyOfficeOwner({
    required String officeId,
    required String ownerId,
  }) async {
    final officeSnapshot = await _offices.doc(officeId).get();

    if (!officeSnapshot.exists) {
      throw StateError(
        'المكتب غير موجود',
      );
    }

    final data = officeSnapshot.data();

    final actualOwnerId = data?['ownerId'] as String? ?? '';

    if (actualOwnerId != ownerId) {
      throw StateError(
        'ليس لديك صلاحية إدارة هذا المكتب',
      );
    }
  }

  // ═════════════════════════════════════════════
  // Helper
  // ═════════════════════════════════════════════

  double _normalizeRating(double value) {
    if (value < 1) {
      return 1;
    }

    if (value > 5) {
      return 5;
    }

    return value;
  }
}
