import 'package:flutter/material.dart';

import '../../models/property_model.dart';
import '../../screens/property_details.dart';
import '../../services/property_service.dart';
import '../property_horizontal_card.dart';

class LatestPropertiesSection extends StatelessWidget {
  const LatestPropertiesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PropertyModel>>(
      stream: PropertyService.latestProperties(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
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
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "🆕 أحدث العقارات",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: شاشة جميع العقارات
                  },
                  child: const Text(
                    "عرض الكل",
                    style: TextStyle(
                      color: Color(0xffD4AF37),
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
                scrollDirection: Axis.horizontal,
                itemCount: properties.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final property =
                      properties[index];

                  return PropertyHorizontalCard(
                    property: property,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PropertyDetails(
                            docId: property.id,
                            propertyNumber:
                                property.propertyNumber,
                            isFavorite: false,
                            imageUrl:
                                property.imageUrl,
                            title: property.title,
                            location:
                                property.location,
                            price: property.price
                                .toString(),
                            rooms: property.rooms,
                            bathrooms:
                                property.bathrooms,
                            area: property.area,
                            livingRooms:
                                property.livingRooms,
                            parking:
                                property.parking,
                            description:
                                property.description,
                            ownerPhone:
                                property.ownerPhone,
                            ownerWhatsapp:
                                property.ownerWhatsapp,
                            publisherPhone:
                                property.publisherPhone,
                            publisherWhatsapp:
                                property
                                    .publisherWhatsapp,
                            publisherUid:
                                property.publisherUid,
                            publisherName:
                                property.publisherName,
                            publisherEmail:
                                property.publisherEmail,
                            propertyType:
                                property.propertyType,
                            adType:
                                property.adType,
                            city: property.city,
                            areaName:
                                property.areaName,
                            landmark:
                                property.landmark,
                            latitude:
                                property.latitude,
                            longitude:
                                property.longitude,
                            availabilityStatus:
                                property
                                    .availabilityStatus,
                            isVerified:
                                property.isVerified,
                            isFeatured:
                                property.isFeatured,
                            views:
                                property.views,
                            createdAt:
                                property.createdAt,
                            buildYear:
                                property.buildYear,
                            images:
                                property.images,
                            features:
                                property.features,
                            documentType:
                                property.documentType,
                            furnitureStatus:
                                property
                                    .furnitureStatus,
                          ),
                        ),
                      );
                    },
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