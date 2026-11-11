import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bookings/booking_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'theme/app_theme.dart';

const bookingStagingProject = 'aqar-bookings-test-20261009';
bool bookingStagingAllowed(String? flavor, String project) {
  if (project != bookingStagingProject) return false;
  const envFlavor = String.fromEnvironment('BOOKINGS_APP_FLAVOR');
  final effective = flavor ?? (envFlavor.isNotEmpty ? envFlavor : null);
  return effective == 'bookingsStaging';
}
Future<void> endBookingStagingSession({
  required Future<void> Function() detachNotifications,
  required Future<void> Function() signOut,
}) async {
  try {
    await detachNotifications().timeout(const Duration(seconds: 3));
  } catch (_) {
    // Notification cleanup must not prevent local logout while offline.
  } finally {
    await signOut();
  }
}

final _stagingNavigator = GlobalKey<NavigatorState>();
RemoteMessage? _pendingNotification;
bool _stagingSessionReady = false;
void _openNotification(RemoteMessage message) {
  final bookingId = message.data['bookingId'];
  if (bookingId is! String || bookingId.isEmpty || bookingId.contains('/')) {
    return;
  }
  if (!_stagingSessionReady ||
      FirebaseAuth.instance.currentUser == null ||
      _stagingNavigator.currentState == null) {
    _pendingNotification = message;
    return;
  }
  _stagingNavigator.currentState!.push(MaterialPageRoute(
      builder: (_) => BookingDetailsScreen(bookingId: bookingId)));
}

Future<void> main() => runBookingStaging();

Future<void> runBookingStaging({FirebaseOptions? options}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!bookingStagingAllowed(appFlavor, bookingStagingProject)) {
    throw StateError('Dedicated staging flavor required');
  }
  if (options != null && options.projectId != bookingStagingProject) {
    throw StateError('Staging options must identify the Staging project');
  }
  final app = await Firebase.initializeApp(options: options);
  if (!bookingStagingAllowed(appFlavor, app.options.projectId)) {
    await app.delete();
    throw StateError('Staging cannot connect to any other Firebase project');
  }
  FirebaseMessaging.onMessageOpenedApp.listen(_openNotification);
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) _pendingNotification = message;
  }).catchError((_) {});
  runApp(MaterialApp(
      navigatorKey: _stagingNavigator,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: Column(children: [
            const Material(
                color: Colors.amber,
                child: SafeArea(
                    bottom: false,
                    child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('STAGING — اختبار فقط — لا تحوّل أموالًا',
                            style: TextStyle(color: Colors.black))))),
            Expanded(child: child!)
          ])),
      home: const _StagingLogin()));
}

class _StagingLogin extends StatefulWidget {
  const _StagingLogin();
  @override
  State<_StagingLogin> createState() => _LoginState();
}

class _LoginState extends State<_StagingLogin> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? error;
  StreamSubscription<String>? tokenUpdates;
  @override
  void initState() {
    super.initState();
    email.text = 'staging.admin.20261010@test.invalid';
    password.text = 'AqarUat2026!Test';
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await FirebaseAuth.instance.authStateChanges().first;
    if (!mounted) return;
    setState(() => busy = false);
  }

  Future<void> _enterBookings({bool restore = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    bool opened = false;
    bool inactive = false;
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email.text.trim(), password: password.text);
      } else {
        // Validate the persisted session before showing protected screens.
        await FirebaseAuth.instance.currentUser!.getIdToken(true);
      }
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final user = await FirebaseFirestore.instance
          .doc('users/$uid')
          .get(const GetOptions(source: Source.server));
      inactive = !user.exists || user.data()?['isBlocked'] == true;
      if (inactive) throw StateError('Inactive test account');
      try {
        await FirebaseMessaging.instance.requestPermission();
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .doc('users/$uid')
              .update({'fcmToken': token});
        }
        tokenUpdates =
            FirebaseMessaging.instance.onTokenRefresh.listen((token) {
          FirebaseFirestore.instance
              .doc('users/$uid')
              .update({'fcmToken': token}).catchError((_) {});
        });
      } catch (_) {}
      if (!mounted) return;
      opened = true;
      _stagingSessionReady = true;
      final navigation = Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  const BookingScreen(admin: false)));
      final notification = _pendingNotification;
      _pendingNotification = null;
      if (notification != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (FirebaseAuth.instance.currentUser != null) {
            _openNotification(notification);
          }
        });
      }
      await navigation;
    } catch (e) {
      if (e is FirebaseAuthException &&
          const {
            'user-disabled',
            'user-not-found',
            'user-token-expired',
            'invalid-user-token'
          }.contains(e.code)) {
        inactive = true;
      }
      if (mounted) {
        setState(() => error =
            'تعذر الدخول. تحقق من الحساب وتشغيل خدمات staging واتصال الإنترنت.');
      }
    } finally {
      _stagingSessionReady = false;
      await tokenUpdates?.cancel();
      tokenUpdates = null;
      // Returning from bookings remains an explicit end of this staging session.
      // Transient restore failures must not delete a valid persisted session.
      if (opened || inactive || !restore) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        await endBookingStagingSession(
          detachNotifications: () async {
            if (uid == null) return;
            await FirebaseFirestore.instance
                .doc('users/$uid')
                .update({'fcmToken': FieldValue.delete()});
          },
          signOut: () => FirebaseAuth.instance.signOut(),
        );
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _enterAdminDashboard() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email.text.trim(), password: password.text);
      }
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final user = await FirebaseFirestore.instance.doc('users/$uid').get();
      if (user.data()?['isAdmin'] != true) {
        throw StateError('هذا الحساب ليس لديه صلاحية إدارة');
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = 'تعذر فتح لوحة الإدارة: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    tokenUpdates?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('حساب اختبار staging')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text(
            'يتطلب تشغيل خدمات مشروع الاختبار المنفصل وتوفير حساب اختبار من الإدارة. حسابات المحاكيات المحلية لا تعمل هنا.'),
        TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
        TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور')),
        if (error != null) Text(error!),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: busy ? null : () => _enterBookings(),
            child: Text(busy ? 'جاري الدخول...' : 'دخول لتطبيق الحجوزات (واجهة المستخدم)')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: const Text('لوحة الإدارة العامة (Admin Dashboard)'),
          onPressed: busy ? null : () => _enterAdminDashboard(),
        ),
        if (!busy && FirebaseAuth.instance.currentUser != null)
          TextButton(
              onPressed: _restoreSession,
              child: const Text('إعادة محاولة استعادة الجلسة'))
      ]));
}
