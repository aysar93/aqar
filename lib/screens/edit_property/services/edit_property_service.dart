import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../analytics/services/app_activity_service.dart';
import '../../../reels/services/reel_service.dart';

import '../../../services/media_store.dart';
import '../models/edit_property_data.dart';

class EditPropertyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================
  // حفظ تعديلات العقار
  // =========================

  Future<void> updateProperty(
    EditPropertyData property,
  ) =>
      AppActivityService.instance.recordSuccessfulAction(() async {
        // =========================
        // 1. الاحتفاظ بالصور القديمة
        // =========================

        final List<String> finalImages =
            List<String>.from(property.existingImages);

        // =========================
        // 2. رفع الصور الجديدة فقط
        // =========================

        for (final image in property.newImages) {
          final uploadedUrl = await uploadMediaImage(image, purpose: MediaPurpose.property);

          if (uploadedUrl == null || uploadedUrl.isEmpty) {
            throw Exception(
              'تعذر رفع إحدى الصور الجديدة',
            );
          }

          finalImages.add(uploadedUrl);
        }

        // =========================
        // 2.2 رفع فيديو جديد إن وجد
        // =========================

        if (property.newVideo != null) {
          try {
            final bytes = await property.newVideo!.readAsBytes();
            final fileName = 'prop_edit_${DateTime.now().millisecondsSinceEpoch}.mp4';
            final url = await ReelService.instance.uploadVideo(
              bytes: bytes,
              fileName: fileName,
              contentType: 'video/mp4',
            );
            property.videoUrl = url;
          } catch (e) {
            debugPrint('Video upload warning during edit: $e');
          }
        }

        // =========================
        // 3. تجهيز بيانات التحديث
        // =========================

        final updateData = property.toUpdateMap(
          finalImages: finalImages,
        );

        if (property.newVideo != null && property.videoUrl != null) {
          updateData['videoUrl'] = property.videoUrl;
          updateData['videoThumbnailUrl'] = property.videoThumbnailUrl;
        }

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
        property.newVideo = null;
        property.removeVideo = false;
      });
}
