import 'main_full_test.dart' as isolated;
import 'moderation/user_blocks.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/notification_navigation_service.dart';
import 'screens/onboarding/splash_screen.dart';

Future<void> main() async {
  await isolated.main();
}

class AqarApp extends StatelessWidget {
  const AqarApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => BlockScope(child: child!),
        theme: AppTheme.lightTheme,
        navigatorKey: NotificationNavigationService.navigatorKey,
        home: const SplashScreen(),
      );
}
