import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_stats/app_stats.dart';

/// خدمة مسؤولة عن جلب الإحصائيات العامة لمنصة "عقار".
///
/// عدد العقارات يتم احتسابه مباشرة من properties.
///
/// عدد المستخدمين يتم قراءته من المستند العام:
/// settings/publicStats
///
/// وذلك حتى يستطيع الضيف والمستخدم والأدمن قراءة العدد
/// بدون منح صلاحية قراءة Collection users.
class AppStatsService {
  final FirebaseFirestore _firestore;

  AppStatsService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================================
  // العقارات
  // ============================================================

  CollectionReference<Map<String, dynamic>> get _properties =>
      _firestore.collection('properties');

  // ============================================================
  // الإحصائيات العامة
  // ============================================================

  DocumentReference<Map<String, dynamic>> get _publicStats =>
      _firestore.collection('settings').doc('publicStats');

  // ============================================================
  // جلب جميع الإحصائيات
  // ============================================================

  Future<AppStats> getAppStats() async {
    try {
      final results = await Future.wait<int>([
        getApprovedPropertiesCount(),
        getUsersCount(),
      ]);

      return AppStats(
        propertiesCount: results[0],
        usersCount: results[1],
      );
    } on FirebaseException catch (error) {
      throw AppStatsException(
        message: _firebaseErrorMessage(error),
        code: error.code,
        originalError: error,
      );
    } catch (error) {
      if (error is AppStatsException) {
        rethrow;
      }

      throw AppStatsException(
        message: 'تعذر تحميل إحصائيات المنصة',
        originalError: error,
      );
    }
  }

  // ============================================================
  // عدد العقارات المعتمدة
  // ============================================================

  Future<int> getApprovedPropertiesCount() async {
    try {
      final snapshot = await _properties
          .where(
            'status',
            isEqualTo: 'approved',
          )
          .count()
          .get();

      return snapshot.count ?? 0;
    } on FirebaseException catch (error) {
      throw AppStatsException(
        message: 'تعذر جلب عدد العقارات',
        code: error.code,
        originalError: error,
      );
    }
  }

  // ============================================================
  // عدد المستخدمين
  // ============================================================

  Future<int> getUsersCount() async {
    try {
      final snapshot = await _publicStats.get();

      if (!snapshot.exists) {
        throw const AppStatsException(
          message: 'لم يتم إعداد إحصائيات المستخدمين بعد',
        );
      }

      final data = snapshot.data();

      if (data == null) {
        throw const AppStatsException(
          message: 'بيانات إحصائيات المستخدمين غير متوفرة',
        );
      }

      final value = data['usersCount'];

      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.toInt();
      }

      throw const AppStatsException(
        message: 'عدد المستخدمين غير صالح',
      );
    } on FirebaseException catch (error) {
      throw AppStatsException(
        message: 'تعذر جلب عدد المستخدمين',
        code: error.code,
        originalError: error,
      );
    } catch (error) {
      if (error is AppStatsException) {
        rethrow;
      }

      throw AppStatsException(
        message: 'تعذر جلب عدد المستخدمين',
        originalError: error,
      );
    }
  }

  // ============================================================
  // رسائل أخطاء Firebase
  // ============================================================

  String _firebaseErrorMessage(
    FirebaseException error,
  ) {
    switch (error.code) {
      case 'permission-denied':
        return 'لا توجد صلاحية لقراءة إحصائيات المنصة.';

      case 'unavailable':
        return 'خدمة الإحصائيات غير متاحة حاليًا.';

      case 'deadline-exceeded':
        return 'استغرق تحميل الإحصائيات وقتًا أطول من المتوقع.';

      default:
        return 'تعذر تحميل إحصائيات المنصة.';
    }
  }
}

// ============================================================================
// AppStatsException
// ============================================================================

class AppStatsException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const AppStatsException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;
}
