import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Wait for authentication before resolving NetworkImage: its cache key does
/// not distinguish Authorization headers on the same URL.
class BookingMediaImage extends StatelessWidget {
  const BookingMediaImage({super.key, required this.url, this.width,
    this.height, this.token});
  final String url;
  final double? width, height;
  final Future<String?>? token;

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
      future: token ?? FirebaseAuth.instance.currentUser?.getIdToken() ??
          Future<String?>.value(null),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(width: width, height: height,
              child: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return const Text('تعذر تحميل الصورة');
        return Image.network(url, width: width, height: height, fit: BoxFit.cover,
            headers: snapshot.data == null ? null :
                {'Authorization': 'Bearer ${snapshot.data}'},
            errorBuilder: (_, __, ___) => const Text('تعذر تحميل الصورة'));
      });
}
