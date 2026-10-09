import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../banners/banner_service.dart';
import '../widgets/banner_slider.dart';
import '../screens/admin/banner_management_screen.dart';
import 'dart:async';
import 'booking_widgets.dart';
import 'booking_map.dart';
import 'booking_management.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../subscription/payment_accounts.dart';
import '../screens/admin/payment_account_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

List<DateTime> bookingShiftDates(DateTime date, Map<String, dynamic> shift) {
  final minute = shift['checkInMinute'] as int;
  final duration = ((shift['checkOutMinute'] as int) - minute + 1440) % 1440;
  final start = DateTime.utc(date.year, date.month, date.day)
      .add(Duration(minutes: minute - 180));
  return [start, start.add(Duration(minutes: duration == 0 ? 1440 : duration))];
}

String bookingTime(dynamic minute) =>
    '${((minute as int) ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
int? bookingMinute(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
  return h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60
      ? h * 60 + m
      : null;
}

String bookingCancellationText(dynamic p) => p == null
    ? 'سياسة الاسترداد غير محددة لهذا الحجز القديم؛ يلزم اعتمادها قبل الإلغاء المالي.'
    : 'استرداد كامل العربون عند إلغاء الزبون قبل الدخول بـ ${p['freeCancellationHours']} ساعة أو أكثر، وبعدها استرداد ${p['lateRefundPercent']}٪. إلغاء المالك أو الإدارة قبل الدخول يعيد كامل العربون. لا يتاح الإلغاء بعد الدخول. الاسترداد بتحويل يدوي يراجعه موظف مالي.';

String bookingActionLabel(dynamic action) =>
    const {
      'request': 'إرسال الطلب',
      'approve': 'موافقة المالك',
      'reject': 'رفض الطلب',
      'submitPayment': 'إرسال إيصال العربون',
      'confirmPayment': 'اعتماد العربون',
      'rejectPayment': 'رفض الإيصال',
      'cancel': 'إلغاء الحجز',
      'expire': 'انتهاء المهلة',
      'checkIn': 'تسجيل الوصول',
      'qrCheckIn': 'التحقق من رمز الوصول',
      'complete': 'انتهاء الزيارة',
      'settleRefund': 'تسجيل الاسترداد',
      'settleOwner': 'تسجيل تسوية المالك',
    }[action] ??
    'تحديث الحجز';
const bookingStatuses = {
  'requested': 'بانتظار المالك',
  'held': 'حجز مؤقت — بانتظار العربون',
  'payment_review': 'الإيصال قيد مراجعة الإدارة',
  'confirmed': 'حجز مؤكد',
  'arrived': 'تم الوصول',
  'completed': 'مكتمل',
  'cancel_requested': 'إلغاء بانتظار مراجعة الإيصال',
  'rejected': 'مرفوض',
  'cancelled': 'ملغي',
  'expired': 'انتهت المهلة',
  'payment_rejected': 'إيصال مرفوض'
};
Future<Map<String, dynamic>> bookingCall(
    String name, Map<String, dynamic> data) async {
  if (appFlavor == 'bookingsTest') {
    const host = String.fromEnvironment('BOOKINGS_EMULATOR_HOST',
        defaultValue: '127.0.0.1');
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    final response = await http
        .post(
          Uri.parse('http://$host:5001/demo-aqar/us-central1/$name'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode({'data': data}),
        )
        .timeout(const Duration(seconds: 30));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['error'] != null) {
      final error = payload['error'] as Map;
      throw FirebaseFunctionsException(
          code: '${error['status']}', message: '${error['message']}');
    }
    return Map<String, dynamic>.from(payload['result'] as Map);
  }
  final result =
      await FirebaseFunctions.instance.httpsCallable(name).call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

Future<void> bookingRun(
    BuildContext context, Future<void> Function() task) async {
  try {
    await task();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is FirebaseFunctionsException
              ? e.message ?? 'تعذر تنفيذ العملية'
              : 'تعذر تنفيذ العملية، حاول مجدداً')));
    }
  }
}

