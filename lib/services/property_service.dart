import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/property_model.dart';

class PropertyService {
  static final _properties =
      FirebaseFirestore.instance.collection(
    "properties",
  );

  /// العقارات المميزة
  static Stream<List<PropertyModel>>
      featuredProperties() {
    return _properties
        .where(
          "status",
          isEqualTo: "approved",
        )
        .where(
          "isFeatured",
          isEqualTo: true,
        )
        .limit(4)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => PropertyModel.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// أحدث العقارات
  static Stream<List<PropertyModel>>
      latestProperties() {
    return _properties
        .where(
          "status",
          isEqualTo: "approved",
        )
        .orderBy(
          "createdAt",
          descending: true,
        )
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => PropertyModel.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// الأكثر مشاهدة
  static Stream<List<PropertyModel>>
      mostViewedProperties() {
    return _properties
        .where(
          "status",
          isEqualTo: "approved",
        )
        .orderBy(
          "views",
          descending: true,
        )
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => PropertyModel.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// عقارات مكتب معين
  static Stream<List<PropertyModel>>
      officeProperties(
    String officeId,
  ) {
    return _properties
        .where(
          "status",
          isEqualTo: "approved",
        )
        .where(
          "officeId",
          isEqualTo: officeId,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => PropertyModel.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }
}