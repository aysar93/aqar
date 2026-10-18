import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'media_location.dart';

enum MediaPurpose {
  property,
  avatar,
  office,
  banner,
  appLogo,
  license,
  receipt,
  chatImage
}

class MediaStore {
  final FirebaseStorage storage;
  final FirebaseAuth auth;
  final String bucket;
  MediaStore({required this.storage, required this.auth, required this.bucket});
  static MediaStore get instance {
    const bucket = MediaLocation.defaultBucket;
    if (bucket.isEmpty) {
      throw StateError('MEDIA_STORAGE_BUCKET must be configured explicitly');
    }
    return MediaStore(
        storage: FirebaseStorage.instanceFor(bucket: 'gs://$bucket'),
        auth: FirebaseAuth.instance,
        bucket: bucket);
  }

  String _uid() {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Sign in to upload private or public media');
    }
    return user.uid;
  }

  static String imageType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'jpg';
    }
    throw StateError(
        'Only JPEG and PNG are supported; convert HEIC before upload');
  }

  Future<Map<String, String>> uploadImage(File file,
      {required MediaPurpose purpose, String? chatId}) async {
    _uid();
    if (await file.length() > 10 * 1024 * 1024) {
      throw StateError('Image exceeds 10 MiB');
    }
    var bytes = await file.readAsBytes();
    try {
      imageType(bytes);
    } on StateError {
      bytes = await FlutterImageCompress.compressWithList(bytes,
          quality: 85, format: CompressFormat.jpeg);
      imageType(bytes);
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw StateError('Converted image exceeds 10 MiB');
    }
    if (purpose == MediaPurpose.chatImage &&
        (chatId == null || chatId.isEmpty || chatId.contains('/'))) {
      throw StateError('A valid chat is required');
    }
    return _privateUpload(bytes, purpose: purpose.name, chatId: chatId);
  }

  Future<Map<String, dynamic>> uploadAudio(
      File file, String chatId, int seconds) async {
    _uid();
    if (chatId.isEmpty || chatId.contains('/')) {
      throw StateError('Invalid chat');
    }
    if (seconds <= 0 || seconds > 120 || await file.length() == 0) {
      throw StateError('Invalid audio');
    }
    if (await file.length() > 5 * 1024 * 1024) {
      throw StateError('Audio exceeds 5 MiB');
    }
    final result = await _privateUpload(await file.readAsBytes(),
        purpose: 'chatAudio', chatId: chatId, seconds: seconds);
    return {
      'audioUrl': result['url'],
      'audioPath': result['path'],
      'audioSeconds': seconds
    };
  }

  Future<String> uploadBookingReceipt(File file, String bookingId) async {
    _uid();
    if (bookingId.isEmpty ||
        bookingId.length > 128 ||
        bookingId.contains('/')) {
      throw StateError('Invalid booking');
    }
    if (await file.length() > 10 * 1024 * 1024) {
      throw StateError('Receipt exceeds 10 MiB');
    }
    var bytes = await file.readAsBytes();
    try {
      if (imageType(bytes) != 'jpg') {
        bytes = await FlutterImageCompress.compressWithList(bytes,
            quality: 85, format: CompressFormat.jpeg);
      }
    } on StateError {
      bytes = await FlutterImageCompress.compressWithList(bytes,
          quality: 85, format: CompressFormat.jpeg);
    }
    if (imageType(bytes) != 'jpg' || bytes.length > 10 * 1024 * 1024) {
      throw StateError('Invalid receipt');
    }
    return (await _privateUpload(bytes,
        purpose: 'bookingReceipt', bookingId: bookingId))['path']!;
  }

  Future<Map<String, String>> _privateUpload(Uint8List bytes,
      {required String purpose,
      String? chatId,
      String? bookingId,
      int? seconds,
      String? uploadId,
      int attempt = 0}) async {
    final uid = _uid();
    final operationId = uploadId ??
        List.generate(
            16,
            (_) => Random.secure()
                .nextInt(256)
                .toRadixString(16)
                .padLeft(2, '0')).join();
    const endpoint = String.fromEnvironment('MEDIA_UPLOAD_URL');
    final uri = Uri.tryParse(endpoint);
    final sandbox = bucket.startsWith('demo-') &&
        auth.app.options.projectId.startsWith('demo-') &&
        uri != null &&
        uri.scheme == 'http' &&
        ['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host) &&
        uri.port == 9396 &&
        uri.path == '/uploadMedia' &&
        !uri.hasQuery &&
        uri.userInfo.isEmpty;
    final isolatedCloud = bucket == 'aqar-media-test-20261018-media' && auth.app.options.projectId == 'aqar-media-test-20261018' && uri != null && uri.scheme == 'https' && uri.host == 'us-central1-aqar-media-test-20261018.cloudfunctions.net' && uri.path == '/mediaBrokerTest/uploadMedia' && !uri.hasQuery && uri.userInfo.isEmpty;
    if (!sandbox && !isolatedCloud &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'us-central1-aqar-9f3f9.cloudfunctions.net' ||
            uri.path != '/uploadMedia' ||
            uri.hasQuery ||
            uri.userInfo.isNotEmpty)) {
      throw StateError('Approved private upload broker must be configured');
    }
    final idToken = await auth.currentUser!.getIdToken();
    if (idToken == null || auth.currentUser?.uid != uid) {
      throw StateError('Authentication changed');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(uri);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $idToken');
      request.write(jsonEncode({
        'uploadId': operationId,
        'purpose': purpose,
        'chatId': chatId,
        'bookingId': bookingId,
        'seconds': seconds,
        'content': base64Encode(bytes)
      }));
      final response =
          await request.close().timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        await response.drain();
        if (response.statusCode >= 500) {
          throw const HttpException('Temporary upload failure');
        }
        throw StateError('Media upload rejected');
      }
      final text = await utf8.decoder.bind(response).join();
      if (text.length > 4096) {
        throw StateError('Unexpected broker response');
      }
      final result = jsonDecode(text) as Map<String, dynamic>;
      final path = result['path'] as String;
      final url = result['url'] as String;
      if (auth.currentUser?.uid != uid ||
          MediaLocation.pathFor(url, bucket) != path ||
          Uri.parse(url).queryParameters.containsKey('token') ||
          !(path.startsWith('uploads/private/') ||
              path.startsWith('uploads/public/') ||
              path.startsWith('booking_receipts/'))) {
        throw StateError('Invalid private upload response');
      }
      return {'path': path, 'url': url};
    } on IOException {
      if (attempt < 2 && auth.currentUser?.uid == uid) {
        return _privateUpload(bytes,
            purpose: purpose,
            chatId: chatId,
            bookingId: bookingId,
            seconds: seconds,
            uploadId: operationId,
            attempt: attempt + 1);
      }
      rethrow;
    } on TimeoutException {
      if (attempt < 2 && auth.currentUser?.uid == uid) {
        return _privateUpload(bytes,
            purpose: purpose,
            chatId: chatId,
            bookingId: bookingId,
            seconds: seconds,
            uploadId: operationId,
            attempt: attempt + 1);
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List> readPrivatePath(String path) =>
      readPrivate(MediaLocation.urlFor(bucket, path));

  Future<HttpClientResponse> _privateReadRequest(
      String path, String method, HttpClient client) async {
    final uid = _uid();
    const endpoint = String.fromEnvironment('MEDIA_PRIVATE_READ_URL');
    final uri = Uri.tryParse(endpoint);
    final sandbox = bucket.startsWith('demo-') &&
        auth.app.options.projectId.startsWith('demo-') &&
        uri != null &&
        uri.scheme == 'http' &&
        ['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host) &&
        uri.port == 9396 &&
        uri.path == '/readPrivateMedia' &&
        !uri.hasQuery &&
        uri.userInfo.isEmpty;
    final isolatedCloud = bucket == 'aqar-media-test-20261018-media' && auth.app.options.projectId == 'aqar-media-test-20261018' && uri != null && uri.scheme == 'https' && uri.host == 'us-central1-aqar-media-test-20261018.cloudfunctions.net' && uri.path == '/mediaBrokerTest/readPrivateMedia' && !uri.hasQuery && uri.userInfo.isEmpty;
    if (!sandbox && !isolatedCloud &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'us-central1-aqar-9f3f9.cloudfunctions.net' ||
            uri.path != '/readPrivateMedia' ||
            uri.hasQuery ||
            uri.userInfo.isNotEmpty)) {
      throw StateError('Approved private read broker must be configured');
    }
    final token = await auth.currentUser!.getIdToken();
    if (token == null || auth.currentUser?.uid != uid) {
      throw StateError('Authentication changed');
    }
    final request = await client.openUrl(
        method, uri.replace(queryParameters: {'path': path}));
    request.followRedirects = false;
    request.headers.set('Authorization', 'Bearer $token');
    final response = await request.close().timeout(const Duration(seconds: 60));
    if (response.statusCode != 200 || auth.currentUser?.uid != uid) {
      await response.drain();
      throw StateError('Private read rejected');
    }
    return response;
  }

  Future<String?> privateContentType(String url) async {
    final path = MediaLocation.pathFor(url, bucket);
    if (path == null) {
      throw StateError('Untrusted media bucket');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final response = await _privateReadRequest(path, 'HEAD', client);
      final type = response.headers.contentType?.mimeType;
      await response.drain();
      return type;
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List> readPrivate(String url) async {
    final uid = _uid();
    final path = MediaLocation.pathFor(url, bucket);
    if (path == null) {
      throw StateError('Untrusted media bucket');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final response = await _privateReadRequest(path, 'GET', client);
      final bytes = BytesBuilder(copy: false);
      var size = 0;
      await for (final chunk in response) {
        size += chunk.length;
        if (size > 10 * 1024 * 1024) {
          throw StateError('Private object too large');
        }
        bytes.add(chunk);
      }
      if (auth.currentUser?.uid != uid) {
        throw StateError('Account changed during private read');
      }
      return bytes.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> deletePath(String path) async {
    _uid();
    if (!path.startsWith('uploads/') ||
        path.contains('..') ||
        path.contains('://')) {
      throw StateError('Only newly uploaded media can be removed');
    }
    if (path.startsWith('uploads/private/')) {
      return;
    } // Retained until server reference-aware cleanup.
    await storage
        .ref(path)
        .delete(); // Rules enforce owner/admin; archived 469 are immutable.
  }
}

Future<String?> uploadMediaImage(File file,
        {required MediaPurpose purpose}) async =>
    (await MediaStore.instance.uploadImage(file, purpose: purpose))['url'];