class BookingScreen extends StatefulWidget {
  final bool admin;
  const BookingScreen({super.key, this.admin = false});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int tab = 0;
  String search = '';
  bool finance = false;
  late final bookingBanners =
      BannerService.activeBanners(placement: BannerPlacement.bookings);
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.doc('users/$uid').get().then((s) {
        if (mounted) {
          setState(
              () => finance = s.data()?['canReviewBookingPayments'] == true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const BookingScaffold(
          body: Center(child: Text('سجل الدخول للوصول إلى الحجوزات')));
    }
    Query<Map<String, dynamic>> query;
    if (tab == 6) {
      query = FirebaseFirestore.instance
          .collection('booking_venue_staff')
          .where('userId', isEqualTo: uid);
    } else if (tab == 5) {
      query = FirebaseFirestore.instance
          .collection('booking_venues')
          .where('ownerId', isEqualTo: uid);
    } else if (tab == 0) {
      query = FirebaseFirestore.instance.collection('booking_venues');
      if (!widget.admin) query = query.where('active', isEqualTo: true);
    } else if (tab == 3) {
      query = FirebaseFirestore.instance.collection('booking_reports');
    } else {
      query = FirebaseFirestore.instance.collection('bookings');
      if (tab == 4) {
        query = query.where('status',
            whereIn: ['payment_review', 'cancel_requested', 'cancelled']);
      } else if (!widget.admin) {
        query =
            query.where(tab == 1 ? 'customerId' : 'ownerId', isEqualTo: uid);
      }
    }
    return Directionality(
        textDirection: TextDirection.rtl,
        child: BookingScaffold(
            appBar: AppBar(
                backgroundColor: bookingNavy,
                foregroundColor: Colors.white,
                title: Text(
                    widget.admin ? 'إدارة الحجوزات' : 'الشاليهات والقاعات'),
                actions: widget.admin
                    ? [
                        IconButton(
                            icon: const Icon(Icons.campaign_outlined),
                            tooltip: 'بنرات الحجوزات',
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BannerManagementScreen(
                                            placement:
                                                BannerPlacement.bookings)))),
                        IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: 'إضافة مكان',
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BookingVenueEditor()))),
                        IconButton(
                            icon: const Icon(Icons.settings),
                            tooltip: 'إعدادات الحجوزات',
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BookingSettingsScreen())))
                      ]
                    : null),
            body: Column(children: [
              Wrap(children: [
                if (widget.admin)
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BookingReviewInbox())),
                      child: const Text('مراجعة التقييمات')),
                if (widget.admin)
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BookingMediaInbox())),
                      child: const Text('مراجعة الوسائط')),
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                BookingTransferInbox(admin: widget.admin))),
                    child: const Text('نقل الملكية')),
                if (widget.admin || finance)
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BookingLedgerScreen())),
                      child: const Text('التقرير المالي')),
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BookingVenueEditor(
                                ownerMode: true, data: {'ownerId': uid}))),
                    child: const Text('إضافة مكان للتوثيق')),
                if (widget.admin)
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BookingProofInbox())),
                      child: const Text('توثيق الملكية')),
              ]),
              TextButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BookingMapScreen())),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('خريطة الحجوزات')),
              Wrap(spacing: 8, children: [
                for (final entry in {
                  0: 'الأماكن',
                  1: widget.admin ? 'جميع الحجوزات' : 'حجوزاتي',
                  if (!widget.admin) 2: 'لوحة المالك',
                  if (!widget.admin) 5: 'أماكني وأسعاري',
                  if (!widget.admin) 6: 'مهام الموظف',
                  if (widget.admin) 3: 'البلاغات',
                  if (finance) 4: 'المراجعة المالية'
                }.entries)
                  ChoiceChip(
                      label: Text(entry.value),
                      selected: tab == entry.key,
                      onSelected: (_) => setState(() => tab = entry.key))
              ]),
              if (tab == 0)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => search = value.trim()),
                      decoration: const InputDecoration(
                          hintText: 'ابحث عن شاليه أو قاعة أو مدينة',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder()),
                    )),
              Expanded(
                  child: ListView(children: [
                if (tab == 0)
                  BannerSlider(
                      stream: bookingBanners,
                      onBookingVenue: (id, category) async {
                        await bookingRun(context, () async {
                          final doc = await FirebaseFirestore.instance
                              .doc('booking_venues/$id')
                              .get();
                          final venue = doc.data();
                          if (venue == null ||
                              venue['active'] != true ||
                              venue['category'] != category)
                            throw StateError('المكان غير متاح');
                          if (context.mounted)
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => BookingRequestScreen(
                                        venueId: id, venue: venue)));
                        });
                      }),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query.snapshots(),
                    builder: (context, s) {
                      if (s.hasError) {
                        return const Center(child: Text('تعذر تحميل البيانات'));
                      }
                      if (!s.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (s.data!.docs.isEmpty) {
                        return const Center(child: Text('لا توجد بيانات بعد'));
                      }
                      return Column(
                          children: s.data!.docs.map((doc) {
                        final d = doc.data();
                        if (tab == 6)
                          return ListTile(
                              title: Text('مكان ${d['venueId']}'),
                              subtitle: const Text('صلاحيات موظف مفوض'),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => BookingStaffScreen(
                                          venueId: d['venueId'],
                                          scopes: List<String>.from(
                                              d['scopes'] ?? [])))));
                        if (tab == 0 || tab == 5) {
                          if (search.isNotEmpty &&
                              tab == 0 &&
                              !'${d['name']} ${d['location']}'.contains(search))
                            return const SizedBox.shrink();
                          return BookingVenueCard(
                              venue: d,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => widget.admin || tab == 5
                                          ? BookingVenueEditor(
                                              venueId: doc.id,
                                              data: d,
                                              ownerMode: tab == 5)
                                          : BookingRequestScreen(
                                              venueId: doc.id, venue: d))));
                        }
                        return Card(
                            child: ListTile(
                                title: Text('${d['name'] ?? d['venueName']}'),
                                subtitle: Text(tab == 0
                                    ? '${d['location']}\nالسعر: ${d['price']} د.ع — العربون: ${d['deposit']} د.ع'
                                    : tab == 3
                                        ? '${d['userName']}: ${d['reason']} — ${d['status']}'
                                        : '${d['customerName']} — ${bookingStatuses[d['status']] ?? d['status']}'),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => tab == 0
                                            ? (widget.admin
                                                ? BookingVenueEditor(
                                                    venueId: doc.id, data: d)
                                                : BookingRequestScreen(
                                                    venueId: doc.id, venue: d))
                                            : BookingDetailsScreen(
                                                bookingId: (tab == 3
                                                        ? d['bookingId']
                                                        : doc.id)
                                                    .toString()))),
                                trailing: tab == 3 && d['status'] == 'open'
                                    ? IconButton(
                                        icon: const Icon(Icons.check),
                                        onPressed: () => bookingRun(
                                            context,
                                            () => doc.reference.update(
                                                {'status': 'resolved'})))
                                    : null));
                      }).toList());
                    })
              ]))
            ])));
  }
}

