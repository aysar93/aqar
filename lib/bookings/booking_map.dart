import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../features/property_map/config/anbar_map_config.dart';
import '../features/property_map/widgets/aqar_map_tile_layer.dart';
import 'booking_directions_button.dart';
import 'booking_filters.dart';
import 'booking_location.dart';
import 'booking_screen.dart';
import 'booking_widgets.dart';

class BookingMapScreen extends StatefulWidget {
  final BookingLocationService? locationService;
  final Stream<List<Map<String, dynamic>>>? venues;
  final bool loadTiles;

  const BookingMapScreen({
    super.key,
    this.locationService,
    this.venues,
    this.loadTiles = true,
  });

  @override
  State<BookingMapScreen> createState() => _BookingMapScreenState();
}

class _BookingMapScreenState extends State<BookingMapScreen> {
  static const Color _navy = Color(0xFF0F172A);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardBg = Color(0xFF1E293B);

  final filters = BookingFilters();
  final controller = MapController();
  final searchController = TextEditingController();

  late final Stream<List<Map<String, dynamic>>> venues;
  List<Map<String, dynamic>> lastVenues = [];
  Map<String, dynamic>? selectedVenue;
  LatLng? userPoint;
  BookingLocationFailure? locationFailure;
  bool locating = false, tileError = false;
  int tileGeneration = 0;

  @override
  void initState() {
    super.initState();
    venues = widget.venues ??
        FirebaseFirestore.instance
            .collection('booking_venues')
            .where('active', isEqualTo: true)
            .snapshots(includeMetadataChanges: true)
            .map((snapshot) => [
                  for (final doc in snapshot.docs)
                    {
                      ...doc.data(),
                      'id': doc.id,
                      '_fromCache': snapshot.metadata.isFromCache,
                    }
                ]);
  }

