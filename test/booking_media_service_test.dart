import 'dart:async';
import 'package:aqar/bookings/booking_media_image.dart';
import 'dart:typed_data';
import 'package:aqar/bookings/booking_media_service.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'private images wait for token before creating a network provider',
      (tester) async {
    final token = Completer<String?>();
    await tester.pumpWidget(MaterialApp(
        home: BookingMediaImage(
            url: 'https://image.test/bookingImage?mediaId=id',
            token: token.future)));
    expect(find.byType(Image), findsNothing);
    token.complete('preview-token');
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).headers!['Authorization'],
        'Bearer preview-token');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  test('images use booking server callable with venue association', () async {
    String? name;
    Map<String, dynamic>? payload;
    final result = await BookingMediaService.uploadImage(
        Uint8List.fromList([255, 216, 255]), (n, d) async {
      name = n;
      payload = d;
      return {'mediaId': 'server-id', 'path': 'https://image.test'};
    }, venueId: 'farm-id', banner: true);
    expect(name, 'uploadBookingImage');
    expect(payload!['venueId'], 'farm-id');
    expect(payload!['kind'], 'banner');
    expect(payload!.keys, isNot(contains('public_id')));
    expect(result['mediaId'], 'server-id');
  });
  test('empty images are rejected before a server call', () {
    expect(
        () => BookingMediaService.uploadImage(
            Uint8List(0), (_, __) async => throw StateError('unexpected call')),
        throwsStateError);
  });
  test('video client rejects a reservation pointing at reels', () async {
    await expectLater(
        BookingMediaService.uploadVideo(
            Uint8List(12),
            'venue',
            (_, __) async => {
                  'mediaId': 'id',
                  'path': 'https://worker.test/reels/original/id.mp4'
                }),
        throwsStateError);
  });
  test('video uploads the reserved Firebase path then finalizes review',
      () async {
    final calls = <String>[];
    await BookingMediaService.uploadVideo(Uint8List(12), 'venue',
        (name, data) async {
      calls.add(name);
      return {'mediaId': 'id', 'path': 'booking_media_v3/venue/owner/id.mp4'};
    }, upload: (path, bytes) async {
      expect(path, 'booking_media_v3/venue/owner/id.mp4');
      expect(bytes.length, 12);
      calls.add('storage');
    });
    expect(calls, ['reserveBookingVideo', 'storage', 'finishBookingVideo']);
  });
  test('local booking video playback stays on the Storage emulator', () {
    BookingMediaService.emulatorHost = '127.0.0.1';
    expect(
        BookingMediaService.videoUrl(
            'demo-aqar.appspot.com', 'booking_media_v3/v/u/id.mp4'),
        'http://127.0.0.1:9198/v0/b/demo-aqar.appspot.com/o/booking_media_v3%2Fv%2Fu%2Fid.mp4?alt=media');
    BookingMediaService.emulatorHost = null;
    expect(
        BookingMediaService.videoUrl(
            'staging.firebasestorage.app', 'booking_media_v3/v/u/id.mp4'),
        startsWith(
            'https://firebasestorage.googleapis.com/v0/b/staging.firebasestorage.app/'));
  });
  for (final width in [320.0, 430.0, 900.0]) {
    testWidgets('new and legacy video entries retain RTL at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
          home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                  body: BookingMediaGallery(paths: [
                'https://worker.test/bookings/media/new.mp4',
                'booking_media/venue/owner/old.mp4',
              ])))));
      expect(find.text('مشاهدة فيديو المكان'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}
