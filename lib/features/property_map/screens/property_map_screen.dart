import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/property_model.dart';
import '../../../screens/property_details.dart';
import '../config/anbar_map_config.dart';
import '../controllers/property_map_controller.dart';
import '../models/map_cluster.dart';
import '../models/map_filter.dart';
import '../models/map_property.dart';
import '../services/map_marker_service.dart';
import '../services/property_map_service.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_empty_state.dart';
import '../widgets/map_filter_chips.dart';
import '../widgets/map_filter_sheet.dart';
import '../widgets/map_loading_overlay.dart';
import '../widgets/map_property_card.dart';
import '../widgets/map_results_sheet.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/aqar_map_tile_layer.dart';

class PropertyMapScreen extends StatefulWidget {
  final ValueChanged<MapProperty>? onPropertyOpen;

  const PropertyMapScreen({
    super.key,
    this.onPropertyOpen,
  });

  @override
  State<PropertyMapScreen> createState() => _PropertyMapScreenState();
}

class _PropertyMapScreenState extends State<PropertyMapScreen> {
  static const Color _background = Color(0xFF0F172A);
  static const Color _gold = Color(0xFFD4AF37);

  late final PropertyMapController _controller;
  late final TextEditingController _searchController;

  final MapMarkerService _markerService = const MapMarkerService();

  List<Marker> _markers = const <Marker>[];

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();

    _controller = PropertyMapController(
      repository: PropertyMapService(),
    );

