import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/office_statistics_model.dart';

/// خدمة إحصائيات المكتب.
///
/// تجمع إحصائيات المكتب من:
/// - العقارات.
/// - المشاهدات.
/// - المفضلة.
/// - المشاركات.
/// - المتابعين.
/// - التقييمات.
/// - الاتصالات.
/// - الواتساب.
/// - الموقع.
/// - التواصل.
///
/// ملاحظة:
/// هذه الخدمة لا تعتمد على انتهاء الاشتراك.
/// الاشتراك يحدد صلاحية ظهور/استخدام المكتب،
/// بينما الإحصائيات تبقى محفوظة.
class OfficeStatisticsService {
  OfficeStatisticsService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ─────────────────────────────────────────────
  // Collections
  // ─────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _offices {
    return _firestore.collection('offices');
  }

  CollectionReference<Map<String, dynamic>> get _properties {
    return _firestore.collection('properties');
  }

  CollectionReference<Map<String, dynamic>> get _reviews {
    return _firestore.collection('office_reviews');
  }

  CollectionReference<Map<String, dynamic>> get _followers {
    return _firestore.collection('office_followers');
  }

  CollectionReference<Map<String, dynamic>> get _officeEvents {
    return _firestore.collection('office_events');
  }

  // ═════════════════════════════════════════════
  // جلب إحصائيات المكتب
  // ═════════════════════════════════════════════

  Future<OfficeStatisticsModel> getStatistics(
    String officeId,
  ) async {
    final officeSnapshot = await _offices.doc(officeId).get();

    if (!officeSnapshot.exists) {
      throw StateError(
        'المكتب غير موجود',
      );
    }

    final officeData = officeSnapshot.data() ?? {};

    final propertiesSnapshot = await _properties
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .get();

    final reviewsSnapshot = await _reviews
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .get();

    final followersSnapshot = await _followers
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .where(
          'isActive',
          isEqualTo: true,
        )
        .get();

    final eventsSnapshot = await _officeEvents
        .where(
          'officeId',
          isEqualTo: officeId,
        )
        .get();

    final properties = propertiesSnapshot.docs;
    final reviews = reviewsSnapshot.docs;
    final events = eventsSnapshot.docs;

    int activeProperties = 0;
    int pendingProperties = 0;
    int rejectedProperties = 0;
    int soldProperties = 0;
    int rentedProperties = 0;

    int totalViews = 0;
    int totalFavorites = 0;
    int totalShares = 0;

    // المشاهدات نوعان:
    // 1) مشاهدة صفحة المكتب: view بدون propertyId.
    // 2) مشاهدة عقار: view مع propertyId.
    //
    // نستخدم عداد views المخزن داخل العقارات، ونستعين بأحداث
    // المشاهدة القديمة إذا كانت قيمة views ناقصة.
    int eventPropertyViews = 0;
    int officeProfileViews = 0;

    for (final event in events) {
      final eventData = event.data();

      if ((eventData['type']?.toString() ?? '') != 'view') {
        continue;
      }

      final propertyId = eventData['propertyId']?.toString().trim() ?? '';

      if (propertyId.isEmpty) {
        officeProfileViews++;
      } else {
        eventPropertyViews++;
      }
    }

    for (final property in properties) {
      final data = property.data();

      final status = data['status']?.toString().toLowerCase() ?? '';

      final availabilityStatus =
          data['availabilityStatus']?.toString().toLowerCase() ?? '';

      if (_isActiveProperty(
        status: status,
        availabilityStatus: availabilityStatus,
      )) {
        activeProperties++;
      }

      if (status == 'pending') {
        pendingProperties++;
      }

      if (status == 'rejected') {
        rejectedProperties++;
      }

      if (_isSoldStatus(availabilityStatus)) {
        soldProperties++;
      }

      if (_isRentedStatus(availabilityStatus)) {
        rentedProperties++;
      }

      totalViews += _intValue(
        data['views'],
      );

      totalFavorites += _intValue(
        data['favorites'],
      );

      totalShares += _intValue(
        data['shares'],
      );
    }

    final publishedReviews = reviews.where((document) {
      final data = document.data();

      return (data['status']?.toString() ?? 'published') == 'published';
    }).toList();

    double averageRating = 0;

    if (publishedReviews.isNotEmpty) {
      double ratingTotal = 0;

      for (final review in publishedReviews) {
        ratingTotal += _doubleValue(
          review.data()['rating'],
        );
      }

      averageRating = ratingTotal / publishedReviews.length;
    }

    // نحافظ على المشاهدات التاريخية الموجودة داخل العقارات،
    // ونكملها بأحداث المشاهدة القديمة عند الحاجة.
    if (eventPropertyViews > totalViews) {
      totalViews = eventPropertyViews;
    }

    // مشاهدة صفحة المكتب لا تدخل في properties.views.
    totalViews += officeProfileViews;

    final eventStats = _calculateEventStatistics(
      events,
    );

    final statistics = OfficeStatisticsModel(
      officeId: officeId,
      totalProperties: properties.length,
      activeProperties: activeProperties,
      pendingProperties: pendingProperties,
      rejectedProperties: rejectedProperties,
      soldProperties: soldProperties,
      rentedProperties: rentedProperties,
      totalViews: totalViews,
      totalFavorites: totalFavorites,
      totalShares: totalShares,
      followersCount: followersSnapshot.docs.length,
      reviewsCount: publishedReviews.length,
      averageRating: averageRating,
      phoneClicks: eventStats.phoneClicks,
      whatsappClicks: eventStats.whatsappClicks,
      locationClicks: eventStats.locationClicks,
      contactClicks: eventStats.contactClicks,
      viewsToday: eventStats.viewsToday,
      viewsThisWeek: eventStats.viewsThisWeek,
      viewsThisMonth: eventStats.viewsThisMonth,
      inquiriesToday: eventStats.inquiriesToday,
      inquiriesThisWeek: eventStats.inquiriesThisWeek,
      inquiriesThisMonth: eventStats.inquiriesThisMonth,
      updatedAt: DateTime.now(),
    );

    // الاحتفاظ بالقيم الموجودة في المكتب
    // إذا كانت هناك قيم إضافية مستقبلًا.
    //
    // نستخدم officeData هنا للتأكد من أن القراءة
    // من Firestore تمت بنجاح وحتى لا يكون وجود
    // الحقل إجباريًا.
    officeData;

    return statistics;
  }

  // ═════════════════════════════════════════════
  // مراقبة إحصائيات المكتب
  // ═════════════════════════════════════════════

  Stream<OfficeStatisticsModel> watchStatistics(
    String officeId,
  ) {
    return _offices.doc(officeId).snapshots().asyncMap(
      (_) async {
        return getStatistics(officeId);
      },
    );
  }

  // ═════════════════════════════════════════════
  // تسجيل مشاهدة
  // ═════════════════════════════════════════════

  Future<void> recordView({
    required String officeId,
    String? userId,
    String? propertyId,
  }) async {
    await _recordEvent(
      officeId: officeId,
      type: 'view',
      userId: userId,
      propertyId: propertyId,
    );

    if (propertyId != null && propertyId.trim().isNotEmpty) {
      await _properties.doc(propertyId).update({
        'views': FieldValue.increment(1),
      });
    }
  }

  // ═════════════════════════════════════════════
  // تسجيل مشاركة
  // ═════════════════════════════════════════════

  Future<void> recordShare({
    required String officeId,
    String? userId,
    String? propertyId,
  }) async {
    await _recordEvent(
      officeId: officeId,
      type: 'share',
      userId: userId,
      propertyId: propertyId,
    );

    if (propertyId != null && propertyId.trim().isNotEmpty) {
      await _properties.doc(propertyId).update({
        'shares': FieldValue.increment(1),
      });
    }
  }

  // ═════════════════════════════════════════════
  // تسجيل ضغط اتصال
  // ═════════════════════════════════════════════

  Future<void> recordPhoneClick({
    required String officeId,
    String? userId,
  }) async {
    await _recordEvent(
      officeId: officeId,
      type: 'phone',
      userId: userId,
    );
  }

  // ═════════════════════════════════════════════
  // تسجيل ضغط واتساب
  // ═════════════════════════════════════════════

  Future<void> recordWhatsappClick({
    required String officeId,
    String? userId,
  }) async {
    await _recordEvent(
      officeId: officeId,
      type: 'whatsapp',
      userId: userId,
    );
  }

  // ═════════════════════════════════════════════
  // تسجيل ضغط الموقع
  // ═════════════════════════════════════════════

  Future<void> recordLocationClick({
    required String officeId,
    String? userId,
  }) async {
    await _recordEvent(
      officeId: officeId,
      type: 'location',
      userId: userId,
    );
  }

  // ═════════════════════════════════════════════
  // تسجيل رسالة
  // ═════════════════════════════════════════════

  Future<void> recordContactClick({
    required String officeId,
    String? userId,
  }) async {
    await _recordEvent(
      officeId: officeId,
      type: 'contact',
      userId: userId,
    );
  }

  // ═════════════════════════════════════════════
  // تسجيل استفسار
  // ═════════════════════════════════════════════

  Future<void> recordInquiry({
    required String officeId,
    String? userId,
    String? propertyId,
  }) async {
    await _recordEvent(
      officeId: officeId,
      type: 'inquiry',
      userId: userId,
      propertyId: propertyId,
    );
  }

  // ═════════════════════════════════════════════
  // تسجيل حدث عام
  // ═════════════════════════════════════════════

  Future<void> _recordEvent({
    required String officeId,
    required String type,
    String? userId,
    String? propertyId,
  }) async {
    await _officeEvents.add({
      'officeId': officeId,
      'type': type,
      'userId': userId,
      'propertyId': propertyId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // تحديث طابع المزامنة يجعل watchStatistics يعيد الحساب
    // مباشرة بعد تسجيل أي مشاهدة أو نقرة.
    await _touchStatistics(officeId);
  }

  Future<void> _touchStatistics(String officeId) async {
    try {
      await _offices.doc(officeId).update({
        'statisticsUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // لا نفشل تسجيل الحدث إذا تعذر تحديث طابع المزامنة.
    }
  }

  // ═════════════════════════════════════════════
  // حساب إحصائيات الأحداث
  // ═════════════════════════════════════════════

  _EventStatistics _calculateEventStatistics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
  ) {
    final now = DateTime.now();

    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final weekStart = todayStart.subtract(const Duration(days: 7));

    final monthStart = DateTime(
      now.year,
      now.month,
      1,
    );

    int phoneClicks = 0;
    int whatsappClicks = 0;
    int locationClicks = 0;
    int contactClicks = 0;

    int viewsToday = 0;
    int viewsThisWeek = 0;
    int viewsThisMonth = 0;

    int inquiriesToday = 0;
    int inquiriesThisWeek = 0;
    int inquiriesThisMonth = 0;

    for (final document in events) {
      final data = document.data();

      final type = data['type']?.toString() ?? '';

      final createdAt = _dateValue(data['createdAt']);

      if (type == 'phone') {
        phoneClicks++;
      }

      if (type == 'whatsapp') {
        whatsappClicks++;
      }

      if (type == 'location') {
        locationClicks++;
      }

      if (type == 'contact') {
        contactClicks++;
      }

      if (createdAt != null) {
        if (type == 'view') {
          if (!createdAt.isBefore(todayStart)) {
            viewsToday++;
          }

          if (!createdAt.isBefore(weekStart)) {
            viewsThisWeek++;
          }

          if (!createdAt.isBefore(monthStart)) {
            viewsThisMonth++;
          }
        }

        if (type == 'inquiry') {
          if (!createdAt.isBefore(todayStart)) {
            inquiriesToday++;
          }

          if (!createdAt.isBefore(weekStart)) {
            inquiriesThisWeek++;
          }

          if (!createdAt.isBefore(monthStart)) {
            inquiriesThisMonth++;
          }
        }
      }
    }

    return _EventStatistics(
      phoneClicks: phoneClicks,
      whatsappClicks: whatsappClicks,
      locationClicks: locationClicks,
      contactClicks: contactClicks,
      viewsToday: viewsToday,
      viewsThisWeek: viewsThisWeek,
      viewsThisMonth: viewsThisMonth,
      inquiriesToday: inquiriesToday,
      inquiriesThisWeek: inquiriesThisWeek,
      inquiriesThisMonth: inquiriesThisMonth,
    );
  }

  // ═════════════════════════════════════════════
  // هل العقار نشط؟
  // ═════════════════════════════════════════════

  bool _isActiveProperty({
    required String status,
    required String availabilityStatus,
  }) {
    if (status == 'approved' || status == 'active' || status == 'published') {
      if (_isSoldStatus(availabilityStatus) ||
          _isRentedStatus(availabilityStatus)) {
        return false;
      }

      return true;
    }

    return false;
  }

  // ═════════════════════════════════════════════
  // هل العقار مباع؟
  // ═════════════════════════════════════════════

  bool _isSoldStatus(String status) {
    return status == 'sold' || status == 'مباع' || status == 'تم البيع';
  }

  // ═════════════════════════════════════════════
  // هل العقار مؤجر؟
  // ═════════════════════════════════════════════

  bool _isRentedStatus(String status) {
    return status == 'rented' || status == 'مؤجر' || status == 'تم الإيجار';
  }

  // ═════════════════════════════════════════════
  // تحويل رقم إلى int
  // ═════════════════════════════════════════════

  int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ═════════════════════════════════════════════
  // تحويل رقم إلى double
  // ═════════════════════════════════════════════

  double _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ═════════════════════════════════════════════
  // تحويل التاريخ
  // ═════════════════════════════════════════════

  DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}

// ═══════════════════════════════════════════════
// نموذج داخلي لإحصائيات الأحداث
// ═══════════════════════════════════════════════

class _EventStatistics {
  final int phoneClicks;
  final int whatsappClicks;
  final int locationClicks;
  final int contactClicks;

  final int viewsToday;
  final int viewsThisWeek;
  final int viewsThisMonth;

  final int inquiriesToday;
  final int inquiriesThisWeek;
  final int inquiriesThisMonth;

  const _EventStatistics({
    required this.phoneClicks,
    required this.whatsappClicks,
    required this.locationClicks,
    required this.contactClicks,
    required this.viewsToday,
    required this.viewsThisWeek,
    required this.viewsThisMonth,
    required this.inquiriesToday,
    required this.inquiriesThisWeek,
    required this.inquiriesThisMonth,
  });
}