class BookingRequestScreen extends StatefulWidget {
  final String venueId;
  final Map<String, dynamic> venue;
  const BookingRequestScreen(
      {super.key, required this.venueId, required this.venue});
  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  DateTime? start, end;
  bool accepted = false, busy = false;
  String? shiftId;
  DateTime calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<Map<String, dynamic>> availability = loadAvailability();
  Future<Map<String, dynamic>> loadAvailability() {
    final first = DateTime.utc(calendarMonth.year, calendarMonth.month, 1, -3)
        .millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch + 1000;
    return bookingCall('getBookingAvailability', {
      'venueId': widget.venueId,
      'start': first > now ? first : now,
      'end': DateTime.utc(calendarMonth.year, calendarMonth.month + 1, 1, -3)
          .millisecondsSinceEpoch
    });
  }

  int get total {
    final offer = widget.venue['offer'] as Map?;
    final percent = offer?['percent'];
    if (percent is int &&
        percent >= 0 &&
        percent <= 50 &&
        offer?['until'] is num &&
        (offer!['until'] as num) >= DateTime.now().millisecondsSinceEpoch)
      return baseTotal * (100 - percent) ~/ 100;
    return baseTotal;
  }

  int get baseTotal {
    final v = widget.venue;
    if (v['pricingMode'] == 'hourly' && start != null && end != null) {
      return ((end!.difference(start!).inMinutes / 60) *
              (v['hourlyPrice'] as num))
          .round();
    }
    if (v['pricingMode'] == 'shifts' && shiftId != null) {
      return (v['shifts'] as List)
          .firstWhere((s) => s['id'] == shiftId)['price'] as int;
    }
    return v['price'] as int;
  }

  void setShiftDate(DateTime date) {
    final shift =
        (widget.venue['shifts'] as List).firstWhere((s) => s['id'] == shiftId);
    final dates =
        bookingShiftDates(date, Map<String, dynamic>.from(shift as Map));
    start = dates[0];
    end = dates[1];
  }

  final notes = TextEditingController();
  late final requestId = '${DateTime.now().microsecondsSinceEpoch}';
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<DateTime?> pick() async {
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) return null;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    return time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.venue;
    return BookingScaffold(
        appBar: AppBar(title: Text('${v['name']}')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          BookingMediaGallery(paths: List<String>.from(v['mediaPaths'] ?? [])),
          if (v['pricingMode'] == 'shifts' && shiftId != null)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(
                  tooltip: 'الشهر السابق',
                  onPressed: calendarMonth.isAfter(
                          DateTime(DateTime.now().year, DateTime.now().month))
                      ? () => setState(() {
                            calendarMonth = DateTime(
                                calendarMonth.year, calendarMonth.month - 1);
                            availability = loadAvailability();
                          })
                      : null,
                  icon: const Icon(Icons.chevron_right)),
              const Text('تقويم التوافر'),
              IconButton(
                  tooltip: 'الشهر التالي',
                  onPressed: () => setState(() {
                        calendarMonth = DateTime(
                            calendarMonth.year, calendarMonth.month + 1);
                        availability = loadAvailability();
                      }),
                  icon: const Icon(Icons.chevron_left)),
            ]),
          if (v['pricingMode'] == 'shifts' && shiftId != null)
            FutureBuilder<Map<String, dynamic>>(
                future: availability,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return TextButton(
                        onPressed: () =>
                            setState(() => availability = loadAvailability()),
                        child:
                            const Text('تعذر تحميل التوافر — إعادة المحاولة'));
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return BookingCalendar(
                      month: calendarMonth,
                      slots: (snapshot.data!['slots'] as List)
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList(),
                      intervalForDay: (day) => bookingShiftDates(
                          day,
                          Map<String, dynamic>.from((v['shifts'] as List)
                              .firstWhere((s) => s['id'] == shiftId))),
                      onSelect: (day) => setState(() {
                            setShiftDate(day);
                            accepted = false;
                          }));
                }),
          Text(
              'المالك: ${v['ownerName']}\nالموقع: ${v['location']}\nالسعر المحدد: $total د.ع\nالعربون: ${v['deposit']} د.ع\nالمتبقي بعد اعتماد العربون: ${total - (v['deposit'] as num)} د.ع\n\nالشروط: ${v['terms']}'),
          if (v['pricingMode'] == 'hourly')
            Text('سعر الساعة: ${v['hourlyPrice']} د.ع — اختر ساعات كاملة'),
          if (v['pricingMode'] == 'shifts') ...[
            DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: shiftId,
                decoration:
                    const InputDecoration(labelText: 'الشفت (توقيت بغداد)'),
                items: [
                  for (final shift in v['shifts'] as List)
                    DropdownMenuItem(
                        value: shift['id'] as String,
                        child: Text(
                            '${shift['name']} — ${bookingTime(shift['checkInMinute'])} إلى ${bookingTime(shift['checkOutMinute'])} — ${shift['price']} د.ع',
                            overflow: TextOverflow.ellipsis))
                ],
                onChanged: (value) => setState(() {
                      shiftId = value;
                      start = null;
                      end = null;
                      accepted = false;
                    })),
            TextButton(
                onPressed: shiftId == null
                    ? null
                    : () async {
                        final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)));
                        if (mounted && date != null) {
                          setState(() {
                            setShiftDate(date);
                            accepted = false;
                          });
                        }
                      },
                child: const Text('اختر تاريخ دخول الشفت')),
            if (start != null)
              Text(
                  'الدخول: ${start!.add(const Duration(hours: 3)).toString().replaceAll("Z", "")}\nالخروج: ${end!.add(const Duration(hours: 3)).toString().replaceAll("Z", "")} — توقيت بغداد'),
          ] else ...[
            TextButton(
                onPressed: () async {
                  final d = await pick();
                  if (mounted && d != null) {
                    setState(() {
                      start = d;
                      accepted = false;
                    });
                  }
                },
                child: Text('البداية: ${start ?? "اختر"}')),
            TextButton(
                onPressed: () async {
                  final d = await pick();
                  if (mounted && d != null) {
                    setState(() {
                      end = d;
                      accepted = false;
                    });
                  }
                },
                child: Text('النهاية: ${end ?? "اختر"}')),
          ],
          Text(bookingCancellationText(v['cancellationPolicy'])),
          TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'ملاحظات')),
          CheckboxListTile(
              value: accepted,
              onChanged: (v) => setState(() => accepted = v ?? false),
              title: const Text('أوافق على السعر والشروط وسياسة الإلغاء')),
          FilledButton(
              onPressed: busy || !accepted || start == null || end == null
                  ? null
                  : () async {
                      setState(() => busy = true);
                      await bookingRun(context, () async {
                        final r = await bookingCall('requestBooking', {
                          'venueId': widget.venueId,
                          'requestId': requestId,
                          'start': start!.millisecondsSinceEpoch,
                          'end': end!.millisecondsSinceEpoch,
                          'acceptedTerms': v['terms'],
                          'price': total,
                          'shiftId': shiftId,
                          'cancellationPolicy': v['cancellationPolicy'],
                          'deposit': v['deposit'],
                          'notes': notes.text
                        });
                        if (context.mounted) {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => BookingDetailsScreen(
                                      bookingId: r['id'])));
                        }
                      });
                      if (mounted) setState(() => busy = false);
                    },
              child: const Text('طلب الحجز'))
        ]));
  }
}

