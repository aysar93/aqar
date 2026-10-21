import 'booking_operations.dart';
import 'booking_workspace.dart';
import 'booking_experience.dart';
import 'booking_location.dart';
import 'booking_directions_button.dart';
import 'booking_media_service.dart';
import 'booking_filters.dart';
import 'booking_extras.dart';
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
import 'booking_detail_access.dart';
import 'booking_finance_query.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

DateTime bookingBaghdadDate([DateTime? instant]) {
  final date =
      (instant ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
  return DateTime(date.year, date.month, date.day);
}

DateTime bookingBaghdadInput(DateTime date, TimeOfDay time) =>
    DateTime.utc(date.year, date.month, date.day, time.hour, time.minute)
        .subtract(const Duration(hours: 3));
DateTime bookingBaghdadMonth() {
  final date = bookingBaghdadDate();
  return DateTime(date.year, date.month);
}

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
      'arrive': 'تسجيل الوصول',
      'qrCheckIn': 'التحقق من رمز الوصول',
      'complete': 'انتهاء الزيارة',
      'settleRefund': 'تسجيل الاسترداد',
      'settleOwner': 'تسجيل تسوية المالك',
    }[action] ??
    'تحديث الحجز';
const bookingStatuses = bookingStatusNames;
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
        // Local workers can start slowly on development machines with limited RAM.
        .timeout(const Duration(seconds: 90));
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['error'] != null) {
      final error = payload['error'] as Map;
      throw FirebaseFunctionsException(
          code: '${error['status']}', message: '${error['message']}');
    }
    return Map<String, dynamic>.from(payload['result'] as Map);
  }
  final result = await FirebaseFunctions.instance
      .httpsCallable(name,
          options: HttpsCallableOptions(timeout: const Duration(minutes: 5)))
      .call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

Future<void> bookingRun(
    BuildContext context, Future<void> Function() task) async {
  try {
    await task();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is BookingReceiptIntegrityException
              ? e.message
              : e is FirebaseFunctionsException
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
  final filters = BookingFilters();
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
        query = bookingFinanceQueue(query);
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
                title: Text(widget.admin
                    ? 'إدارة الحجوزات'
                    : tab == 2
                        ? 'لوحة المالك'
                        : tab == 1
                            ? 'حجوزاتي'
                            : tab == 4
                                ? 'المراجعة المالية'
                                : 'حجوزات الأنبار'),
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
            body: ListView(children: [
              if (tab != 2)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: BookingWorkspaceHeader(
                        title: widget.admin
                            ? 'مركز إدارة الحجوزات'
                            : tab == 2
                                ? 'لوحة المالك'
                                : 'مكان يليق بيومك',
                        subtitle: widget.admin
                            ? 'راجع الأماكن والطلبات والتوثيق من مساحة واحدة.'
                            : 'شاليهات ومزارع وقاعات · اختر المكان والموعد المناسبين لك.')),
              ExpansionTile(
                  title:
                      Text(widget.admin ? 'أدوات الإدارة' : 'أدوات الحجوزات'),
                  children: [
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      if (widget.admin)
                        BookingWorkspaceAction(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BookingReviewInbox())),
                            child: const Text('مراجعة التقييمات')),
                      if (widget.admin)
                        BookingWorkspaceAction(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const BookingMediaInbox())),
                            child: const Text('مراجعة الوسائط')),
                      BookingWorkspaceAction(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => BookingTransferInbox(
                                      admin: widget.admin))),
                          child: const Text('نقل الملكية')),
                      if (widget.admin || finance)
                        BookingWorkspaceAction(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BookingLedgerScreen())),
                            child: const Text('التقرير المالي')),
                      BookingWorkspaceAction(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => BookingVenueEditor(
                                      ownerMode: true,
                                      data: {'ownerId': uid}))),
                          child: const Text('إضافة مكان للتوثيق')),
                      if (widget.admin)
                        BookingWorkspaceAction(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const BookingProofInbox())),
                            child: const Text('توثيق الملكية')),
                    ])
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BookingFilterBar(
                        filters: filters, onChanged: () => setState(() {}))),
              if (tab == 0)
                TextButton.icon(
                    icon: const Icon(Icons.event_available),
                    label: const Text('البحث عن موعد متاح'),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const BookingAvailabilitySearchScreen()))),
              TextButton.icon(
                  icon: const Icon(Icons.support_agent),
                  label: const Text('دعم الحجوزات'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              BookingSupportScreen(admin: widget.admin)))),
              ...[
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
                    stream: query.snapshots(includeMetadataChanges: true),
                    builder: (context, s) {
                      if (s.hasError ||
                          (s.hasData &&
                              (s.data!.metadata.isFromCache ||
                                  s.data!.metadata.hasPendingWrites))) {
                        return const BookingStateView(
                            title: 'يلزم اتصال للتحقق من الصلاحية',
                            detail:
                                'أعد الاتصال ليتم التحقق من الحساب وتحديث البيانات الخاصة بأمان.');
                      }
                      if (s.hasError) {
                        return const Center(child: Text('تعذر تحميل البيانات'));
                      }
                      if (!s.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (s.data!.docs.isEmpty) {
                        return const BookingStateView(
                            title: 'لا توجد بيانات بعد',
                            detail: 'ستظهر الطلبات هنا عند توفرها.',
                            icon: Icons.inbox_outlined);
                      }
                      final docs = s.data!.docs
                          .where((d) => tab != 0 || filters.matches(d.data()))
                          .toList();
                      if (tab == 0)
                        docs.sort(
                            (a, b) => filters.compare(a.data(), b.data()));
                      if (docs.isEmpty)
                        return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'لا توجد أماكن تطابق الفلاتر؛ جرّب تخفيفها'));
                      if (tab == 2)
                        return BookingOwnerPanel(
                            bookings: docs
                                .map((d) =>
                                    <String, dynamic>{...d.data(), 'id': d.id})
                                .toList(),
                            onOpen: (id) => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        BookingDetailsScreen(bookingId: id))));
                      return Column(children: [
                        ...docs.map((doc) {
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
                          if (tab == 3)
                            return BookingReportCard(
                                data: d,
                                onOpen: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => BookingDetailsScreen(
                                            bookingId: '${d['bookingId']}'))),
                                onResolve: d['status'] == 'open'
                                    ? () => bookingRun(
                                        context,
                                        () => doc.reference
                                            .update({'status': 'resolved'}))
                                    : null);
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
                                                      venueId: doc.id,
                                                      venue: d))
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
                        }).toList()
                      ]);
                    })
              ]
            ])));
  }
}

