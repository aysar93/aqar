import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/map_filter.dart';
import '../models/map_property.dart';
import '../repositories/property_map_repository.dart';
import '../utils/map_constants.dart';
import 'map_bounds_service.dart';

/// التنفيذ الحقيقي لمصدر بيانات خريطة العقارات.
///
/// مسؤول عن:
/// - قراءة العقارات المعتمدة من Firestore.
/// - تحويلها إلى MapProperty.
/// - تجاهل العقارات التي لا تمتلك موقعًا جغرافيًا صالحًا.
/// - تطبيق الفلاتر التي لا نريد تحميل Firestore باستعلامات مركبة بسببها.
///
/// لاحقًا يمكن إضافة GeoHash أو استعلامات جغرافية أكثر تقدمًا
/// دون تغيير Controller أو واجهة الخريطة.
class PropertyMapService implements PropertyMapRepository {
  final FirebaseFirestore _firestore;
  final MapBoundsService _boundsService;

  PropertyMapService({
    FirebaseFirestore? firestore,
    MapBoundsService boundsService = const MapBoundsService(),
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _boundsService = boundsService;

  CollectionReference<Map<String, dynamic>> get _propertiesCollection {
    return _firestore.collection(
      MapConstants.propertiesCollection,
    );
  }

  @override
  Future<List<MapProperty>> fetchProperties({
    MapFilter filter = MapFilter.empty,
  }) async {
    final snapshot = await _approvedPropertiesQuery().get();

    return _buildProperties(
      snapshot.docs,
      filter: filter,
    );
  }

  @override
  Future<List<MapProperty>> refreshProperties({
    MapFilter filter = MapFilter.empty,
  }) {
    // Firestore get() سيعيد أحدث snapshot المتاح
    // وفق إعدادات Firestore الحالية.
    return fetchProperties(filter: filter);
  }

  @override
  Future<MapProperty?> fetchPropertyById(
    String propertyId,
  ) async {
    final id = propertyId.trim();

    if (id.isEmpty) {
      return null;
    }

    final document = await _propertiesCollection.doc(id).get();

    if (!document.exists) {
      return null;
    }

    final data = document.data();

    if (data == null) {
      return null;
    }

    if (!_isApproved(data)) {
      return null;
    }

    final property = MapProperty.fromMap(
      data,
      document.id,
    );

    if (!_boundsService.containsProperty(property)) {
      return null;
    }

    return property;
  }

  @override
  Stream<List<MapProperty>> watchProperties({
    MapFilter filter = MapFilter.empty,
  }) {
    return _approvedPropertiesQuery().snapshots().map(
          (snapshot) => _buildProperties(
            snapshot.docs,
            filter: filter,
          ),
        );
  }

  Query<Map<String, dynamic>> _approvedPropertiesQuery() {
    return _propertiesCollection.where(
      'status',
      isEqualTo: MapConstants.approvedStatus,
    );
  }

  List<MapProperty> _buildProperties(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents, {
    required MapFilter filter,
  }) {
    final properties = <MapProperty>[];

    for (final document in documents) {
      try {
        final property = MapProperty.fromMap(
          document.data(),
          document.id,
        );

        if (!_boundsService.containsProperty(property)) {
          continue;
        }

        if (!_matchesFilter(property, filter)) {
          continue;
        }

        properties.add(property);
      } catch (_) {
        // مستند غير صالح لا يجب أن يمنع بقية العقارات
        // من الظهور على الخريطة.
        continue;
      }
    }

    return List<MapProperty>.unmodifiable(properties);
  }

  bool _isApproved(Map<String, dynamic> data) {
    return data['status']?.toString() == MapConstants.approvedStatus;
  }

  bool _matchesFilter(
    MapProperty property,
    MapFilter filter,
  ) {
    if (filter.city != null && !_sameText(property.city, filter.city!)) {
      return false;
    }

    if (filter.district != null &&
        !_sameText(property.district, filter.district!)) {
      return false;
    }

    if (filter.propertyType != null &&
        !_sameText(
          property.propertyType,
          filter.propertyType!,
        )) {
      return false;
    }

    if (filter.adType != null && !_sameText(property.adType, filter.adType!)) {
      return false;
    }

    if (filter.minPrice != null && property.price < filter.minPrice!) {
      return false;
    }

    if (filter.maxPrice != null && property.price > filter.maxPrice!) {
      return false;
    }

    if (filter.featuredOnly && !property.isFeatured) {
      return false;
    }

    final query = _normalize(filter.searchQuery);

    if (query.isNotEmpty) {
      final propertyNumber = property.propertyNumber.toString();

      final searchableText = _normalize(
        '${property.title} '
        '${property.city} '
        '${property.district}',
      );

      final matchesText = searchableText.contains(query);
      final matchesNumber = propertyNumber.contains(query);

      if (!matchesText && !matchesNumber) {
        return false;
      }
    }

    return true;
  }

  bool _sameText(String first, String second) {
    return _normalize(first) == _normalize(second);
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
