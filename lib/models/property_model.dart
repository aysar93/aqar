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

  final int rooms;
  final int bathrooms;
  final int area;
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
  final String publisherEmail;
  final String publisherPhone;
  final String publisherWhatsapp;
  final String officeId;
  final String officeName;
  final bool isOfficeProperty;
  final bool isPromoted;

  final bool isVerified;
  final bool isFeatured;

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

    required this.rooms,
    required this.bathrooms,
    required this.area,
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
    required this.publisherEmail,
    required this.publisherPhone,
    required this.publisherWhatsapp,
    required this.officeId,
    required this.officeName,
    required this.isOfficeProperty,
    required this.isPromoted,

    required this.isVerified,
    required this.isFeatured,

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

      location: map['location'] ?? '',
      city: map['city'] ?? '',
      areaName: map['areaName'] ?? '',
      landmark: map['landmark'] ?? '',

      propertyType: map['propertyType'] ?? '',
      adType: map['adType'] ?? '',

      price: (map['price'] ?? 0).toDouble(),

      rooms: (map['rooms'] ?? 0).toInt(),
      bathrooms: (map['bathrooms'] ?? 0).toInt(),
      area: (map['area'] ?? 0).toInt(),
      livingRooms: (map['livingRooms'] ?? 0).toInt(),
      parking: (map['parking'] ?? 0).toInt(),
      buildYear: (map['buildYear'] ?? 0).toInt(),

      description: map['description'] ?? '',

      features: List<dynamic>.from(map['features'] ?? []),

      documentType: map['documentType'] ?? '',
      furnitureStatus: map['furnitureStatus'] ?? '',

      ownerPhone: map['ownerPhone'] ?? '',
      ownerWhatsapp: map['ownerWhatsapp'] ?? '',

      publisherUid: map['publisherUid'] ?? '',
      publisherName: map['publisherName'] ?? '',
      publisherEmail: map['publisherEmail'] ?? '',
      publisherPhone: map['publisherPhone'] ?? '',
      publisherWhatsapp: map['publisherWhatsapp'] ?? '',
      officeId: map['officeId'] ?? '',
officeName: map['officeName'] ?? '',
isOfficeProperty: map['isOfficeProperty'] ?? false,
isPromoted: map['isPromoted'] ?? false,

      isVerified: map['isVerified'] ?? false,
      isFeatured: map['isFeatured'] ?? false,

      availabilityStatus:
          map['availabilityStatus'] ?? 'available',

      views: (map['views'] ?? 0).toInt(),

      propertyNumber:
          (map['adNumber'] ?? 0).toInt(),

      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),

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

      'rooms': rooms,
      'bathrooms': bathrooms,
      'area': area,
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
      'publisherEmail': publisherEmail,
      'publisherPhone': publisherPhone,
      'publisherWhatsapp': publisherWhatsapp,
      'officeId': officeId,
'officeName': officeName,
'isOfficeProperty': isOfficeProperty,
'isPromoted': isPromoted,

      'isVerified': isVerified,
      'isFeatured': isFeatured,

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