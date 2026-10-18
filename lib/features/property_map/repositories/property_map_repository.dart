import '../models/map_filter.dart';
import '../models/map_property.dart';

/// العقد الذي يحدد طريقة حصول نظام الخرائط
/// على بيانات العقارات.
///
/// Controller لن يعرف أن البيانات تأتي من Firestore.
/// هذا يسمح بتغيير مصدر البيانات أو طريقة الاستعلام
/// مستقبلًا دون إعادة بناء واجهة الخريطة.
abstract class PropertyMapRepository {
  /// جلب العقارات التي يمكن عرضها على الخريطة.
  Future<List<MapProperty>> fetchProperties({
    MapFilter filter = MapFilter.empty,
  });

  /// تحديث البيانات وإعادة جلبها من المصدر.
  Future<List<MapProperty>> refreshProperties({
    MapFilter filter = MapFilter.empty,
  });

  /// جلب عقار واحد عند الحاجة.
  Future<MapProperty?> fetchPropertyById(
    String propertyId,
  );

  /// Stream اختياري للتحديثات الحية.
  Stream<List<MapProperty>> watchProperties({
    MapFilter filter = MapFilter.empty,
  });
}
