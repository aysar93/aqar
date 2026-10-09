import 'booking_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/property_map/widgets/aqar_map_tile_layer.dart';
import '../features/property_map/config/anbar_map_config.dart';
import 'booking_screen.dart';
import 'booking_widgets.dart';

class BookingMapScreen extends StatefulWidget {
  const BookingMapScreen({super.key});
  @override
  State<BookingMapScreen> createState() => _BookingMapScreenState();
}

class _BookingMapScreenState extends State<BookingMapScreen> {
  final filters = BookingFilters();
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: BookingScaffold(
        appBar: AppBar(title: const Text('خريطة الشاليهات والقاعات')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: BookingFilterBar(
                  filters: filters, onChanged: () => setState(() {}))),
          Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('booking_venues')
                      .where('active', isEqualTo: true)
                      .snapshots(),
                  builder: (context, s) {
                    if (s.hasError)
                      return const Center(
                          child: Text('تعذر تحميل مواقع الحجوزات'));
                    if (!s.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final docs = s.data!.docs
                        .where((d) =>
                            d.data()['latitude'] is num &&
                            d.data()['longitude'] is num &&
                            filters.matches(d.data()))
                        .toList();
                    return FlutterMap(
                        options: const MapOptions(
                            initialCenter: AnbarMapConfig.initialCenter,
                            initialZoom: AnbarMapConfig.initialZoom),
                        children: [
                          const AqarMapTileLayer(),
                          MarkerLayer(markers: [
                            for (final d in docs)
                              Marker(
                                  point: LatLng(
                                      (d.data()['latitude'] as num).toDouble(),
                                      (d.data()['longitude'] as num)
                                          .toDouble()),
                                  width: 130,
                                  height: 70,
                                  child: Semantics(
                                      label:
                                          '${d.data()['name']} ${bookingStartingPrice(d.data())} دينار',
                                      child: TextButton(
                                          style: TextButton.styleFrom(
                                              backgroundColor: bookingNavy,
                                              foregroundColor: Colors.white),
                                          onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      BookingRequestScreen(
                                                          venueId: d.id,
                                                          venue: d.data()))),
                                          child: Text(
                                              '${d.data()['name']}\n${bookingStartingPrice(d.data())} د.ع',
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis))))
                          ]),
                          const RichAttributionWidget(attributions: [
                            TextSourceAttribution('OpenStreetMap contributors')
                          ]),
                        ]);
                  })),
        ]),
      ));
}