class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailsScreen({super.key, required this.bookingId});
  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  int rating = 5;
  bool busy = false, admin = false, finance = false;
  String method = 'qicard';
  String? displayedNumber;
  Map<String, dynamic> accounts = {};
  StreamSubscription<Map<String, dynamic>>? accountListener;
  final transaction = TextEditingController(),
      reason = TextEditingController(),
      refundReference = TextEditingController();
  @override
  void initState() {
    super.initState();
    accountListener = SubscriptionPaymentAccounts.watch().listen((value) {
      if (!mounted) return;
      setState(() {
        accounts = value;
        if (!accounts.containsKey(method)) {
          method = accounts.keys.firstOrNull ?? '';
        }
        displayedNumber = accounts[method]?['number'];
      });
    }, onError: (_) {
      if (mounted) {
        setState(() {
          accounts = {};
          displayedNumber = null;
        });
      }
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.doc('users/$uid').get().then((s) {
        if (mounted) {
          setState(() {
            admin = s.data()?['isAdmin'] == true;
            finance = s.data()?['canReviewBookingPayments'] == true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    accountListener?.cancel();
    refundReference.dispose();
    transaction.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> act(String action,
      [Map<String, dynamic> extra = const {}]) async {
    setState(() => busy = true);
    await bookingRun(context, () async {
      await bookingCall('actOnBooking', {
        'bookingId': widget.bookingId,
        'action': action,
        'reason': reason.text,
        ...extra
      });
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('تفاصيل الحجز')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .doc('bookings/${widget.bookingId}')
              .snapshots(),
          builder: (context, s) {
            if (s.hasError) {
              return const Center(child: Text('لا تملك صلاحية عرض هذا الحجز'));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final b = s.data!.data();
            if (b == null) return const Center(child: Text('الحجز غير موجود'));
            final uid = FirebaseAuth.instance.currentUser?.uid,
                owner = uid == b['ownerId'],
                customer = uid == b['customerId'];
            final held = b['status'] == 'held' &&
                (b['holdUntil'] as num) > DateTime.now().millisecondsSinceEpoch;
            Widget button(String label, String action) => FilledButton(
                onPressed: busy ? null : () => act(action), child: Text(label));
            return ListView(padding: const EdgeInsets.all(20), children: [
              BookingProgress(status: b['status']),
              if (customer && b['status'] == 'completed') ...[
                DropdownButtonFormField<int>(
                    initialValue: rating,
                    decoration:
                        const InputDecoration(labelText: 'تقييم تجربة الحجز'),
                    items: [
                      for (var i = 1; i <= 5; i++)
                        DropdownMenuItem(value: i, child: Text('$i / 5'))
                    ],
                    onChanged:
                        busy ? null : (v) => setState(() => rating = v ?? 5)),
                TextButton(
                    onPressed: busy
                        ? null
                        : () => bookingRun(context, () async {
                              await bookingCall('reviewCompletedBooking', {
                                'bookingId': widget.bookingId,
                                'rating': rating,
                                'comment': reason.text
                              });
                            }),
                    child: const Text(
                        'إرسال التقييم — اكتب تعليقك في حقل الملاحظات')),
              ],
              if (owner || customer)
                TextButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BookingChatScreen(
                                bookingId: widget.bookingId))),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('محادثة الحجز')),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('booking_action_audit')
                      .where('bookingId', isEqualTo: widget.bookingId)
                      .snapshots(),
                  builder: (context, events) {
                    if (!events.hasData) return const SizedBox.shrink();
                    final docs = events.data!.docs.toList()
                      ..sort((a, b) => ((a.data()['version'] as num?) ?? 0)
                          .compareTo((b.data()['version'] as num?) ?? 0));
                    return Column(children: [
                      for (final event in docs)
                        ListTile(
                            dense: true,
                            title: Text(bookingActionLabel(event.data()['action'])),
                            subtitle: Text(
                                '${event.data()['createdAt'] is Timestamp ? (event.data()['createdAt'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3)).toString().replaceAll('Z', '') : ""} — بغداد'))
                    ]);
                  }),
              if (finance &&
                  !owner &&
                  !customer &&
                  b['status'] == 'completed' &&
                  b['ownerSettlementStatus'] != 'settled')
                TextField(
                    controller: refundReference,
                    decoration: const InputDecoration(
                        labelText:
                            'مرجع تحويل مستحقات المالك بعد التحويل الفعلي')),
              if (finance &&
                  !owner &&
                  !customer &&
                  b['status'] == 'completed' &&
                  b['ownerSettlementStatus'] != 'settled')
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => act('settleOwner',
                            {'settlementReference': refundReference.text}),
                    child: const Text('تسجيل تسوية مستحقات المالك يدويًا')),
              if (customer && b['status'] == 'confirmed')
                FilledButton.icon(
                    icon: const Icon(Icons.qr_code),
                    label: const Text('رمز الوصول — صالح 10 دقائق'),
                    onPressed: busy
                        ? null
                        : () => bookingRun(context, () async {
                              final result = await bookingCall(
                                  'issueBookingCheckInCode',
                                  {'bookingId': widget.bookingId});
                              if (context.mounted)
                                await showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                        child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                      'اعرض الرمز للمالك عند الوصول'),
                                                  QrImageView(
                                                      data: result['code'],
                                                      size: 240),
                                                  SelectableText(
                                                      result['code']),
                                                ]))));
                            })),
              if (owner && b['status'] == 'confirmed')
                button('تسجيل الوصول', 'arrive'),
              if (owner && b['status'] == 'confirmed')
                TextButton(
                    onPressed: busy
                        ? null
                        : () => bookingRun(context, () async {
                              await bookingCall('verifyBookingCheckInCode',
                                  {'code': reason.text.trim()});
                            }),
                    child: const Text(
                        'تحقق من رمز الوصول الملصق في حقل الملاحظات')),
              if (owner && ['confirmed', 'arrived'].contains(b['status']))
                button('إنهاء الحجز بعد موعد الخروج', 'complete'),
              BookingSummary(
                  booking: b,
                  status: bookingStatuses[b['status']] ?? b['status']),
              Text(bookingCancellationText(b['cancellationPolicy'])),
              if (b['pricing'] != null)
                Text(
                    'التسعير: ${b['pricing']['name'] ?? b['pricing']['mode']}'),
              if (b['refundDue'] != null)
                Text(
                    'الاسترداد المستحق: ${b['refundDue']} د.ع — المعاد: ${b['refunded'] ?? 0} — الحالة: ${b['refundStatus'] == 'settled' ? 'تمت التسوية' : b['refundStatus'] == 'pending' ? 'بانتظار التسوية المالية' : 'لا يوجد مبلغ مستحق'}'),
              if (b['reviewedBy'] != null)
                Text('مراجع العربون: ${b['reviewedBy']}'),
              if (b['cancelledBy'] != null)
                Text(
                    'ألغاه: ${b['cancelledBy']} — السبب: ${b['cancellationReason'] ?? b['reason']}'),
              if (b['refundReference'] != null)
                Text(
                    'مرجع الاسترداد: ${b['refundReference']}\nالمراجع: ${b['refundSettledBy']}\nوقت التسوية: ${DateTime.fromMillisecondsSinceEpoch(b['refundSettledAt'])}'),
              if (finance &&
                  !owner &&
                  !customer &&
                  b['refundStatus'] == 'pending') ...[
                TextField(
                    controller: refundReference,
                    decoration: const InputDecoration(
                        labelText:
                            'مرجع تحويل الاسترداد بعد إعادة المبلغ فعلياً')),
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => act('settleRefund',
                            {'refundReference': refundReference.text}),
                    child: const Text('تسجيل إعادة المبلغ يدوياً')),
              ],
              if (b['receiptPath'] != null)
                TextButton(
                    onPressed: () => bookingRun(context, () async {
                          final bytes = await FirebaseStorage.instance
                              .ref(b['receiptPath'])
                              .getData(10 * 1024 * 1024);
                          if (context.mounted && bytes != null) {
                            showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                    child: InteractiveViewer(
                                        child: Image.memory(bytes))));
                          }
                        }),
                    child: const Text('عرض الإيصال')),
              TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                      labelText: 'سبب الرفض أو الإلغاء أو البلاغ')),
              if (owner && b['status'] == 'requested') ...[
                button('موافقة وحجز مؤقت', 'approve'),
                button('رفض الطلب', 'reject')
              ],
              if (customer && held) ...[
                if (accounts.isEmpty) const Text('لا تتوفر وسيلة دفع حاليًا'),
                for (final entry in accounts.entries)
                  RadioListTile<String>(
                      value: entry.key,
                      groupValue: method,
                      title: Text(
                          '${entry.key == 'qicard' ? 'كي' : 'زين كاش'}: ${entry.value['number']}'),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                                method = v!;
                                displayedNumber = accounts[method]['number'];
                              })),
                TextField(
                    controller: transaction,
                    decoration:
                        const InputDecoration(labelText: 'رقم التحويل')),
                FilledButton(
                    onPressed: busy || displayedNumber == null
                        ? null
                        : () async {
                            final expectedNumber = displayedNumber;
                            final selectedMethod = method;
                            setState(() => busy = true);
                            await bookingRun(context, () async {
                              final image = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1600,
                                  imageQuality: 85);
                              if (image == null) return;
                              final path =
                                  'booking_receipts/${widget.bookingId}/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
                              await FirebaseStorage.instance.ref(path).putData(
                                  await FlutterImageCompress.compressWithList(
                                      await image.readAsBytes(),
                                      format: CompressFormat.jpeg,
                                      quality: 85),
                                  SettableMetadata(contentType: 'image/jpeg'));

                              await bookingCall('actOnBooking', {
                                'bookingId': widget.bookingId,
                                'action': 'submitPayment',
                                'method': selectedMethod,
                                'expectedNumber': expectedNumber,
                                'transactionNumber': transaction.text,
                                'receiptPath': path
                              });
                            });
                            if (mounted) setState(() => busy = false);
                          },
                    child: const Text('رفع إيصال وإرسال للمراجعة'))
              ],
              if (finance &&
                  !owner &&
                  !customer &&
                  ['payment_review', 'cancel_requested']
                      .contains(b['status'])) ...[
                button(
                    b['status'] == 'cancel_requested'
                        ? 'اعتماد المبلغ وفتح تسوية الاسترداد'
                        : 'اعتماد العربون وتأكيد الحجز',
                    'confirmPayment'),
                button('رفض الإيصال', 'rejectPayment')
              ],
              if ((owner || customer || admin) &&
                  ['requested', 'held', 'confirmed', 'payment_review']
                      .contains(b['status']))
                button('إلغاء الحجز', 'cancel'),
              if (owner || customer)
                OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => bookingRun(context, () async {
                              await bookingCall('reportBooking', {
                                'bookingId': widget.bookingId,
                                'reason': reason.text
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('تم إرسال البلاغ')));
                              }
                            }),
                    child: const Text('إرسال بلاغ للإدارة')),
            ]);
          }));
}

