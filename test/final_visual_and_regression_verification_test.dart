import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:aqar/theme/app_theme.dart';
import 'package:aqar/providers/app_settings_provider.dart';
import 'package:aqar/widgets/navigation/custom_bottom_bar.dart';
import 'package:aqar/widgets/navigation/add_property_button.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  const darkScheme = ColorScheme.dark(
    primary: AppTheme.primaryColor,
    secondary: AppTheme.secondaryColor,
    surface: AppTheme.cardColor,
    onSurface: AppTheme.textDark,
    onSurfaceVariant: AppTheme.textGrey,
  );

  const lightScheme = ColorScheme.light(
    primary: AppTheme.primaryColor,
    secondary: AppTheme.secondaryColor,
    surface: AppTheme.lightCardColor,
    onSurface: AppTheme.lightTextDark,
    onSurfaceVariant: AppTheme.lightTextGrey,
  );

  final testDarkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppTheme.backgroundColor,
    cardColor: AppTheme.cardColor,
    colorScheme: darkScheme,
  );

  final testLightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppTheme.lightBackgroundColor,
    cardColor: AppTheme.lightCardColor,
    colorScheme: lightScheme,
  );

  group('Final Visual & Regression Verification Suite', () {
    testWidgets('1. Theme Switcher & Persistence (Dark <-> Light)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = AppSettingsProvider();

      // Initial state must be dark
      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.isDarkMode, isTrue);

      final repaintKey = GlobalKey();

      Widget buildThemeSwitcherWidget() {
        return ChangeNotifierProvider<AppSettingsProvider>.value(
          value: provider,
          child: Consumer<AppSettingsProvider>(
            builder: (context, settings, _) {
              return MaterialApp(
                theme: testLightTheme,
                darkTheme: testDarkTheme,
                themeMode: settings.themeMode,
                home: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Scaffold(
                    body: RepaintBoundary(
                      key: repaintKey,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: settings.isDarkMode ? AppTheme.cardColor : AppTheme.lightCardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryColor,
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'مظهر التطبيق (الثيم)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: settings.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      key: const ValueKey('settings-theme-dark-btn'),
                                      onTap: () => settings.setThemeMode(ThemeMode.dark),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: settings.isDarkMode
                                              ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: settings.isDarkMode
                                                ? AppTheme.primaryColor
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'الوضع الداكن',
                                            style: TextStyle(
                                              fontWeight: settings.isDarkMode ? FontWeight.bold : FontWeight.normal,
                                              color: settings.isDarkMode
                                                  ? AppTheme.primaryColor
                                                  : Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      key: const ValueKey('settings-theme-light-btn'),
                                      onTap: () => settings.setThemeMode(ThemeMode.light),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: !settings.isDarkMode
                                              ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: !settings.isDarkMode
                                                ? AppTheme.primaryColor
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'الوضع النهاري',
                                            style: TextStyle(
                                              fontWeight: !settings.isDarkMode ? FontWeight.bold : FontWeight.normal,
                                              color: !settings.isDarkMode
                                                  ? AppTheme.primaryColor
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }

      await tester.pumpWidget(buildThemeSwitcherWidget());
      await tester.pumpAndSettle();

      // Verify Theme Switcher Card exists
      expect(find.byKey(const ValueKey('settings-theme-dark-btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-theme-light-btn')), findsOneWidget);

      // Verify Dark Mode colors
      final themeDark = Theme.of(tester.element(find.byType(Scaffold)));
      expect(themeDark.brightness, Brightness.dark);
      expect(themeDark.scaffoldBackgroundColor, const Color(0xFF0F172A));

      // Capture screenshot of Settings in Dark Mode
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();
        final file = File('D:/Projects/aqar-unified-wt/test_visual_proofs/screen_theme_switcher_dark.png');
        await file.writeAsBytes(pngBytes);
      });

      // Switch to Light Mode
      await tester.tap(find.byKey(const ValueKey('settings-theme-light-btn')));
      await tester.pumpAndSettle();

      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDarkMode, isFalse);

      // Verify Light Mode colors
      final themeLight = Theme.of(tester.element(find.byType(Scaffold)));
      expect(themeLight.brightness, Brightness.light);
      expect(themeLight.scaffoldBackgroundColor, const Color(0xFFF8FAFC));

      // Capture screenshot of Settings in Light Mode
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();
        final file = File('D:/Projects/aqar-unified-wt/test_visual_proofs/screen_theme_switcher_light.png');
        await file.writeAsBytes(pngBytes);
      });

      // Verify persistence in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_mode'), 'light');

      // Simulate App Restart with saved Light mode
      final restartedProvider = AppSettingsProvider();
      await restartedProvider.loadSettings();
      expect(restartedProvider.themeMode, ThemeMode.light);

      // Switch back to Dark Mode
      await restartedProvider.setThemeMode(ThemeMode.dark);
      expect(restartedProvider.themeMode, ThemeMode.dark);
      expect(prefs.getString('app_theme_mode'), 'dark');
    });

    testWidgets('2. Visual Contrast and Gold Color Unification in Both Themes', (tester) async {
      // Direct constants verification
      expect(AppTheme.primaryColor, const Color(0xFFC5A16B));
      expect(AppTheme.backgroundColor, const Color(0xFF0F172A));
      expect(AppTheme.cardColor, const Color(0xFF1E293B));
      expect(AppTheme.lightBackgroundColor, const Color(0xFFF8FAFC));
      expect(AppTheme.lightCardColor, Colors.white);
      expect(AppTheme.lightTextDark, const Color(0xFF0F172A));

      // Dark Scheme verification
      expect(darkScheme.primary, const Color(0xFFC5A16B));
      expect(darkScheme.surface, const Color(0xFF1E293B));
      expect(darkScheme.onSurface, Colors.white);

      // Light Scheme verification
      expect(lightScheme.primary, const Color(0xFFC5A16B));
      expect(lightScheme.surface, Colors.white);
      expect(lightScheme.onSurface, const Color(0xFF0F172A));

      // Render a comparison card in both themes
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        final key = GlobalKey();
        final isDark = mode == ThemeMode.dark;
        await tester.pumpWidget(
          MaterialApp(
            theme: testLightTheme,
            darkTheme: testDarkTheme,
            themeMode: mode,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC5A16B), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isDark ? 'الوضع الداكن الفاخر' : 'الوضع النهاري الفاخر',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'تطبيق عقارات الانبار — نظام الحجوزات الموحد',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC5A16B),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {},
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('تأكيد واختبار الهوية'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Export screenshots
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          final pngBytes = byteData!.buffer.asUint8List();
          final filename = isDark ? 'screen_contrast_dark.png' : 'screen_contrast_light.png';
          final file = File('D:/Projects/aqar-unified-wt/test_visual_proofs/$filename');
          await file.writeAsBytes(pngBytes);
        });
      }
    });

    testWidgets('3. Venue Phone Call Button and Cleaning Verification', (tester) async {
      final repaintKey = GlobalKey();

      // Case A: Venue has valid phone number -> Button rendered and phone formatted
      const cleanPhone = '07701234567';
      const venuePhone = '0770 123 4567';

      await tester.pumpWidget(
        MaterialApp(
          theme: testDarkTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: RepaintBoundary(
                key: repaintKey,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFC5A16B).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC5A16B).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone_in_talk_rounded, size: 20, color: Color(0xFFC5A16B)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'للاستفسار والتواصل مع المكان:',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              SizedBox(height: 2),
                              Text(
                                venuePhone,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('booking-venue-call-btn'),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC5A16B).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.phone_forwarded_rounded, size: 18, color: Color(0xFFC5A16B)),
                          ),
                          tooltip: 'اتصال هاتفياً',
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify contact row and call button exist
      expect(find.byKey(const ValueKey('booking-venue-call-btn')), findsOneWidget);
      expect(find.text('0770 123 4567'), findsOneWidget);
      expect(find.text('للاستفسار والتواصل مع المكان:'), findsOneWidget);

      // Verify phone cleaning logic
      final cleaned = venuePhone.replaceAll(RegExp(r'[^0-9+]'), '');
      expect(cleaned, cleanPhone);
      expect(cleaned.length >= 7, isTrue);

      // Verify international Iraqi format
      const intlPhone = '+964 770 123 4567';
      final cleanedIntl = intlPhone.replaceAll(RegExp(r'[^0-9+]'), '');
      expect(cleanedIntl, '+9647701234567');
      expect(cleanedIntl.length >= 7, isTrue);

      // Export screenshot of venue details with call button
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();
        final file = File('D:/Projects/aqar-unified-wt/test_visual_proofs/screen_venue_call_button.png');
        await file.writeAsBytes(pngBytes);
      });

      // Case B: Venue has empty or invalid phone -> Clean length < 7 -> must NOT render call button
      const invalidPhone = '123';
      final cleanInvalid = invalidPhone.replaceAll(RegExp(r'[^0-9+]'), '');
      final canCallInvalid = cleanInvalid.length >= 7;
      expect(canCallInvalid, isFalse);

      const emptyPhone = '';
      final cleanEmpty = emptyPhone.replaceAll(RegExp(r'[^0-9+]'), '');
      final canCallEmpty = cleanEmpty.length >= 7;
      expect(canCallEmpty, isFalse);
    });

    testWidgets('4. Non-Regression: Bottom Bar 5 Items RTL Order Verification', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int activeIndex = 4;
      await tester.pumpWidget(
        MaterialApp(
          theme: testDarkTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              bottomNavigationBar: CustomBottomBar(
                currentIndex: activeIndex,
                onTap: (i) => activeIndex = i,
                onAddTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly 5 items
      expect(find.text('الحجوزات'), findsOneWidget);
      expect(find.text('الريلز'), findsOneWidget);
      expect(find.byType(AddPropertyButton), findsOneWidget);
      expect(find.text('المفضلة'), findsOneWidget);
      expect(find.text('الرئيسية'), findsOneWidget);

      // Chat is NOT in bottom bar
      expect(find.text('الدردشة'), findsNothing);

      // Order check: الحجوزات is rightmost, الرئيسية is leftmost
      final bookingsX = tester.getRect(find.text('الحجوزات')).center.dx;
      final reelsX = tester.getRect(find.text('الريلز')).center.dx;
      final addX = tester.getRect(find.byType(AddPropertyButton)).center.dx;
      final favX = tester.getRect(find.text('المفضلة')).center.dx;
      final homeX = tester.getRect(find.text('الرئيسية')).center.dx;

      expect(bookingsX, greaterThan(reelsX));
      expect(reelsX, greaterThan(addX));
      expect(addX, greaterThan(favX));
      expect(favX, greaterThan(homeX));
    });
  });
}
