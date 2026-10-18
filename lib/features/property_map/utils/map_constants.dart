/// ثوابت تشغيل نظام خريطة العقارات.
///
/// لا نضع هنا الإحداثيات الجغرافية الخاصة بالأنبار؛
/// مكانها AnbarMapConfig.
class MapConstants {
  MapConstants._();

  // =========================
  // Firestore
  // =========================

  static const String propertiesCollection = 'properties';

  static const String approvedStatus = 'approved';

  static const String availableStatus = 'available';

  // =========================
  // Map behaviour
  // =========================

  /// تأخير بسيط قبل تنفيذ البحث بعد الكتابة.
  static const Duration searchDebounce = Duration(
    milliseconds: 350,
  );

  /// تأخير تحديث النتائج بعد انتهاء حركة الخريطة.
  static const Duration cameraIdleDebounce = Duration(
    milliseconds: 250,
  );

  /// مدة الحركة الافتراضية لبعض عناصر الواجهة.
  static const Duration animationDuration = Duration(
    milliseconds: 250,
  );

  // =========================
  // Clustering
  // =========================

  /// من هذا المستوى تقريبًا تبدأ العقارات
  /// بالظهور بشكل أكثر تفصيلًا.
  static const double detailedClusterZoom = 13.0;

  /// عند الوصول لهذا المستوى نميل إلى إظهار
  /// العقارات منفردة بدل المجموعات الكبيرة.
  static const double singleMarkerZoom = 17.0;

  /// الحد الأدنى لتكوين Cluster.
  static const int minimumClusterSize = 2;

  // =========================
  // Results
  // =========================

  /// عدد مناسب للنتائج التي يمكن إظهارها
  /// في واجهة الخريطة في دفعة واحدة.
  static const int mapResultsPageSize = 50;

  // =========================
  // Marker identifiers
  // =========================

  static const String propertyMarkerPrefix = 'property_';

  static const String clusterMarkerPrefix = 'cluster_';

  // =========================
  // UI
  // =========================

  static const double propertyCardHeight = 150.0;

  static const double mapControlsSpacing = 12.0;

  static const double defaultHorizontalPadding = 16.0;
}
