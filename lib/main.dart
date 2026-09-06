import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'analytics/services/app_activity_service.dart';
import 'providers/app_settings_provider.dart';
import 'providers/user_provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/fcm_service.dart';
import 'services/notification_navigation_service.dart';
import 'screens/onboarding/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Anonymous sessions created by older app versions are persisted by Firebase.
  // Remove only those sessions; real users remain signed in across app restarts.
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser?.isAnonymous ?? false) {
    await FirebaseAuth.instance.signOut();
  }

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(
        create: (_) => AppSettingsProvider()..loadSettings()),
    ChangeNotifierProvider(create: (_) => UserProvider()),
  ], child: const AqarApp()));

  // Network-dependent services must never block the first Flutter frame.
  // This is especially important on fresh installs, simulators, or when
  // notification/analytics permissions have not been provisioned yet.
  unawaited(_initializeBackgroundServices());
}

Future<void> _initializeBackgroundServices() async {
  try {
    await FCMService.initialize();
  } catch (error, stack) {
    debugPrint('FCM initialization failed: $error');
    await FirebaseCrashlytics.instance.recordError(error, stack);
  }

  // Guests intentionally have no Firebase user. If a guest signs in later in
  // this app session, initialize presence/activity for that real user then.
  final user = FirebaseAuth.instance.currentUser ??
      await FirebaseAuth.instance.authStateChanges().firstWhere(
            (user) => user != null && !user.isAnonymous,
          );

  if (user != null && !user.isAnonymous) {
    try {
      await AppActivityService.instance.initialize();
    } catch (error, stack) {
      debugPrint('App activity initialization failed: $error');
      await FirebaseCrashlytics.instance.recordError(error, stack);
    }
  }
}

class AqarApp extends StatelessWidget {
  const AqarApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: NotificationNavigationService.navigatorKey,
        home: const SplashScreen(),
      );
}
