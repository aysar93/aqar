import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/services/media_location.dart';
import 'package:aqar/services/media_public_imports.dart';
void main() {
 test('isolated snapshot does not expose imported production manifests', () {
  expect(publicImportedMediaPaths,isEmpty);
  const bucket='demo-media';
  expect(MediaLocation.needsAuth(MediaLocation.urlFor(bucket,'uploads/public/avatar/synthetic/file.jpg'),bucket),isFalse);
  expect(MediaLocation.needsAuth(MediaLocation.urlFor(bucket,'staging/private/synthetic/file.jpg'),bucket),isTrue);
 });
}
