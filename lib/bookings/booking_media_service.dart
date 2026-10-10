import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

typedef BookingMediaCall = Future<Map<String, dynamic>> Function(
  String name,
  Map<String, dynamic> data,
);

class BookingMediaService {
  static String? emulatorHost;
  static String videoUrl(String bucket, String path) {
    final host = emulatorHost;
    final base = host == null
        ? 'https://firebasestorage.googleapis.com'
        : 'http://$host:9198';
    return '$base/v0/b/${Uri.encodeComponent(bucket)}/o/${Uri.encodeComponent(path)}?alt=media';
  }

  static Future<Map<String, dynamic>> uploadImage(
    Uint8List bytes,
    BookingMediaCall call, {
    String? venueId,
    bool banner = false,
  }) {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw StateError('حجم الصورة غير صالح');
    }
    return call('uploadBookingImage', {
      'kind': banner ? 'banner' : 'venue',
      if (venueId != null) 'venueId': venueId,
      'base64': base64Encode(bytes),
    });
  }

  static Future<void> uploadVideo(
    Uint8List bytes,
    String venueId,
    BookingMediaCall call, {
    Future<void> Function(String, Uint8List)? upload,
  }) async {
    if (bytes.isEmpty || bytes.length > 50 * 1024 * 1024) {
      throw StateError('حجم الفيديو غير صالح');
    }
    final result = await call('reserveBookingVideo', {
      'venueId': venueId,
      'size': bytes.length,
    });
    final path = result['path'] as String;
    final mediaId = result['mediaId'] as String;
    final expected = RegExp('^booking_media_v3/' +
        RegExp.escape(venueId) +
        r'/[A-Za-z0-9_-]+/' +
        RegExp.escape(mediaId) +
        r'\.mp4$');
    if (!expected.hasMatch(path)) throw StateError('مسار الفيديو غير صالح');
    if (upload != null) {
      await upload(path, bytes);
    } else {
      await FirebaseStorage.instance.ref(path).putData(
          bytes,
          SettableMetadata(
              contentType: 'video/mp4', cacheControl: 'private, no-store'));
    }
    await call('finishBookingVideo', {'mediaId': mediaId});
  }
}
