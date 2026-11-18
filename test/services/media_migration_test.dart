import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/services/media_location.dart';
import 'package:aqar/services/media_store.dart';

void main() {
  const bucket = 'demo-media';
  test('Firebase paths round trip once without trusting another bucket', () {
    for (final path in [
      'uploads/private/license/u/file.png',
      'folder/a b.jpg',
      'literal%2Fname.jpg',
      'صورة.png'
    ]) {
      expect(MediaLocation.pathFor(MediaLocation.urlFor(bucket, path), bucket),
          path);
    }
    expect(MediaLocation.pathFor('gs://demo-media/a/b.png', bucket), 'a/b.png');
    expect(MediaLocation.pathFor('gs://other/a.png', bucket), isNull);
    expect(
        MediaLocation.pathFor(
            'https://firebasestorage.googleapis.com.evil.test/v0/b/demo-media/o/file',
            bucket),
        isNull);
    expect(
        MediaLocation.pathFor(
            'http://firebasestorage.googleapis.com/v0/b/demo-media/o/file',
            bucket),
        isNull);
    expect(MediaLocation.pathFor(MediaLocation.urlFor(bucket, 'private/a'), ''),
        isNull);
  });
  test('Private namespace never selects an unauthenticated reader', () {
    for (final path in [
      'uploads/private/license/u/a.png',
      'uploads/private/receipt/u/a.png',
      'uploads/private/chat_audio/chat/u/a.m4a',
      'staging/private/a.png'
    ]) {
      expect(
          MediaLocation.needsAuth(MediaLocation.urlFor(bucket, path), bucket),
          isTrue);
    }
    expect(
        MediaLocation.needsAuth(
            MediaLocation.urlFor(bucket, 'uploads/public/avatar/u/a.png'),
            bucket),
        isFalse);
    expect(
        MediaLocation.needsAuth(
            'https://res.cloudinary.com/hwxcrlcj/image/upload/v1/x.jpg',
            bucket),
        isFalse);
  });
  test('Image content sniff rejects mislabeled and unsupported files', () {
    expect(
        MediaStore.imageType(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10])),
        'png');
    expect(
        MediaStore.imageType(Uint8List.fromList([255, 216, 255, 224])), 'jpg');
    for (final bytes in [
      <int>[],
      [60, 104, 116, 109, 108],
      [0, 0, 0, 24, 102, 116, 121, 112]
    ]) {
      expect(() => MediaStore.imageType(Uint8List.fromList(bytes)),
          throwsStateError);
    }
  });
  testWidgets('Image bytes render with Android and iOS widget platforms',
      (tester) async {
    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNQCu34DwADmwH/RyECiQAAAABJRU5ErkJggg==');
    await tester.pumpWidget(MaterialApp(home: Image.memory(bytes)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  },
      variant:
          TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));
}
