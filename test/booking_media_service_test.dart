import 'dart:async';
import 'package:aqar/bookings/booking_media_image.dart';
import 'dart:typed_data';
import 'package:aqar/bookings/booking_media_service.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
      'large legacy images use bounded authenticated ranges without truncation',
      () async {
    const size = 9 * 1024 * 1024;
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.headers['Authorization'], 'Bearer preview-token');
      final range = request.headers['Range'];
      if (range == null)
        return http.Response('', 416,
            headers: {'content-range': 'bytes */$size'});
      final parts = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
      final start = int.parse(parts.group(1)!),
          end = int.parse(parts.group(2)!);
      expect(end - start + 1, lessThanOrEqualTo(4 * 1024 * 1024));
      return http.Response.bytes(
          Uint8List(end - start + 1)..fillRange(0, end - start + 1, 7), 206,
          headers: {'content-range': 'bytes $start-$end/$size'});
    });
    final bytes = await BookingMediaService.readImageData(
        'https://image.test/gateway', 'preview-token',
        client: client);
    expect(bytes.length, size);
    expect(bytes.every((byte) => byte == 7), isTrue);
    expect(calls, 4);
  });
  test('image access revoked between ranges never returns partial content',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1)
        return http.Response('', 416,
            headers: {'content-range': 'bytes */9437184'});
      if (calls == 2)
        return http.Response.bytes(Uint8List(4194304), 206,
            headers: {'content-range': 'bytes 0-4194303/9437184'});
      return http.Response('', 403);
    });
    await expectLater(
        BookingMediaService.readImageData('https://image.test/gateway', null,
            client: client),
        throwsStateError);
    expect(calls, 3);
  });
  test('oversize legacy image rejected before downloading ranges', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('', 416,
          headers: {'content-range': 'bytes */10485761'});
    });
    await expectLater(
        BookingMediaService.readImageData('https://image.test/gateway', null,
            client: client),
        throwsStateError);
    expect(calls, 1);
  });
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
  test('booking playback uses the project gateway including emulator', () {
    BookingMediaService.emulatorHost = '127.0.0.1';
    expect(
        BookingMediaService.videoUrl(
            'demo-aqar.appspot.com', 'booking_media_v3/v/u/id.mp4'),
        'http://127.0.0.1:5001/demo-aqar/us-central1/bookingMediaContent?mediaId=id');
    BookingMediaService.emulatorHost = null;
    expect(
        BookingMediaService.videoUrl(
            'staging.firebasestorage.app', 'booking_media_v3/v/u/id.mp4'),
        startsWith(
            'https://us-central1-staging.cloudfunctions.net/bookingMediaContent'));
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
