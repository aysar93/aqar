import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aqar/widgets/home/home_header.dart';
import 'package:aqar/widgets/app_drawer.dart';
import 'package:aqar/providers/app_settings_provider.dart';
import 'package:aqar/providers/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme Toggle, Drawer & Header Verification Tests', () {
    testWidgets('HomeHeader has NO ThemePillToggle and NO Chat button', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettingsProvider>(
          create: (_) => AppSettingsProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: HomeHeader(
                userName: 'أحمد',
                photoUrl: '',
                notificationCount: 3,
                onMenuPressed: () {},
                onNotificationPressed: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify ThemePillToggle is NOT in HomeHeader (moved to AppDrawer)
      expect(find.byType(ThemePillToggle), findsNothing);

      // Verify Notification icon is present
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

      // Verify Chat icon is NOT present in HomeHeader
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.chat), findsNothing);
    });

    testWidgets('ThemePillToggle switches theme reactively', (tester) async {
      final settings = AppSettingsProvider();
      expect(settings.isDarkMode, isTrue); // default is dark

      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: ThemePillToggle(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap ThemePillToggle
      await tester.tap(find.byType(ThemePillToggle));
      await tester.pumpAndSettle();

      // Verify theme toggled to light
      expect(settings.isDarkMode, isFalse);

      // Tap again
      await tester.tap(find.byType(ThemePillToggle));
      await tester.pumpAndSettle();

      // Verify theme toggled back to dark
      expect(settings.isDarkMode, isTrue);
    });
  });
}
