// Independent diagnostic entry only. Never used by main.dart or store builds.
// No embedded accounts, seed data, automatic writes, or Push registration.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:aqar/bookings/booking_design.dart';

const reviewProject = 'aqar-paypush-uat-20261023';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (appFlavor != 'bookingsPaymentPushDiagnostic' ||
      !const bool.fromEnvironment('BOOKING_UI_REVIEW')) {
    throw StateError('Dedicated UI review diagnostic required');
  }
  final app = await Firebase.initializeApp();
  if (app.options.projectId != reviewProject ||
      app.options.messagingSenderId != '100428295312' ||
      app.options.storageBucket != '$reviewProject.firebasestorage.app') {
    await app.delete();
    throw StateError('Isolated review configuration required');
  }
  runApp(bookingUiReviewShell());
}

Widget bookingUiReviewShell({Widget? home}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: bookingDesignTheme(ThemeData.light(useMaterial3: true)),
    darkTheme: bookingDesignTheme(ThemeData.dark(useMaterial3: true)),
    themeMode: ThemeMode.system,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                  bottom: false,
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('نسخة مراجعة واجهات · مشروع اختبار مستقل',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12))))),
          Expanded(
              child: MediaQuery.removePadding(
                  context: context, removeTop: true, child: child!)),
        ])),
    home: home ?? const _ReviewLogin());

class _ReviewLogin extends StatefulWidget {
  const _ReviewLogin();
  @override
  State<_ReviewLogin> createState() => _ReviewLoginState();
}

class _ReviewLoginState extends State<_ReviewLogin> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> enter() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(), password: password.text);
      final profile = await FirebaseFirestore.instance
          .doc('users/${result.user!.uid}')
          .get(const GetOptions(source: Source.server));
      if (!profile.exists || profile.data()?['isBlocked'] == true) {
        await FirebaseAuth.instance.signOut();
        throw StateError('Account unavailable');
      }
      if (!mounted) {
        return;
      }
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  BookingScreen(admin: profile.data()?['isAdmin'] == true)));
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted)
        setState(() =>
            error = 'تعذر فتح حساب الاختبار؛ تحقق من البيانات والصلاحية.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('مراجعة الحجوزات')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text(
            'استخدم حساب اختبار مصرحًا به في المشروع المستقل. لا توجد حسابات أو بيانات مضافة داخل النسخة.'),
        const SizedBox(height: 24),
        TextField(
            controller: email,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
        const SizedBox(height: 16),
        TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور')),
        const SizedBox(height: 24),
        if (error != null) Text(error!),
        FilledButton(
            onPressed: busy ? null : enter,
            child: Text(busy ? 'جارٍ التحقق' : 'فتح حساب الاختبار')),
      ]));
}
