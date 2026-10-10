import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'booking_media_service.dart';

/// Wait for authentication before resolving NetworkImage: its cache key does
/// not distinguish Authorization headers on the same URL.
class BookingMediaImage extends StatelessWidget {
  const BookingMediaImage(
      {super.key, required this.url, this.width, this.height, this.token});
  final String url;
  final double? width, height;
  final Future<String?>? token;

  Future<Uint8List> loadV3() async {
    final bearer = await (token ??
        FirebaseAuth.instance.currentUser?.getIdToken() ??
        Future<String?>.value(null));
    return BookingMediaService.readImageData(
        BookingMediaService.videoUrl(FirebaseStorage.instance.bucket, url),
        bearer);
  }

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('booking_media_v3/') ||
        url.startsWith('booking_media/')) {
      return FutureBuilder<Uint8List>(
          future: loadV3(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('تعذر تحميل الصورة');
            if (!snapshot.hasData) return const CircularProgressIndicator();
            return Image.memory(snapshot.data!,
                width: width, height: height, fit: BoxFit.cover);
          });
    }
    return FutureBuilder<String?>(
        future: token ??
            FirebaseAuth.instance.currentUser?.getIdToken() ??
            Future<String?>.value(null),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
                width: width,
                height: height,
                child: const Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) return const Text('تعذر تحميل الصورة');
          return Image.network(url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              headers: snapshot.data == null
                  ? null
                  : {'Authorization': 'Bearer ${snapshot.data}'},
              errorBuilder: (_, __, ___) => const Text('تعذر تحميل الصورة'));
        });
  }
}
