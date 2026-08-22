import 'package:cloud_firestore/cloud_firestore.dart';

class PropertyModel {
  final String id;

  final String title;
  final String imageUrl;
  final List<dynamic> images;

  final String location;
  final String city;
  final String areaName;
  final String landmark;

  final String propertyType;
  final String adType;

  final double price;
  final bool negotiable;

  final int rooms;
  final int bathrooms;
  final int area;
  final double? frontage;
  final double? depth;
  final int? floors;
  final int? apartmentFloor;
  final int? unitsCount;
  final int livingRooms;
  final int parking;
  final int buildYear;

  final String description;

  final List<dynamic> features;

  final String documentType;
  final String furnitureStatus;

  final String ownerPhone;
  final String ownerWhatsapp;

  final String publisherUid;
  final String publisherName;
  final String publisherPhotoUrl;
  final String publisherEmail;
  final String publisherPhone;
  final String publisherWhatsapp;
  final String officeId;
  final String officeName;
  final String officeLogoUrl;
  final bool isOfficeProperty;

  final bool isPromoted;

  final bool isVerified;
  final bool isFeatured;
  final bool isFavorite;

  final String availabilityStatus;

  final int views;

  final int propertyNumber;

  final double latitude;
  final double longitude;

  final Timestamp? createdAt;

  final String status;

  const PropertyModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.images,
    required this.location,
    required this.city,
    required this.areaName,
    required this.landmark,
    required this.propertyType,
    required this.adType,
    required this.price,
    required this.negotiable,
    required this.rooms,
    required this.bathrooms,
    required this.area,
    this.frontage,
    this.depth,
    this.floors,
    this.apartmentFloor,
    this.unitsCount,
    required this.livingRooms,
    required this.parking,
    required this.buildYear,
    required this.description,
    required this.features,
    required this.documentType,
    required this.furnitureStatus,
    required this.ownerPhone,
    required this.ownerWhatsapp,
    required this.publisherUid,
    required this.publisherName,
    required this.publisherPhotoUrl,
    required this.publisherEmail,
    required this.publisherPhone,
    required this.publisherWhatsapp,
    required this.officeId,
    required this.officeName,
    required this.isOfficeProperty,
    required this.officeLogoUrl,
    required this.isPromoted,
    required this.isVerified,
    required this.isFeatured,
    required this.isFavorite,
    required this.availabilityStatus,
    required this.views,
    required this.propertyNumber,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.status,
  });

  factory PropertyModel.fromMap(
    Map<String, dynamic> map,
    String id,
  ) {
    return PropertyModel(
      id: id,
      title: map['title'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      images: List<dynamic>.from(map['images'] ?? []),
      location: (map['location'] ?? '').toString().isNotEmpty
          ? map['location']
          : ((map['areaName'] ?? map['district'] ?? '').toString().isNotEmpty
              ? "${map['city'] ?? ''} - ${map['areaName'] ?? map['district']}"
              : (map['city'] ?? '')),
      city: map['city'] ?? '',
      areaName: map['areaName'] ?? map['district'] ?? '',
      landmark: map['landmark'] ?? '',
      propertyType: map['propertyType'] ?? '',
      adType: map['adType'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      negotiable: map['negotiable'] == true,
      rooms: (map['rooms'] as num?)?.toInt() ?? 0,
      bathrooms: (map['bathrooms'] as num?)?.toInt() ?? 0,
      area: (map['area'] as num?)?.toInt() ?? 0,
      frontage: (map['frontage'] as num?)?.toDouble(),
      depth: (map['depth'] as num?)?.toDouble(),
      floors: (map['floors'] as num?)?.toInt(),
      apartmentFloor: (map['apartmentFloor'] as num?)?.toInt(),
      unitsCount: (map['unitsCount'] as num?)?.toInt(),
      livingRooms: (map['livingRooms'] as num?)?.toInt() ?? 0,
      parking: (map['parking'] as num?)?.toInt() ?? 0,
      buildYear: (map['buildYear'] as num?)?.toInt() ?? 0,
      description: map['description'] ?? '',
      features: List<dynamic>.from(map['features'] ?? []),
      documentType: map['documentType'] ?? '',
      furnitureStatus: map['furnitureStatus'] ?? '',
      ownerPhone: map['ownerPhone'] ?? '',
      ownerWhatsapp: map['ownerWhatsapp'] ?? '',
      publisherUid: map['publisherUid'] ?? '',
      publisherName: map['publisherName'] ?? '',
      publisherPhotoUrl:
          map['publisherPhotoUrl'] ?? map['publisherPhoto'] ?? '',
      publisherEmail: map['publisherEmail'] ?? '',
      publisherPhone: map['publisherPhone'] ?? '',
      publisherWhatsapp: map['publisherWhatsapp'] ?? '',
      officeId: map['officeId'] ?? '',
      officeName: map['officeName'] ?? '',
      officeLogoUrl: map['officeLogoUrl'] ?? '',
      isOfficeProperty: map['isOfficeProperty'] ?? false,
      isPromoted: map['isPromoted'] ?? false,
      isVerified: map['isVerified'] ?? false,
      isFeatured: map['isFeatured'] ?? false,
      isFavorite: map['isFavorite'] ?? false,
      availabilityStatus: map['availabilityStatus'] ?? 'available',
      views: (map['views'] as num?)?.toInt() ?? 0,
      propertyNumber: (map['adNumber'] as num?)?.toInt() ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'],
      status: map['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'images': images,
      'location': location,
      'city': city,
      'areaName': areaName,
      'landmark': landmark,
      'propertyType': propertyType,
      'adType': adType,
      'price': price,
      'negotiable': negotiable,
      'rooms': rooms,
      'bathrooms': bathrooms,
      'area': area,
      'frontage': frontage,
      'depth': depth,
      'floors': floors,
      'apartmentFloor': apartmentFloor,
      'unitsCount': unitsCount,
      'livingRooms': livingRooms,
      'parking': parking,
      'buildYear': buildYear,
      'description': description,
      'features': features,
      'documentType': documentType,
      'furnitureStatus': furnitureStatus,
      'ownerPhone': ownerPhone,
      'ownerWhatsapp': ownerWhatsapp,
      'publisherUid': publisherUid,
      'publisherName': publisherName,
      'publisherPhotoUrl': publisherPhotoUrl,
      'publisherEmail': publisherEmail,
      'publisherPhone': publisherPhone,
      'publisherWhatsapp': publisherWhatsapp,
      'officeId': officeId,
      'officeName': officeName,
      'officeLogoUrl': officeLogoUrl,
      'isOfficeProperty': isOfficeProperty,
      'isPromoted': isPromoted,
      'isVerified': isVerified,
      'isFeatured': isFeatured,
      'isFavorite': isFavorite,
      'availabilityStatus': availabilityStatus,
      'views': views,
      'adNumber': propertyNumber,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt,
      'status': status,
    };
  }
}