    _controller.addListener(
      _onControllerChanged,
    );

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        _controller.load();
      },
    );
  }

  @override
  void dispose() {
    _controller.removeListener(
      _onControllerChanged,
    );

    _controller.dispose();
    _searchController.dispose();

    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }

    _rebuildMarkers();

    setState(() {});
  }

  void _rebuildMarkers() {
    _markers = _markerService.buildMarkers(
      clusters: _controller.clusters,
      selectedPropertyId: _controller.selectedProperty?.id,
      onPropertyTap: _onMarkerPropertyTap,
      onClusterTap: _onClusterTap,
    );
  }

  void _onMarkerPropertyTap(
    MapProperty property,
  ) {
    _controller.selectProperty(property);
  }

  Future<void> _onClusterTap(
    MapCluster cluster,
  ) async {
    await _controller.focusCluster(cluster);
  }

  Future<void> _openFilter() async {
    final result = await MapFilterSheet.show(
      context,
      initialFilter: _controller.filter,
    );

    if (!mounted || result == null) {
      return;
    }

    _controller.setFilter(result);
  }

  Future<void> _openProperty(
    MapProperty property,
  ) async {
    final callback = widget.onPropertyOpen;

    if (callback != null) {
      callback(property);
      return;
    }

    try {
      final document = await FirebaseFirestore.instance
          .collection('properties')
          .doc(property.id)
          .get();

      if (!mounted) {
        return;
      }

      if (!document.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر العثور على بيانات العقار',
            ),
          ),
        );
        return;
      }

      final data = document.data();

      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'بيانات العقار غير متوفرة',
            ),
          ),
        );
        return;
      }

      final propertyModel = PropertyModel.fromMap(
        data,
        document.id,
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PropertyDetails(
            property: propertyModel,
            imageUrl: propertyModel.imageUrl,
            title: propertyModel.title,
            location: propertyModel.location,
            price: propertyModel.price.toString(),
            negotiable: propertyModel.negotiable,
            rooms: propertyModel.rooms,
            bathrooms: propertyModel.bathrooms,
            area: propertyModel.area,
            frontage: propertyModel.frontage,
            depth: propertyModel.depth,
            floors: propertyModel.floors,
            apartmentFloor: propertyModel.apartmentFloor,
            unitsCount: propertyModel.unitsCount,
            livingRooms: propertyModel.livingRooms,
            parking: propertyModel.parking,
            description: propertyModel.description,
            ownerPhone: propertyModel.ownerPhone,
            ownerWhatsapp: propertyModel.ownerWhatsapp,
            publisherUid: propertyModel.publisherUid,
            publisherName: propertyModel.publisherName,
            publisherEmail: propertyModel.publisherEmail,
            publisherPhone: propertyModel.publisherPhone,
            publisherWhatsapp: propertyModel.publisherWhatsapp,
            images: propertyModel.images,
            features: propertyModel.features,
            documentType: propertyModel.documentType,
            furnitureStatus: propertyModel.furnitureStatus,
            propertyType: propertyModel.propertyType,
            adType: propertyModel.adType,
            city: propertyModel.city,
            areaName: propertyModel.areaName,
            landmark: propertyModel.landmark,
            latitude: propertyModel.latitude,
            longitude: propertyModel.longitude,
            isVerified: propertyModel.isVerified,
            isFeatured: propertyModel.isFeatured,
            availabilityStatus: propertyModel.availabilityStatus,
            views: propertyModel.views,
            createdAt: propertyModel.createdAt,
            buildYear: propertyModel.buildYear,
            propertyNumber: propertyModel.propertyNumber,
            docId: propertyModel.id,
            isFavorite: propertyModel.isFavorite,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حدث خطأ أثناء فتح تفاصيل العقار',
          ),
        ),
      );
    }
  }

  int _activeFilterCount(
    MapFilter filter,
  ) {
    var count = 0;

    if (filter.city != null) count++;
    if (filter.district != null) count++;
    if (filter.propertyType != null) count++;
    if (filter.adType != null) count++;
    if (filter.minPrice != null) count++;
    if (filter.maxPrice != null) count++;
    if (filter.featuredOnly) count++;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final selectedProperty = _controller.selectedProperty;

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: FlutterMap(
                mapController: _controller.mapController,
                options: MapOptions(
                  initialCenter: AnbarMapConfig.initialCenter,
                  initialZoom: AnbarMapConfig.initialZoom,
                  minZoom: AnbarMapConfig.minZoom,
                  maxZoom: AnbarMapConfig.maxZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom,
                  ),
                  onMapReady: () {
                    _controller.updateVisibleBounds(
                      _controller.mapController.camera.visibleBounds,
                    );
                  },
                  onPositionChanged: (
                    camera,
                    hasGesture,
                  ) {
                    _controller.onMapMove(
                      center: camera.center,
                      zoom: camera.zoom,
                    );
                  },
                  onMapEvent: (event) {
                    if (event is MapEventMoveEnd ||
                        event is MapEventFlingAnimationEnd ||
                        event is MapEventDoubleTapZoomEnd) {
                      _controller.onMapIdle();
                    }
                  },
                  onTap: (_, __) {
                    _controller.clearSelectedProperty();
                  },
                ),
                children: [
                  const AqarMapTileLayer(),
                  MarkerLayer(
                    markers: _markers,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _BackButton(
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MapSearchBar(
                          controller: _searchController,
                          onChanged: _controller.updateSearchQuery,
                          onClear: () {
                            _controller.updateSearchQuery(
                              '',
                            );
                          },
                          onFilterTap: _openFilter,
                          activeFiltersCount: _activeFilterCount(
                            _controller.filter,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  MapFilterChips(
                    selectedPropertyType: _controller.filter.propertyType,
                    onChanged: _controller.updatePropertyType,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: MediaQuery.paddingOf(context).top + 124,
            child: MapControls(
              onResetMap: _controller.resetCamera,
              onRefresh: _controller.refresh,
              isRefreshing: _controller.isLoading,
            ),
          ),
          if (!state.isLoading && state.filteredProperties.isEmpty)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: MapEmptyState(
                  hasFilters: _controller.hasActiveFilters,
                  onClearFilters:
                      _controller.hasActiveFilters ? _clearFilters : null,
                  onRefresh: !_controller.hasActiveFilters
                      ? _controller.refresh
                      : null,
                ),
              ),
            ),
          if (selectedProperty != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: MediaQuery.paddingOf(context).bottom + 82,
              child: MapPropertyCard(
                property: selectedProperty,
                onTap: () => _openProperty(
                  selectedProperty,
                ),
                onClose: _controller.clearSelectedProperty,
              ),
            ),
          Positioned(
            left: 14,
            right: 14,
            bottom: MediaQuery.paddingOf(context).bottom + 14,
            child: MapResultsSheet(
              properties: _controller.propertiesInVisibleRegion,
              onPropertyTap: (property) async {
                await _controller.focusProperty(property);
              },
            ),
          ),
          if (state.isLoading) const MapLoadingOverlay(),
          if (state.hasError)
            Positioned(
              left: 14,
              right: 14,
              top: MediaQuery.paddingOf(context).top + 126,
              child: _ErrorBanner(
                message: state.errorMessage ?? 'تعذر تحميل العقارات',
                onRetry: _controller.refresh,
              ),
            ),
        ],
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    _controller.clearFilters();
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.06,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.14,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _PropertyMapScreenState._gold,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.16,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
