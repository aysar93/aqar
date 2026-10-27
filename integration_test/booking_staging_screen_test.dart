import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_media_service.dart';
import '../tool/booking_network/staging_screen_adapter.dart';

Future<void> waitUi(WidgetTester t,bool Function() done)async{
 final deadline=DateTime.now().add(const Duration(seconds:120));
 while(!done()){
  if(find.text('تعذر تشغيل الفيديو').evaluate().isNotEmpty)throw StateError('NATIVE_PLAYBACK_FAILED_STOP');
  if(DateTime.now().isAfter(deadline))throw TimeoutException('STAGING_BOUNDARY_TIMEOUT_STOP');
  await t.pump(const Duration(milliseconds:150));
 }
}
void emit(String kind,Map<String,dynamic> data)=>print('BOOKING_STAGING_$kind ${jsonEncode({...data,'project':StagingScreenAdapter.project,'atUtc':DateTime.now().toUtc().toIso8601String()})}');
void main(){
 IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 testWidgets('isolated Staging original editor S3 V5',(t)async{
 if(appFlavor!='bookingsStagingDiagnostic'||!const bool.fromEnvironment('RUN_BOOKINGS_STAGING_DIAGNOSTIC'))throw StateError('STAGING_DIAGNOSTIC_ONLY');
 final dir=(await getApplicationSupportDirectory()).path;
 final f=jsonDecode(await File('$dir/stage_fixture.json').readAsString()) as Map<String,dynamic>;
 final c=f['case'] as String;
 if(!{'S3_KILL','S3_RECOVER','V5_KILL','V5_RECOVER'}.contains(c))throw StateError('CASE_NOT_ALLOWED');
 final video=c.startsWith('V5'),recovery=c.endsWith('RECOVER');
 await Firebase.initializeApp();
 if(Firebase.app().options.projectId!=StagingScreenAdapter.project||Firebase.app().options.storageBucket!='${StagingScreenAdapter.project}.firebasestorage.app')throw StateError('NATIVE_PROJECT_REJECTED');
 FirebaseFirestore.instance.settings=const Settings(persistenceEnabled:false);
 await FirebaseAuth.instance.signInWithEmailAndPassword(email:f['email'],password:f['password']);
 final venue=f[video?'videoVenue':'imageVenue'] as String;
 final data=(await FirebaseFirestore.instance.doc('booking_venues/$venue').get(const GetOptions(source:Source.server))).data()!;
 if(data['active']!=false||data['ownerId']!=FirebaseAuth.instance.currentUser!.uid)throw StateError('SYNTHETIC_VENUE_GUARD');
 final recorder=ui.PictureRecorder();ui.Canvas(recorder).drawColor(const Color(0xff9933bb),ui.BlendMode.src);
 final img=await recorder.endRecording().toImage(32,32);final png=await img.toByteData(format:ui.ImageByteFormat.png);img.dispose();
 final input=video?await File('$dir/stage_video.mp4').readAsBytes():png!.buffer.asUint8List();
 if(video&&(input.length>=4*1024*1024||sha256.convert(input).toString()!=f['videoSha256']))throw StateError('ONE_SMALL_VIDEO_REQUIRED');
 final adapter=StagingScreenAdapter(video,input);adapter.guard();
 final transport=SingleAttemptStagingClient();
 // Scope covers original async http.post calls, never substitutes the service.
 await http.runWithClient(()async{
 await t.pumpWidget(MaterialApp(home:BookingVenueEditor(venueId:venue,data:data,ownerMode:true,call:adapter.call,localMediaHooks:recovery?null:adapter)));
 await t.pump(const Duration(seconds:1));
 final tab=find.widgetWithText(Tab,'الوسائط');await t.ensureVisible(tab);await t.pump(const Duration(milliseconds:400));await t.tap(tab);await t.pump(const Duration(seconds:1));
 final query=FirebaseFirestore.instance.collection('booking_media_reviews').where('venueId',isEqualTo:venue).where('ownerId',isEqualTo:FirebaseAuth.instance.currentUser!.uid);
 if(!recovery){
  final upload=find.text(video?'رفع فيديو للمراجعة (50 MB)':'رفع صورة للمراجعة (10 MB)');await t.ensureVisible(upload);await t.tap(upload);await t.pump();
  await waitUi(t,()=>adapter.result.reached.isCompleted&&adapter.queryEvents.reached.isCompleted&&adapter.documentEvents.reached.isCompleted);
  final rows=await query.get(const GetOptions(source:Source.server));expect(rows.docs,hasLength(1));expect(rows.docs.single.data()['status'],'pending');
  expect(adapter.result.delivered,0);expect(adapter.queryEvents.delivered,0);expect(adapter.documentEvents.delivered,0);
  expect(find.text('بانتظار مراجعة الإدارة'),findsNothing);expect(find.text('الملف بانتظار مراجعة الإدارة'),findsNothing);
  final save=t.widget<FilledButton>(find.widgetWithText(FilledButton,'حفظ بيانات المكان'));expect(save.onPressed,isNull);
  emit('CHECKPOINT',{'case':c,'mediaId':rows.docs.single.id,'documents':rows.docs.length,
   'functionsDelivered':0,'queryDelivered':0,'documentDelivered':0,'saveDisabled':true,
   'calls':adapter.calls,'events':adapter.events,'transport':transport.events,
   'sourceSha256':sha256.convert(input).toString()});
 }else{
  await waitUi(t,()=>find.text('بانتظار مراجعة الإدارة').evaluate().isNotEmpty);
  await t.ensureVisible(find.text('بانتظار مراجعة الإدارة'));await t.pump(const Duration(seconds:1));
  final rows=await query.get(const GetOptions(source:Source.server));expect(rows.docs,hasLength(1));expect(rows.docs.single.id,f['mediaId']);
  final save=t.widget<FilledButton>(find.widgetWithText(FilledButton,'حفظ بيانات المكان'));expect(save.onPressed,isNotNull);
  if(video){
   final button=find.text('مشاهدة فيديو المكان');await t.ensureVisible(button);await t.tap(button);await t.pump();
   await waitUi(t,()=>find.byType(VideoPlayer).evaluate().isNotEmpty);
   final controller=t.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
   expect(controller.value.isInitialized,isTrue);expect(controller.value.duration.inMilliseconds,greaterThan(0));
   final downloaded=controller.dataSource.startsWith('file:')?File.fromUri(Uri.parse(controller.dataSource)):File(controller.dataSource);expect(await downloaded.exists(),isTrue);
   final hash=sha256.convert(await downloaded.readAsBytes()).toString();expect(hash,f['videoSha256']);
   await t.tap(find.byIcon(Icons.play_arrow));await t.pump();
   await waitUi(t,()=>controller.value.isCompleted||controller.value.position>=controller.value.duration);
   expect(controller.value.hasError,isFalse);
   emit('RESULT',{'case':c,'result':'PASS_STAGING_ORIGINAL_SCREEN_RECOVERY_PLAYBACK','documents':1,'mediaId':rows.docs.single.id,
    'durationMs':controller.value.duration.inMilliseconds,'positionMs':controller.value.position.inMilliseconds,
    'width':controller.value.size.width,'height':controller.value.size.height,'sha256':hash,'completed':controller.value.isCompleted,'uploadCallsOnRecovery':adapter.calls.length});
  }else{
   await waitUi(t,()=>t.widgetList<RawImage>(find.byType(RawImage)).any((i)=>i.image!=null));
   final images=t.widgetList<Image>(find.byType(Image)).where((i)=>i.image is MemoryImage);
   expect(images.any((i)=>sha256.convert((i.image as MemoryImage).bytes).toString()==f['imageSha256']),isTrue);
   emit('RESULT',{'case':c,'result':'PASS_STAGING_ORIGINAL_SCREEN_S3_RECOVERY','mediaId':rows.docs.single.id,'documents':1,'sha256':f['imageSha256'],'decodedImage':true,'uploadCallsOnRecovery':adapter.calls.length});
  }
 }
 await Completer<void>().future;
 },()=>stagingClientForPhase(recovery:recovery,upload:transport));
 },timeout:const Timeout(Duration(minutes:10)));
}
