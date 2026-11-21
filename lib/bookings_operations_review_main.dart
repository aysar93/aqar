import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'bookings/booking_screen.dart';
import 'bookings/booking_widgets.dart';
import 'bookings/booking_operations.dart';
import 'bookings/booking_map.dart';

/// Local-only composition of the real editor and live operational components.
/// No Firebase initialization, credentials, uploads or callable writes.
void main() => runApp(const BookingOperationsReviewApp());
const operationsVenue = <String, dynamic>{
  'name': 'شاليه ضفاف الفرات',
  'category': 'chalet',
  'location': 'الرمادي · الأنبار',
  'latitude': 33.42,
  'longitude': 43.30,
  'capacity': 12,
  'bedrooms': 3,
  'deposit': 50000,
  'price': 250000,
  'terms': 'احترام مواعيد الدخول والخروج والمحافظة على مرافق المكان.',
  'pricingMode': 'shifts',
  'amenities': ['pool', 'parking'],
  'shifts': [
    {
      'id': 'night',
      'name': 'الفترة المسائية',
      'checkInMinute': 1200,
      'checkOutMinute': 480,
      'price': 300000
    }
  ],
  'cancellationPolicy': {'freeCancellationHours': 24, 'lateRefundPercent': 25},
};

class BookingOperationsReviewApp extends StatefulWidget {
  const BookingOperationsReviewApp({super.key});
  @override
  State<BookingOperationsReviewApp> createState() => _ReviewState();
}

class _ReviewState extends State<BookingOperationsReviewApp> {
  var view = 0;
  final subject = TextEditingController(text: 'طلب متابعة الحجز');
  final message =
      TextEditingController(text: 'أحتاج مساعدة في مراجعة حالة الطلب.');
  final staff = TextEditingController(text: 'SYNTHETIC-STAFF');
  final scopes = <String>{'calendar'};
  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    staff.dispose();
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
                          'مكونات التطبيق الفعلية · بيانات اصطناعية · لا إرسال',
                          style: TextStyle(fontSize: 12)),
                      Wrap(children: [
                        for (final e in {
                          0: 'محرر المكان',
                          1: 'الدعم',
                          2: 'الموظفون',
                          3: 'المراجعة',
                          4: 'الخريطة'
                        }.entries)
                          TextButton(
                              onPressed: () => setState(() => view = e.key),
                              child: Text(e.value))
                      ]),
                    ]))),
            Expanded(child: child!),
          ])),
      home: view == 0
          ? BookingVenueEditor(
              ownerMode: true,
              data: operationsVenue,
              call: (name, data) async => throw StateError(
                  'الحفظ متوقف في المعاينة المحلية؛ لا اتصال بـFirebase.'))
          : view == 4
              ? BookingMapScreen(
                  venues: Stream.value([
                  {...operationsVenue, 'id': 'synthetic-map'}
                ]))
              : BookingScaffold(
                  appBar: AppBar(
                      title: Text({
                    1: 'دعم الحجوزات',
                    2: 'فريق المكان',
                    3: 'مركز المراجعة'
                  }[view]!)),
                  body: ListView(padding: const EdgeInsets.all(20), children: [
                    if (view == 1) ...[
                      BookingSupportForm(
                          subject: subject,
                          message: message,
                          busy: false,
                          onSubmit: () {}),
                      const BookingSupportTicket(data: {
                        'subject': 'استفسار عن موعد الزيارة',
                        'status': 'in_progress',
                        'message': 'هل يمكنني تعديل الفترة؟',
                        'response': 'نراجع طلبك مع المالك.'
                      }),
                    ],
                    if (view == 2)
                      BookingStaffPermissions(
                          controller: staff,
                          scopes: scopes,
                          busy: false,
                          onChanged: (key, yes) => setState(() {
                                if (yes) {
                                  scopes.add(key);
                                } else {
                                  scopes.remove(key);
                                }
                              }),
                          onSave: () {}),
                    if (view == 3) ...[
                      const BookingMediaReviewCard(
                          venueId: 'SYNTHETIC-VENUE',
                          preview: BookingMediaGallery(paths: []),
                          onReview: null),
                      const BookingReviewCard(
                          rating: 5,
                          comment:
                              'مكان جميل وخدمة منظمة وتجربة تستحق التكرار.',
                          verified: true),
                      BookingReportCard(data: const {
                        'reason': 'طلب مراجعة اختلاف في موعد الدخول',
                        'userName': 'ضيف تجريبي',
                        'status': 'open'
                      }, onOpen: () {}),
                    ],
                  ])));
}