  @override
  void dispose() {
    searchController.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    setState(() {
      locating = true;
      locationFailure = null;
      userPoint = null;
    });
    try {
      final point =
          await (widget.locationService ?? BookingLocationService()).locate();
      if (!mounted) return;
      setState(() => userPoint = point);
      controller.move(point, 11);
    } on BookingLocationFailure catch (failure) {
      if (mounted) setState(() => locationFailure = failure);
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void details(Map<String, dynamic> venue) {
    setState(() {
      selectedVenue = venue;
    });
    final coord = bookingCoordinates(venue);
    if (coord != null) {
      controller.move(coord, 13);
    }
  }

  void openVenueDetails(Map<String, dynamic> venue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingRequestScreen(
          venueId: venue['id'] as String,
          venue: venue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: venues,
          builder: (context, snapshot) {
            if (snapshot.hasData) lastVenues = snapshot.data!;
            final docs = (snapshot.data ?? lastVenues)
                .where((v) =>
                    bookingCoordinates(v) != null && filters.matches(v))
                .toList();
            final nearby = userPoint == null
                ? <Map<String, dynamic>>[]
                : docs
                    .where((v) =>
                        bookingDistanceKm(
                            userPoint!, bookingCoordinates(v)!) <=
                        50)
                    .toList()
              ..sort((a, b) =>
                  bookingDistanceKm(userPoint!, bookingCoordinates(a)!)
                      .compareTo(bookingDistanceKm(
                          userPoint!, bookingCoordinates(b)!)));

            return Stack(
              children: [
                // 1. Full Screen FlutterMap
                Positioned.fill(
                  child: FlutterMap(
                    mapController: controller,
                    options: MapOptions(
                      initialCenter: AnbarMapConfig.initialCenter,
                      initialZoom: AnbarMapConfig.initialZoom,
                      minZoom: AnbarMapConfig.minZoom,
                      maxZoom: AnbarMapConfig.maxZoom,
                      onTap: (_, __) => setState(() => selectedVenue = null),
                    ),
                    children: [
                      if (widget.loadTiles)
                        TileLayer(
                          key: ValueKey(tileGeneration),
                          urlTemplate: AqarMapTileLayer.urlTemplate,
                          userAgentPackageName:
                              AqarMapTileLayer.userAgentPackageName,
                          maxNativeZoom: 19,
                          maxZoom: 19,
                          errorTileCallback: (tile, error, stackTrace) {
                            if (!mounted || tileError) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => tileError = true);
                            });
                          },
                        ),
                      MarkerLayer(
                        markers: [
                          if (userPoint != null)
                            Marker(
                              point: userPoint!,
                              width: 44,
                              height: 44,
                              child: Semantics(
                                label: 'موقعك الحالي',
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.blueAccent,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          for (final venue in docs)
                            Marker(
                              point: bookingCoordinates(venue)!,
                              width: 130,
                              height: 70,
                              child: Semantics(
                                label:
                                    '${venue['name']} ${bookingStartingPrice(venue)} دينار',
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: selectedVenue?['id'] == venue['id']
                                        ? _gold
                                        : _navy,
                                    foregroundColor: selectedVenue?['id'] == venue['id']
                                        ? _navy
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: selectedVenue?['id'] == venue['id']
                                            ? Colors.white
                                            : _gold.withValues(alpha: 0.6),
                                        width: 1.5,
                                      ),
                                    ),
                                    elevation: 4,
                                  ),
                                  onPressed: () => details(venue),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: 114,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${venue['name']}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${bookingStartingPrice(venue)} د.ع',
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: selectedVenue?['id'] == venue['id']
                                                    ? _navy
                                                    : _gold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors')
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Floating Top Header & Search Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search Row
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: _cardBg.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: _gold.withValues(alpha: 0.3)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  )
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_forward_ios_rounded,
                                    color: Colors.white, size: 18),
                                onPressed: () => Navigator.maybePop(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _cardBg.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _gold.withValues(alpha: 0.3)),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    )
                                  ],
                                ),
                                child: TextField(
                                  controller: searchController,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'ابحث عن شاليه، مزرعة، قاعة...',
                                    hintStyle: const TextStyle(
                                        color: Colors.white60, fontSize: 13),
                                    prefixIcon: const Icon(Icons.search,
                                        color: _gold, size: 20),
                                    suffixIcon: IconButton(
                                      tooltip: 'تصفية النتائج',
                                      icon: const Icon(Icons.tune,
                                          color: _gold, size: 20),
                                      onPressed: () => BookingFilterBar(filters: filters, onChanged: () => setState(() {})).openFilters(context),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onChanged: (val) {
                                    filters.search = val;
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Chalet Category Chips (Horizontal Strip)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              for (final entry in {
                                '': 'الكل',
                                'chalet': 'شاليه',
                                'farm': 'مزرعة',
                                'hall': 'قاعة',
                              }.entries)
                                Padding(
                                  padding:
                                      const EdgeInsetsDirectional.only(end: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      entry.value,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        fontWeight:
                                            filters.category == entry.key
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                        color: filters.category == entry.key
                                            ? const Color(0xFFE6C894)
                                            : Colors.white70,
                                      ),
                                    ),
                                    selected: filters.category == entry.key,
                                    selectedColor: const Color(0xFF303343),
                                    backgroundColor: _cardBg.withValues(alpha: 0.88),
                                    side: BorderSide(
                                      color: filters.category == entry.key
                                          ? const Color(0xFFC5A16B)
                                          : Colors.white12,
                                      width: filters.category == entry.key
                                          ? 1.4
                                          : 1.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    showCheckmark: false,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) {
                                      setState(() {
                                        filters.category = entry.key;
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

                // 3. Floating Map Controls (Locate & Reset)
                Positioned(
                  left: 14,
                  top: MediaQuery.paddingOf(context).top + 115,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _cardBg.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _gold.withValues(alpha: 0.3)),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 3))
                          ],
                        ),
                        child: Column(
                          children: [
                            IconButton(
                              tooltip: 'تحديد موقعي',
                              icon: locating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _gold))
                                  : const Icon(Icons.my_location,
                                      color: _gold),
                              onPressed: locating ? null : locate,
                            ),
                            const Divider(height: 1, color: Colors.white12),
                            IconButton(
                              tooltip: 'إعادة ضبط الخريطة',
                              icon: const Icon(Icons.refresh_rounded,
                                  color: Colors.white70),
                              onPressed: () {
                                controller.move(AnbarMapConfig.initialCenter,
                                    AnbarMapConfig.initialZoom);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Hidden/Visible Text Buttons for test compatibility
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _cardBg.withValues(alpha: 0.95),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: _gold.withValues(alpha: 0.4)),
                          ),
                        ),
                        onPressed: locating ? null : locate,
                        icon: locating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _gold))
                            : const Icon(Icons.my_location,
                                size: 16, color: _gold),
                        label: const Text('موقعي الحالي',
                            style: TextStyle(fontSize: 11)),
                      ),
                      if (userPoint != null) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: _cardBg.withValues(alpha: 0.9),
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => setState(() => userPoint = null),
                          child: const Text('إخفاء موقعي',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                      if (locationFailure?.appSettings == true)
                        TextButton(
                            onPressed: Geolocator.openAppSettings,
                            child: const Text('إعدادات الإذن',
                                style: TextStyle(fontSize: 11))),
                      if (locationFailure?.locationSettings == true)
                        TextButton(
                            onPressed: Geolocator.openLocationSettings,
                            child: const Text('إعدادات GPS',
                                style: TextStyle(fontSize: 11))),
                    ],
                  ),
                ),

                // 4. Status Banners (Offline, errors, warnings)
                if (locationFailure != null ||
                    docs.any((v) => v['_fromCache'] == true) ||
                    snapshot.hasError ||
                    tileError)
                  Positioned(
                    left: 14,
                    right: 14,
                    top: MediaQuery.paddingOf(context).top + 175,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _cardBg.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (locationFailure != null)
                            Text(locationFailure!.message,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          if (docs.any((v) => v['_fromCache'] == true))
                            const Text(
                                'بيانات محلية قد لا تكون محدثة؛ الحجز يحتاج اتصالًا.',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          if (snapshot.hasError)
                            const Text(
                                'تعذر تحديث الأماكن. تحقق من الإنترنت وأعد فتح الخريطة؛ الحجز يحتاج اتصالًا.',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          if (tileError) ...[
                            const Text(
                                'تعذر تحميل خلفية الخريطة. تحقق من الإنترنت؛ علامات الأماكن المتاحة تبقى قابلة للفتح.',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                            TextButton(
                                onPressed: () => setState(() {
                                      tileError = false;
                                      tileGeneration++;
                                    }),
                                child: const Text('إعادة تحميل الخريطة',
                                    style: TextStyle(fontSize: 11))),
                          ],
                        ],
                      ),
                    ),
                  ),

                // 5. Floating Bottom Card for Selected Venue (Design identical to MapPropertyCard)
                if (selectedVenue != null)
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: MediaQuery.paddingOf(context).bottom + 16,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${selectedVenue!['name']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Cairo',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${venueCategory(selectedVenue!['category'])} · ${selectedVenue!['location'] ?? ''}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.close,
                                      color: Colors.white60, size: 20),
                                  onPressed: () =>
                                      setState(() => selectedVenue = null),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _gold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _gold.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    'السعر يبدأ من ${bookingStartingPrice(selectedVenue!)} د.ع',
                                    style: const TextStyle(
                                      color: _gold,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                                if (userPoint != null &&
                                    bookingCoordinates(selectedVenue!) != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${bookingDistanceKm(userPoint!, bookingCoordinates(selectedVenue!)!).toStringAsFixed(1)} كم',
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                            if (selectedVenue!['terms'] != null &&
                                selectedVenue!['terms'].toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${selectedVenue!['terms']}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: BookingDirectionsButton(
                                      venue: selectedVenue!),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _gold,
                                      foregroundColor: _navy,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    onPressed: () =>
                                        openVenueDetails(selectedVenue!),
                                    child: const Text(
                                      'التفاصيل والحجز',
                                      style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 6. Nearby venues list for test compatibility and geo-exploration
                if (userPoint != null && selectedVenue == null)
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: MediaQuery.paddingOf(context).bottom + 16,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _cardBg.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _gold.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الأماكن القريبة ضمن 50 كم — مسافة خط مستقيم، حسب عوامل البحث',
                            style: TextStyle(
                                color: _gold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          if (nearby.isEmpty)
                            const Text(
                              'لا توجد أماكن قريبة ضمن هذا النطاق.',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: nearby.length,
                                itemBuilder: (context, idx) {
                                  final v = nearby[idx];
                                  return Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('${v['name']}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12)),
                                      subtitle: Text(
                                        '${bookingDistanceKm(userPoint!, bookingCoordinates(v)!).toStringAsFixed(1)} كم · ${bookingStartingPrice(v)} د.ع',
                                        style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 10.5),
                                      ),
                                      onTap: () => details(v),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
