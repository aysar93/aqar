import 'dart:io';
import '../../services/media_store.dart';

class ChatImageService {
  ChatImageService._();
  static Future<Map<String, String>> uploadAttachment(
          String chatId, File image) =>
      MediaStore.instance
          .uploadImage(image, purpose: MediaPurpose.chatImage, chatId: chatId);
}