class BookingVenueEditor extends StatefulWidget {
  final bool ownerMode;
  final String? venueId;
  final Map<String, dynamic> data;
  const BookingVenueEditor(
      {super.key, this.venueId, this.data = const {}, this.ownerMode = false});
  @override
  State<BookingVenueEditor> createState() => _BookingVenueEditorState();
}

class _BookingVenueEditorState extends State<BookingVenueEditor> {
  late final fields = {
    for (final k in [
      'name',
      'ownerId',
      'location',
      'latitude',
      'longitude',
      'commissionPercent',
      'price',
      'deposit',
      'terms',
      'hourlyPrice',
      'freeCancellationHours',
      'lateRefundPercent'
    ])
      k: TextEditingController(
          text: (k == 'commissionPercent'
                      ? ((widget.data['commissionBps'] as num? ?? 0) / 100)
                          .toString()
                      : ['freeCancellationHours', 'lateRefundPercent']
                              .contains(k)
                          ? (widget.data['cancellationPolicy'] as Map? ?? {})[k]
                          : widget.data[k])
                  ?.toString() ??
              '')
  };
  late String pricingMode = widget.data['pricingMode'] ?? 'fixed';
  late final List<Map<String, TextEditingController>> shifts = [
    for (final shift in (widget.data['shifts'] as List? ?? []))
      {
        for (final key in [
          'id',
          'name',
          'checkInMinute',
          'checkOutMinute',
          'price'
        ])
          key: TextEditingController(
              text: ['checkInMinute', 'checkOutMinute'].contains(key)
                  ? bookingTime(shift[key])
                  : '${shift[key]}')
      }
  ];
  late String category = widget.data['category'] ?? 'chalet';
  late bool active = widget.data['active'] ?? false;
  bool busy = false;
  @override
  void dispose() {
    for (final shift in shifts) {
      for (final c in shift.values) {
        c.dispose();
      }
    }
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('إعداد مكان للحجز')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.venueId != null)
          TextButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          BookingOwnerTools(venueId: widget.venueId!))),
              icon: const Icon(Icons.calendar_month),
              label: const Text('التقويم والحجوزات الخارجية ونقل الملكية')),
        if (widget.ownerMode && widget.venueId != null)
          Wrap(children: [
            for (final video in [false, true])
              TextButton.icon(
                  icon: Icon(video ? Icons.videocam : Icons.photo),
                  label: Text(video
                      ? 'رفع فيديو للمراجعة (50 MB)'
                      : 'رفع صورة للمراجعة (10 MB)'),
                  onPressed: busy
                      ? null
                      : () => bookingRun(context, () async {
                            final file = video
                                ? await ImagePicker()
                                    .pickVideo(source: ImageSource.gallery)
                                : await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 2000,
                                    imageQuality: 90);
                            if (file == null) return;
                            if (await file.length() >
                                (video ? 50 : 10) * 1024 * 1024)
                              throw StateError('حجم الملف كبير');
                            final bytes = video
                                ? await file.readAsBytes()
                                : await FlutterImageCompress.compressWithList(
                                    await file.readAsBytes(),
                                    format: CompressFormat.jpeg,
                                    quality: 90);
                            final path =
                                'booking_media/${widget.venueId}/${FirebaseAuth.instance.currentUser!.uid}/${DateTime.now().microsecondsSinceEpoch}.${video ? 'mp4' : 'jpg'}';
                            await FirebaseStorage.instance.ref(path).putData(
                                bytes,
                                SettableMetadata(
                                    contentType:
                                        video ? 'video/mp4' : 'image/jpeg'));
                            await bookingCall('submitBookingMedia',
                                {'venueId': widget.venueId, 'path': path});
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'الملف بانتظار مراجعة الإدارة')));
                          }))
          ]),
        if (widget.ownerMode &&
            widget.venueId != null &&
            ['pending', 'rejected'].contains(widget.data['verificationStatus']))
          FilledButton(
              onPressed: busy
                  ? null
                  : () => bookingRun(context, () async {
                        final image = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 2000,
                            imageQuality: 90);
                        if (image == null) return;
                        final uid = FirebaseAuth.instance.currentUser!.uid,
                            path =
                                'booking_ownership_documents/${widget.venueId}/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
                        final bytes =
                            await FlutterImageCompress.compressWithList(
                                await image.readAsBytes(),
                                format: CompressFormat.jpeg,
                                quality: 90);
                        if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024)
                          throw StateError('حجم الصورة غير صالح');
                        await FirebaseStorage.instance.ref(path).putData(
                            bytes, SettableMetadata(contentType: 'image/jpeg'));
                        await bookingCall('submitBookingOwnershipProof',
                            {'venueId': widget.venueId, 'path': path});
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'أرسلت وثيقة الملكية للمراجعة الإدارية')));
                      }),
              child: const Text('رفع صورة إثبات الملكية — خاصة بالإدارة')),
        if (!widget.ownerMode)
          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('users').get(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('تعذر تحميل حسابات الملاك');
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final users = snapshot.data!.docs
                  .where((u) => u.data()['isBlocked'] != true)
                  .toList();
              return DropdownButtonFormField<String>(
                initialValue: users.any((u) => u.id == fields['ownerId']!.text)
                    ? fields['ownerId']!.text
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'حساب المالك'),
                items: users
                    .map((u) => DropdownMenuItem(
                        value: u.id,
                        child: Text(
                            '${u.data()['name'] ?? u.data()['displayName'] ?? "حساب بلا اسم"} — ${u.data()['phone'] ?? ""}',
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: widget.venueId != null
                    ? null
                    : (v) => fields['ownerId']!.text = v ?? '',
              );
            },
          ),
        for (final e in fields.entries.where((e) =>
            e.key != 'ownerId' &&
            (e.key != 'price' || pricingMode == 'fixed') &&
            (e.key != 'hourlyPrice' || pricingMode == 'hourly')))
          TextField(
              controller: e.value,
              decoration: InputDecoration(
                  labelText: const {
                'name': 'اسم المكان',
                'ownerId': 'معرف حساب المالك للتحقق من الحساب',
                'location': 'الموقع',
                'latitude': 'خط العرض',
                'longitude': 'خط الطول',
                'commissionPercent':
                    'عمولة المنصة من العربون المحصّل فقط (٪) — الافتراضي صفر',
                'price': 'السعر الثابت لكل حجز بالدينار',
                'deposit': 'العربون بالدينار',
                'terms': 'شروط المكان',
                'hourlyPrice':
                    'سعر الساعة بالدينار (عند اختيار التسعير بالساعة)',
                'freeCancellationHours':
                    'عدد ساعات الإلغاء قبل الدخول لاسترداد كامل العربون',
                'lateRefundPercent':
                    'نسبة استرداد العربون بعد الموعد أعلاه (0–100)'
              }[e.key]),
              enabled: !(widget.ownerMode && e.key == 'commissionPercent'),
              maxLines: e.key == 'terms' ? 4 : 1),
        DropdownButtonFormField<String>(
            initialValue: pricingMode,
            decoration: const InputDecoration(labelText: 'نوع التسعير'),
            items: const [
              DropdownMenuItem(value: 'fixed', child: Text('سعر ثابت')),
              DropdownMenuItem(value: 'shifts', child: Text('شفتات')),
              DropdownMenuItem(value: 'hourly', child: Text('بالساعة'))
            ],
            onChanged: (v) => setState(() => pricingMode = v!)),
        if (pricingMode == 'shifts') ...[
          const Text(
              'أوقات الشفتات بتوقيت بغداد. الخروج قبل الدخول أو مساوياً له يعني اليوم التالي.'),
          for (final shift in shifts)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      for (final key in [
                        'name',
                        'checkInMinute',
                        'checkOutMinute',
                        'price'
                      ])
                        TextField(
                            controller: shift[key],
                            decoration: InputDecoration(
                                labelText: {
                              'name': 'اسم الشفت',
                              'checkInMinute': 'الدخول HH:mm',
                              'checkOutMinute': 'الخروج HH:mm',
                              'price': 'السعر بالدينار'
                            }[key])),
                      TextButton(
                          onPressed: () => setState(() {
                                shifts.remove(shift);
                                for (final c in shift.values) {
                                  c.dispose();
                                }
                              }),
                          child: const Text('حذف الشفت')),
                    ]))),
          TextButton(
              onPressed: shifts.length >= 12
                  ? null
                  : () => setState(() => shifts.add({
                        for (final key in [
                          'id',
                          'name',
                          'checkInMinute',
                          'checkOutMinute',
                          'price'
                        ])
                          key: TextEditingController(
                              text: key == 'id'
                                  ? 'shift_${DateTime.now().microsecondsSinceEpoch}'
                                  : '')
                      })),
              child: const Text('إضافة شفت')),
        ],
        DropdownButton<String>(
            value: category,
            items: [
              for (final e in {
                'chalet': 'شاليه',
                'farm': 'مزرعة',
                'hall': 'قاعة',
                'other': 'أخرى'
              }.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value))
            ],
            onChanged: (v) => setState(() => category = v!)),
        SwitchListTile(
            title: const Text('متاح للحجز'),
            value: active,
            onChanged:
                widget.ownerMode ? null : (v) => setState(() => active = v)),
        FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    await bookingRun(context, () async {
                      await bookingCall('saveBookingVenue', {
                        'id': widget.venueId,
                        for (final e in fields.entries)
                          e.key: [
                            'price',
                            'deposit',
                            'hourlyPrice',
                            'freeCancellationHours',
                            'lateRefundPercent'
                          ].contains(e.key)
                              ? int.tryParse(e.value.text)
                              : e.value.text,
                        'pricingMode': pricingMode,
                        'shifts': [
                          for (final shift in shifts)
                            {
                              for (final entry in shift.entries)
                                entry.key: ['checkInMinute', 'checkOutMinute']
                                        .contains(entry.key)
                                    ? bookingMinute(entry.value.text)
                                    : entry.key == 'price'
                                        ? int.tryParse(entry.value.text)
                                        : entry.value.text
                            }
                        ],
                        'cancellationPolicy': {
                          'freeCancellationHours': int.tryParse(
                              fields['freeCancellationHours']!.text),
                          'lateRefundPercent':
                              int.tryParse(fields['lateRefundPercent']!.text)
                        },
                        'category': category,
                        'active': active,
                        'commissionBps': ((double.tryParse(
                                        fields['commissionPercent']!.text) ??
                                    0) *
                                100)
                            .round(),
                        'latitude': double.tryParse(fields['latitude']!.text),
                        'longitude': double.tryParse(fields['longitude']!.text),
                      });
                      if (context.mounted) Navigator.pop(context);
                    });
                    if (mounted) setState(() => busy = false);
                  },
            child: const Text('حفظ'))
      ]));
}

