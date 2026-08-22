import 'package:cloud_firestore/cloud_firestore.dart';

class AppUpdateFeature {
  final String title;
  final String description;
  final String iconKey;

  const AppUpdateFeature({
    required this.title,
    required this.description,
    required this.iconKey,
  });

  factory AppUpdateFeature.fromMap(Map<String, dynamic> map) {
    return AppUpdateFeature(
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      iconKey: (map['iconKey'] ?? 'star').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title.trim(),
        'description': description.trim(),
        'iconKey': iconKey,
      };
}

class AppUpdateModel {
  final String id;
  final String version;
  final int buildNumber;
  final String title;
  final String description;
  final String storeUrl;
  final bool isMandatory;
  final bool isActive;
  final List<AppUpdateFeature> features;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const AppUpdateModel({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.title,
    required this.description,
    required this.storeUrl,
    required this.isMandatory,
    required this.isActive,
    required this.features,
    this.publishedAt,
    this.updatedAt,
    this.createdAt,
  });

  factory AppUpdateModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawFeatures = data['features'];

    return AppUpdateModel(
      id: doc.id,
      version: (data['version'] ?? '').toString(),
      buildNumber: _toInt(data['buildNumber']),
      title: (data['title'] ?? 'تحديث جديد متاح!').toString(),
      description: (data['description'] ?? '').toString(),
      storeUrl: (data['storeUrl'] ?? '').toString(),
      isMandatory: data['isMandatory'] == true,
      isActive: data['isActive'] == true,
      features: rawFeatures is List
          ? rawFeatures
              .whereType<Map>()
              .map(
                (e) => AppUpdateFeature.fromMap(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      publishedAt: _toDate(data['publishedAt']),
      updatedAt: _toDate(data['updatedAt']),
      createdAt: _toDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'version': version.trim(),
        'buildNumber': buildNumber,
        'title': title.trim(),
        'description': description.trim(),
        'storeUrl': storeUrl.trim(),
        'isMandatory': isMandatory,
        'isActive': isActive,
        'features': features.map((e) => e.toMap()).toList(),
        'publishedAt':
            publishedAt == null ? null : Timestamp.fromDate(publishedAt!),
        'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      };

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
