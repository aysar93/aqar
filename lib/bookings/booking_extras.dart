import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'booking_screen.dart';
import 'booking_widgets.dart';

class BookingPublishedReviews extends StatefulWidget {
  const BookingPublishedReviews({super.key, required this.venueId});
  final String venueId;
  @override
  State<BookingPublishedReviews> createState() => _PublishedReviewsState();
}

class _PublishedReviewsState extends State<BookingPublishedReviews> {
  late final reviews =
      bookingCall('getPublishedBookingReviews', {'venueId': widget.venueId});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: reviews,
      builder: (context, s) {
        if (s.hasError) return const Text('تعذر تحميل التقييمات');
        if (!s.hasData) return const LinearProgressIndicator();
        return ExpansionTile(
            title: Text(
                'تقييمات حجوزات مكتملة: ${s.data!['count']} — ${(s.data!['average'] as num).toStringAsFixed(1)} / 5'),
            children: [
              if (s.data!['count'] == 0)
                const ListTile(title: Text('لا توجد تقييمات منشورة بعد')),
              for (final r in s.data!['reviews'] as List)
                ListTile(
                    leading: const Icon(Icons.verified),
                    title: Text('${r['rating']} / 5 — حجز مكتمل موثوق'),
                    subtitle: Text('${r['comment']}'))
            ]);
      });
}

class BookingScannerScreen extends StatefulWidget {
  const BookingScannerScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<BookingScannerScreen> createState() => _ScannerState();
}

class _ScannerState extends State<BookingScannerScreen> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> verify(String code) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    await controller.stop();
    try {
      if (!code.startsWith('aqar-booking:${widget.bookingId}:'))
        throw StateError('رمز لحجز آخر؛ افتح الحجز الصحيح');
      await bookingCall('verifyBookingCheckInCode',
          {'code': code, 'bookingId': widget.bookingId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تحقق الخادم وسجل الوصول')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        setState(() => error =
            'تعذر اعتماد الرمز. تحقق من الموعد وصلاحية الرمز واتصال الإنترنت.');
    }
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('مسح رمز وصول الحجز')),
      body: Column(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'اعرض رمز الزبون أمام الكاميرا. يلزم اتصال بالخادم لاعتماد الوصول.')),
        Expanded(
            child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  for (final b in capture.barcodes) {
                    if (b.rawValue != null) {
                      verify(b.rawValue!);
                      break;
                    }
                  }
                },
                errorBuilder: (context, error) => const Center(
                    child: Text(
                        'تعذر فتح الكاميرا؛ اسمح باستخدامها من إعدادات الهاتف أو استخدم لصق الرمز في الحجز.')))),
        if (error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
        if (error != null)
          TextButton(
              onPressed: () async {
                setState(() {
                  busy = false;
                  error = null;
                });
                await controller.start();
              },
              child: const Text('إعادة المسح'))
      ]));
}

class BookingSupportScreen extends StatefulWidget {
  const BookingSupportScreen({super.key, this.bookingId, this.admin = false});
  final String? bookingId;
  final bool admin;
  @override
  State<BookingSupportScreen> createState() => _SupportState();
}

class _SupportState extends State<BookingSupportScreen> {
  final subject = TextEditingController(), message = TextEditingController();
  final requestId = '${DateTime.now().microsecondsSinceEpoch}';
  bool busy = false;
  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> respond(String id, String status) async {
    final response = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('رد الدعم'),
                content: TextField(
                    controller: response, maxLength: 2000, maxLines: 4),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, response.text),
                      child: const Text('إرسال'))
                ]));
    response.dispose();
    if (value != null && mounted)
      await bookingRun(context, () async {
        await bookingCall('updateBookingSupportTicket',
            {'ticketId': id, 'status': status, 'response': value});
      });
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('booking_support');
    if (!widget.admin)
      query = query.where('userId',
          isEqualTo: FirebaseAuth.instance.currentUser!.uid);
    return BookingScaffold(
        appBar: AppBar(title: const Text('دعم الحجوزات')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (widget.bookingId != null) ...[
            TextField(
                controller: subject,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'موضوع الطلب')),
            TextField(
                controller: message,
                maxLength: 2000,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText:
                        'اشرح المشكلة دون مشاركة كلمة مرور أو معلومات بطاقة')),
            FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        await bookingRun(context, () async {
                          await bookingCall('openBookingSupportTicket', {
                            'bookingId': widget.bookingId,
                            'requestId': requestId,
                            'subject': subject.text,
                            'message': message.text
                          });
                          if (mounted) Navigator.pop(context);
                        });
                        if (mounted) setState(() => busy = false);
                      },
                child: const Text('فتح تذكرة دعم'))
          ],
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, s) {
                if (s.hasError) return const Text('تعذر تحميل تذاكر الدعم');
                if (!s.hasData) return const LinearProgressIndicator();
                final docs = s.data!.docs.toList()
                  ..sort((a, b) => ((b.data()['updatedAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0)
                      .compareTo((a.data()['updatedAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0));
                if (docs.isEmpty)
                  return const Text(
                      'لا توجد تذاكر. افتح تفاصيل الحجز لطلب الدعم.');
                return Column(children: [
                  for (final d in docs)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${d.data()['subject']} — ${{
                                    'open': 'مفتوحة',
                                    'in_progress': 'قيد المتابعة',
                                    'resolved': 'تم الحل'
                                  }[d.data()['status']]}'),
                                  Text('${d.data()['message']}'),
                                  if (d.data()['response'] != null)
                                    Text('رد الدعم: ${d.data()['response']}'),
                                  if (widget.admin)
                                    Wrap(children: [
                                      TextButton(
                                          onPressed: () =>
                                              respond(d.id, 'in_progress'),
                                          child:
                                              const Text('تولي التذكرة والرد')),
                                      TextButton(
                                          onPressed: () =>
                                              respond(d.id, 'resolved'),
                                          child: const Text('حل وإغلاق'))
                                    ])
                                ])))
                ]);
              })
        ]));
  }
}

