import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aqar/providers/app_settings_provider.dart';
import 'package:aqar/theme/app_theme.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  test('AppSettingsProvider defaults to Dark Mode and persists ThemeMode', () async {
    final provider = AppSettingsProvider();
    expect(provider.themeMode, ThemeMode.dark, reason: 'Default must be dark mode');
    expect(provider.isDarkMode, isTrue);

    // Switch to Light Mode
    await provider.setThemeMode(ThemeMode.light);
    expect(provider.themeMode, ThemeMode.light);
    expect(provider.isDarkMode, isFalse);

    // Verify persisted in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_mode'), 'light');

    // Create a new instance and verify restoration
    final newProvider = AppSettingsProvider();
    await newProvider.loadSettings();
    expect(newProvider.themeMode, ThemeMode.light);
    expect(newProvider.isDarkMode, isFalse);

    // Switch back to Dark Mode
    await newProvider.setThemeMode(ThemeMode.dark);
    expect(newProvider.themeMode, ThemeMode.dark);
    expect(newProvider.isDarkMode, isTrue);
    expect(prefs.getString('app_theme_mode'), 'dark');
  });

  testWidgets('Theme Switcher UI toggles theme and updates immediately', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = AppSettingsProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettingsProvider>.value(
        value: provider,
        child: Consumer<AppSettingsProvider>(
          builder: (context, settings, _) {
            return MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settings.themeMode,
              home: Scaffold(
                body: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Consumer<AppSettingsProvider>(
                    builder: (context, s, _) {
                      final isDark = s.isDarkMode;
                      return Column(
                        children: [
                          Text('Current: ' + (isDark ? 'Dark' : 'Light')),
                          InkWell(
                            key: const ValueKey('settings-theme-dark-btn'),
                            onTap: () => s.setThemeMode(ThemeMode.dark),
                            child: const Text('الوضع الداكن'),
                          ),
                          InkWell(
                            key: const ValueKey('settings-theme-light-btn'),
                            onTap: () => s.setThemeMode(ThemeMode.light),
                            child: const Text('الوضع النهاري'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current: Dark'), findsOneWidget);

    // Tap Light Mode button
    await tester.tap(find.byKey(const ValueKey('settings-theme-light-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Current: Light'), findsOneWidget);
    expect(provider.themeMode, ThemeMode.light);

    // Tap Dark Mode button
    await tester.tap(find.byKey(const ValueKey('settings-theme-dark-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Current: Dark'), findsOneWidget);
    expect(provider.themeMode, ThemeMode.dark);
  });
}
