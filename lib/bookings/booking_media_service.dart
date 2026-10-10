import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

typedef BookingMediaCall =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> data,
    );

class BookingMediaService {
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
    BookingMediaCall call,
  ) async {
    if (bytes.isEmpty || bytes.length > 50 * 1024 * 1024) {
      throw StateError('حجم الفيديو غير صالح');
    }
    final result = await call('reserveBookingVideo', {
      'venueId': venueId,
      'size': bytes.length,
    });
    // Use only the booking endpoint returned by the server reservation.
    final media = Uri.parse(result['path'] as String);
    if (media.scheme != 'https' || !media.path.startsWith('/bookings/media/')) {
      throw StateError('إعداد خدمة الفيديو غير صالح');
    }
    final upload = media.replace(
      path: '/bookings/upload',
      queryParameters: {'mediaId': result['mediaId'] as String},
    );
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final response = await http
        .post(
          upload,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'video/mp4',
          },
          body: bytes,
        )
        .timeout(const Duration(minutes: 5));
    if (response.statusCode != 201) {
      throw StateError('تعذر رفع الفيديو؛ يمكنك إعادة المحاولة لاحقًا');
    }
  }
}
