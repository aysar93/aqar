import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/anbar_map_config.dart';
import '../models/map_cluster.dart';
import '../models/map_filter.dart';
import '../models/map_property.dart';
import '../models/map_view_state.dart';
import '../repositories/property_map_repository.dart';
import '../services/map_bounds_service.dart';
import '../services/map_cluster_service.dart';
import '../utils/map_constants.dart';

/// المتحكم الرئيسي بخريطة البحث عن العقارات.
///
/// مسؤول عن:
/// - تحميل العقارات.
/// - تحديثها.
/// - تطبيق الفلاتر.
/// - البحث.
/// - إدارة Zoom.
/// - بناء Clusters.
/// - معرفة الجزء الظاهر من الخريطة.
/// - تحديد العقار المختار.
/// - الاستماع للتحديثات الحية عند الحاجة.
///
/// لا يحتوي على Widgets ولا يعرف تفاصيل Firestore.
class PropertyMapController extends ChangeNotifier {
  final PropertyMapRepository repository;
  final MapClusterService clusterService;
  final MapBoundsService boundsService;

  MapViewState _state;

  final MapController _mapController = MapController();

  Timer? _searchDebounce;
  Timer? _cameraIdleDebounce;

  StreamSubscription<List<MapProperty>>? _propertiesSubscription;

  LatLngBounds? _visibleBounds;

  bool _disposed = false;
  int _operationId = 0;

  PropertyMapController({
    required this.repository,
    this.clusterService = const MapClusterService(),
    this.boundsService = const MapBoundsService(),
    MapViewState initialState = const MapViewState(),
  }) : _state = initialState;

  MapViewState get state => _state;

  MapLoadingStatus get status => _state.status;

  List<MapProperty> get properties => _state.properties;

  List<MapProperty> get filteredProperties => _state.filteredProperties;

  List<MapCluster> get clusters => _state.clusters;

  MapFilter get filter => _state.filter;

  MapProperty? get selectedProperty => _state.selectedProperty;

  double get zoom => _state.zoom;

  LatLngBounds? get visibleBounds => _visibleBounds;

  MapController get mapController => _mapController;

  bool get isLoading => _state.isLoading;

  bool get hasError => _state.hasError;

  bool get hasActiveFilters => _state.hasActiveFilters;

  int get totalProperties => _state.totalProperties;

  int get filteredCount => _state.visibleProperties;

  /// عدد العقارات الموجودة داخل الجزء المرئي من الخريطة.
  int get visibleCount {
    final bounds = _visibleBounds;

    if (bounds == null) {
      return filteredProperties.length;
    }

    return boundsService
        .propertiesInsideBounds(
          properties: filteredProperties,
          bounds: bounds,
        )
        .length;
  }

  /// العقارات الموجودة داخل الجزء الظاهر حاليًا.
  List<MapProperty> get propertiesInVisibleRegion {
    final bounds = _visibleBounds;

    if (bounds == null) {
      return filteredProperties;
    }

    return boundsService.propertiesInsideBounds(
      properties: filteredProperties,
      bounds: bounds,
    );
  }

  /// تحميل البيانات للمرة الأولى.
  Future<void> load() async {
    final operationId = ++_operationId;

    _setState(
      _state.startLoading(),
    );

    try {
      final result = await repository.fetchProperties();

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      _applySourceProperties(result);
    } catch (error) {
      if (!_isCurrentOperation(operationId)) {
        return;
      }

      _setState(
        _state.withError(
          _errorMessage(error),
        ),
      );
    }
  }

  /// إعادة جلب البيانات.
  Future<void> refresh() async {
    final operationId = ++_operationId;

    _setState(
      _state.startLoading(),
    );

    try {
      final result = await repository.refreshProperties();

      if (!_isCurrentOperation(operationId)) {
        return;
      }

      _applySourceProperties(result);
    } catch (error) {
      if (!_isCurrentOperation(operationId)) {
        return;
      }

      _setState(
        _state.withError(
          _errorMessage(error),
        ),
      );
    }
  }

  /// تشغيل الاستماع الحي لتغير العقارات.
  ///
  /// لا نشغله تلقائيًا حتى نقرر من الشاشة
  /// إذا كانت التحديثات الفورية مطلوبة.
  void startWatching() {
    _propertiesSubscription?.cancel();

    _propertiesSubscription = repository.watchProperties().listen(
      _applySourceProperties,
      onError: (Object error) {
        _setState(
          _state.withError(
            _errorMessage(error),
          ),
        );
      },
    );
  }

  Future<void> stopWatching() async {
    await _propertiesSubscription?.cancel();
    _propertiesSubscription = null;
  }

