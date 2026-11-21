// Native integration harness. Never run against Staging or production.
// Not a device acceptance test for N3/S3/V5; it proves the local service binding.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:aqar/bookings/booking_media_service.dart';
import '../tool/booking_network/original_service_local_adapter.dart';
import 'booking_network_cases.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_BOOKINGS_LOCAL_NATIVE');
  testWidgets('original image service + native SDK + held emulator results',
      (tester) async {
    await tester.runAsync(() async {
      if (appFlavor != 'bookingsLocalDiagnostic') {
        throw StateError('LOCAL_FLAVOR_REQUIRED');
      }
      final fixtureFile = File(
          '${(await getApplicationSupportDirectory()).path}/local_fixture.json');
      final fixture =
          jsonDecode(await fixtureFile.readAsString()) as Map<String, dynamic>;
      final caseName = fixture['BOOKING_CASE'] as String? ?? 'BINDING';
      final email = fixture[caseName == 'N3'
          ? 'BOOKINGS_LOCAL_CUSTOMER_EMAIL'
          : 'BOOKINGS_LOCAL_EMAIL'] as String;
      final password = fixture[caseName == 'N3'
          ? 'BOOKINGS_LOCAL_CUSTOMER_PASSWORD'
          : 'BOOKINGS_LOCAL_PASSWORD'] as String;
      final venue = fixture['BOOKINGS_LOCAL_VENUE'] as String;
      if (email.isEmpty || password.isEmpty || venue.isEmpty) {
        throw StateError('LOCAL_SYNTHETIC_FIXTURE_REQUIRED');
      }
      await Firebase.initializeApp(
          options: const FirebaseOptions(
        apiKey: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        appId: '1:123456789000:android:0123456789abcdef',
        messagingSenderId: '123456789000',
        projectId: 'demo-aqar',
        storageBucket: 'demo-aqar.appspot.com',
      ));
      final adapter = OriginalServiceLocalAdapter();
      await adapter.configureExistingDemoApp();
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      if (['N3', 'V5A', 'S3_RECOVER'].contains(caseName)) {
        try {
          final result = caseName == 'N3'
              ? await originalBookingCut(adapter, fixture)
              : caseName == 'V5A'
                  ? await originalVideoCut(adapter, fixture)
                  : await recoverOriginalImage(fixture);
          print('BOOKING_LOCAL_NATIVE_RESULT ${jsonEncode({
                ...result,
                'case': caseName,
                'project': Firebase.app().options.projectId,
                'atUtc': DateTime.now().toUtc().toIso8601String()
              })}');
        } finally {
          await FirebaseAuth.instance.signOut();
        }
        return;
      }
      final reviews = FirebaseFirestore.instance
          .collection('booking_media_reviews')
          .where('venueId', isEqualTo: venue)
          .where('ownerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid);
      var deliveredQuery = 0, deliveredDocument = 0, completed = false;
      final querySubscription = adapter
          .holdQuery(reviews.snapshots())
          .listen((_) => deliveredQuery++);
      StreamSubscription? documentSubscription;
      try {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xff00aa88), ui.BlendMode.src);
        final image = await recorder.endRecording().toImage(32, 32);
        final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final upload = adapter
            .uploadOriginalImage(encoded!.buffer.asUint8List(), venue)
            .then((result) {
          completed = true;
          return result;
        });
        await adapter.imageResult.reached.future
            .timeout(const Duration(seconds: 60));
        final stored =
            await reviews.get(const GetOptions(source: Source.server));
        expect(stored.docs, hasLength(1));
        expect(stored.docs.single.data()['status'], 'pending');
        documentSubscription = adapter
            .holdDocument(stored.docs.single.reference.snapshots())
            .listen((_) => deliveredDocument++);
        await adapter.documentEvents.reached.future
            .timeout(const Duration(seconds: 10));
        expect(completed, isFalse);
        expect(deliveredQuery, 0);
        expect(deliveredDocument, 0);
        if (caseName == 'S3_KILL') {
          final mediaId = stored.docs.single.id;
          final token = await FirebaseAuth.instance.currentUser!.getIdToken();
          final saved = await BookingMediaService.readImageData(
              'http://127.0.0.1:5001/demo-aqar/us-central1/bookingMediaContent?mediaId=$mediaId',
              token!);
          print('BOOKING_LOCAL_NATIVE_CHECKPOINT ${jsonEncode({
                'phase': 'S3_READY_FOR_PROCESS_KILL',
                'mediaId': mediaId,
                'sha256': sha256.convert(saved).toString(),
                'functionsHeld': true,
                'queryDelivered': deliveredQuery,
                'documentDelivered': deliveredDocument,
                'atUtc': DateTime.now().toUtc().toIso8601String()
              })}');
          await Completer<void>().future;
        }
        adapter.imageResult.release();
        adapter.queryEvents.release();
        adapter.documentEvents.release();
        final result = await upload;
        expect(result['mediaId'], stored.docs.single.id);
        // No credentials or payloads. This marker is emitted after real SDK assertions.
        print('BOOKING_LOCAL_NATIVE_RESULT ${jsonEncode({
              'result': 'PASS_LOCAL_ORIGINAL_IMAGE_BINDING',
              'project': Firebase.app().options.projectId,
              'documents': stored.docs.length,
              'functionsHeldBeforeRelease': true,
              'queryDeliveredBeforeRelease': 0,
              'documentDeliveredBeforeRelease': 0,
              'atUtc': DateTime.now().toUtc().toIso8601String(),
            })}');
      } finally {
        adapter.imageResult.release();
        adapter.queryEvents.release();
        adapter.documentEvents.release();
        await querySubscription.cancel();
        await documentSubscription?.cancel();
        await FirebaseAuth.instance.signOut();
      }
    });
  }, skip: !enabled);
}
