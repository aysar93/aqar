import 'dart:typed_data';
import 'package:aqar/bookings/booking_media_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final original = Uint8List.fromList([0xff, 0xd8, 1, 2, 0xff, 0xd9]);
  test('cold retry reuses complete receipt without writing an immutable object',
      () async {
    await BookingMediaService.uploadVerifiedReceipt(original,
        reuseExisting: true,
        upload: (_) async => throw StateError('duplicate upload'),
        read: () async => Uint8List.fromList(original));
    expect(BookingMediaService.receiptFileName(original),
        BookingMediaService.receiptFileName(Uint8List.fromList(original)));
    expect(BookingMediaService.receiptFileName(original),
        matches(r'^[0-9]+\.jpg$'));
    expect(BookingMediaService.receiptFileName(Uint8List.fromList([1, 2, 3])),
        isNot(BookingMediaService.receiptFileName(original)));
  });
  test('missing receipt uploads once and verifies before accepting', () async {
    var uploaded = false;
    await BookingMediaService.uploadVerifiedReceipt(original,
        reuseExisting: true,
        upload: (_) async => uploaded = true,
        read: () async => uploaded ? original : null);
    expect(uploaded, isTrue);
  });
  test('cold retry rejects truncated immutable receipt and requests discard',
      () async {
    var discarded = false;
    await expectLater(
        BookingMediaService.uploadVerifiedReceipt(original,
            reuseExisting: true,
            upload: (_) async => throw StateError('must not overwrite'),
            read: () async => Uint8List.fromList([0xff, 0xd8]),
            discardInvalid: () async => discarded = true),
        throwsA(isA<BookingReceiptIntegrityException>()));
    expect(discarded, isTrue);
  });
  test('offline lookup cannot create a second receipt', () async {
    await expectLater(
        BookingMediaService.uploadVerifiedReceipt(original,
            reuseExisting: true,
            upload: (_) async => throw StateError('must not upload'),
            read: () async => throw StateError('offline')),
        throwsStateError);
  });
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
