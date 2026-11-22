import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_media_local_hooks.dart';
import 'package:aqar/bookings/booking_media_service.dart';
import '../tool/booking_network/original_service_local_adapter.dart';

class ScreenHooks extends BookingMediaLocalHooks {
  final OriginalServiceLocalAdapter adapter;
  final Uint8List image;
  ScreenHooks(this.adapter,this.image);
  @override Stream<T> document<T>(Stream<T> source)=>adapter.holdDocument(source);
  @override Stream<T> query<T>(Stream<T> source)=>adapter.holdQuery(source);
  @override Future<Uint8List?> pick(bool video) async {if(video)throw StateError('IMAGE_CASE_ONLY');return image;}
}
Future<void> waitUi(WidgetTester t,bool Function() done) async {
 final deadline=DateTime.now().add(const Duration(seconds:90));
 while(!done()){if(DateTime.now().isAfter(deadline))throw TimeoutException('ORIGINAL_SCREEN_BOUNDARY_TIMEOUT');await t.pump(const Duration(milliseconds:150));}
}
void main(){
 IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 testWidgets('original venue editor S3 boundaries and fresh-process recovery',(t)async{
 if(appFlavor!='bookingsLocalDiagnostic'||!const bool.fromEnvironment('RUN_BOOKINGS_LOCAL_NATIVE'))throw StateError('LOCAL_NATIVE_ONLY');
 final fixture=jsonDecode(await File('${(await getApplicationSupportDirectory()).path}/local_fixture.json').readAsString()) as Map<String,dynamic>;
 final renderOnly=fixture['BOOKING_CASE']=='UI_S3_RENDER';
 final recovery=fixture['BOOKING_CASE']=='UI_S3_RECOVER'||renderOnly;
 if(!recovery&&fixture['BOOKING_CASE']!='UI_S3_KILL')throw StateError('NEW_UI_CASE_REQUIRED');
 await Firebase.initializeApp(options:const FirebaseOptions(apiKey:'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',appId:'1:123456789000:android:0123456789abcdef',messagingSenderId:'123456789000',projectId:'demo-aqar',storageBucket:'demo-aqar.appspot.com'));
 final adapter=OriginalServiceLocalAdapter();await adapter.configureExistingDemoApp();
 await FirebaseStorage.instance.useStorageEmulator('127.0.0.1',9198,automaticHostMapping:false);
 await FirebaseAuth.instance.signInWithEmailAndPassword(email:fixture['BOOKINGS_LOCAL_EMAIL'],password:fixture['BOOKINGS_LOCAL_PASSWORD']);
 final venue=fixture['BOOKINGS_LOCAL_VENUE'] as String;
 final data=(await FirebaseFirestore.instance.doc('booking_venues/$venue').get(const GetOptions(source:Source.server))).data()!;
 final recorder=ui.PictureRecorder();ui.Canvas(recorder).drawColor(const Color(0xff9933bb),ui.BlendMode.src);final img=await recorder.endRecording().toImage(32,32);final encoded=await img.toByteData(format:ui.ImageByteFormat.png);img.dispose();
 await t.pumpWidget(MaterialApp(home:BookingVenueEditor(venueId:venue,data:data,ownerMode:true,call:adapter.nativeCall,localMediaHooks:recovery?null:ScreenHooks(adapter,encoded!.buffer.asUint8List()))));
 await t.pump(const Duration(seconds:1));
 final mediaTab=find.widgetWithText(Tab,'الوسائط');await t.ensureVisible(mediaTab);await t.pump(const Duration(milliseconds:400));await t.tap(mediaTab);await t.pump(const Duration(seconds:1));
 final query=FirebaseFirestore.instance.collection('booking_media_reviews').where('venueId',isEqualTo:venue).where('ownerId',isEqualTo:FirebaseAuth.instance.currentUser!.uid);
 if(!recovery){
  final upload=find.text('رفع صورة للمراجعة (10 MB)');await t.ensureVisible(upload);await t.tap(upload);await t.pump();
  await waitUi(t,()=>adapter.imageResult.reached.isCompleted&&adapter.queryEvents.reached.isCompleted&&adapter.documentEvents.reached.isCompleted);
  final rows=await query.get(const GetOptions(source:Source.server));expect(rows.docs,hasLength(1));expect(rows.docs.single.data()['status'],'pending');
  expect(adapter.queryEvents.delivered,0);expect(adapter.documentEvents.delivered,0);expect(adapter.imageResult.delivered,0);
  expect(find.text('بانتظار مراجعة الإدارة'),findsNothing);expect(find.text('الملف بانتظار مراجعة الإدارة'),findsNothing);
  final save=t.widget<FilledButton>(find.widgetWithText(FilledButton,'حفظ بيانات المكان'));expect(save.onPressed,isNull);
  final row=rows.docs.single;final bytes=await BookingMediaService.readImageData(BookingMediaService.videoUrl('demo-aqar.appspot.com',row.data()['path']),await FirebaseAuth.instance.currentUser!.getIdToken());
  print('BOOKING_LOCAL_NATIVE_CHECKPOINT ${jsonEncode({'phase':'ORIGINAL_EDITOR_S3_READY_FOR_PROCESS_KILL','mediaId':row.id,'sha256':sha256.convert(bytes).toString(),'functionsDelivered':adapter.imageResult.delivered,'queryDelivered':adapter.queryEvents.delivered,'documentDelivered':adapter.documentEvents.delivered,'saveDisabled':save.onPressed==null,'successSnackAbsent':true,'pendingCardAbsent':true,'atUtc':DateTime.now().toUtc().toIso8601String()})}');
  await Completer<void>().future;
 }else{
  await waitUi(t,()=>find.text('بانتظار مراجعة الإدارة').evaluate().isNotEmpty);
  await t.ensureVisible(find.text('بانتظار مراجعة الإدارة'));await t.pump(const Duration(seconds:1));
  await waitUi(t,()=>t.widgetList<Image>(find.byType(Image)).any((i)=>i.image is MemoryImage));
  final images=t.widgetList<Image>(find.byType(Image)).where((i)=>i.image is MemoryImage).toList();final expected=fixture['BOOKINGS_LOCAL_IMAGE_SHA256'];expect(images.any((i)=>sha256.convert((i.image as MemoryImage).bytes).toString()==expected),isTrue);
  final rows=await query.get(const GetOptions(source:Source.server));expect(rows.docs,hasLength(1));expect(rows.docs.single.id,fixture['BOOKINGS_LOCAL_MEDIA_ID']);
  expect(find.text('الملف بانتظار مراجعة الإدارة'),findsNothing);final save=t.widget<FilledButton>(find.widgetWithText(FilledButton,'حفظ بيانات المكان'));expect(save.onPressed,isNotNull);
  if(renderOnly){await waitUi(t,()=>t.widgetList<RawImage>(find.byType(RawImage)).any((i)=>i.image!=null));await t.pump(const Duration(milliseconds:400));final decoded=t.widgetList<RawImage>(find.byType(RawImage)).firstWhere((i)=>i.image!=null).image!;expect(decoded.width,32);expect(decoded.height,32);final pixels=await decoded.toByteData(format:ui.ImageByteFormat.rawRgba);expect(pixels,isNotNull);print('BOOKING_LOCAL_NATIVE_RESULT ${jsonEncode({'result':'PASS_LOCAL_RESTORED_FIXTURE_IMAGE_RENDER','restoredFixtureNotNewUpload':true,'decodedWidth':decoded.width,'decodedHeight':decoded.height,'firstDecodedRgba':pixels!.buffer.asUint8List().take(4).toList(),'providerHash':expected,'project':'demo-aqar','atUtc':DateTime.now().toUtc().toIso8601String()})}');await Completer<void>().future;}
  print('BOOKING_LOCAL_NATIVE_RESULT ${jsonEncode({'result':'PASS_LOCAL_ORIGINAL_EDITOR_S3_RECOVERY','mediaId':rows.docs.single.id,'documents':rows.docs.length,'displayedImageSha256':expected,'pendingCardVisible':true,'saveEnabled':true,'duplicateSuccessSnackAbsent':true,'project':'demo-aqar','atUtc':DateTime.now().toUtc().toIso8601String()})}');
 }
 },timeout:const Timeout(Duration(minutes:10)));
}
