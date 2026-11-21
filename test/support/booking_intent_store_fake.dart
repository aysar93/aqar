import 'package:aqar/bookings/booking_request_intent_store.dart';

class MemoryIntentStore implements BookingRequestIntentStore {
  bool failRead = false;
  final data = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String u, String v) async {
    if (failRead) throw StateError('synthetic unreadable journal');
    return data['$u/$v'];
  }

  @override
  Future<void> save(String u, String v, Map<String, dynamic> p) async {
    data['$u/$v'] = Map.of(p);
  }

  @override
  Future<void> clear(String u, String v, String id) async {
    if (data['$u/$v']?['requestId'] == id) data.remove('$u/$v');
  }
}
