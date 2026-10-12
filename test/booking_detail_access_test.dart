import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_detail_access.dart';

void main() {
  final cached = <String, dynamic>{
    'customerId': 'first',
    'ownerId': 'venue-owner',
    'customerPhone': 'PRIVATE_PHONE',
    'receiptPath': 'PRIVATE_RECEIPT'
  };
  test('cached first-account document cannot render for a second account', () {
    expect(bookingCanDisplayDetails(uid: 'first', booking: cached), isTrue);
    expect(bookingCanDisplayDetails(uid: 'second', booking: cached), isFalse);
  });
  test('signed-out sessions cannot reuse cached details or privileged flags',
      () {
    expect(
        bookingCanDisplayDetails(
            uid: null, booking: cached, admin: true, finance: true),
        isFalse);
  });
  test('customer, venue owner and authorized review roles retain access', () {
    expect(
        bookingCanDisplayDetails(uid: 'venue-owner', booking: cached), isTrue);
    expect(bookingCanDisplayDetails(uid: 'admin', booking: cached, admin: true),
        isTrue);
    expect(
        bookingCanDisplayDetails(
            uid: 'reviewer', booking: cached, finance: true),
        isTrue);
    expect(bookingCanDisplayDetails(uid: 'staff', booking: cached), isFalse);
  });
  test('missing participant fields never authorize a signed-out account', () {
    expect(bookingCanDisplayDetails(uid: null, booking: {}), isFalse);
    expect(bookingCanDisplayDetails(uid: 'second', booking: {}), isFalse);
  });
}