  /// تحديث البحث النصي مع Debounce.
  void updateSearchQuery(String query) {
    _searchDebounce?.cancel();

    final nextFilter = _state.filter.copyWith(
      searchQuery: query,
    );

    _setFilterWithoutApplying(nextFilter);

    _searchDebounce = Timer(
      MapConstants.searchDebounce,
      _applyCurrentFilter,
    );
  }

  void updateCity(String? city) {
    final normalized = _nullableValue(city);

    final nextFilter = normalized == null
        ? _state.filter.copyWith(
            clearCity: true,
            clearDistrict: true,
          )
        : _state.filter.copyWith(
            city: normalized,
            clearDistrict: true,
          );

    _applyFilter(nextFilter);
  }

  void updateDistrict(String? district) {
    final normalized = _nullableValue(district);

    final nextFilter = normalized == null
        ? _state.filter.copyWith(
            clearDistrict: true,
          )
        : _state.filter.copyWith(
            district: normalized,
          );

    _applyFilter(nextFilter);
  }

  void updatePropertyType(String? propertyType) {
    final normalized = _nullableValue(propertyType);

    final nextFilter = normalized == null
        ? _state.filter.copyWith(
            clearPropertyType: true,
          )
        : _state.filter.copyWith(
            propertyType: normalized,
          );

    _applyFilter(nextFilter);
  }

  void updateAdType(String? adType) {
    final normalized = _nullableValue(adType);

    final nextFilter = normalized == null
        ? _state.filter.copyWith(
            clearAdType: true,
          )
        : _state.filter.copyWith(
            adType: normalized,
          );

    _applyFilter(nextFilter);
  }

  void updatePriceRange({
    double? minPrice,
    double? maxPrice,
  }) {
    var nextFilter = _state.filter;

    if (minPrice == null) {
      nextFilter = nextFilter.copyWith(
        clearMinPrice: true,
      );
    } else {
      nextFilter = nextFilter.copyWith(
        minPrice: minPrice,
      );
    }

    if (maxPrice == null) {
      nextFilter = nextFilter.copyWith(
        clearMaxPrice: true,
      );
    } else {
      nextFilter = nextFilter.copyWith(
        maxPrice: maxPrice,
      );
    }

    _applyFilter(nextFilter);
  }

  void updateFeaturedOnly(bool value) {
    _applyFilter(
      _state.filter.copyWith(
        featuredOnly: value,
      ),
    );
  }

  /// تطبيق MapFilter كامل.
  void setFilter(MapFilter filter) {
    _applyFilter(filter);
  }

  void clearFilters() {
    _searchDebounce?.cancel();

    _applyFilter(MapFilter.empty);
  }

  /// تحديث حالة الخريطة أثناء الحركة.
  ///
  /// flutter_map يعطينا المركز والـZoom مباشرة.
  void onMapMove({
    required LatLng center,
    required double zoom,
  }) {
    final nextZoom = AnbarMapConfig.clampZoom(
      zoom,
    );

    if ((nextZoom - _state.zoom).abs() < 0.05) {
      return;
    }

    _state = _state.copyWith(
      zoom: nextZoom,
    );
  }

  /// تستدعى بعد توقف حركة الخريطة.
  ///
  /// المنطقة المرئية تُقرأ من كاميرا flutter_map
  /// ثم نعيد حساب الـClusters.
  void onMapIdle() {
    _cameraIdleDebounce?.cancel();

    _cameraIdleDebounce = Timer(
      MapConstants.cameraIdleDebounce,
      () {
        if (_disposed) {
          return;
        }

        try {
          _visibleBounds = _mapController.camera.visibleBounds;

          if (_disposed) {
            return;
          }

          _rebuildClusters();
        } catch (_) {
          // قد لا تكون الخريطة جاهزة بعد.
        }
      },
    );
  }

  /// يمكن للشاشة تمرير الحدود مباشرة عند الحاجة.
  void updateVisibleBounds(
    LatLngBounds bounds,
  ) {
    _visibleBounds = bounds;
    _rebuildClusters();
  }

  void selectProperty(MapProperty property) {
    _setState(
      _state.copyWith(
        selectedProperty: property,
      ),
    );
  }

  void clearSelectedProperty() {
    if (_state.selectedProperty == null) {
      return;
    }

    _setState(
      _state.clearSelection(),
    );
  }

  /// عند الضغط على Cluster نحرك الخريطة إليه
  /// ونزيد Zoom تدريجيًا.
  Future<void> focusCluster(
    MapCluster cluster,
  ) async {
    final targetZoom = AnbarMapConfig.clampZoom(
      _state.zoom + 2,
    );

    final target = LatLng(
      cluster.latitude,
      cluster.longitude,
    );

    _mapController.move(
      target,
      targetZoom,
    );

    _state = _state.copyWith(
      zoom: targetZoom,
    );
  }

