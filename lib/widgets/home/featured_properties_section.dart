import 'package:flutter/material.dart';

import '../../models/property_model.dart';
import '../../screens/property_details.dart';
import '../../services/property_service.dart';
import '../property_horizontal_card.dart';

class FeaturedPropertiesSection extends StatelessWidget {
  const FeaturedPropertiesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PropertyModel>>(
      stream: PropertyService.featuredProperties(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 325,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: Text(
                "حدث خطأ أثناء تحميل العقارات",
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final properties = snapshot.data ?? [];

        if (properties.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xffD4AF37),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "العقارات المميزة",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: .3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "أفضل العقارات المختارة لك",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: شاشة جميع العقارات المميزة
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xffD4AF37),
                    side: const BorderSide(
                      color: Color(0xffD4AF37),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                  ),
                  label: const Text(
                    "عرض الكل",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 325,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: properties.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final property = properties[index];

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 250 + (index * 120)),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(30 * (1 - value), 0),
                          child: child,
                        ),
                      );
                    },
                    child: PropertyHorizontalCard(
                      property: property,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PropertyDetails(
                              docId: property.id,
                              propertyNumber: property.propertyNumber,
                              isFavorite: false,
                              imageUrl: property.imageUrl,
                              title: property.title,
                              location: property.location,
                              price: property.price.toString(),
                              negotiable: property.negotiable,
                              rooms: property.rooms,
                              bathrooms: property.bathrooms,
                              area: property.area,
                              frontage: property.frontage,
                              depth: property.depth,
                              floors: property.floors,
                              apartmentFloor: property.apartmentFloor,
                              unitsCount: property.unitsCount,
                              livingRooms: property.livingRooms,
                              parking: property.parking,
                              description: property.description,
                              ownerPhone: property.ownerPhone,
                              ownerWhatsapp: property.ownerWhatsapp,
                              publisherPhone: property.publisherPhone,
                              publisherWhatsapp: property.publisherWhatsapp,
                              publisherUid: property.publisherUid,
                              publisherName: property.publisherName,
                              publisherEmail: property.publisherEmail,
                              propertyType: property.propertyType,
                              adType: property.adType,
                              city: property.city,
                              areaName: property.areaName,
                              landmark: property.landmark,
                              latitude: property.latitude,
                              longitude: property.longitude,
                              availabilityStatus: property.availabilityStatus,
                              isVerified: property.isVerified,
                              isFeatured: property.isFeatured,
                              views: property.views,
                              createdAt: property.createdAt,
                              buildYear: property.buildYear,
                              images: property.images,
                              features: property.features,
                              documentType: property.documentType,
                              furnitureStatus: property.furnitureStatus,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 25),
          ],
        );
      },
    );
  }
}
