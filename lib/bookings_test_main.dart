import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'bookings/booking_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  if (appFlavor != 'bookingsTest')
    throw StateError('Bookings test entry requires bookingsTest flavor');
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          appId: '1:123456789000:android:0123456789abcdef',
          messagingSenderId: '123456789000',
          projectId: 'demo-aqar',
          storageBucket: 'demo-aqar.appspot.com'));
  const host = String.fromEnvironment('BOOKINGS_EMULATOR_HOST',
      defaultValue: '127.0.0.1');
  await FirebaseAuth.instance
      .useAuthEmulator(host, 9099, automaticHostMapping: false);

  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: false);
  FirebaseFirestore.instance
      .useFirestoreEmulator(host, 8185, automaticHostMapping: false);
  FirebaseFunctions.instance
      .useFunctionsEmulator(host, 5001, automaticHostMapping: false);
  await FirebaseStorage.instance
      .useStorageEmulator(host, 9198, automaticHostMapping: false);
  runApp(MaterialApp(
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
                        child: Text(
                            'اختبار محلي — بيانات ودفعات وهمية — يلزم تشغيل المحاكيات')))),
            Expanded(child: child!)
          ])),
      home: const _TestLogin()));
}

class _TestLogin extends StatefulWidget {
  const _TestLogin();
  @override
  State<_TestLogin> createState() => _TestLoginState();
}

class _TestLoginState extends State<_TestLogin> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('بيئة اختبار الحجوزات')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text(
            'اختر حساب اختبار. جميع العمليات تتصل بمحاكيات demo-aqar فقط.'),
        if (error != null) Text(error!),
        for (final role in ['customer', 'owner', 'admin', 'reviewer'])
          FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await FirebaseAuth.instance.signInWithEmailAndPassword(
                            email: '$role@test.invalid',
                            password: 'AqarTest123!');
                        if (context.mounted)
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      BookingScreen(admin: role == 'admin')));
                        await FirebaseAuth.instance.signOut();
                      } catch (_) {
                        if (mounted)
                          setState(() => error =
                              'تعذر الاتصال. شغّل المحاكيات وأضف بيانات الاختبار أولًا.');
                      }
                      if (mounted) setState(() => busy = false);
                    },
              child: Text(const {
                'customer': 'الزبون',
                'owner': 'المالك',
                'admin': 'الإدارة',
                'reviewer': 'المالية'
              }[role]!)),
      ]));
}
