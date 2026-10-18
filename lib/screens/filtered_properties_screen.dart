import 'package:flutter/material.dart';
import '../utils/property_navigator.dart';
import '../models/property_model.dart';
import '../widgets/property_card.dart';
import '../utils/currency.dart';
import '../services/favorites_service.dart';

class FilteredPropertiesScreen extends StatelessWidget {
  final String title;
  final Stream<List<PropertyModel>> stream;

  const FilteredPropertiesScreen({
    super.key,
    required this.title,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: StreamBuilder<List<PropertyModel>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text("حدث خطأ"),
            );
          }

          final properties = snapshot.data ?? [];

          if (properties.isEmpty) {
            return const Center(
              child: Text("لا توجد عقارات"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: properties.length,
            itemBuilder: (context, index) {
              final property = properties[index];

              return PropertyCard(
                docId: property.id,
                imageUrl: property.imageUrl,
                title: property.title,
                location: property.location,
                price: iqd(property.price),
                rooms: property.rooms,
                bathrooms: property.bathrooms,
                area: property.area,
                livingRooms: property.livingRooms,
                parking: property.parking,
                description: property.description,
                ownerPhone: property.ownerPhone,
                ownerWhatsapp: property.ownerWhatsapp,
                images: property.images,
                features: property.features,
                propertyNumber: property.propertyNumber,
                availabilityStatus: property.availabilityStatus,
                isFavorite: property.isFavorite,
                onFavorite: () async {
                  await FavoritesService.toggleFavorite(property.id);
                },
                onTap: () => PropertyNavigator.open(
                  context,
                  property,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