class BookingSettingsScreen extends StatefulWidget {
  const BookingSettingsScreen({super.key});
  @override
  State<BookingSettingsScreen> createState() => _BookingSettingsScreenState();
}

class _BookingSettingsScreenState extends State<BookingSettingsScreen> {
  final hold = TextEditingController(text: '120');
  bool loaded = false, busy = false;
  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.doc('settings/bookings').get().then((s) async {
      final d = s.data() ?? {};
      hold.text = '${d['holdMinutes'] ?? 120}';
      if (mounted) setState(() => loaded = true);
    });
  }

  @override
  void dispose() {
    hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('إعدادات الحجوزات')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(
            controller: hold,
            decoration: const InputDecoration(
                labelText: 'مدة الحجز المؤقت بالدقائق (5–10080)')),
        ListTile(
            title: const Text('حسابات الدفع المشتركة'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PaymentAccountSettingsScreen()))),
        const Text(
            'حسابات التحويل مشتركة مع اشتراكات المكاتب. لا يُفعّل زين كاش دون حساب موثّق. الإلغاء بواسطة المالك أو الإدارة يعيد كامل العربون. التسوية اليدوية تحتاج مرجع تحويل.'),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('users').get(),
            builder: (context, snapshot) => Column(children: [
                  const Text(
                      'صلاحية مراجعة مدفوعات الحجوزات (مستقلة عن الإدارة)'),
                  for (final user in snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    SwitchListTile(
                        title: Text('${user.data()['name'] ?? user.id}'),
                        value: user.data()['canReviewBookingPayments'] == true,
                        onChanged: busy
                            ? null
                            : (enabled) => bookingRun(context, () async {
                                  await bookingCall('setBookingPaymentReviewer',
                                      {'userId': user.id, 'enabled': enabled});
                                  if (mounted) setState(() {});
                                })),
                ])),
        FilledButton(
            onPressed: !loaded || busy
                ? null
                : () async {
                    final minutes = int.tryParse(hold.text);
                    if (minutes == null || minutes < 5 || minutes > 10080) {
                      return;
                    }
                    setState(() => busy = true);
                    await bookingRun(
                        context,
                        () => FirebaseFirestore.instance
                            .doc('settings/bookings')
                            .set({'holdMinutes': minutes}));
                    if (mounted) setState(() => busy = false);
                  },
            child: const Text('حفظ'))
      ]));
}
