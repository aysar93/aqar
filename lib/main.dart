import 'bookings_staging_main.dart' as bookings_staging;
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
import 'services/push_migration.dart';
import 'services/notification_navigation_service.dart';
import 'services/deep_link_service.dart';
import 'screens/onboarding/splash_screen.dart';

Future<void> main() async {
  if (appFlavor == 'bookingsStaging') {
    await bookings_staging.main();
    return;
  }
  if (appFlavor == 'bookingsTest') {
    await bookings_test.main();
    return;
  }
  const stagingProject = String.fromEnvironment('STAGING_PROJECT_ID');
  const mediaBucket = String.fromEnvironment('MEDIA_STORAGE_BUCKET');
  if (mediaBucket.isNotEmpty &&
      mediaBucket != 'aqar-9f3f9-media-canary' &&
      stagingProject.isEmpty) {
    throw StateError(
      'Non-production MEDIA_STORAGE_BUCKET requires explicit STAGING_PROJECT_ID to prevent accidental production Firebase attachment',
    );
  }
  if (stagingProject.isNotEmpty) {
    const apiKey = String.fromEnvironment('STAGING_API_KEY');
    const appId = String.fromEnvironment('STAGING_APP_ID');
    const sender = String.fromEnvironment('STAGING_SENDER_ID');
    if (apiKey.isEmpty || appId.isEmpty || sender.isEmpty) {
      throw StateError(
        'STAGING_PROJECT_ID requires STAGING_API_KEY, STAGING_APP_ID, and STAGING_SENDER_ID',
      );
    }
    await startAqar(
      FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: sender,
        projectId: stagingProject,
        storageBucket: mediaBucket.isNotEmpty ? mediaBucket : null,
        iosBundleId: 'com.andalus.aqar.staging',
      ),
      isolated: true,
    );
    return;
  }
  await startAqar(DefaultFirebaseOptions.currentPlatform);
}

Future<void> startAqar(
  FirebaseOptions options, {
  bool isolated = false,
  bool bridgeCandidate = false,
}) async {
  final approvedCandidate =
      bridgeCandidate &&
      PushMigration.bridgeEnabled &&
      !PushMigration.isolated &&
      options.projectId == 'aqar-9f3f9' &&
      options.messagingSenderId == '1031621585901';
  if (PushMigration.enabled &&
      !approvedCandidate &&
      (!isolated || options.projectId != 'aqar-fcm-test-20261014')) {
    throw StateError('FCM migration requires the isolated staging entry point');
  }
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }
  FirebaseApp app;
  try {
    app = await Firebase.initializeApp(options: options);
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      app = Firebase.app();
    } else {
      rethrow;
    }
  }
  if (app.options.projectId != options.projectId) {
    throw StateError(
      'Firebase [DEFAULT] app is attached to ${app.options.projectId} '
      'which does not match requested ${options.projectId}',
    );
  }

  // Anonymous sessions created by older app versions are persisted by Firebase.
  // Remove only those sessions; real users remain signed in across app restarts.
  final currentUser = FirebaseAuth.instance.currentUser;
  if (!isolated && (currentUser?.isAnonymous ?? false)) {
    await FirebaseAuth.instance.signOut();
  }

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  UserBlocks.instance.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppSettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const AqarApp(),
    ),
  );

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
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: BlockScope(child: child!),
      ),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      navigatorKey: NotificationNavigationService.navigatorKey,
      home: const SplashScreen(),
    );
  }
}
