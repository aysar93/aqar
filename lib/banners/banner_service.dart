import 'package:cloud_firestore/cloud_firestore.dart';
import 'banner_model.dart';

class BannerService {
  static final _collection = FirebaseFirestore.instance.collection("banners");

  /// جميع البنرات مرتبة حسب الترتيب
  static Stream<List<BannerModel>> banners() {
    return _collection.orderBy("order").snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => BannerModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// البنرات المفعلة فقط
  static Stream<List<BannerModel>> activeBanners() {
    return _collection
        .where("isActive", isEqualTo: true)
        .orderBy("order")
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BannerModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// إضافة بنر
  static Future<void> add(BannerModel banner) {
    return _collection.add(banner.toMap());
  }

  /// تعديل بنر
  static Future<void> update(
    String id,
    Map<String, dynamic> data,
  ) {
    return _collection.doc(id).update(data);
  }

  /// حذف بنر
  static Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }
}
