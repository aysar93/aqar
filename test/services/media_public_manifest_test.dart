import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/services/media_location.dart';
import 'package:aqar/services/media_public_imports.dart';

void main() {
  test(
      'exact public manifest never authorizes prefix, suffix or unknown private paths',
      () {
    const bucket = 'aqar-9f3f9-media-canary';
    expect(publicImportedMediaPaths.length, 227);
    for (final path in publicImportedMediaPaths) {
      expect(
          MediaLocation.needsAuth(MediaLocation.urlFor(bucket, path), bucket),
          isFalse);
      expect(
          MediaLocation.needsAuth(
              MediaLocation.urlFor(bucket, '$path.extra'), bucket),
          isTrue);
    }
    for (final path in [
      'uploads/private/license/owner/synthetic.png',
      'staging/private/cloudinary-hwxcrlcj/image/synthetic/v1/unknown.png'
    ]) {
      expect(
          MediaLocation.needsAuth(MediaLocation.urlFor(bucket, path), bucket),
          isTrue);
    }
  });
}
