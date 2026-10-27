// Explicit Staging diagnostic harness only. Not imported by application entrypoints.
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:aqar/bookings/booking_media_service.dart';
import 'package:aqar/bookings/booking_media_local_hooks.dart';
import 'callback_gates.dart' show CallbackGate;

class StagingScreenAdapter extends BookingMediaLocalHooks {
 static const project='aqar-bookings-test-20261009';
 final bool video;
 final Uint8List bytes;
 final result=CallbackGate(),queryEvents=CallbackGate(),documentEvents=CallbackGate();
 final events=<Map<String,dynamic>>[];
 final calls=<String,int>{};
 StagingScreenAdapter(this.video,this.bytes);
 void guard(){
  checkLocalOnly();
  final options=Firebase.app().options;
  if(!kDebugMode||appFlavor!='bookingsStagingDiagnostic'||
    !const bool.fromEnvironment('RUN_BOOKINGS_STAGING_DIAGNOSTIC')||
    options.projectId!=project||options.storageBucket!='$project.firebasestorage.app'||
    BookingMediaService.emulatorHost!=null||FirebaseAuth.instance.currentUser==null) {
   throw StateError('STAGING_DIAGNOSTIC_TARGET_REJECTED');
  }
 }
 Future<Map<String,dynamic>> call(String name,Map<String,dynamic> data)async{
  guard();
  final allowed=video?{'reserveBookingVideo','finishBookingVideo'}:{'uploadBookingImage'};
  if(!allowed.contains(name)||(calls[name]??0)!=0)throw StateError('DIAGNOSTIC_NO_REPEAT');
  calls[name]=1;events.add({'name':name,'phase':'sent','atUtc':DateTime.now().toUtc().toIso8601String()});
  // Errors propagate immediately; never gate or retry a failed Functions result.
  final original=await FirebaseFunctions.instanceFor(region:'us-central1').httpsCallable(name,
   options:HttpsCallableOptions(timeout:const Duration(minutes:5))).call(data);
  events.add({'name':name,'phase':'successful_sdk_response','atUtc':DateTime.now().toUtc().toIso8601String()});
  if(name=='uploadBookingImage'||name=='finishBookingVideo')await result.future(Future.value(true));
  return Map<String,dynamic>.from(original.data as Map);
 }
 @override Future<Uint8List?> pick(bool isVideo)async{guard();if(isVideo!=video)throw StateError('WRONG_MEDIA_CASE');return bytes;}
 @override Stream<T> query<T>(Stream<T> source){guard();return queryEvents.stream(source);}
 @override Stream<T> document<T>(Stream<T> source){guard();return documentEvents.stream(source);}
}

// Preserve original upload/chunking/auth SDK. Abort rather than let its retry
// loop transmit a second request after any chunk transport/server failure.
class SingleAttemptStagingClient extends http.BaseClient {
 final http.Client inner;bool sent=false;
 SingleAttemptStagingClient({http.Client? client}):inner=client??http.Client();
 final events=<Map<String,dynamic>>[];
 @override Future<http.StreamedResponse> send(http.BaseRequest request)async{
  final u=request.url;
  if(u.scheme!='https'||u.host!='us-central1-${StagingScreenAdapter.project}.cloudfunctions.net')throw StateError('DIAGNOSTIC_TRANSPORT_TARGET_REJECTED');
  if({'GET','HEAD'}.contains(request.method)&&u.path=='/bookingMediaContent')return inner.send(request);
  if(request.method!='POST'||u.path!='/uploadBookingVideoChunk'||sent)throw StateError('DIAGNOSTIC_TRANSPORT_NO_REPEAT');
  sent=true;final at=DateTime.now().toUtc().toIso8601String();
  try{
   final response=await inner.send(request);
   events.add({'atUtc':at,'completedUtc':DateTime.now().toUtc().toIso8601String(),
    'http':response.statusCode,'type':response.headers['content-type'],'bytesSent':request.contentLength});
   if(response.statusCode!=200)throw StateError('DIAGNOSTIC_CHUNK_FAILED_HTTP_${response.statusCode}');
   return response;
  }catch(_){throw StateError('DIAGNOSTIC_CHUNK_FAILED_STOP');}
 }
 @override void close(){inner.close();super.close();}
}

// Top-level http.head/get close the factory's client after EACH request.
// Keep the single-use upload fence out of recovery; use original fresh clients.
http.Client stagingClientForPhase({required bool recovery,required SingleAttemptStagingClient upload}) => recovery?http.Client():upload;
