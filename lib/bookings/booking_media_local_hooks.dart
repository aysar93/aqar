import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:firebase_core/firebase_core.dart';

/// Explicit debug flavors only; ordinary application builds reject these seams.
abstract class BookingMediaLocalHooks {
  void checkLocalOnly() {
    final local = const bool.fromEnvironment('RUN_BOOKINGS_LOCAL_NATIVE') &&
        appFlavor == 'bookingsLocalDiagnostic';
    final staging = const bool.fromEnvironment('RUN_BOOKINGS_STAGING_DIAGNOSTIC') &&
        appFlavor == 'bookingsStagingDiagnostic';
    if (!kDebugMode || (!local && !staging)) {
      throw StateError('DIAGNOSTIC_BUILD_REQUIRED');
    }
    final expected = staging ? 'aqar-bookings-test-20261009' : 'demo-aqar';
    if (Firebase.app().options.projectId != expected) {
      throw StateError('LOCAL_DIAGNOSTIC_EDITOR_ONLY');
    }
  }

  Stream<T> document<T>(Stream<T> source);
  Stream<T> query<T>(Stream<T> source);
  Future<Uint8List?> pick(bool video);
}
