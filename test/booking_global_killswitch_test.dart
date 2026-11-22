import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildBookingView({
    required bool isBookingsEnabled,
    required String maintenanceMessage,
    VoidCallback? onSubmit,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            if (!isBookingsEnabled)
              Container(
                key: const ValueKey('platform-maintenance-banner'),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(maintenanceMessage)),
                  ],
                ),
              ),
            ElevatedButton(
              key: const ValueKey('submit-booking-button'),
              onPressed: !isBookingsEnabled ? null : onSubmit ?? () {},
              child: Text(!isBookingsEnabled ? 'خدمة الحجوزات متوقفة مؤقتاً' : 'إرسال طلب الحجز'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildKillSwitchCard({required bool isEnabled}) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('قاطع الطوارئ المركزي لمنظومة الحجوزات'),
              Text(isEnabled
                  ? 'المنظومة مفعلة بالكامل وتستقبل طلبات الحجز'
                  : 'المنظومة متوقفة بالقاطع الشامل'),
              ElevatedButton(
                onPressed: () {},
                child: Text(isEnabled
                    ? 'إيقاف منصة الحجوزات بالكامل (طوارئ)'
                    : 'إعادة تشغيل منصة الحجوزات'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('Booking Global Kill-Switch UI Logic Tests', () {
    testWidgets('Disabled platform state renders maintenance banner and disables action button', (tester) async {
      const String maintenanceMessage = 'خدمة الحجوزات متوقفة مؤقتاً لأعمال الصيانة والتحديث';

      await tester.pumpWidget(
        buildBookingView(
          isBookingsEnabled: false,
          maintenanceMessage: maintenanceMessage,
        ),
      );

      // Verify maintenance banner appears
      expect(find.byKey(const ValueKey('platform-maintenance-banner')), findsOneWidget);
      expect(find.text(maintenanceMessage), findsOneWidget);

      // Verify submit button is disabled
      final button = tester.widget<ElevatedButton>(find.byKey(const ValueKey('submit-booking-button')));
      expect(button.onPressed, isNull);
      expect(find.text('خدمة الحجوزات متوقفة مؤقتاً'), findsOneWidget);
    });

    testWidgets('Enabled platform state allows normal booking submission', (tester) async {
      bool submitted = false;

      await tester.pumpWidget(
        buildBookingView(
          isBookingsEnabled: true,
          maintenanceMessage: '',
          onSubmit: () => submitted = true,
        ),
      );

      expect(find.text('إرسال طلب الحجز'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byKey(const ValueKey('submit-booking-button')));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('submit-booking-button')));
      await tester.pump();
      expect(submitted, isTrue);
    });

    testWidgets('Kill-switch emergency card renders correct status and action for enabled platform', (tester) async {
      await tester.pumpWidget(buildKillSwitchCard(isEnabled: true));

      expect(find.text('قاطع الطوارئ المركزي لمنظومة الحجوزات'), findsOneWidget);
      expect(find.text('المنظومة مفعلة بالكامل وتستقبل طلبات الحجز'), findsOneWidget);
      expect(find.text('إيقاف منصة الحجوزات بالكامل (طوارئ)'), findsOneWidget);
    });
  });
}
