import 'booking_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../features/property_map/widgets/aqar_map_tile_layer.dart';
import '../features/property_map/config/anbar_map_config.dart';
import 'booking_screen.dart';
import 'booking_widgets.dart';
import 'booking_location.dart';
import 'booking_directions_button.dart';

class BookingMapScreen extends StatefulWidget {
  final BookingLocationService? locationService;
  // Injection keeps permission, offline and navigation widget tests independent of Firebase.
  final Stream<List<Map<String, dynamic>>>? venues;
  final bool loadTiles;
  const BookingMapScreen(
      {super.key, this.locationService, this.venues, this.loadTiles = true});
  @override
  State<BookingMapScreen> createState() => _BookingMapScreenState();
}

class _BookingMapScreenState extends State<BookingMapScreen> {
  final filters = BookingFilters();
  final controller = MapController();
  late final Stream<List<Map<String, dynamic>>> venues;
  List<Map<String, dynamic>> lastVenues = [];
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
                      '_fromCache': snapshot.metadata.isFromCache
                    }
                ]);
  }

  @override
  void dispose() {
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
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('${venue['name']}',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              Text(
                                  '${venueCategory(venue['category'])} · ${venue['location'] ?? ''}'),
                              Text(
                                  'السعر يبدأ من ${bookingStartingPrice(venue)} د.ع'),
                              if (userPoint != null)
                                Text(
                                    'المسافة التقريبية: ${bookingDistanceKm(userPoint!, bookingCoordinates(venue)!).toStringAsFixed(1)} كم'),
                              Text('${venue['terms'] ?? ''}'),
                              BookingDirectionsButton(venue: venue),
                              FilledButton(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                BookingRequestScreen(
                                                    venueId:
                                                        venue['id'] as String,
                                                    venue: venue)));
                                  },
                                  child: const Text('التفاصيل والحجز')),
                            ]))))));
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: BookingScaffold(
          appBar:
              AppBar(title: const Text('خريطة الشاليهات والمزارع والقاعات')),
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
                return Column(children: [
                  ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * .45),
                      child: SingleChildScrollView(
                          child: Column(children: [
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: BookingFilterBar(
                                filters: filters,
                                onChanged: () => setState(() {}))),
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Wrap(spacing: 8, children: [
                              FilledButton.icon(
                                  onPressed: locating ? null : locate,
                                  icon: locating
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.my_location),
                                  label: const Text('موقعي الحالي')),
                              if (userPoint != null)
                                TextButton(
                                    onPressed: () =>
                                        setState(() => userPoint = null),
                                    child: const Text('إخفاء موقعي')),
                              if (locationFailure?.appSettings == true)
                                const TextButton(
                                    onPressed: Geolocator.openAppSettings,
                                    child: Text('إعدادات الإذن')),
                              if (locationFailure?.locationSettings == true)
                                const TextButton(
                                    onPressed: Geolocator.openLocationSettings,
                                    child: Text('إعدادات GPS')),
                            ])),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                                'موقعك لهذه الشاشة فقط ولا يُحفظ. خلفية OpenStreetMap تطلب منطقة الخريطة؛ الاتجاهات تشارك إحداثيات المكان مع تطبيق الخرائط.',
                                style: TextStyle(fontSize: 12))),
                        if (locationFailure != null)
                          Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(locationFailure!.message)),
                        if (docs.any((v) => v['_fromCache'] == true))
                          const Text(
                              'بيانات محلية قد لا تكون محدثة؛ الحجز يحتاج اتصالًا.'),
                        if (snapshot.hasError)
                          const Text(
                              'تعذر تحديث الأماكن. تحقق من الإنترنت وأعد فتح الخريطة؛ الحجز يحتاج اتصالًا.'),
                        if (!snapshot.hasData && !snapshot.hasError)
                          const LinearProgressIndicator(),
                        if (snapshot.hasData && docs.isEmpty)
                          const Text(
                              'لا توجد أماكن بإحداثيات صالحة تطابق البحث.'),
                        if (tileError) ...[
                          const Text(
                              'تعذر تحميل خلفية الخريطة. تحقق من الإنترنت؛ علامات الأماكن المتاحة تبقى قابلة للفتح.'),
                          TextButton(
                              onPressed: () => setState(() {
                                    tileError = false;
                                    tileGeneration++;
                                  }),
                              child: const Text('إعادة تحميل الخريطة')),
                        ],
                      ]))),
                  Expanded(
                      child: FlutterMap(
                          mapController: controller,
                          options: const MapOptions(
                              initialCenter: AnbarMapConfig.initialCenter,
                              initialZoom: AnbarMapConfig.initialZoom),
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
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (mounted) setState(() => tileError = true);
                                });
                              }),
                        MarkerLayer(markers: [
                          if (userPoint != null)
                            Marker(
                                point: userPoint!,
                                width: 40,
                                height: 40,
                                child: Semantics(
                                    label: 'موقعك الحالي',
                                    child: const Icon(Icons.my_location,
                                        color: Colors.blue, size: 32))),
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
                                            backgroundColor: bookingNavy,
                                            foregroundColor: Colors.white),
                                        onPressed: () => details(venue),
                                        child: Text(
                                            '${venue['name']}\n${bookingStartingPrice(venue)} د.ع',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis)))),
                        ]),
                        const RichAttributionWidget(attributions: [
                          TextSourceAttribution('OpenStreetMap contributors')
                        ]),
                      ])),
                  if (userPoint != null)
                    SizedBox(
                        height: MediaQuery.sizeOf(context).height < 625
                            ? MediaQuery.sizeOf(context).height * .2
                            : 125,
                        child: ListView(children: [
                          const Text(
                              'الأماكن القريبة ضمن 50 كم — مسافة خط مستقيم، حسب عوامل البحث'),
                          if (nearby.isEmpty)
                            const Text('لا توجد أماكن قريبة ضمن هذا النطاق.'),
                          for (final venue in nearby)
                            ListTile(
                                title: Text('${venue['name']}'),
                                subtitle: Text(
                                    '${bookingDistanceKm(userPoint!, bookingCoordinates(venue)!).toStringAsFixed(1)} كم · ${bookingStartingPrice(venue)} د.ع'),
                                onTap: () => details(venue)),
                        ])),
                ]);
              })));
}
