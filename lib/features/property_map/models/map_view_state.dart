import 'map_cluster.dart';
import 'map_filter.dart';
import 'map_property.dart';

enum MapLoadingStatus {
  initial,
  loading,
  loaded,
  empty,
  error,
}

/// الحالة المركزية لشاشة خريطة العقارات.
class MapViewState {
  final MapLoadingStatus status;

  /// جميع العقارات التي تم تحميلها للخريطة.
  final List<MapProperty> properties;

  /// العقارات المطابقة للفلاتر الحالية.
  final List<MapProperty> filteredProperties;

  /// المجموعات الحالية حسب مستوى التكبير.
  final List<MapCluster> clusters;

  /// الفلاتر النشطة.
  final MapFilter filter;

  /// العقار الذي اختاره المستخدم حاليًا.
  final MapProperty? selectedProperty;

  /// مستوى Zoom الحالي.
  final double zoom;

  /// رسالة الخطأ عند وجود مشكلة.
  final String? errorMessage;

  const MapViewState({
    this.status = MapLoadingStatus.initial,
    this.properties = const [],
    this.filteredProperties = const [],
    this.clusters = const [],
    this.filter = MapFilter.empty,
    this.selectedProperty,
    this.zoom = 7,
    this.errorMessage,
  });

  bool get isInitial => status == MapLoadingStatus.initial;

  bool get isLoading => status == MapLoadingStatus.loading;

  bool get isLoaded => status == MapLoadingStatus.loaded;

  bool get isEmpty => status == MapLoadingStatus.empty;

  bool get hasError => status == MapLoadingStatus.error;

  bool get hasSelectedProperty => selectedProperty != null;

  int get totalProperties => properties.length;

  int get visibleProperties => filteredProperties.length;

  bool get hasActiveFilters => !filter.isEmpty;

  MapViewState copyWith({
    MapLoadingStatus? status,
    List<MapProperty>? properties,
    List<MapProperty>? filteredProperties,
    List<MapCluster>? clusters,
    MapFilter? filter,
    MapProperty? selectedProperty,
    double? zoom,
    String? errorMessage,
    bool clearSelectedProperty = false,
    bool clearError = false,
  }) {
    return MapViewState(
      status: status ?? this.status,
      properties: properties ?? this.properties,
      filteredProperties: filteredProperties ?? this.filteredProperties,
      clusters: clusters ?? this.clusters,
      filter: filter ?? this.filter,
      selectedProperty: clearSelectedProperty
          ? null
          : selectedProperty ?? this.selectedProperty,
      zoom: zoom ?? this.zoom,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  MapViewState startLoading() {
    return copyWith(
      status: MapLoadingStatus.loading,
      clearError: true,
    );
  }

  MapViewState withError(String message) {
    return copyWith(
      status: MapLoadingStatus.error,
      errorMessage: message,
    );
  }

  MapViewState clearSelection() {
    return copyWith(
      clearSelectedProperty: true,
    );
  }
}
