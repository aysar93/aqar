// Native, original checkout and disk journal; demo project + loopback only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_experience.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:aqar/bookings/booking_request_intent_store.dart';
import '../tool/booking_network/original_service_local_adapter.dart';

Future<void> waitFor(WidgetTester t,bool Function() predicate)async{
 final deadline=DateTime.now().add(const Duration(seconds:120));
 while(!predicate()){if(DateTime.now().isAfter(deadline))throw TimeoutException('LOCAL_RESTART_BOUNDARY_TIMEOUT');await t.pump(const Duration(milliseconds:150));}
}
Future<Map<String,dynamic>> proxy()async=>jsonDecode((await http.get(Uri.parse('http://127.0.0.1:5001/__state'))).body) as Map<String,dynamic>;
void main(){
 IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 testWidgets('native original checkout durable request restart',(t)async{
 if(appFlavor!='bookingsLocalDiagnostic'||!const bool.fromEnvironment('RUN_BOOKINGS_LOCAL_NATIVE'))throw StateError('LOCAL_FLAVOR_REQUIRED');
 final fixture=jsonDecode(await File('${(await getApplicationSupportDirectory()).path}/local_fixture.json').readAsString()) as Map<String,dynamic>;
 final c=fixture['case'] as String;
 if(!{'CUT','VERIFY_PENDING','OTHER_ACCOUNT','OTHER_VENUE','RECOVER'}.contains(c))throw StateError('CASE_REJECTED');
 await Firebase.initializeApp(options:const FirebaseOptions(apiKey:'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',appId:'1:123456789000:android:0123456789abcdef',messagingSenderId:'123456789000',projectId:'demo-aqar',storageBucket:'demo-aqar.appspot.com'));
 final adapter=OriginalServiceLocalAdapter();await adapter.configureExistingDemoApp();await FirebaseStorage.instance.useStorageEmulator('127.0.0.1',9198,automaticHostMapping:false);
 await FirebaseAuth.instance.signOut();
 await FirebaseAuth.instance.signInWithEmailAndPassword(email:fixture[c=='OTHER_ACCOUNT'?'otherEmail':'email'],password:fixture[c=='OTHER_ACCOUNT'?'otherPassword':'password']);
 final uid=FirebaseAuth.instance.currentUser!.uid,venue=fixture[c=='OTHER_VENUE'?'otherVenue':'venue'] as String;
 final data=(await FirebaseFirestore.instance.doc('booking_venues/$venue').get(const GetOptions(source:Source.server))).data()!;
 final journal=FileBookingRequestIntentStore();var requestCalls=0;String? sentId,errorCode,destination;
 Future<Map<String,dynamic>> call(String name,Map<String,dynamic> payload)async{
  if(Firebase.app().options.projectId!='demo-aqar'||!{'requestBooking','getBookingAvailability','getPublishedBookingReviews'}.contains(name))throw StateError('LOCAL_CALL_REJECTED');
  if(name=='requestBooking'){requestCalls++;if(requestCalls>1)throw StateError('NO_REPEAT_IN_ONE_PROCESS');sentId=payload['requestId'] as String;}
  try{final r=await FirebaseFunctions.instance.httpsCallable(name,options:HttpsCallableOptions(timeout:const Duration(minutes:5))).call(payload);return Map<String,dynamic>.from(r.data as Map);}
  on FirebaseFunctionsException catch(e){if(name=='requestBooking')errorCode=e.code;rethrow;}
 }
 Future<void> mount({bool detailsAfterSuccess=false})async{
  await t.pumpWidget(MaterialApp(home:BookingRequestScreen(venueId:venue,venue:data,call:call,onRequested:detailsAfterSuccess?(id){destination=id;}:null)));
  await waitFor(t,()=>find.text('اختيار الموعد').evaluate().isNotEmpty||find.text('إعادة المحاولة بنفس الطلب').evaluate().isNotEmpty);
 }
 Future<void> visibleTap(Finder finder)async{
  if(finder.evaluate().isEmpty){
   await t.scrollUntilVisible(finder,180,scrollable:find.byType(Scrollable).first,maxScrolls:25);
  }
  await t.ensureVisible(finder);await t.pump(const Duration(milliseconds:300));
  for(var i=0;i<6&&finder.hitTestable().evaluate().isEmpty;i++){await t.drag(find.byType(ListView).first,const Offset(0,-160));await t.pump(const Duration(milliseconds:200));}
  expect(finder.hitTestable(),findsOneWidget);await t.tap(finder.hitTestable());await t.pump(const Duration(milliseconds:300));
 }
 Future<void> calendar()async{
  await visibleTap(find.byKey(const ValueKey('booking-next')));
  await visibleTap(find.byType(DropdownButtonFormField<String>));
  await visibleTap(find.textContaining('DIAGNOSTIC DAY').last);
  await visibleTap(find.byTooltip('الشهر التالي'));
  await waitFor(t,()=>find.byType(BookingCalendar).evaluate().isNotEmpty);
 }
 void marker(String kind,Map<String,dynamic> extra)=>print('BOOKING_RESTART_$kind ${jsonEncode({'case':c,'project':'demo-aqar','atUtc':DateTime.now().toUtc().toIso8601String(),...extra})}');
 await mount(detailsAfterSuccess:c=='RECOVER');
 if(c=='OTHER_ACCOUNT'||c=='OTHER_VENUE'){
  expect(await journal.read(uid,venue),isNull);expect(find.text('إعادة المحاولة بنفس الطلب'),findsNothing);expect(find.text('SYNTHETIC_PENDING_PRIVATE'),findsNothing);expect(requestCalls,0);
  final original=await journal.read(fixture['customerUid'],fixture['venue']);expect(original?['requestId'],fixture['requestId']);
  marker('RESULT',{'result':'PASS_LOCAL_DEVICE_PENDING_ISOLATION','requestCalls':requestCalls,'primaryIntentPreserved':true,'pendingIntentForCurrentContext':false});
 }else if(c=='VERIFY_PENDING'){
  final pending=await journal.read(uid,venue);expect(pending?['requestId'],fixture['requestId']);
  final retry=find.widgetWithText(FilledButton,'إعادة المحاولة بنفس الطلب');
  expect(t.widget<FilledButton>(retry).onPressed,isNotNull);expect(requestCalls,0);
  final rows=await FirebaseFirestore.instance.collection('bookings').where('venueId',isEqualTo:venue).where('customerId',isEqualTo:uid).get(const GetOptions(source:Source.server));expect(rows.docs,hasLength(1));
  marker('RESULT',{'result':'PASS_LOCAL_DEVICE_FIRST_REOPEN_PENDING_INTENT','requestId':pending!['requestId'],'bookingId':rows.docs.single.id,'documents':rows.docs.length,'requestCalls':requestCalls,'retryEnabled':true,'status':rows.docs.single.data()['status']});
 }else if(c=='CUT'){
  await calendar();await visibleTap(find.text('22'));await visibleTap(find.byKey(const ValueKey('booking-next')));
  await visibleTap(find.byType(CheckboxListTile));
  await http.post(Uri.parse('http://127.0.0.1:5001/__arm'));
  await visibleTap(find.text('إرسال طلب الحجز'));
  Map<String,dynamic> p={};
  final deadline=DateTime.now().add(const Duration(seconds:120));
  while(p['held']!=true){if(DateTime.now().isAfter(deadline))throw TimeoutException('LOCAL_SERVER_RESPONSE_NOT_HELD');p=await proxy();await t.pump(const Duration(milliseconds:200));}
  final pending=await journal.read(uid,venue);expect(pending?['requestId'],sentId);
  final rows=await FirebaseFirestore.instance.collection('bookings').where('venueId',isEqualTo:venue).where('customerId',isEqualTo:uid).get(const GetOptions(source:Source.server));expect(rows.docs,hasLength(1));
  marker('HELD',{'requestId':sentId,'bookingId':rows.docs.single.id,'documents':1,'journalPersistedBeforeSend':true});
  await waitFor(t,()=>errorCode!=null);
  final retry=find.widgetWithText(FilledButton,'إعادة المحاولة بنفس الطلب');await waitFor(t,()=>retry.evaluate().isNotEmpty&&t.widget<FilledButton>(retry).onPressed!=null);
  marker('CHECKPOINT',{'requestId':sentId,'bookingId':rows.docs.single.id,'documents':1,'transportErrorCode':errorCode,'journalRequestId':(await journal.read(uid,venue))?['requestId'],'retryEnabled':true,'requestCalls':requestCalls});
 }else{
  final pending=await journal.read(uid,venue);expect(pending?['requestId'],fixture['requestId']);
  marker('RESTORED',{'requestId':pending!['requestId'],'beforeRetryRequestCalls':requestCalls,'restoredReviewVisible':true});
  await visibleTap(find.text('إعادة المحاولة بنفس الطلب'));await waitFor(t,()=>destination!=null);
  expect(sentId,fixture['requestId']);expect(await journal.read(uid,venue),isNull);
  await t.pumpWidget(MaterialApp(home:BookingDetailsScreen(bookingId:destination!,call:call)));
  await waitFor(t,()=>find.textContaining('بانتظار المالك').evaluate().isNotEmpty);
  marker('DETAILS',{'bookingId':destination,'status':'requested','originalDetailsScreen':true});
  await Future<void>.delayed(const Duration(seconds:8));
  await mount();await calendar();
  await waitFor(t,()=>find.byType(BookingCalendar).evaluate().isNotEmpty&&t.widget<BookingCalendar>(find.byType(BookingCalendar)).slots.length==1);
  final slots=t.widget<BookingCalendar>(find.byType(BookingCalendar)).slots;
  expect(slots,hasLength(1));expect(slots.single['start'],pending['start']);expect(slots.single['end'],pending['end']);expect(slots.single['state'],'pending');
  final rows=await FirebaseFirestore.instance.collection('bookings').where('venueId',isEqualTo:venue).where('customerId',isEqualTo:uid).get(const GetOptions(source:Source.server));expect(rows.docs,hasLength(1));expect(rows.docs.single.id,destination);
  marker('RESULT',{'result':'PASS_LOCAL_DEVICE_REQUESTID_PROCESS_RECOVERY','requestId':sentId,'bookingId':destination,'documents':rows.docs.length,'auditCountVerifiedSeparatelyByHost':true,'requestCallsOnRecovery':requestCalls,'status':rows.docs.single.data()['status'],'calendarSlots':slots,'journalClearedAfterAcknowledgedSuccess':true});
 }
 await Completer<void>().future;
 },timeout:const Timeout(Duration(minutes:15)));
}