class BookingAvailabilitySearchScreen extends StatefulWidget {
  const BookingAvailabilitySearchScreen({super.key});
  @override
  State<BookingAvailabilitySearchScreen> createState() =>
      _AvailabilitySearchState();
}

class _AvailabilitySearchState extends State<BookingAvailabilitySearchScreen> {
  DateTime? start, end;
  bool busy = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> results = [];
  bool searched = false;
  Future<DateTime?> pick() async {
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDate: DateTime.now().add(const Duration(days: 1)));
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null) return null;
    // Date/time controls represent Baghdad, independent of the phone timezone.
    return DateTime.utc(
        date.year, date.month, date.day, time.hour - 3, time.minute);
  }

  String label(DateTime? value) => value == null
      ? 'لم يحدد'
      : value.add(const Duration(hours: 3)).toString().replaceAll('Z', '');
  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('البحث عن موعد متاح')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'حدد فترة الدخول والخروج بتوقيت بغداد. النتائج لقطة توافر؛ يراجع الخادم الموعد مجددًا عند الحجز. يجب اختيار شفت المكان المطابق أو مدته المعتمدة.'),
        TextButton(
            onPressed: busy
                ? null
                : () async {
                    final value = await pick();
                    if (value != null && mounted) setState(() => start = value);
                  },
            child: Text('الدخول: ${label(start)}')),
        TextButton(
            onPressed: busy
                ? null
                : () async {
                    final value = await pick();
                    if (value != null && mounted) setState(() => end = value);
                  },
            child: Text('الخروج: ${label(end)}')),
        FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (start == null ||
                        end == null ||
                        !start!.isAfter(DateTime.now()) ||
                        !end!.isAfter(start!) ||
                        end!.difference(start!).inDays > 31) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'حدد موعدًا مستقبليًا وخروجًا بعد الدخول خلال 31 يومًا')));
                      return;
                    }
                    setState(() => busy = true);
                    await bookingRun(context, () async {
                      final venues = await FirebaseFirestore.instance
                          .collection('booking_venues')
                          .where('active', isEqualTo: true)
                          .get();
                      final free = <String>{};
                      for (var offset = 0;
                          offset < venues.docs.length;
                          offset += 50) {
                        final ids = venues.docs
                            .skip(offset)
                            .take(50)
                            .map((d) => d.id)
                            .toList();
                        final response =
                            await bookingCall('findAvailableBookingVenues', {
                          'venueIds': ids,
                          'start': start!.millisecondsSinceEpoch,
                          'end': end!.millisecondsSinceEpoch
                        });
                        free.addAll(List<String>.from(response['venueIds']));
                      }
                      if (mounted)
                        setState(() {
                          results = venues.docs
                              .where((d) => free.contains(d.id))
                              .toList();
                          searched = true;
                        });
                    });
                    if (mounted) setState(() => busy = false);
                  },
            child: Text(busy ? 'جاري فحص التوافر...' : 'ابحث عن أماكن متاحة')),
        if (searched && results.isEmpty)
          const Text('لا يوجد مكان متاح خلال الفترة المحددة'),
        for (final d in results)
          BookingVenueCard(
              venue: d.data(),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BookingRequestScreen(
                          venueId: d.id, venue: d.data()))))
      ]));
}
