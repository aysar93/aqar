import 'dart:io';

import '../../services/cloudinary_service.dart';

class ChatImageService {
  ChatImageService._();
  static Future<Map<String, String>> uploadAttachment(
      String chatId, File image) async {
    if (await image.length() > 10 * 1024 * 1024) {
      throw StateError('Image too large');
    }
    return {'url': await uploadImage(image), 'path': ''};
  }

  static Future<String> uploadImage(File image) async {
    final url = await uploadToCloudinary(image);

    if (url == null) {
      throw Exception("فشل رفع الصورة إلى Cloudinary");
    }

    return url;
  }
}
