import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aqar/main.dart' as app;
import 'package:aqar/screens/main_shell.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture the real iPad onboarding and guest home',
      (tester) async {
    // Bounded waits also work with the app's continuously running animations.
    Future<void> waitFor(Finder finder) async {
      for (var attempt = 0; attempt < 90; attempt++) {
        await tester.pump(const Duration(seconds: 1));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('Screen did not appear: $finder');
    }

    await app.main();
    await waitFor(find.text('تخطي'));
    await tester.pump(const Duration(seconds: 2));
    await binding.takeScreenshot('ipad-01-welcome');

    await tester.tap(find.text('تخطي'));
    await waitFor(find.text('الدخول كضيف'));
    await tester.pump(const Duration(seconds: 2));
    await binding.takeScreenshot('ipad-02-sign-in');

    await tester.ensureVisible(find.text('الدخول كضيف'));
    await tester.tap(find.text('الدخول كضيف'));
    await waitFor(find.byType(MainShell));
    // Allow real network images and property listings time to load.
    for (var second = 0; second < 30; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await binding.takeScreenshot('ipad-03-home');
  });
}
