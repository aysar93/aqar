import 'dart:io';

import '../../services/cloudinary_service.dart';

class ChatImageService {
  ChatImageService._();

  static Future<String> uploadImage(File image) async {
    final url = await uploadToCloudinary(image);

    if (url == null) {
      throw Exception("فشل رفع الصورة إلى Cloudinary");
    }

    return url;
  }
}