import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'bookings/booking_services_ui.dart';
import 'bookings/booking_widgets.dart';

/// Local rendering of the exact live post-authorization components. No Firebase
/// initialization, credentials, camera access, settings writes or real QR token.
void main() => runApp(const BookingServicesReviewApp());

class BookingServicesReviewApp extends StatefulWidget {
  const BookingServicesReviewApp({super.key});
  @override
  State<BookingServicesReviewApp> createState() => _ReviewState();
}

class _ReviewState extends State<BookingServicesReviewApp> {
  int page = 0;
  final hold = TextEditingController(text: '120'),
      message = TextEditingController(),
      reference = TextEditingController(text: 'SYNTHETIC-REFERENCE');
  final expires = DateTime.now().add(const Duration(minutes: 10));
  @override
  void dispose() {
    hold.dispose();
    message.dispose();
    reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'SplashTajawal',
          colorSchemeSeed: bookingNavy),
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: Column(children: [
            Material(
                color: const Color(0xFFF4EAD0),
                child: SafeArea(
                    bottom: false,
                    child: Column(children: [
                      const Text(
                          'مكونات التطبيق الفعلية · بيانات اصطناعية · الأفعال الخدمية معطلة',
                          style: TextStyle(fontSize: 12)),
                      Wrap(children: [
                        for (final e in {
                          0: 'الإعدادات',
                          1: 'المحادثة',
                          2: 'نقل الملكية',
                          3: 'QR',
                          4: 'الكاميرا',
                          5: 'التسوية'
                        }.entries)
                          TextButton(
                              onPressed: () => setState(() => page = e.key),
                              child: Text(e.value))
                      ]),
                    ]))),
            Expanded(child: child!),
          ])),
      home: BookingScaffold(
          appBar: AppBar(
              title: Text({
            0: 'إعدادات الحجوزات',
            1: 'محادثة الحجز',
            2: 'نقل الملكية',
            3: 'رمز الوصول',
            4: 'مسح الرمز',
            5: 'التحويلات اليدوية'
          }[page]!)),
          body: page == 0
              ? BookingSettingsPanel(
                  hold: hold,
                  busy: false,
                  onSave: null,
                  onAccounts: null,
                  reviewers: const SwitchListTile(
                      value: true,
                      onChanged: null,
                      title: Text('مراجع تجريبي')))
              : page == 1
                  ? BookingChatPanel(
                      messages: const [
                          {
                            'senderId': 'owner',
                            'message':
                                'أهلًا بك، نتطلع لاستقبالكم في الموعد المحدد.'
                          },
                          {
                            'senderId': 'customer',
                            'message': 'شكرًا لكم، سنصل في الموعد المتفق عليه.'
                          }
                        ],
                      uid: 'customer',
                      controller: message,
                      busy: false,
                      retry: false,
                      onSend: null)
                  : page == 4
                      ? const BookingScannerPanel(
                          camera: ColoredBox(
                              color: bookingNavy,
                              child: Center(
                                  child: Text(
                                      'لا تُفتح الكاميرا في المعاينة المحلية',
                                      style: TextStyle(color: Colors.white)))),
                          busy: false)
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: page == 2
                              ? const BookingTransferCard(data: {
                                  'venueId': 'SYNTHETIC-VENUE',
                                  'ownerId': 'SYNTHETIC-OWNER',
                                  'newOwnerId': 'SYNTHETIC-NEW-OWNER',
                                  'reason': 'نقل الملكية وفق طلب الطرفين',
                                  'status': 'pending_admin'
                                }, admin: true, onAction: null)
                              : page == 3
                                  ? BookingQrPass(
                                      code:
                                          'aqar-booking:SYNTHETIC:${List.filled(64, '0').join()}',
                                      expiresAt: expires)
                                  : BookingManualSettlement(
                                      title: 'تسوية مستحقات المالك',
                                      reference: reference,
                                      busy: false,
                                      label: 'تسجيل التسوية',
                                      onSubmit: null))));
}
