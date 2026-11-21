// PREPARATION ONLY: outside the repository; not imported by production.
// Requires a Flutter harness on a native platform and local Firebase emulators.
// No top-level execution, sign-in, upload, or emulator process startup.
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:aqar/bookings/booking_media_service.dart';
import 'original_http_gate.dart' show BodyGateClient;
import 'callback_gates.dart' show CallbackGate;

class OriginalServiceLocalAdapter {
  static const project = 'demo-aqar';
  final imageResult = CallbackGate();
  final finishResult = CallbackGate();
  final queryEvents = CallbackGate();
  final documentEvents = CallbackGate();
  bool _configured = false;

  Future<void> configureExistingDemoApp() async {
    // Deliberately require the harness to initialize a demo default app.
    // Never silently reuse an installed Staging/production default app.
    if (Firebase.app().options.projectId != project) {
      throw StateError('LOCAL_DEMO_PROJECT_REQUIRED');
    }
    const host = '127.0.0.1';
    await FirebaseAuth.instance.useAuthEmulator(
      host,
      9099,
      automaticHostMapping: false,
    );
    FirebaseFunctions.instance.useFunctionsEmulator(
      host,
      5001,
      automaticHostMapping: false,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      8185,
      automaticHostMapping: false,
    );
    BookingMediaService.emulatorHost = host;
    _configured = true;
  }

  void _guard() {
    if (!_configured ||
        Firebase.app().options.projectId != project ||
        BookingMediaService.emulatorHost != '127.0.0.1') {
      throw StateError('LOCAL_CONFIGURATION_REQUIRED');
    }
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('LOCAL_SYNTHETIC_USER_REQUIRED');
    }
  }

  Future<Map<String, dynamic>> nativeCall(
    String name,
    Map<String, dynamic> data,
  ) async {
    _guard();
    // Call the actual native Functions SDK, never bookingCall's REST test branch.
    final original = FirebaseFunctions.instance
        .httpsCallable(name,
            options: HttpsCallableOptions(timeout: const Duration(minutes: 5)))
        .call(data);
    final result = name == 'uploadBookingImage'
        ? await imageResult.future(original)
        : name == 'finishBookingVideo'
            ? await finishResult.future(original)
            : await original;
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> uploadOriginalVideo(Uint8List bytes, String venueId,
      [BodyGateClient? gate]) {
    _guard();
    if (gate == null) {
      return BookingMediaService.uploadVideo(bytes, venueId, nativeCall);
    }
    // No `upload:` override: original service chunking, Auth, reserve and finish.
    // Scope covers async http.post calls; the client rejects non-loopback URLs.
    return http.runWithClient(
      () => BookingMediaService.uploadVideo(bytes, venueId, nativeCall),
      () => gate,
    );
  }

  Future<Map<String, dynamic>> uploadOriginalImage(
    Uint8List bytes,
    String venueId,
  ) {
    _guard();
    return BookingMediaService.uploadImage(bytes, nativeCall, venueId: venueId);
  }

  Stream<T> holdQuery<T>(Stream<T> original) {
    _guard();
    return queryEvents.stream(original);
  }

  Stream<T> holdDocument<T>(Stream<T> original) {
    _guard();
    return documentEvents.stream(original);
  }
}

// IMPORTANT: nativeCall retains the SDK but has no native request-body gate.
// Thus it does NOT close N3. Dart stream wrappers alone also cannot prove all
// widget listeners/caches or native EventSinks were intercepted for S3/V5-B.
// This file has NOT been compiled or run; local native harness still required.
