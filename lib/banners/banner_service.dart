import 'package:cloud_firestore/cloud_firestore.dart';
import 'banner_model.dart';

enum BannerPlacement { home, bookings }

class BannerService {
  static String collectionName(BannerPlacement placement) =>
      placement == BannerPlacement.bookings ? "booking_banners" : "banners";
  static CollectionReference<Map<String, dynamic>> _collection(
          BannerPlacement placement) =>
      FirebaseFirestore.instance.collection(collectionName(placement));

  /// جميع البنرات مرتبة حسب الترتيب
  static Stream<List<BannerModel>> banners(
      {BannerPlacement placement = BannerPlacement.home}) {
    return _collection(placement).orderBy("order").snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => BannerModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// البنرات المفعلة فقط
  static Stream<List<BannerModel>> activeBanners(
      {BannerPlacement placement = BannerPlacement.home}) {
    return _collection(placement)
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
  static Future<void> add(BannerModel banner,
      {BannerPlacement placement = BannerPlacement.home}) {
    return _collection(placement).add(banner.toMap());
  }

  /// تعديل بنر
  static Future<void> update(
    String id,
    Map<String, dynamic> data, {
    BannerPlacement placement = BannerPlacement.home,
  }) {
    return _collection(placement).doc(id).update(data);
  }

  /// حذف بنر
  static Future<void> delete(String id,
      {BannerPlacement placement = BannerPlacement.home}) {
    return _collection(placement).doc(id).delete();
  }
}
