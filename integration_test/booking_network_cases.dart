import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:aqar/bookings/booking_media_service.dart';
import '../tool/booking_network/original_service_local_adapter.dart';

Future<Map<String, dynamic>> localProxyState() async => jsonDecode(
        (await http.get(Uri.parse('http://127.0.0.1:5001/__state'))).body)
    as Map<String, dynamic>;

Future<void> armLocalCut(String function, int offset) async {
  final response = await http.post(Uri.parse('http://127.0.0.1:5001/__arm'),
      headers: {'Content-Type': 'application/json'},
      body:
          jsonEncode({'function': function, 'mode': 'cut', 'offset': offset}));
  expect(response.statusCode, 200);
}

Future<Map<String, dynamic>> originalBookingCut(
    OriginalServiceLocalAdapter adapter, Map<String, dynamic> fixture) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final venue = fixture['BOOKINGS_LOCAL_VENUE'] as String;
  final requestId = fixture['BOOKINGS_LOCAL_REQUEST_ID'] as String;
  final query = FirebaseFirestore.instance
      .collection('bookings')
      .where('customerId', isEqualTo: uid)
      .where('venueId', isEqualTo: venue);
  expect(
      (await query.get(const GetOptions(source: Source.server))).docs, isEmpty);
  final start = (fixture['BOOKINGS_LOCAL_START'] as num).toInt();
  final data = <String, dynamic>{
    'venueId': venue,
    'requestId': requestId,
    'start': start,
    'end': start + 4 * 3600000,
    'price': 100000,
    'deposit': 20000,
    'acceptedTerms': 'local synthetic terms',
    'cancellationPolicy': {'freeCancellationHours': 24, 'lateRefundPercent': 50}
  };
  await armLocalCut('requestBooking', 64);
  String? firstError;
  try {
    await adapter.nativeCall('requestBooking', data);
  } on FirebaseFunctionsException catch (error) {
    firstError = error.code;
  }
  final beforeRetry = await query.get(const GetOptions(source: Source.server));
  expect(beforeRetry.docs.length, lessThanOrEqualTo(1));
  final state = await localProxyState();
  final cut = (state['events'] as List).cast<Map>().lastWhere(
      (e) => e['event'] == 'REQUEST_CUT' && e['function'] == 'requestBooking');
  expect(cut['submittedUpstream'], 64);
  expect(cut['declaredLength'] as num, greaterThan(64));
  final retry = await adapter.nativeCall('requestBooking', data);
  final after = await query.get(const GetOptions(source: Source.server));
  expect(after.docs, hasLength(1));
  expect(after.docs.single.id, retry['id']);
  return {
    'result': 'PASS_LOCAL_NATIVE_BOOKING_CUT_RETRY',
    'requestId': requestId,
    'beforeRetryCount': beforeRetry.docs.length,
    'afterRetryCount': after.docs.length,
    'firstError': firstError,
    'cut': cut,
    'explicitRetryCalls': 1,
    'limits': 'Local emulator proxy cut; not a Staging radio-cut acceptance'
  };
}

Future<Map<String, dynamic>> originalVideoCut(
    OriginalServiceLocalAdapter adapter, Map<String, dynamic> fixture) async {
  final file = File(
      '${(await getApplicationSupportDirectory()).path}/video_fixture.mp4');
  final bytes = await file.readAsBytes();
  expect(bytes.length, greaterThan(4 * 1024 * 1024));
  expect(bytes.length, lessThanOrEqualTo(50 * 1024 * 1024));
  await armLocalCut('uploadBookingVideoChunk', 2 * 1024 * 1024);
  Object? finalError;
  final upload = adapter
      .uploadOriginalVideo(bytes, fixture['BOOKINGS_LOCAL_VENUE'] as String)
      .then<void>((_) {}, onError: (Object error, StackTrace stack) {
    finalError = error;
  });
  await adapter.finishResult.reached.future.timeout(const Duration(minutes: 3));
  final records = await FirebaseFirestore.instance
      .collection('booking_media_reviews')
      .where('ownerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
      .where('venueId', isEqualTo: fixture['BOOKINGS_LOCAL_VENUE'])
      .get(const GetOptions(source: Source.server));
  expect(records.docs, hasLength(1));
  final state = await localProxyState();
  final cut = (state['events'] as List).cast<Map>().lastWhere((e) =>
      e['event'] == 'REQUEST_CUT' &&
      e['function'] == 'uploadBookingVideoChunk');
  expect(cut['submittedUpstream'], 2 * 1024 * 1024);
  expect(cut['declaredLength'], 4 * 1024 * 1024);
  adapter.finishResult.release();
  await upload;
  return {
    'result': finalError == null
        ? 'LOCAL_VIDEO_FINISHED'
        : 'BLOCKED_LOCAL_VIDEO_FINALIZE',
    'mediaId': records.docs.single.id,
    'status': records.docs.single.data()['status'],
    'bytes': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
    'cut': cut,
    'errorCode': finalError is FirebaseFunctionsException
        ? (finalError as FirebaseFunctionsException).code
        : null,
    'limits':
        'Original Dart service retry and native SDK; compose support/playback not substituted'
  };
}

Future<Map<String, dynamic>> recoverOriginalImage(
    Map<String, dynamic> fixture) async {
  final id = fixture['BOOKINGS_LOCAL_MEDIA_ID'] as String;
  final document = await FirebaseFirestore.instance
      .collection('booking_media_reviews')
      .doc(id)
      .get(const GetOptions(source: Source.server));
  expect(document.data()?['status'], 'pending');
  final token = await FirebaseAuth.instance.currentUser!.getIdToken();
  final bytes = await BookingMediaService.readImageData(
      'http://127.0.0.1:5001/demo-aqar/us-central1/bookingMediaContent?mediaId=$id',
      token!);
  expect(
      sha256.convert(bytes).toString(), fixture['BOOKINGS_LOCAL_IMAGE_SHA256']);
  final rows = await FirebaseFirestore.instance
      .collection('booking_media_reviews')
      .where('ownerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
      .where('venueId', isEqualTo: fixture['BOOKINGS_LOCAL_VENUE'])
      .get(const GetOptions(source: Source.server));
  expect(rows.docs, hasLength(1));
  return {
    'result': 'PASS_LOCAL_NATIVE_IMAGE_PROCESS_RECOVERY',
    'mediaId': id,
    'documents': rows.docs.length,
    'sha256': sha256.convert(bytes).toString(),
    'limits':
        'Native service harness; original booking screen listeners not all instrumented'
  };
}