class BookingRequestScreen extends StatefulWidget {
  final String venueId;
  final Map<String, dynamic> venue;
  const BookingRequestScreen(
      {super.key,
      required this.venueId,
      required this.venue,
      this.call = bookingCall,
      this.onRequested,
      this.currentUserId});
  final BookingMediaCall call;
  final ValueChanged<String>? onRequested;

  /// For scoped data adapters; normal routes observe Firebase Auth directly.
  final String? Function()? currentUserId;
  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  DateTime? start, end;
  int step = 0;
  Map<String, dynamic>? submittedIntent;
  String? submittedUid;
  bool identityChanged = false;
  StreamSubscription<User?>? requestSession;
  String? currentUid() => widget.currentUserId == null
      ? FirebaseAuth.instance.currentUser?.uid
      : widget.currentUserId!();
  void invalidateIdentity() {
    if (!mounted) return;
    notes.clear();
    if (mounted) setState(() => identityChanged = true);
  }

  @override
  void initState() {
    super.initState();
    if (widget.currentUserId == null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      requestSession = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (mounted && user?.uid != uid) invalidateIdentity();
      });
    }
  }

  bool accepted = false, busy = false;
  String? shiftId;
  DateTime calendarMonth = bookingBaghdadMonth();
  late Future<Map<String, dynamic>> availability = loadAvailability();
  Future<Map<String, dynamic>> loadAvailability() {
    final first = DateTime.utc(calendarMonth.year, calendarMonth.month, 1, -3)
        .millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch + 1000;
    return widget.call('getBookingAvailability', {
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
    requestSession?.cancel();
    notes.dispose();
    super.dispose();
  }

  Future<DateTime?> pick() async {
    final date = await showDatePicker(
        context: context,
        firstDate: bookingBaghdadDate(),
        lastDate: bookingBaghdadDate().add(const Duration(days: 365)));
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
            DateTime.now().toUtc().add(const Duration(hours: 3))));
    return time == null ? null : bookingBaghdadInput(date, time);
  }

  @override
  Widget build(BuildContext context) {
    if (identityChanged)
      return BookingScaffold(
          appBar: AppBar(title: const Text('تغيّر الحساب')),
          body: const BookingStateView(
              title: 'تغيّر الحساب أثناء الطلب',
              detail:
                  'أُخفيت بيانات النموذج. ارجع إلى الحجوزات وأعد فتح المكان بالحساب الحالي.',
              icon: Icons.lock_outline));
    final v = widget.venue;
    final validRange = start != null &&
        end != null &&
        start!.isBefore(end!) &&
        start!.isAfter(DateTime.now());
    return BookingScaffold(
      appBar: AppBar(
          title: Text(step == 0
              ? '${v['name']}'
              : step == 1
                  ? 'اختيار الموعد'
                  : 'مراجعة الطلب'),
          leading: step == 0
              ? null
              : IconButton(
                  tooltip: 'الخطوة السابقة',
                  icon: const Icon(Icons.arrow_forward,
                      textDirection: TextDirection.ltr),
                  onPressed: busy || submittedIntent != null
                      ? null
                      : () => setState(() => step--))),
      bottomNavigationBar: Center(
          heightFactor: 1,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (step == 0)
                          Text(
                              'يبدأ من ${bookingMoney(bookingStartingPrice(v))} · العربون ${bookingMoney(v['deposit'])}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (step < 2)
                          FilledButton.icon(
                              key: const ValueKey('booking-next'),
                              icon: const Icon(Icons.arrow_back,
                                  textDirection: TextDirection.ltr),
                              onPressed: busy || (step == 1 && !validRange)
                                  ? null
                                  : () => setState(() => step++),
                              label: Text(step == 0
                                  ? 'اختيار الموعد'
                                  : 'مراجعة السعر والطلب')),
                        if (step == 2)
                          FilledButton(
                              onPressed: busy ||
                                      !accepted ||
                                      start == null ||
                                      end == null
                                  ? null
                                  : () async {
                                      if (busy) return;
                                      setState(() => busy = true);
                                      await bookingRun(context, () async {
                                        final uid = currentUid();
                                        if (uid == null)
                                          throw FirebaseFunctionsException(
                                              code: 'unauthenticated',
                                              message:
                                                  'سجل الدخول لإرسال الطلب.');
                                        if (submittedUid != null &&
                                            submittedUid != uid) {
                                          invalidateIdentity();
                                          return;
                                        }
                                        submittedUid = uid;
                                        final retrying =
                                            submittedIntent != null;
                                        final payload = submittedIntent ??=
                                            Map<String, dynamic>.unmodifiable({
                                          'venueId': widget.venueId,
                                          'requestId': requestId,
                                          'start':
                                              start!.millisecondsSinceEpoch,
                                          'end': end!.millisecondsSinceEpoch,
                                          'acceptedTerms': v['terms'],
                                          'price': total,
                                          'shiftId': shiftId,
                                          'cancellationPolicy':
                                              v['cancellationPolicy'],
                                          'deposit': v['deposit'],
                                          'notes': notes.text
                                        });
                                        Map<String, dynamic> r;
                                        try {
                                          r = await widget.call(
                                              'requestBooking', payload);
                                        } on FirebaseFunctionsException catch (e) {
                                          if (!retrying &&
                                              [
                                                'invalid-argument',
                                                'failed-precondition',
                                                'permission-denied',
                                                'unauthenticated',
                                                'not-found'
                                              ].contains(e.code))
                                            submittedIntent = null;
                                          rethrow;
                                        }
                                        if (!mounted) return;
                                        if (currentUid() != uid) {
                                          invalidateIdentity();
                                          return;
                                        }
                                        if (context.mounted &&
                                            widget.onRequested != null) {
                                          widget
                                              .onRequested!(r['id'] as String);
                                          return;
                                        }
                                        if (context.mounted) {
                                          Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      BookingDetailsScreen(
                                                          bookingId: r['id'])));
                                        }
                                      });
                                      if (mounted) setState(() => busy = false);
                                    },
                              child: Text(busy
                                  ? 'جار إرسال الطلب…'
                                  : submittedIntent != null
                                      ? 'إعادة المحاولة بنفس الطلب'
                                      : 'إرسال طلب الحجز')),
                        if (step == 2 && submittedIntent != null)
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => Navigator.maybePop(context),
                              child: const Text('العودة للتحقق من حجوزاتي')),
                      ])))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                  key: ValueKey('booking-step-$step'),
                  padding: const EdgeInsets.all(20),
                  children: [
                    BookingCheckoutHeader(step: step),
                    if (step == 0) ...[
                      BookingMediaGallery(
                          paths: List<String>.from(v['mediaPaths'] ?? [])),
                      const SizedBox(height: 20),
                      BookingVenueIdentity(venue: v),
                      if ((v['description'] ?? '').toString().trim().isNotEmpty)
                        BookingSection(
                            title: 'عن المكان',
                            child: Text('${v['description']}',
                                style: const TextStyle(height: 1.9))),
                      BookingSection(
                          title: 'الموقع والاستضافة',
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('${v['location']}',
                                    style: const TextStyle(height: 1.8)),
                                Text('المالك: ${v['ownerName']}',
                                    style: const TextStyle(height: 1.8)),
                                BookingDirectionsButton(venue: v),
                              ])),
                      BookingSection(
                          title: 'تجارب الضيوف',
                          child: BookingPublishedReviews(
                              venueId: widget.venueId,
                              load: () => widget.call(
                                  'getPublishedBookingReviews',
                                  {'venueId': widget.venueId}))),
                    ],
                    if (step == 1) ...[
                      BookingSection(
                          title: 'رتّب يومك',
                          subtitle:
                              'اختر الفترة ثم اليوم. التوافر النهائي يتحقق منه الخادم عند إرسال الطلب.',
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (v['pricingMode'] == 'hourly')
                                  Text(
                                      'سعر الساعة: ${v['hourlyPrice']} د.ع — اختر ساعات كاملة'),
                                if (v['pricingMode'] == 'shifts') ...[
                                  DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue: shiftId,
                                      decoration: const InputDecoration(
                                          labelText: 'الشفت (توقيت بغداد)'),
                                      items: [
                                        for (final shift in v['shifts'] as List)
                                          DropdownMenuItem(
                                              value: shift['id'] as String,
                                              child: Text(
                                                  '${shift['name']} — ${bookingTime(shift['checkInMinute'])} إلى ${bookingTime(shift['checkOutMinute'])} — ${shift['price']} د.ع',
                                                  overflow:
                                                      TextOverflow.ellipsis))
                                      ],
                                      onChanged: busy
                                          ? null
                                          : (value) => setState(() {
                                                shiftId = value;
                                                start = null;
                                                end = null;
                                                accepted = false;
                                              })),
                                  TextButton(
                                      onPressed: busy || shiftId == null
                                          ? null
                                          : () async {
                                              final date = await showDatePicker(
                                                  context: context,
                                                  firstDate:
                                                      bookingBaghdadDate(),
                                                  lastDate: bookingBaghdadDate()
                                                      .add(const Duration(
                                                          days: 365)));
                                              if (mounted && date != null) {
                                                setState(() {
                                                  setShiftDate(date);
                                                  accepted = false;
                                                });
                                              }
                                            },
                                      child:
                                          const Text('اختر تاريخ دخول الشفت')),
                                  if (start != null)
                                    Text(
                                        'الدخول: ${bookingVisitTime(start?.add(const Duration(hours: 3)))}\nالخروج: ${bookingVisitTime(end?.add(const Duration(hours: 3)))} — توقيت بغداد'),
                                ] else ...[
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () async {
                                              final d = await pick();
                                              if (mounted && d != null) {
                                                setState(() {
                                                  start = d;
                                                  accepted = false;
                                                });
                                              }
                                            },
                                      child: Text(
                                          'البداية: ${bookingVisitTime(start?.add(const Duration(hours: 3)))}')),
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () async {
                                              final d = await pick();
                                              if (mounted && d != null) {
                                                setState(() {
                                                  end = d;
                                                  accepted = false;
                                                });
                                              }
                                            },
                                      child: Text(
                                          'النهاية: ${bookingVisitTime(end?.add(const Duration(hours: 3)))}')),
                                ],
                              ])),
                      BookingSection(
                          key: const ValueKey('booking-calendar-section'),
                          title: 'تقويم التوافر',
                          subtitle: 'توقيت بغداد · اختر يومًا متاحًا',
                          child: Column(children: [
                            if (v['pricingMode'] == 'shifts' && shiftId != null)
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                        tooltip: 'الشهر السابق',
                                        onPressed: calendarMonth
                                                .isAfter(bookingBaghdadMonth())
                                            ? () => setState(() {
                                                  calendarMonth = DateTime(
                                                      calendarMonth.year,
                                                      calendarMonth.month - 1);
                                                  availability =
                                                      loadAvailability();
                                                })
                                            : null,
                                        icon: const Icon(Icons.chevron_right)),
                                    const Text('تقويم التوافر'),
                                    IconButton(
                                        tooltip: 'الشهر التالي',
                                        onPressed: () => setState(() {
                                              calendarMonth = DateTime(
                                                  calendarMonth.year,
                                                  calendarMonth.month + 1);
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
                                          onPressed: () => setState(() =>
                                              availability =
                                                  loadAvailability()),
                                          child: const Text(
                                              'تعذر تحميل التوافر — إعادة المحاولة'));
                                    if (!snapshot.hasData)
                                      return const LinearProgressIndicator();
                                    return BookingCalendar(
                                        selectedDay: start
                                            ?.add(const Duration(hours: 3)),
                                        month: calendarMonth,
                                        slots: (snapshot.data!['slots'] as List)
                                            .map((e) =>
                                                Map<String, dynamic>.from(e))
                                            .toList(),
                                        intervalForDay: (day) =>
                                            bookingShiftDates(
                                                day,
                                                Map<String, dynamic>.from(
                                                    (v['shifts'] as List)
                                                        .firstWhere((s) =>
                                                            s['id'] ==
                                                            shiftId))),
                                        onSelect: (day) => setState(() {
                                              setShiftDate(day);
                                              accepted = false;
                                            }));
                                  }),
                            if (v['pricingMode'] != 'shifts')
                              const Text(
                                  'حدد البداية والنهاية من منتقي التاريخ والوقت أعلاه.'),
                            if (v['pricingMode'] == 'shifts' && shiftId == null)
                              const Text('اختر الفترة أولًا ليظهر التقويم.'),
                          ])),
                    ],
                    if (step == 2) ...[
                      if (submittedIntent != null)
                        const BookingStateView(
                            title: 'إعادة التحقق من الطلب',
                            detail:
                                'عند انقطاع الرد، تعاد المحاولة بنفس البيانات ومعرّف الطلب لمنع إنشاء طلب آخر.'),
                      BookingVenueOverview(venue: v, total: total),
                      BookingSection(
                          title: 'موعد الزيارة',
                          child: Text(
                              'الدخول: ${bookingVisitTime(start?.add(const Duration(hours: 3)))}\nالخروج: ${bookingVisitTime(end?.add(const Duration(hours: 3)))} — توقيت بغداد',
                              style: const TextStyle(height: 1.8))),
                      BookingSection(
                          title: 'الشروط والتأكيد',
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(bookingCancellationText(
                                    v['cancellationPolicy'])),
                                TextField(
                                    controller: notes,
                                    enabled: !busy && submittedIntent == null,
                                    decoration: const InputDecoration(
                                        labelText: 'ملاحظات')),
                                CheckboxListTile(
                                    value: accepted,
                                    onChanged: busy || submittedIntent != null
                                        ? null
                                        : (v) => setState(
                                            () => accepted = v ?? false),
                                    title: const Text(
                                        'أوافق على السعر والشروط وسياسة الإلغاء')),
                              ])),
                    ],
                  ]))),
    );
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? roleListener;
  StreamSubscription<User?>? sessionListener;
  String? privilegedUid;
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

    sessionListener = FirebaseAuth.instance.authStateChanges().listen((user) {
      roleListener?.cancel();
      if (!mounted) return;
      setState(() {
        admin = false;
        finance = false;
        privilegedUid = null;
      });
      final uid = user?.uid;
      if (uid == null) return;
      roleListener = FirebaseFirestore.instance
          .doc('users/$uid')
          .snapshots(includeMetadataChanges: true)
          .listen((s) {
        if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
        final verified = !s.metadata.isFromCache &&
            !s.metadata.hasPendingWrites &&
            s.data() != null &&
            s.data()?['isBlocked'] != true;
        setState(() {
          privilegedUid = verified ? uid : null;
          admin = verified && s.data()?['isAdmin'] == true;
          finance = verified && s.data()?['canReviewBookingPayments'] == true;
        });
      }, onError: (_) {
        if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
        setState(() {
          admin = false;
          finance = false;
          privilegedUid = null;
        });
      });
    });
  }

  @override
  void dispose() {
    accountListener?.cancel();
    roleListener?.cancel();
    sessionListener?.cancel();
    refundReference.dispose();
    transaction.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> act(String action,
      [Map<String, dynamic> extra = const {}]) async {
    if (busy) return;
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
              .snapshots(includeMetadataChanges: true),
          builder: (context, s) {
            if (s.hasError ||
                (s.hasData &&
                    (s.data!.metadata.isFromCache ||
                        s.data!.metadata.hasPendingWrites))) {
              return const BookingStateView(
                  title: 'يلزم اتصال للتحقق من الصلاحية',
                  detail:
                      'أعد الاتصال ليتم التحقق من الحساب وتحديث البيانات الخاصة بأمان.');
            }
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
            if (!bookingCanDisplayDetails(
                uid: uid,
                booking: b,
                admin: admin,
                finance: finance,
                privilegedUid: privilegedUid)) {
              return const Center(child: Text('لا تملك صلاحية عرض هذا الحجز'));
            }
            final holdDeadline = bookingHoldDeadline(b['holdUntil']);
            final held = b['status'] == 'held' &&
                holdDeadline != null &&
                holdDeadline.isAfter(DateTime.now());
            Widget button(String label, String action) => FilledButton(
                onPressed: busy ? null : () => act(action), child: Text(label));
            return Column(children: [
              if (b['status'] == 'held' && holdDeadline == null)
                const BookingStateView(
                    title: 'تعذر التحقق من مهلة العربون',
                    detail: 'حدّث الحجز أو تواصل مع الدعم قبل إرسال أي دفعة.',
                    icon: Icons.info_outline),
              if (b['status'] == 'held' && holdDeadline != null)
                BookingHoldNotice(
                    compact: true,
                    until: holdDeadline,
                    onExpired: () {
                      if (mounted) setState(() {});
                    }),
              Expanded(
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                Semantics(
                    liveRegion: true,
                    child: Text(bookingStatuses[b['status']] ?? b['status'],
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700))),
                BookingSummary(
                    booking: b,
                    status: bookingStatuses[b['status']] ?? b['status']),
                ExpansionTile(
                    title: const Text('مراحل الحجز'),
                    children: [BookingProgress(status: b['status'])]),
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
                        .snapshots(includeMetadataChanges: true),
                    builder: (context, events) {
                      if (events.hasError ||
                          (events.hasData &&
                              (events.data!.metadata.isFromCache ||
                                  events.data!.metadata.hasPendingWrites))) {
                        return const Center(
                            child: Text(
                                'يلزم اتصال للتحقق من صلاحية عرض البيانات'));
                      }
                      if (!events.hasData) return const SizedBox.shrink();
                      final docs = events.data!.docs.toList()
                        ..sort((a, b) => ((a.data()['version'] as num?) ?? 0)
                            .compareTo((b.data()['version'] as num?) ?? 0));
                      return Column(children: [
                        for (final event in docs)
                          ListTile(
                              dense: true,
                              title: Text(
                                  bookingActionLabel(event.data()['action'])),
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
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                TextButton.icon(
                    icon: const Icon(Icons.support_agent),
                    label: const Text('طلب دعم لهذا الحجز'),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BookingSupportScreen(
                                bookingId: widget.bookingId)))),
                if (owner && ['confirmed', 'arrived'].contains(b['status']))
                  TextButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('مسح رمز الوصول بالكاميرا'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => BookingScannerScreen(
                                  bookingId: widget.bookingId)))),
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
                                          child: Image.memory(bytes,
                                              errorBuilder: (_, __, ___) =>
                                                  const Padding(
                                                      padding:
                                                          EdgeInsets.all(24),
                                                      child: Text(
                                                          'تعذر عرض الإيصال؛ الملف غير صالح'))))));
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
                if (customer && held)
                  BookingPaymentPanel(
                      deposit: b['deposit'],
                      accounts: accounts,
                      method: method,
                      transaction: transaction,
                      busy: busy,
                      onMethod: (value) => setState(() {
                            method = value;
                            displayedNumber = accounts[method]['number'];
                          }),
                      onSubmit: busy || displayedNumber == null
                          ? null
                          : () async {
                              if (busy) return;
                              final expectedNumber = displayedNumber;
                              final selectedMethod = method;
                              setState(() => busy = true);
                              await bookingRun(context, () async {
                                final image = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 1600,
                                    imageQuality: 85);
                                if (image == null) return;
                                final bytes =
                                    await FlutterImageCompress.compressWithList(
                                        await image.readAsBytes(),
                                        format: CompressFormat.jpeg,
                                        quality: 85);
                                final path =
                                    'booking_receipts/${widget.bookingId}/$uid/${BookingMediaService.receiptFileName(bytes)}';
                                final receipt =
                                    FirebaseStorage.instance.ref(path);
                                await BookingMediaService.uploadVerifiedReceipt(
                                    bytes,
                                    reuseExisting: true, upload: (data) async {
                                  await receipt.putData(
                                      data,
                                      SettableMetadata(
                                          contentType: 'image/jpeg'));
                                }, read: () async {
                                  try {
                                    return await receipt
                                        .getData(10 * 1024 * 1024);
                                  } on FirebaseException catch (e) {
                                    if (e.code == 'object-not-found')
                                      return null;
                                    rethrow;
                                  }
                                }, discardInvalid: () async {
                                  await bookingCall(
                                      'discardInvalidBookingReceipt', {
                                    'bookingId': widget.bookingId,
                                    'path': path,
                                  });
                                });

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
                            }),
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
              ]))
            ]);
          }));
}

