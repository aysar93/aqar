import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/office_model.dart';

class OfficeService {
  static final CollectionReference<Map<String, dynamic>> _offices =
      FirebaseFirestore.instance.collection('offices');

  /// إنشاء مكتب جديد
  static Future<void> createOffice(OfficeModel office) async {
    await _offices.doc(office.id).set(office.toMap());
  }

  /// تحديث بيانات المكتب
  static Future<void> updateOffice(OfficeModel office) async {
    await _offices.doc(office.id).update(office.toMap());
  }

  /// جلب بيانات مكتب واحد
  static Future<OfficeModel?> getOffice(String officeId) async {
    final doc = await _offices.doc(officeId).get();

    if (!doc.exists) return null;

    return OfficeModel.fromMap(doc.data()!, doc.id);
  }

  /// الاستماع لتغييرات المكتب
  static Stream<OfficeModel?> officeStream(String officeId) {
    return _offices.doc(officeId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return OfficeModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// المكاتب المميزة
  static Stream<List<OfficeModel>> featuredOffices() {
    return _offices
        .where('status', isEqualTo: 'approved')
        .where('featured', isEqualTo: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OfficeModel.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// أحدث المكاتب
  static Stream<List<OfficeModel>> latestOffices() {
    return _offices
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OfficeModel.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// جميع المكاتب المعتمدة
  static Stream<List<OfficeModel>> approvedOffices() {
    return _offices
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => OfficeModel.fromMap(
                  doc.data(),
                  doc.id,
                ),
              )
              .toList(),
        );
  }
}