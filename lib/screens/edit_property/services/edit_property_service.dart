import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/cloudinary_service.dart';
import '../models/edit_property_data.dart';

class EditPropertyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================
  // حفظ تعديلات العقار
  // =========================

  Future<void> updateProperty(
    EditPropertyData property,
  ) async {
    // =========================
    // 1. الاحتفاظ بالصور القديمة
    // =========================

    final List<String> finalImages = List<String>.from(property.existingImages);

    // =========================
    // 2. رفع الصور الجديدة فقط
    // =========================

    for (final image in property.newImages) {
      final uploadedUrl = await uploadToCloudinary(image);

      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        throw Exception(
          'تعذر رفع إحدى الصور الجديدة',
        );
      }

      finalImages.add(uploadedUrl);
    }

    // =========================
    // 3. تجهيز بيانات التحديث
    // =========================

    final updateData = property.toUpdateMap(
      finalImages: finalImages,
    );

    // وقت آخر تعديل
    updateData['updatedAt'] = FieldValue.serverTimestamp();

    // =========================
    // 4. تحديث العقار الحالي
    // =========================

    await _firestore
        .collection('properties')
        .doc(property.docId)
        .update(updateData);

    // =========================
    // 5. تحديث البيانات المحلية
    // =========================

    property.existingImages
      ..clear()
      ..addAll(finalImages);

    property.newImages.clear();
  }
}
