import 'media_public_imports.dart';

// Token-free Firebase URLs remain normal HTTPS strings in Firestore.
class MediaLocation {
  static const defaultBucket = String.fromEnvironment('MEDIA_STORAGE_BUCKET');
  static String? pathFor(String value, String bucket) {
    final uri = Uri.tryParse(value);
    if (uri == null || bucket.isEmpty) return null;
    if (uri.scheme == 'gs' && uri.host == bucket) {
      return uri.pathSegments.join('/');
    }
    final segments = uri.pathSegments;
    if (uri.scheme == 'https' &&
        uri.host == 'firebasestorage.googleapis.com' &&
        segments.length == 5 &&
        segments[0] == 'v0' &&
        segments[1] == 'b' &&
        segments[2] == bucket &&
        segments[3] == 'o') {
      return segments[4];
    }
    return null;
  }

  static String urlFor(String bucket, String path) =>
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(path)}?alt=media';
  static bool needsAuth(String value, String bucket) {
    final path = pathFor(value, bucket);
    return path != null &&
        !path.startsWith('uploads/public/') &&
        !publicImportedMediaPaths.contains(path);
  }
}