  /// تحريك الخريطة إلى عقار محدد.
  Future<void> focusProperty(
    MapProperty property,
  ) async {
    selectProperty(property);

    final target = LatLng(
      property.latitude,
      property.longitude,
    );

    final targetZoom = AnbarMapConfig.clampZoom(
      AnbarMapConfig.propertyZoom,
    );

    _mapController.move(
      target,
      targetZoom,
    );

    _state = _state.copyWith(
      zoom: targetZoom,
    );
  }

  /// إعادة الخريطة إلى عرض الأنبار.
  Future<void> resetCamera() async {
    clearSelectedProperty();

    final targetZoom = AnbarMapConfig.clampZoom(
      AnbarMapConfig.initialZoom,
    );

    _mapController.move(
      AnbarMapConfig.initialCenter,
      targetZoom,
    );

    _visibleBounds = null;

    _state = _state.copyWith(
      zoom: targetZoom,
    );

    _rebuildClusters();
  }

  void _applySourceProperties(
    List<MapProperty> source,
  ) {
    final validProperties = boundsService.filterProperties(source);

    final filtered = _filterProperties(
      validProperties,
      _state.filter,
    );

    final nextStatus =
        filtered.isEmpty ? MapLoadingStatus.empty : MapLoadingStatus.loaded;

    _state = _state.copyWith(
      status: nextStatus,
      properties: validProperties,
      filteredProperties: filtered,
      clearSelectedProperty: true,
      clearError: true,
    );

    _rebuildClusters();
  }

  void _applyFilter(MapFilter nextFilter) {
    _searchDebounce?.cancel();

    final filtered = _filterProperties(
      _state.properties,
      nextFilter,
    );

    final selected = _state.selectedProperty;

    final keepSelection = selected != null &&
        filtered.any(
          (property) => property.id == selected.id,
        );

    _state = _state.copyWith(
      status:
          filtered.isEmpty ? MapLoadingStatus.empty : MapLoadingStatus.loaded,
      filter: nextFilter,
      filteredProperties: filtered,
      clearSelectedProperty: !keepSelection,
      clearError: true,
    );

    _rebuildClusters();
  }

  void _setFilterWithoutApplying(
    MapFilter nextFilter,
  ) {
    _setState(
      _state.copyWith(
        filter: nextFilter,
      ),
    );
  }

  void _applyCurrentFilter() {
    if (_disposed) {
      return;
    }

    _applyFilter(_state.filter);
  }

  List<MapProperty> _filterProperties(
    Iterable<MapProperty> source,
    MapFilter filter,
  ) {
    return source.where((property) {
      if (filter.city != null && !_sameText(property.city, filter.city!)) {
        return false;
      }

      if (filter.district != null &&
          !_sameText(
            property.district,
            filter.district!,
          )) {
        return false;
      }

      if (filter.propertyType != null &&
          !_sameText(
            property.propertyType,
            filter.propertyType!,
          )) {
        return false;
      }

      if (filter.adType != null &&
          !_sameText(
            property.adType,
            filter.adType!,
          )) {
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

      final query = _normalize(
        filter.searchQuery,
      );

      if (query.isNotEmpty) {
        final number = property.propertyNumber.toString();

        final text = _normalize(
          '${property.title} '
          '${property.city} '
          '${property.district}',
        );

        if (!text.contains(query) && !number.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }

  void _rebuildClusters() {
    if (_disposed) {
      return;
    }

    final source = _visibleBounds == null
        ? _state.filteredProperties
        : boundsService.propertiesInsideBounds(
            properties: _state.filteredProperties,
            bounds: _visibleBounds!,
          );

    final nextClusters = clusterService.createClusters(
      properties: source,
      zoom: _state.zoom,
    );

    _setState(
      _state.copyWith(
        clusters: nextClusters,
      ),
    );
  }

  bool _sameText(
    String first,
    String second,
  ) {
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

  String? _nullableValue(String? value) {
    final result = value?.trim();

    if (result == null || result.isEmpty) {
      return null;
    }

    return result;
  }

  String _errorMessage(Object error) {
    if (error is TimeoutException) {
      return 'انتهت مهلة تحميل العقارات';
    }

    return 'تعذر تحميل العقارات على الخريطة';
  }

  bool _isCurrentOperation(int id) {
    return !_disposed && id == _operationId;
  }

  void _setState(MapViewState nextState) {
    if (_disposed) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;

    _searchDebounce?.cancel();
    _cameraIdleDebounce?.cancel();

    _propertiesSubscription?.cancel();
    _propertiesSubscription = null;

    _mapController.dispose();

    super.dispose();
  }
}
