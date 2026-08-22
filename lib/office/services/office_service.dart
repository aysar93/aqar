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

  /// تحديث حقول العرض المسموح بها لصاحب المكتب فقط.
  /// لا تمرر هذه الدالة حقول الملكية أو الإدارة أو الإحصاءات أو الاشتراك.
  static Future<void> updateOfficeByOwner({
    required String officeId,
    required String ownerId,
    required Map<String, dynamic> changes,
  }) async {
    const allowedKeys = <String>{
      'name',
      'description',
      'logoUrl',
      'coverImageUrl',
      'galleryImages',
      'phone',
      'whatsapp',
      'email',
      'website',
      'facebook',
      'instagram',
      'telegram',
      'tiktok',
      'youtube',
      'city',
      'district',
      'areaName',
      'address',
      'latitude',
      'longitude',
      'services',
      'workingHours',
      'establishedYear',
      'licenseNumber',
      'licenseImageUrl',
    };
    if (!changes.keys.every(allowedKeys.contains)) {
      throw ArgumentError('تتضمن التعديلات حقولًا إدارية غير مسموح بها.');
    }
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final reference = _offices.doc(officeId);
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists || snapshot.data()?['ownerId'] != ownerId) {
        throw StateError('ليس لديك صلاحية لتعديل هذا المكتب.');
      }
      transaction.update(reference, <String, dynamic>{
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// جلب بيانات مكتب واحد
  static Future<OfficeModel?> getOffice(String officeId) async {
    final doc = await _offices.doc(officeId).get();

    if (!doc.exists) return null;

    return OfficeModel.fromMap(doc.data()!, doc.id);
  }

  /// الاستماع لتغييرات مكتب واحد
  static Stream<OfficeModel?> officeStream(String officeId) {
    return _offices.doc(officeId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return OfficeModel.fromMap(doc.data()!, doc.id);
    });
  }

  // ============================================================
  // صاحب المكتب
  // ============================================================

  /// جلب المكتب المرتبط بصاحب الحساب
  ///
  /// ownerId يجب أن يكون FirebaseAuth.currentUser.uid
  static Future<OfficeModel?> getMyOffice(String ownerId) async {
    final snapshot =
        await _offices.where('ownerId', isEqualTo: ownerId).limit(1).get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;

    return OfficeModel.fromMap(doc.data(), doc.id);
  }

  /// الاستماع المباشر لمكتب صاحب الحساب
  ///
  /// يسمح بتحديث لوحة صاحب المكتب تلقائيًا عند تغيير
  /// حالة المكتب أو بياناته من الأدمن.
  static Stream<OfficeModel?> myOfficeStream(String ownerId) {
    return _offices
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;

      return OfficeModel.fromMap(doc.data(), doc.id);
    });
  }

  /// التحقق من ملكية المكتب
  static Future<bool> isOfficeOwner(
    String officeId,
    String ownerId,
  ) async {
    final doc = await _offices.doc(officeId).get();

    if (!doc.exists) return false;

    final data = doc.data();

    return data?['ownerId'] == ownerId;
  }

  // ============================================================
  // المكاتب العامة
  // ============================================================

  /// المكاتب المميزة
  static Stream<List<OfficeModel>> featuredOffices() {
    return _offices
        .where('status', isEqualTo: 'active')
        .where('isFeatured', isEqualTo: true)
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
        .where('status', isEqualTo: 'active')
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

  /// جميع المكاتب النشطة والمنشورة للعامة
  static Stream<List<OfficeModel>> activeOffices() {
    return _offices.where('status', isEqualTo: 'active').snapshots().map(
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

  /// للتوافق مع الكود القديم
  ///
  /// أبقينا اسم approvedOffices مؤقتًا حتى لا تنكسر
  /// الشاشات التي تستعمل الاسم القديم.
  static Stream<List<OfficeModel>> approvedOffices() {
    return activeOffices();
  }
}
