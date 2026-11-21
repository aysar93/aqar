import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../tool/booking_network/staging_screen_adapter.dart';
void main(){
 test('staging diagnostic transport blocks other project and cleartext before network',()async{
  var calls=0;final c=SingleAttemptStagingClient(client:MockClient((_)async{calls++;return http.Response('',200);}));
  for(final u in ['https://invalid.example/uploadBookingVideoChunk','http://us-central1-aqar-bookings-test-20261009.cloudfunctions.net/uploadBookingVideoChunk']){
   await expectLater(c.post(Uri.parse(u)),throwsStateError);
  }
  expect(calls,0);c.close();
 });
 test('failed chunk stops original retry path before second transmission',()async{
  var calls=0;final c=SingleAttemptStagingClient(client:MockClient((_)async{calls++;return http.Response('synthetic',500);}));
  final u=Uri.parse('https://us-central1-aqar-bookings-test-20261009.cloudfunctions.net/uploadBookingVideoChunk?mediaId=synthetic&index=0');
  await expectLater(c.post(u,body:[1,2]),throwsStateError);
  await expectLater(c.post(u,body:[1,2]),throwsStateError);
  expect(calls,1);expect(c.events.single['http'],500);c.close();
 });
}
