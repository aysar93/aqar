import 'package:cloud_firestore/cloud_firestore.dart';

class OfficeModel {
  final String id;
  final String ownerUid;

  final String name;
  final String description;

  final String logo;
  final String coverImage;

  final String phone;
  final String whatsapp;
  final String email;

  final String city;
  final String area;
  final String address;

  final bool verified;
  final bool featured;

  final String subscriptionType;
  final String status;

  final int propertyCount;
  final int views;
  final double rating;
  final int reviewCount;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const OfficeModel({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.description,
    required this.logo,
    required this.coverImage,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.city,
    required this.area,
    required this.address,
    required this.verified,
    required this.featured,
    required this.subscriptionType,
    required this.status,
    required this.propertyCount,
    required this.views,
    required this.rating,
    required this.reviewCount,
    this.createdAt,
    this.updatedAt,
  });

  factory OfficeModel.fromMap(
      Map<String, dynamic> map,
      String id,
      ) {
    return OfficeModel(
      id: id,
      ownerUid: map['ownerUid'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      logo: map['logo'] ?? '',
      coverImage: map['coverImage'] ?? '',
      phone: map['phone'] ?? '',
      whatsapp: map['whatsapp'] ?? '',
      email: map['email'] ?? '',
      city: map['city'] ?? '',
      area: map['area'] ?? '',
      address: map['address'] ?? '',
      verified: map['verified'] ?? false,
      featured: map['featured'] ?? false,
      subscriptionType: map['subscriptionType'] ?? 'free',
      status: map['status'] ?? 'pending',
      propertyCount: map['propertyCount'] ?? 0,
      views: map['views'] ?? 0,
      rating: (map['rating'] ?? 0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'name': name,
      'description': description,
      'logo': logo,
      'coverImage': coverImage,
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
      'city': city,
      'area': area,
      'address': address,
      'verified': verified,
      'featured': featured,
      'subscriptionType': subscriptionType,
      'status': status,
      'propertyCount': propertyCount,
      'views': views,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}