import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'bookings/booking_screen.dart';
import 'bookings/booking_widgets.dart';
import 'bookings/booking_experience.dart';
import 'bookings/booking_workspace.dart';

/// Local rendering harness for the actual request screen and post-authorization
/// components. It never initializes Firebase or sends a real booking/payment.
void main() => runApp(const BookingLiveReviewApp());
const reviewVenue = <String, dynamic>{
  'name': 'شاليه ضفاف الفرات',
  'category': 'chalet',
  'location': 'الرمادي · الأنبار',
  'ownerName': 'مالك تجريبي',
  'capacity': 12,
  'bedrooms': 3,
  'amenities': ['pool', 'parking', 'kitchen'],
  'price': 250000,
  'deposit': 50000,
  'terms': 'احترام وقت الدخول والخروج والمحافظة على مرافق المكان.',
  'pricingMode': 'shifts',
  'shifts': [
    {
      'id': 'day',
      'name': 'الفترة النهارية',
      'price': 250000,
      'checkInMinute': 540,
      'checkOutMinute': 1080
    }
  ],
  'cancellationPolicy': {'freeCancellationHours': 24, 'lateRefundPercent': 25},
};
Future<Map<String, dynamic>> reviewReads(
    String name, Map<String, dynamic> data) async {
  if (name == 'getPublishedBookingReviews')
    return {'count': 0, 'average': 0, 'reviews': []};
  if (name == 'getBookingAvailability') {
    final month =
        DateTime.fromMillisecondsSinceEpoch(data['start'] as int, isUtc: true)
            .add(const Duration(hours: 3));
    return {
      'slots': [
        for (final day in [5, 6, 13])
          {
            'start': DateTime.utc(month.year, month.month, day, 6)
                .millisecondsSinceEpoch,
            'end': DateTime.utc(month.year, month.month, day, 15)
                .millisecondsSinceEpoch,
            'state': day == 13 ? 'pending' : 'confirmed'
          }
      ]
    };
  }
  throw FirebaseFunctionsException(
      code: 'unavailable',
      message: 'هذه معاينة محلية ببيانات اصطناعية؛ لا ترسل طلبات أو دفعات.');
}

class BookingLiveReviewApp extends StatefulWidget {
  const BookingLiveReviewApp({super.key});
  @override
  State<BookingLiveReviewApp> createState() => _BookingLiveReviewAppState();
}

class _BookingLiveReviewAppState extends State<BookingLiveReviewApp> {
  int view = 0;
  String method = 'qicard';
  final transaction = TextEditingController();
  @override
  void dispose() {
    transaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'SplashTajawal'),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: Column(children: [
            Material(
                color: const Color(0xFFF4EAD0),
                child: SafeArea(
                    bottom: false,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text(
                              'الواجهات الفعلية · بيانات اصطناعية · لا إرسال',
                              style: TextStyle(fontSize: 12)),
                          Wrap(spacing: 4, children: [
                            for (final e in {
                              0: 'الطلب',
                              1: 'الدفع',
                              2: 'المالية',
                              3: 'المالك'
                            }.entries)
                              TextButton(
                                  onPressed: () => setState(() => view = e.key),
                                  child: Text(e.value))
                          ]),
                        ])))),
            Expanded(child: child!),
          ])),
      home: view == 0
          ? BookingRequestScreen(
              key: const ValueKey('actual-request'),
              venueId: 'local-render-only',
              venue: reviewVenue,
              call: reviewReads,
              currentUserId: () => 'local-render-only')
          : view == 1
              ? BookingScaffold(
                  appBar: AppBar(title: const Text('عربون الحجز')),
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: BookingPaymentPanel(
                              deposit: 50000,
                              accounts: const {
                                'qicard': {'number': 'SYNTHETIC-QI'},
                                'zaincash': {'number': 'SYNTHETIC-ZAIN'}
                              },
                              method: method,
                              transaction: transaction,
                              busy: false,
                              onMethod: (v) => setState(() => method = v),
                              onSubmit: null))))
              : view == 2
                  ? BookingScaffold(
                      appBar: AppBar(title: const Text('دفتر مالية الحجوزات')),
                      body: const BookingLedgerContent(entries: [
                        {
                          'depositCollected': 50000,
                          'refundPaid': 0,
                          'ownerPaid': 0,
                          'platformCommission': 0,
                          'action': 'confirmPayment',
                          'bookingId': 'SYNTHETIC-BOOKING',
                          'reference': 'SYNTHETIC-REFERENCE'
                        }
                      ]))
                  : BookingScaffold(
                      appBar: AppBar(title: const Text('لوحة المالك')),
                      body: const SingleChildScrollView(
                          child: BookingOwnerPanel(onOpen: null, bookings: [
                        {
                          'id': 'SYNTHETIC-1',
                          'status': 'requested',
                          'venueName': 'شاليه ضفاف الفرات',
                          'customerName': 'ضيف تجريبي',
                          'total': 250000,
                          'start': 1795327200000
                        },
                        {
                          'id': 'SYNTHETIC-2',
                          'status': 'confirmed',
                          'venueName': 'قاعة تجريبية',
                          'customerName': 'ضيف تجريبي',
                          'total': 500000,
                          'start': 1795413600000
                        }
                      ]))));
}
