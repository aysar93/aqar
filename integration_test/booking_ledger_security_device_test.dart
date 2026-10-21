import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aqar/bookings/booking_management.dart';
import 'package:aqar/bookings/booking_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'staging ledger stays private across SDK offline and account switch',
      (tester) async {
    expect(appFlavor, 'bookingsStaging');
    final app = await Firebase.initializeApp();
    expect(app.options.projectId, 'aqar-bookings-test-20261009');
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    const reference = 'مرجع LEDGER-SECURITY-SYNTHETIC-20261021';
    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (condition()) return;
      }
      fail('Timed out waiting for ledger security state');
    }

    Future<void> login(String email, String password) =>
        auth.signInWithEmailAndPassword(email: email, password: password);
    try {
      await db.enableNetwork();
      await auth.signOut();
      await login(const String.fromEnvironment('LEDGER_REVIEWER_EMAIL'),
          const String.fromEnvironment('LEDGER_REVIEWER_PASSWORD'));
      await tester.pumpWidget(const MaterialApp(home: BookingLedgerScreen()));
      await waitFor(() => find.text(reference).evaluate().isNotEmpty);
      debugPrint('LEDGER_SECURITY server-authorized ledger visible: PASS');
      await db.disableNetwork();
      await waitFor(() => find.text(reference).evaluate().isEmpty);
      debugPrint('LEDGER_SECURITY SDK offline hides warmed ledger: PASS');
      await auth.signOut();
      await login(const String.fromEnvironment('LEDGER_CUSTOMER_EMAIL'),
          const String.fromEnvironment('LEDGER_CUSTOMER_PASSWORD'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(reference), findsNothing);
      }
      debugPrint('LEDGER_SECURITY customer while Firestore offline: PASS');
      await db.enableNetwork();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(reference), findsNothing);
      await expectLater(
          db
              .collection('booking_ledger')
              .get(const GetOptions(source: Source.server)),
          throwsA(isA<FirebaseException>()
              .having((e) => e.code, 'code', 'permission-denied')));
      debugPrint('LEDGER_SECURITY customer server query denied: PASS');
      await auth.signOut();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(reference), findsNothing);
      debugPrint('LEDGER_SECURITY signed-out ledger hidden: PASS');
      await login(const String.fromEnvironment('LEDGER_REVIEWER_EMAIL'),
          const String.fromEnvironment('LEDGER_REVIEWER_PASSWORD'));
      await tester.pumpWidget(const MaterialApp(
          home: BookingDetailsScreen(
              bookingId: 'ledger_security_private_booking_20261021')));
      const privatePhone = 'SYNTHETIC-PRIVATE-PHONE';
      await waitFor(() => find.text(privatePhone).evaluate().isNotEmpty);
      debugPrint('DETAIL_SECURITY reviewer server grant visible: PASS');
      await db.disableNetwork();
      await waitFor(() => find.text(privatePhone).evaluate().isEmpty);
      debugPrint('DETAIL_SECURITY offline clears privileged visibility: PASS');
      await auth.signOut();
      await login(const String.fromEnvironment('LEDGER_CUSTOMER_EMAIL'),
          const String.fromEnvironment('LEDGER_CUSTOMER_PASSWORD'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(privatePhone), findsNothing);
      }
      debugPrint(
          'DETAIL_SECURITY unrelated account with warm cache hidden: PASS');
      await db.enableNetwork();
      await expectLater(
          db
              .doc('bookings/ledger_security_private_booking_20261021')
              .get(const GetOptions(source: Source.server)),
          throwsA(isA<FirebaseException>()
              .having((e) => e.code, 'code', 'permission-denied')));
      debugPrint('DETAIL_SECURITY unrelated account server denied: PASS');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.enableNetwork();
      await auth.signOut();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
