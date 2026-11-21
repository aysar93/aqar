import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_finance_query.dart';

class FixtureQuery extends Fake implements Query<Map<String, dynamic>> {
  FixtureQuery(this.records);
  final List<Map<String, dynamic>> records;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      final field = invocation.positionalArguments.single as String;
      final accepted = invocation.namedArguments[#whereIn] as Iterable;
      return FixtureQuery(
          records.where((r) => accepted.contains(r[field])).toList());
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  test(
      'finance queue exposes completed booking for independent owner settlement',
      () {
    final queue = bookingFinanceQueue(FixtureQuery([
      {'id': 'settle-owner', 'status': 'completed', 'paid': 1001},
      {'id': 'receipt', 'status': 'payment_review'},
      {'id': 'cancel-review', 'status': 'cancel_requested'},
      {'id': 'refund', 'status': 'cancelled'},
      {'id': 'pending-owner', 'status': 'requested'},
      {'id': 'unpaid', 'status': 'held'},
      {'id': 'ongoing', 'status': 'confirmed'},
    ])) as FixtureQuery;
    expect(queue.records.map((r) => r['id']),
        ['settle-owner', 'receipt', 'cancel-review', 'refund']);
  });
}
