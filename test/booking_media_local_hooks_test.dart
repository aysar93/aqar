import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings/booking_media_local_hooks.dart';
class _Hooks extends BookingMediaLocalHooks {
 @override Stream<T> document<T>(Stream<T> value)=>value;
 @override Stream<T> query<T>(Stream<T> value)=>value;
 @override Future<Uint8List?> pick(bool video) async=>null;
}
void main(){test('original editor local hooks reject ordinary application builds before Firebase access',(){expect(()=>_Hooks().checkLocalOnly(),throwsStateError);});}
