import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

typedef BookingMediaCall = Future<Map<String, dynamic>> Function(
    String name, Map<String, dynamic> data);

class BookingMediaService {
  static String? emulatorHost;
  static Future<Uint8List> readImageData(String url, String? token,
      {http.Client? client}) async {
    final headers =
        token == null ? <String, String>{} : {'Authorization': 'Bearer $token'};
    final uri = Uri.parse(url);
    Future<http.Response> get(Map<String, String> h) => (client == null
            ? http.get(uri, headers: h)
            : client.get(uri, headers: h))
        .timeout(const Duration(seconds: 120));
    final response = await get(headers);
    if (response.statusCode == 200 &&
        response.bodyBytes.length <= 10 * 1024 * 1024)
      return response.bodyBytes;
    final range = RegExp(r'^bytes \*/([0-9]+)$')
        .firstMatch(response.headers['content-range'] ?? '');
    final size = range == null ? null : int.tryParse(range.group(1)!);
    if (response.statusCode != 416 ||
        size == null ||
        size <= 0 ||
        size > 10 * 1024 * 1024) throw StateError('قراءة مرفوضة');
    final bytes = BytesBuilder(copy: false);
    for (var start = 0; start < size; start += 4 * 1024 * 1024) {
      final end = (start + 4 * 1024 * 1024 - 1).clamp(0, size - 1);
      final part = await get({...headers, 'Range': 'bytes=$start-$end'});
      if (part.statusCode != 206 ||
          part.bodyBytes.length != end - start + 1 ||
          part.headers['content-range'] != 'bytes $start-$end/$size')
        throw StateError('قراءة مرفوضة');
      bytes.add(part.bodyBytes);
    }
    return bytes.takeBytes();
  }

  static Future<File> downloadVideo(String bucket, String path) async {
    final uri = Uri.parse(videoUrl(bucket, path));
    Future<Map<String, String>> headers() async {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      return token == null ? {} : {'Authorization': 'Bearer $token'};
    }

    final head = await http
        .head(uri, headers: await headers())
        .timeout(const Duration(seconds: 120));
    final size = int.tryParse(head.headers['content-length'] ?? '');
    if (head.statusCode != 200 ||
        size == null ||
        size < 12 ||
        size > 50 * 1024 * 1024) {
      throw StateError('تعذر تحميل الفيديو');
    }
    final directory = await Directory(
            '${(await getTemporaryDirectory()).path}/booking_video_')
        .createTemp();
    final file = File('${directory.path}/video.mp4');
    final sink = file.openWrite();
    try {
      for (var start = 0; start < size; start += 4 * 1024 * 1024) {
        final end = (start + 4 * 1024 * 1024 - 1).clamp(0, size - 1);
        final response = await http.get(uri, headers: {
          ...await headers(),
          'Range': 'bytes=$start-$end'
        }).timeout(const Duration(seconds: 120));
        if (response.statusCode != 206 ||
            response.bodyBytes.length != end - start + 1 ||
            response.headers['content-range'] != 'bytes $start-$end/$size') {
          throw StateError('تعذر تحميل الفيديو');
        }
        sink.add(response.bodyBytes);
      }
      await sink.close();
      return file;
    } catch (_) {
      await sink.close();
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  static String videoUrl(String bucket, String path) {
    final project = bucket.replaceFirst(
        RegExp(r'\.(firebasestorage\.app|appspot\.com)$'), '');
    final id = path.split('/').last.split('.').first;
    final base = emulatorHost == null
        ? 'https://us-central1-$project.cloudfunctions.net/bookingMediaContent'
        : 'http://$emulatorHost:5001/$project/us-central1/bookingMediaContent';
    return path.startsWith('booking_media/')
        ? '$base?path=${Uri.encodeComponent(path)}'
        : '$base?mediaId=${Uri.encodeComponent(id)}';
  }

  static Future<Map<String, dynamic>> uploadImage(
      Uint8List bytes, BookingMediaCall call,
      {String? venueId, bool banner = false}) {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw StateError('حجم الصورة غير صالح');
    }
    return call('uploadBookingImage', {
      'kind': banner ? 'banner' : 'venue',
      if (venueId != null) 'venueId': venueId,
      'base64': base64Encode(bytes)
    });
  }

  static Future<void> uploadVideo(
      Uint8List bytes, String venueId, BookingMediaCall call,
      {Future<void> Function(String, Uint8List)? upload}) async {
    if (bytes.length < 12 || bytes.length > 50 * 1024 * 1024) {
      throw StateError('حجم الفيديو غير صالح');
    }
    final result = await call(
        'reserveBookingVideo', {'venueId': venueId, 'size': bytes.length});
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
      const chunkSize = 4 * 1024 * 1024;
      final project = Firebase.app().options.projectId;
      final base = emulatorHost == null
          ? 'https://us-central1-$project.cloudfunctions.net/uploadBookingVideoChunk'
          : 'http://$emulatorHost:5001/$project/us-central1/uploadBookingVideoChunk';
      for (var offset = 0; offset < bytes.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, bytes.length);
        for (var attempt = 0;; attempt++) {
          try {
            final token = await FirebaseAuth.instance.currentUser?.getIdToken();
            final response = await http
                .post(
                    Uri.parse(
                        '$base?mediaId=$mediaId&index=${offset ~/ chunkSize}'),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/octet-stream'
                    },
                    body: bytes.sublist(offset, end))
                .timeout(const Duration(seconds: 120));
            if (response.statusCode == 200) break;
            if (response.statusCode < 500) {
              throw StateError('رفع الفيديو مرفوض');
            }
            throw http.ClientException('server');
          } on StateError {
            rethrow;
          } catch (_) {
            if (attempt >= 2) rethrow;
            await Future<void>.delayed(Duration(seconds: attempt + 1));
          }
        }
      }
    }
    await call('finishBookingVideo', {'mediaId': mediaId});
  }
}
