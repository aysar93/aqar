import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/property_model.dart';
import '../../screens/property_details.dart';
import '../../utils/currency.dart';

class PropertyChatCard extends StatelessWidget {
  final Map<String, dynamic> property;
  const PropertyChatCard({super.key, required this.property});

  static Map<String, dynamic> snapshot(PropertyModel p) => {
        'id': p.id,
        'title': p.title,
        'imageUrl': p.imageUrl,
        'price': p.price,
        'location': p.location,
        'adType': p.adType,
        'number': p.propertyNumber,
      };

  Future<void> _open(BuildContext context) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(property['id'] as String)
          .get();
      if (!context.mounted) return;
      if (!doc.exists ||
          !['approved', 'published'].contains(doc.data()?['status'])) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('العقار لم يعد متاحاً')));
        return;
      }
      final p = PropertyModel.fromMap(doc.data()!, doc.id);
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PropertyDetails(
                property: p,
                docId: p.id,
                imageUrl: p.imageUrl,
                title: p.title,
                location: p.location,
                price: p.price.toString(),
                negotiable: p.negotiable,
                rooms: p.rooms,
                bathrooms: p.bathrooms,
                area: p.area,
                frontage: p.frontage,
                depth: p.depth,
                floors: p.floors,
                apartmentFloor: p.apartmentFloor,
                unitsCount: p.unitsCount,
                livingRooms: p.livingRooms,
                parking: p.parking,
                description: p.description,
                ownerPhone: p.ownerPhone,
                ownerWhatsapp: p.ownerWhatsapp,
                publisherUid: p.publisherUid,
                publisherName: p.publisherName,
                publisherEmail: p.publisherEmail,
                publisherPhone: p.publisherPhone,
                publisherWhatsapp: p.publisherWhatsapp,
                images: p.images,
                features: p.features,
                documentType: p.documentType,
                furnitureStatus: p.furnitureStatus,
                propertyType: p.propertyType,
                adType: p.adType,
                city: p.city,
                areaName: p.areaName,
                landmark: p.landmark,
                latitude: p.latitude,
                longitude: p.longitude,
                isVerified: p.isVerified,
                isFeatured: p.isFeatured,
                availabilityStatus: p.availabilityStatus,
                views: p.views,
                createdAt: p.createdAt,
                buildYear: p.buildYear,
                propertyNumber: p.propertyNumber,
              )));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح تفاصيل العقار')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 265,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ((property['imageUrl'] ?? '').toString().isNotEmpty)
          ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(property['imageUrl'],
                  height: 125,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                      height: 80,
                      child: Center(
                          child: Icon(Icons.home_outlined,
                              color: Colors.white54))))),
        const SizedBox(height: 10),
        Text(property['title'] ?? 'عقار',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        Text('${iqd(property['price'])} • ${property['adType'] ?? ''}',
            style: const TextStyle(color: Color(0xFFD4AF37))),
        Text('${property['location'] ?? ''} • رقم ${property['number'] ?? ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        TextButton.icon(
            onPressed: () => _open(context),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('عرض التفاصيل'),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFD4AF37))),
      ]));
}
