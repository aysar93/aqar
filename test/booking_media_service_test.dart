import 'dart:async';
import 'package:aqar/bookings/booking_media_image.dart';
import 'dart:typed_data';
import 'package:aqar/bookings/booking_media_service.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('private images wait for token before creating a network provider', (tester) async {
    final token=Completer<String?>();
    await tester.pumpWidget(MaterialApp(home: BookingMediaImage(url: 'https://image.test/bookingImage?mediaId=id', token: token.future)));
    expect(find.byType(Image), findsNothing);
    token.complete('preview-token');
    await tester.pump();
    final image=tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).headers!['Authorization'], 'Bearer preview-token');
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
    expect(() => BookingMediaService.uploadImage(Uint8List(0),
        (_, __) async => throw StateError('unexpected call')), throwsStateError);
  });
  test('video client rejects a reservation pointing at reels', () async {
    await expectLater(
        BookingMediaService.uploadVideo(Uint8List(12), 'venue',
            (_, __) async => {
                  'mediaId': 'id',
                  'path': 'https://worker.test/reels/original/id.mp4'
                }),
        throwsStateError);
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
