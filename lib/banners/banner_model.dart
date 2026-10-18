import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String type;
  final String targetId;
  final bool isActive;
  final int order;
  final Timestamp? createdAt;

  BannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.type,
    required this.targetId,
    required this.isActive,
    required this.order,
    this.createdAt,
  });

  factory BannerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return BannerModel(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      subtitle: data['subtitle']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      type: data['type']?.toString() ?? 'property',
      targetId: data['targetId']?.toString() ?? '',
      isActive: data['isActive'] as bool? ?? true,
      order: data['order'] is num ? (data['order'] as num).toInt() : 0,
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'type': type,
      'targetId': targetId,
      'isActive': isActive,
      'order': order,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
