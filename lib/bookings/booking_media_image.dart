import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
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

  Widget placeholder(BuildContext context, {bool loading = false}) => SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.broken_image_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('تعذر تحميل الصورة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant))
                        ])))));

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('asset://')) {
      if (!kDebugMode ||
          appFlavor != 'bookingsOfflinePreview' ||
          !const bool.fromEnvironment('BOOKING_OFFLINE_PREVIEW'))
        return placeholder(context);
      return Image.asset(url.substring(8),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder(context));
    }
    if (url.startsWith('booking_media_v3/') ||
        url.startsWith('booking_media/')) {
      return FutureBuilder<Uint8List>(
          future: loadV3(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return placeholder(context);
            if (!snapshot.hasData) return placeholder(context, loading: true);
            return Image.memory(snapshot.data!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder(context));
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
          if (snapshot.hasError) return placeholder(context);
          return Image.network(url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              headers: snapshot.data == null
                  ? null
                  : {'Authorization': 'Bearer ${snapshot.data}'},
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : placeholder(context, loading: true),
              errorBuilder: (_, __, ___) => placeholder(context));
        });
  }
}