class BookingVenueEditor extends StatefulWidget {
  final BookingMediaCall call;
  final VoidCallback? onSaved;
  final bool ownerMode;
  final String? venueId;
  final Map<String, dynamic> data;
  const BookingVenueEditor(
      {super.key,
      this.venueId,
      this.data = const {},
      this.ownerMode = false,
      this.call = bookingCall,
      this.onSaved});
  @override
  State<BookingVenueEditor> createState() => _BookingVenueEditorState();
}

class _BookingVenueEditorState extends State<BookingVenueEditor> {
  late final fields = {
    for (final k in [
      'name',
      'ownerId',
      'location',
      'capacity',
      'bedrooms',
      'complexName',
      'unitName',
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
  late final amenities = Set<String>.from(widget.data['amenities'] ?? []);
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

  Future<void> editorTask(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await bookingRun(context, task);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget editorField(String key) {
    final e = MapEntry(key, fields[key]!);
    return TextField(
        controller: e.value,
        decoration: InputDecoration(
            labelText: const {
          'capacity': 'السعة القصوى للضيوف (0 = غير محددة)',
          'bedrooms': 'عدد الغرف',
          'complexName': 'اسم المنتجع أو المجمع (اختياري)',
          'unitName': 'اسم الوحدة المستقلة (اختياري)',
          'name': 'اسم المكان',
          'ownerId': 'معرف حساب المالك للتحقق من الحساب',
          'location': 'الموقع',
          'latitude': 'خط العرض',
          'longitude': 'خط الطول',
          'commissionPercent': 'عمولة المنصة من العربون (٪)',
          'price': 'السعر الثابت لكل حجز بالدينار',
          'deposit': 'العربون بالدينار',
          'terms': 'شروط المكان',
          'hourlyPrice': 'سعر الساعة بالدينار (عند اختيار التسعير بالساعة)',
          'freeCancellationHours': 'الإلغاء المجاني قبل الدخول (ساعة)',
          'lateRefundPercent': 'استرداد العربون بعد المهلة (٪)'
        }[e.key]),
        keyboardType: ['latitude', 'longitude'].contains(e.key)
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : null,
        textDirection: ['latitude', 'longitude'].contains(e.key)
            ? TextDirection.ltr
            : null,
        enabled: !busy,
        readOnly: widget.ownerMode && e.key == 'commissionPercent',
        maxLines: e.key == 'terms' ? 4 : 1);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 5,
      child: BookingScaffold(
          appBar: AppBar(
              title: const Text('إدارة المكان'),
              bottom: const TabBar(
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: bookingGold,
                  tabs: [
                    Tab(text: 'البيانات'),
                    Tab(text: 'الموقع والمرافق'),
                    Tab(text: 'الأسعار والفترات'),
                    Tab(text: 'الوسائط'),
                    Tab(text: 'المراجعة والحفظ')
                  ])),
          body: TabBarView(children: [
            BookingEditorPage(
                title: 'هوية المكان',
                detail: 'عرّف ضيوفك بالمكان والوحدة والقدرة الاستيعابية.',
                icon: Icons.home_work_outlined,
                children: [
                  if (!widget.ownerMode)
                    FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      future:
                          FirebaseFirestore.instance.collection('users').get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('تعذر تحميل حسابات الملاك');
                        }
                        if (!snapshot.hasData)
                          return const LinearProgressIndicator();
                        final users = snapshot.data!.docs
                            .where((u) => u.data()['isBlocked'] != true)
                            .toList();
                        return DropdownButtonFormField<String>(
                          initialValue:
                              users.any((u) => u.id == fields['ownerId']!.text)
                                  ? fields['ownerId']!.text
                                  : null,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'حساب المالك'),
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
                  editorField('name'),
                  editorField('complexName'),
                  editorField('unitName'),
                  editorField('capacity'),
                  editorField('bedrooms'),
                ]),
            BookingEditorPage(
                title: 'الموقع والمرافق',
                detail: 'ساعد الضيوف على الوصول واختيار المرافق المناسبة.',
                icon: Icons.location_on_outlined,
                children: [
                  editorField('location'),
                  editorField('latitude'),
                  editorField('longitude'),
                  const Text(
                      'إحداثيات المكان اختيارية؛ أدخل القيمتين معًا ليظهر على الخريطة. هذه إحداثيات المكان العامة.'),
                  Wrap(children: [
                    for (final e in bookingAmenities.entries)
                      FilterChip(
                          label: Text(e.value),
                          selected: amenities.contains(e.key),
                          onSelected: (yes) => setState(() {
                                if (yes) {
                                  amenities.add(e.key);
                                } else {
                                  amenities.remove(e.key);
                                }
                              }))
                  ]),
                ]),
            BookingEditorPage(
                title: 'أسعار واضحة لكل زيارة',
                detail: 'حدد نظام التسعير والعربون وسياسة الاسترداد قبل الحفظ.',
                icon: Icons.payments_outlined,
                children: [
                  editorField('deposit'),
                  editorField('commissionPercent'),
                  DropdownButtonFormField<String>(
                      initialValue: pricingMode,
                      decoration:
                          const InputDecoration(labelText: 'نوع التسعير'),
                      items: const [
                        DropdownMenuItem(
                            value: 'fixed', child: Text('سعر ثابت')),
                        DropdownMenuItem(
                            value: 'shifts', child: Text('فترات يومية')),
                        DropdownMenuItem(
                            value: 'hourly', child: Text('بالساعة'))
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() => pricingMode = v!)),
                  if (pricingMode == 'fixed') editorField('price'),
                  if (pricingMode == 'hourly') editorField('hourlyPrice'),
                  if (pricingMode == 'shifts') ...[
                    const Text(
                        'أوقات الفترات بتوقيت بغداد. الخروج قبل الدخول أو مساوياً له يعني اليوم التالي.'),
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
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: TextField(
                                          enabled: !busy,
                                          controller: shift[key],
                                          decoration: InputDecoration(
                                              labelText: {
                                            'name': 'اسم الفترة',
                                            'checkInMinute': 'الدخول HH:mm',
                                            'checkOutMinute': 'الخروج HH:mm',
                                            'price': 'السعر بالدينار'
                                          }[key]))),
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => setState(() {
                                              shifts.remove(shift);
                                              for (final c in shift.values) {
                                                c.dispose();
                                              }
                                            }),
                                    child: const Text('حذف الفترة')),
                              ]))),
                    TextButton(
                        onPressed: busy || shifts.length >= 12
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
                        child: const Text('إضافة فترة')),
                  ],
                  editorField('freeCancellationHours'),
                  editorField('lateRefundPercent'),
                ]),
            BookingEditorPage(
                title: 'معرض المكان',
                detail: 'إدارة الوسائط وإثبات الملكية من المسار المعتمد.',
                icon: Icons.perm_media_outlined,
                children: [
                  BookingMediaPanel(children: [
                    if (widget.venueId != null)
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .doc('booking_venues/${widget.venueId}')
                              .snapshots(includeMetadataChanges: true),
                          builder: (context, s) => Column(children: [
                                for (final path in List<String>.from(
                                    s.data?.data()?['mediaPaths'] ?? []))
                                  ListTile(
                                      title: Text(path.endsWith('.mp4')
                                          ? 'فيديو منشور'
                                          : 'صورة منشورة'),
                                      trailing: IconButton(
                                          tooltip: 'إزالة الوسيط المنشور',
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          onPressed: () => editorTask(() async {
                                                await bookingCall(
                                                    (path.startsWith(
                                                                'https://') ||
                                                            path.startsWith(
                                                                'booking_media_v3/'))
                                                        ? 'removeBookingExternalMedia'
                                                        : 'removeBookingMedia',
                                                    {
                                                      'venueId': widget.venueId,
                                                      'path': path
                                                    });
                                              })))
                              ])),
                    if (widget.ownerMode && widget.venueId != null)
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('booking_media_reviews')
                              .where('venueId', isEqualTo: widget.venueId)
                              .where('ownerId',
                                  isEqualTo:
                                      FirebaseAuth.instance.currentUser!.uid)
                              .snapshots(includeMetadataChanges: true),
                          builder: (context, snapshot) {
                            if (snapshot.hasError ||
                                (snapshot.hasData &&
                                    (snapshot.data!.metadata.isFromCache ||
                                        snapshot.data!.metadata
                                            .hasPendingWrites))) {
                              return const BookingStateView(
                                  title: 'يلزم اتصال للتحقق من الصلاحية',
                                  detail:
                                      'تحديث حالة الوسائط الخاصة يحتاج اتصالًا وحسابًا مصرحًا.');
                            }
                            if (!snapshot.hasData)
                              return const LinearProgressIndicator();
                            return Column(children: [
                              if (snapshot.hasError)
                                const Text('تعذر تحميل حالة الوسائط'),
                              for (final doc in snapshot.data?.docs ??
                                  <QueryDocumentSnapshot<
                                      Map<String, dynamic>>>[])
                                if ([
                                      2,
                                      3
                                    ].contains(doc.data()['schemaVersion']) &&
                                    ['uploading', 'pending', 'delete_pending']
                                        .contains(doc.data()['status']))
                                  Card(
                                      child: Column(children: [
                                    ListTile(
                                        title: Text(const {
                                              'uploading': 'لم يكتمل الرفع',
                                              'pending':
                                                  'بانتظار مراجعة الإدارة',
                                              'delete_pending': 'قيد الحذف'
                                            }[doc.data()['status']] ??
                                            ''),
                                        trailing: doc.data()['status'] ==
                                                'delete_pending'
                                            ? null
                                            : IconButton(
                                                tooltip: 'إزالة الملف',
                                                icon: const Icon(
                                                    Icons.delete_outline),
                                                onPressed: busy
                                                    ? null
                                                    : () =>
                                                        editorTask(() async {
                                                          await bookingCall(
                                                              'removeBookingExternalMedia',
                                                              {
                                                                'venueId': widget
                                                                    .venueId,
                                                                'path':
                                                                    doc.data()[
                                                                        'path']
                                                              });
                                                        }))),
                                    if (doc.data()['status'] == 'pending')
                                      BookingMediaGallery(paths: [
                                        doc.data()['path'] as String
                                      ]),
                                  ])),
                            ]);
                          }),
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
                                  : () => editorTask(() async {
                                        final file = video
                                            ? await ImagePicker().pickVideo(
                                                source: ImageSource.gallery)
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
                                            : await FlutterImageCompress
                                                .compressWithList(
                                                    await file.readAsBytes(),
                                                    format: CompressFormat.jpeg,
                                                    quality: 90);
                                        if (video) {
                                          await BookingMediaService.uploadVideo(
                                              bytes,
                                              widget.venueId!,
                                              bookingCall);
                                        } else {
                                          await BookingMediaService.uploadImage(
                                              bytes, bookingCall,
                                              venueId: widget.venueId!);
                                        }
                                        if (context.mounted)
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'الملف بانتظار مراجعة الإدارة')));
                                      }))
                      ]),
                    if (widget.ownerMode &&
                        widget.venueId != null &&
                        ['pending', 'rejected']
                            .contains(widget.data['verificationStatus']))
                      FilledButton(
                          onPressed: busy
                              ? null
                              : () => editorTask(() async {
                                    final image = await ImagePicker().pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 2000,
                                        imageQuality: 90);
                                    if (image == null) return;
                                    final uid = FirebaseAuth
                                            .instance.currentUser!.uid,
                                        path =
                                            'booking_ownership_documents/${widget.venueId}/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
                                    final bytes = await FlutterImageCompress
                                        .compressWithList(
                                            await image.readAsBytes(),
                                            format: CompressFormat.jpeg,
                                            quality: 90);
                                    if (bytes.isEmpty ||
                                        bytes.length > 10 * 1024 * 1024)
                                      throw StateError('حجم الصورة غير صالح');
                                    await FirebaseStorage.instance
                                        .ref(path)
                                        .putData(
                                            bytes,
                                            SettableMetadata(
                                                contentType: 'image/jpeg'));
                                    await bookingCall(
                                        'submitBookingOwnershipProof', {
                                      'venueId': widget.venueId,
                                      'path': path
                                    });
                                    if (context.mounted)
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'أرسلت وثيقة الملكية للمراجعة الإدارية')));
                                  }),
                          child: const Text(
                              'رفع صورة إثبات الملكية — خاصة بالإدارة')),
                    if (widget.venueId == null)
                      const Text(
                          'احفظ المكان أولًا لتتمكن من رفع الصور والفيديو وإثبات الملكية.'),
                  ]),
                ]),
            BookingEditorPage(
                title: 'راجع ثم احفظ',
                detail:
                    'تحقق من الشروط والإتاحة. تغيير المالك يمر بإجراء نقل الملكية.',
                icon: Icons.task_alt,
                children: [
                  editorField('terms'),
                  if (widget.ownerMode && widget.venueId != null)
                    TextButton.icon(
                        icon: const Icon(Icons.add_home_outlined),
                        label: const Text('إضافة وحدة مستقلة في هذا المجمع'),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => BookingVenueEditor(
                                        ownerMode: true,
                                        data: {
                                          ...widget.data,
                                          'name': '',
                                          'unitName': '',
                                          'active': false
                                        })))),
                  if (widget.venueId != null)
                    TextButton.icon(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => BookingOwnerTools(
                                    venueId: widget.venueId!))),
                        icon: const Icon(Icons.calendar_month),
                        label: const Text(
                            'التقويم والحجوزات الخارجية ونقل الملكية')),
                  SwitchListTile(
                      title: const Text('متاح للحجز'),
                      value: active,
                      onChanged: widget.ownerMode
                          ? null
                          : (v) => setState(() => active = v)),
                  FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (busy) return;
                              setState(() => busy = true);
                              await bookingRun(context, () async {
                                final coordinateError = bookingCoordinateError(
                                    fields['latitude']!.text,
                                    fields['longitude']!.text);
                                if (coordinateError != null)
                                  throw StateError(coordinateError);
                                for (final key in ['capacity', 'bedrooms']) {
                                  if (fields[key]!.text.isNotEmpty &&
                                      (int.tryParse(fields[key]!.text) ==
                                              null ||
                                          int.parse(fields[key]!.text) < 0))
                                    throw StateError('سعة أو عدد غرف غير صالح');
                                }
                                await widget.call('saveBookingVenue', {
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
                                  'capacity':
                                      int.tryParse(fields['capacity']!.text) ??
                                          0,
                                  'bedrooms':
                                      int.tryParse(fields['bedrooms']!.text) ??
                                          0,
                                  'amenities': amenities.toList(),
                                  'pricingMode': pricingMode,
                                  'shifts': [
                                    for (final shift in shifts)
                                      {
                                        for (final entry in shift.entries)
                                          entry.key: [
                                            'checkInMinute',
                                            'checkOutMinute'
                                          ].contains(entry.key)
                                              ? bookingMinute(entry.value.text)
                                              : entry.key == 'price'
                                                  ? int.tryParse(
                                                      entry.value.text)
                                                  : entry.value.text
                                      }
                                  ],
                                  'cancellationPolicy': {
                                    'freeCancellationHours': int.tryParse(
                                        fields['freeCancellationHours']!.text),
                                    'lateRefundPercent': int.tryParse(
                                        fields['lateRefundPercent']!.text)
                                  },
                                  'category': category,
                                  'active': active,
                                  'commissionBps': ((double.tryParse(
                                                  fields['commissionPercent']!
                                                      .text) ??
                                              0) *
                                          100)
                                      .round(),
                                  'latitude':
                                      double.tryParse(fields['latitude']!.text),
                                  'longitude': double.tryParse(
                                      fields['longitude']!.text),
                                });
                                if (context.mounted) {
                                  if (widget.onSaved != null) {
                                    widget.onSaved!();
                                  } else {
                                    Navigator.pop(context);
                                  }
                                }
                              });
                              if (mounted) setState(() => busy = false);
                            },
                      child: const Text('حفظ بيانات المكان'))
                ]),
          ])));
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
