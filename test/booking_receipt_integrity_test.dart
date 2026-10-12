import 'dart:typed_data';
import 'package:aqar/bookings/booking_media_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final original = Uint8List.fromList([0xff, 0xd8, 1, 2, 0xff, 0xd9]);
  test('receipt verification rejects a successful but truncated resumed upload',
      () async {
    await expectLater(
        BookingMediaService.uploadVerifiedReceipt(original,
            upload: (_) async {},
            read: () async => Uint8List.fromList([0xff, 0xd8, 1, 2])),
        throwsA(isA<BookingReceiptIntegrityException>()));
  });
  test('receipt verification rejects corruption even when lengths match',
      () async {
    await expectLater(
        BookingMediaService.uploadVerifiedReceipt(original,
            upload: (_) async {},
            read: () async =>
                Uint8List.fromList([0xff, 0xd8, 9, 2, 0xff, 0xd9])),
        throwsA(isA<BookingReceiptIntegrityException>()));
  });
  test('receipt verification accepts exact private readback', () async {
    var uploaded = false;
    await BookingMediaService.uploadVerifiedReceipt(original,
        upload: (bytes) async {
      expect(bytes, original);
      uploaded = true;
    }, read: () async {
      expect(uploaded, isTrue);
      return Uint8List.fromList(original);
    });
  });
  test('failed receipt upload cannot proceed to readback', () async {
    var read = false;
    await expectLater(
        BookingMediaService.uploadVerifiedReceipt(original,
            upload: (_) async => throw StateError('offline'),
            read: () async {
              read = true;
              return original;
            }),
        throwsStateError);
    expect(read, isFalse);
  });
  test('rejected readback requests cleanup before returning integrity error',
      () async {
    var discarded = false;
    await expectLater(
        BookingMediaService.uploadVerifiedReceipt(original,
            upload: (_) async {},
            read: () async => Uint8List.fromList([0xff, 0xd8]),
            discardInvalid: () async {
              discarded = true;
            }),
        throwsA(isA<BookingReceiptIntegrityException>()));
    expect(discarded, isTrue);
  });
  test('failed cleanup never permits payment submission', () async {
    await expectLater(
        BookingMediaService.uploadVerifiedReceipt(original,
            upload: (_) async {},
            read: () async => null,
            discardInvalid: () async => throw StateError('offline')),
        throwsA(isA<BookingReceiptIntegrityException>()));
  });
}
