import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_request_intent_store.dart';

void main() {
  final payload = <String, dynamic>{
    'venueId': 'v',
    'requestId': '123',
    'start': 100,
    'end': 200,
    'price': 250000,
    'deposit': 50000,
    'notes': 'SYNTHETIC'
  };
  test(
      'pending intent survives store reconstruction and stays account/venue isolated',
      () async {
    final dir = await Directory.systemTemp.createTemp('booking_intent_test_');
    try {
      final first = FileBookingRequestIntentStore(directory: () async => dir);
      await first.save('u', 'v', payload);
      final second = FileBookingRequestIntentStore(directory: () async => dir);
      expect(await second.read('u', 'v'), payload);
      expect(await second.read('other', 'v'), isNull);
      expect(await second.read('u', 'other'), isNull);
      await second.clear('u', 'v', 'wrong-id');
      expect(await second.read('u', 'v'), payload);
      await second.save('u', 'v', payload);
      await second.clear('u', 'v', '123');
      expect(await first.read('u', 'v'), isNull);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('conflicting pending intents cannot overwrite an unresolved request',
      () async {
    final dir = await Directory.systemTemp.createTemp('booking_intent_test_');
    try {
      final store = FileBookingRequestIntentStore(directory: () async => dir);
      final attempts = await Future.wait([
        store.save('u', 'v', payload).then((_) => true),
        store.save('u', 'v', {...payload, 'requestId': '124'}).then((_) => true,
            onError: (_) => false)
      ]);
      expect(attempts, [true, false]);
      expect(await store.read('u', 'v'), payload);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test(
      'corrupt pending journal fails closed instead of silently creating a new request',
      () async {
    final dir = await Directory.systemTemp.createTemp('booking_intent_test_');
    try {
      final store = FileBookingRequestIntentStore(directory: () async => dir);
      await store.save('u', 'v', payload);
      final file = await Directory('${dir.path}/booking_request_intents')
          .list()
          .where((f) => f.path.endsWith('.json'))
          .single;
      await File(file.path).writeAsString('INVALID');
      await expectLater(store.read('u', 'v'), throwsFormatException);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
