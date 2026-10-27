// Dedicated iOS entry. Values must come from the verified Staging app config.
import 'package:firebase_core/firebase_core.dart';
import 'bookings_staging_main.dart' as staging;

FirebaseOptions bookingIosStagingOptions() {
  const key = String.fromEnvironment('BOOKINGS_IOS_API_KEY');
  const appId = String.fromEnvironment('BOOKINGS_IOS_APP_ID');
  const bundle = String.fromEnvironment('BOOKINGS_IOS_BUNDLE_ID');
  if (key.isEmpty ||
      !appId.startsWith('1:463930605039:ios:') ||
      bundle != 'com.andalus.aqar.bookingstest') {
    throw StateError('Verified isolated iOS Staging configuration required');
  }
  return const FirebaseOptions(
    apiKey: key,
    appId: appId,
    messagingSenderId: '463930605039',
    projectId: staging.bookingStagingProject,
    storageBucket: 'aqar-bookings-test-20261009.firebasestorage.app',
    iosBundleId: bundle,
  );
}

Future<void> main() async {
  // Validate before Firebase initialization; never infer options from production.
  final options = bookingIosStagingOptions();
  await staging.runBookingStaging(options: options);
}
