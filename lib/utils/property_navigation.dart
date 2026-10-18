import 'package:flutter/material.dart';

import '../models/property_model.dart';
import '../screens/property_details.dart';

void openPropertyDetails(
  BuildContext context,
  PropertyModel property,
) {
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
}
