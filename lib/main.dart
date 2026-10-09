import 'moderation/user_blocks.dart';
import 'bookings_test_main.dart' as bookings_test;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import 'services/deep_link_service.dart';
import 'screens/onboarding/splash_screen.dart';

Future<void> main() async {
  if (appFlavor == 'bookingsTest') {
    await bookings_test.main();
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
  }
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
  UserBlocks.instance.initialize();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(
        create: (_) => AppSettingsProvider()..loadSettings()),
    ChangeNotifierProvider(create: (_) => UserProvider()),
  ], child: const AqarApp()));

  // Observe auth immediately, independently of notification initialization.
  unawaited(AppActivityService.instance.initialize());

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

  // تهيئة خدمة Deep Link لمعالجة روابط QR العقارات
  try {
    DeepLinkService.initialize();
  } catch (e) {
    debugPrint('DeepLinkService initialization failed: $e');
  }
}

class AqarApp extends StatelessWidget {
  const AqarApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl, child: BlockScope(child: child!)),
        theme: AppTheme.lightTheme,
        navigatorKey: NotificationNavigationService.navigatorKey,
        home: const SplashScreen(),
      );
}
