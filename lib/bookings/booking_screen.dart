import 'booking_access_guard.dart';
import 'booking_form_validator.dart';
import '../features/property_map/models/property_location.dart';
import '../features/property_map/screens/location_picker_screen.dart';
import '../screens/notifications_screen.dart';
import 'booking_reference_checkout.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'booking_venue_details.dart';
import 'booking_pricing_draft.dart';
import '../banners/banner_model.dart';
import 'booking_browse_ui.dart';
import 'booking_media_local_hooks.dart';
import 'booking_request_intent_store.dart';
import 'booking_admin_tasks.dart';
import 'dart:typed_data';
import 'booking_decision_ui.dart';
import 'booking_services_ui.dart';
import 'booking_operations.dart';
import 'booking_workspace.dart';
import 'booking_experience.dart';
import 'booking_location.dart';
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
import 'booking_bottom_bar.dart';
import 'booking_receipt_service.dart';
import 'booking_search_screen.dart';
import 'booking_reels_screen.dart';
import 'booking_account_screen.dart';

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
  final minute = (shift['checkInMinute'] ?? shift['startMinute']) as int;
  final outMinute = (shift['checkOutMinute'] ?? shift['endMinute']) as int;
  final duration = shift['endDayOffset'] is int
      ? outMinute + (shift['endDayOffset'] as int) * 1440 - minute
      : (outMinute - minute + 1440) % 1440;
  final start = DateTime.utc(date.year, date.month, date.day)
      .add(Duration(minutes: minute - 180));
  return [start, start.add(Duration(minutes: duration <= 0 ? 1440 : duration))];
}

String bookingTime(dynamic minute) {
  if (minute == null) return '00:00';
  if (minute is String) {
    if (minute.contains(':')) return minute;
    final parsed = int.tryParse(minute);
    if (parsed != null) minute = parsed;
    else return '00:00';
  }
  final m = (minute is num) ? minute.toInt() : 0;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

String bookingTime12(dynamic minute) {
  if (minute == null) return '08:00 صباحاً';
  int m = 0;
  if (minute is num) {
    m = minute.toInt();
  } else if (minute is String) {
    final parsed = bookingMinute(minute);
    if (parsed != null) {
      m = parsed;
    } else {
      return minute;
    }
  }
  final h = (m ~/ 60) % 24;
  final mins = m % 60;
  final bool isPm = h >= 12;
  int h12 = h % 12;
  if (h12 == 0) h12 = 12;
  final suffix = isPm ? 'مساءً' : 'صباحاً';
  return '${h12.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')} $suffix';
}

int? bookingMinute(String value) {
  final clean = value.trim();
  final isPm = clean.contains('مساء') || clean.contains('م');
  final isAm = clean.contains('صباح') || clean.contains('ص');
  final numericPart = clean.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = numericPart.split(':');
  if (parts.length != 2) return null;
  var h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || m < 0 || m >= 60) return null;
  if (isPm && h < 12) h += 12;
  if (isAm && h == 12) h = 0;
  return (h >= 0 && h < 24) ? h * 60 + m : null;
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
    if (kDebugMode) {
      debugPrint('bookingRun error: $e');
    }
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
  final List<Map<String, dynamic>> diagnosticFeatured;
  const BookingScreen(
      {super.key,
      this.admin = false,
      this.records,
      this.diagnosticFeatured = const [],
      this.currentUserId,
      this.initialTab = 0,
      this.banners,
      this.bannerImageBuilder,
      this.venuePage,
      this.bookingPage,
      this.tools,
      this.appBarActions,
      this.adminTaskRecords,
      this.onAdminTask,
      this.loadVenue});
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(int)? records;
  final String? Function()? currentUserId;
  final int initialTab;
  final Stream<List<BannerModel>>? banners;
  final Widget Function(BannerModel)? bannerImageBuilder;
  final Widget Function(String, Map<String, dynamic>)? venuePage;
  final Widget Function(String)? bookingPage;
  final Widget? tools;
  final List<Widget>? appBarActions;
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>>?
      adminTaskRecords;
  final ValueChanged<String>? onAdminTask;
  final Future<Map<String, dynamic>?> Function(String)? loadVenue;
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late int tab = widget.initialTab;
  late int _bottomBarIndex;
  final filters = BookingFilters();
  bool finance = false;
  String statusGroup = 'الكل';
  int publicLimit = 12;
  static const statusGroups = <String, List<String>>{
    'الكل': [],
    'انتظار': [
      'requested',
      'held',
      'payment_review',
      'payment_rejected',
      'cancel_requested'
    ],
    'مؤكد': ['confirmed', 'arrived'],
    'مكتمل': ['completed'],
    'ملغي': ['cancelled', 'expired', 'rejected']
  };
  late final bookingBanners =
      BannerService.activeBanners(placement: BannerPlacement.bookings);
  @override
  void initState() {
    super.initState();
    if (widget.initialTab == 1) {
      _bottomBarIndex = 3;
    } else if (widget.initialTab == 2 || widget.initialTab == 5) {
      _bottomBarIndex = 4;
    } else {
      _bottomBarIndex = 0;
    }
    if (widget.records != null) return;
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

  List<Widget> workspaceTools(String uid) => widget.tools != null
      ? [widget.tools!]
      : [
          ExpansionTile(
              key: const PageStorageKey('booking-tools-1'),
              title: Text(widget.admin ? 'أدوات الإدارة' : 'أدوات الحجوزات'),
              children: [
                Wrap(spacing: 12, runSpacing: 12, children: [
                  if (widget.admin)
                    BookingWorkspaceAction(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BookingReviewInbox())),
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
                              builder: (_) =>
                                  BookingTransferInbox(admin: widget.admin))),
                      child: const Text('نقل الملكية')),
                  if (widget.admin || finance)
                    BookingWorkspaceAction(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BookingLedgerScreen())),
                        child: const Text('التقرير المالي')),
                  BookingWorkspaceAction(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => BookingVenueEditor(
                                  ownerMode: true, data: {'ownerId': uid}))),
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
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BookingMapScreen())),
              icon: const Icon(Icons.map_outlined),
              label: const Text('خريطة الحجوزات')),
          Wrap(spacing: 8, children: [
            for (final entry in {
              0: 'الأماكن',
              1: widget.admin ? 'جميع الحجوزات' : 'حجوزاتي',
              if (!widget.admin) 2: 'لوحة المالك',
              if (!widget.admin && tab != 0) 5: 'أماكني وأسعاري',
              if (!widget.admin && tab != 0) 6: 'مهام الموظف',
              if (widget.admin) 3: 'البلاغات',
              if (finance) 4: 'المراجعة المالية'
            }.entries)
              ChoiceChip(
                  label: Text(entry.value),
                  selected: tab == entry.key,
                  onSelected: (_) => setState(() => tab = entry.key))
          ]),
          if (!widget.admin && tab == 0)
            ExpansionTile(
                key: const PageStorageKey('booking-tools-2'),
                title: const Text('إدارة أماكني وفريقي'),
                children: [
                  Wrap(spacing: 8, children: [
                    for (final item in const {
                      5: 'أماكني وأسعاري',
                      6: 'مهام الموظف'
                    }.entries)
                      TextButton(
                          onPressed: () => setState(() => tab = item.key),
                          child: Text(item.value))
                  ])
                ]),
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
        ];
  @override
  Widget build(BuildContext context) {
    final uid = widget.currentUserId != null
        ? widget.currentUserId!()
        : FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const BookingScaffold(
          body: Center(child: Text('سجل الدخول للوصول إلى الحجوزات')));
    }
    Query<Map<String, dynamic>>? query;
    if (widget.records == null) {
      if (tab == 6) {
        query = FirebaseFirestore.instance
            .collection('booking_venue_staff')
            .where('userId', isEqualTo: uid);
      } else if (tab == 5) {
        query = ownerBookingVenuesQuery(uid);
      } else if (tab == 0) {
        query = widget.admin
            ? adminBookingVenuesQuery()
            : publicBookingVenuesQuery().limit(publicLimit + 1);
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
    }
    final isDiscovery = !widget.admin && tab == 0 && _bottomBarIndex == 0;
    final isReels = _bottomBarIndex == 2 && (tab == 0 || tab == 1);
    final isSearch = _bottomBarIndex == 1 && (tab == 0 || tab == 1);
    final isAccount = _bottomBarIndex == 4 && (tab == 0 || tab == 1);
    return Directionality(
        textDirection: TextDirection.rtl,
        child: BookingScaffold(
            edgeToEdge: isDiscovery || isReels,
            appBar: isDiscovery || isReels
                ? null
                : AppBar(
                    title: Text(widget.admin
                        ? 'إدارة الحجوزات'
                        : isSearch
                            ? 'بحث الحجوزات'
                            : isAccount
                                ? 'حسابي'
                                : tab == 2
                                    ? 'لوحة المالك'
                                    : tab == 1
                                        ? 'حجوزاتي'
                                        : tab == 4
                                            ? 'المراجعة المالية'
                                            : 'حجوزات الأنبار'),
                    actions: widget.appBarActions ??
                        (widget.admin && tab != 1 && !isDiscovery
                            ? [
                                IconButton(
                                    icon: const Icon(Icons.campaign_outlined),
                                    tooltip: 'بنرات الحجوزات',
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const BannerManagementScreen(
                                                    placement: BannerPlacement
                                                        .bookings)))),
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
                                                const BookingSettingsScreen()))),
                                PopupMenuButton<int>(
                                    tooltip: 'أدوات الإدارة والمالك',
                                    icon: const Icon(Icons.grid_view_outlined),
                                    onSelected: (value) =>
                                        setState(() => tab = value),
                                    itemBuilder: (_) => [
                                          for (final e in <int, String>{
                                            2: 'لوحة المالك',
                                            5: 'أماكني وأسعاري',
                                            6: 'مهام الموظف',
                                            if (finance) 4: 'المراجعة المالية'
                                          }.entries)
                                            PopupMenuItem(
                                                value: e.key,
                                                child: Text(e.value))
                                        ])
                              ]
                            : [
                                IconButton(
                                  tooltip: 'الإشعارات',
                                  icon: const Icon(Icons.notifications_none_rounded),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                  ),
                                ),
                              ])),
            bottomNavigationBar: BookingBottomBar(
              currentIndex: _bottomBarIndex,
              onTap: (newIndex) {
                setState(() {
                  _bottomBarIndex = newIndex;
                  if (newIndex == 0) {
                    tab = 0;
                  } else if (newIndex == 3) {
                    tab = 1;
                  }
                });
              },
            ),
            body: isSearch
                ? const BookingSearchScreen(embedded: true)
                : isReels
                    ? const BookingReelsScreen()
                    : isAccount
                        ? BookingAccountScreen(
                            admin: widget.admin,
                            embedded: true,
                            onOpenAdminTools:
                                widget.admin ? () => setState(() => tab = 0) : null,
                          )
                        : ListView(
                key: const PageStorageKey('booking-workspace-scroll'),
                children: [
                  if (widget.admin && tab == 0)
                    BookingAdminTasks(
                        records: widget.adminTaskRecords ??
                            (widget.records == null ? null : const {}),
                        onOpen: (task) {
                          if (widget.onAdminTask != null) {
                            widget.onAdminTask!(task);
                            return;
                          }
                          if (task == 'requests' || task == 'reports') {
                            setState(() => tab = task == 'requests' ? 1 : 3);
                            return;
                          }
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => task == 'media'
                                      ? const BookingMediaInbox()
                                      : task == 'proofs'
                                          ? const BookingProofInbox()
                                          : const BookingReviewInbox()));
                        }),
                  if (tab != 2 && tab != 0 && tab != 1)
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: !widget.admin && tab == 0
                            ? const BookingBrowseHeader()
                            : BookingWorkspaceHeader(
                                title: widget.admin
                                    ? 'مركز إدارة الحجوزات'
                                    : 'لوحة المالك',
                                subtitle: widget.admin
                                    ? 'راجع الأماكن والطلبات والتوثيق من مساحة واحدة.'
                                    : 'إدارة الشاليهات والأسعار ومتابعة طلبات الحجز.')),
                  if ((tab != 0 && tab != 1 && tab != 2) ||
                      (widget.admin && tab == 0))
                    ...workspaceTools(uid),
                  if (tab == 0)
                    BookingFilterBar(
                        welcome: true,
                        heroAction: null,
                        filters: filters,
                        onChanged: () => setState(() {})),
                  if (tab == 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E222D)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            for (final name in statusGroups.keys)
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => statusGroup = name),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 9),
                                        child: Text(
                                          name,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            fontWeight: statusGroup == name
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: statusGroup == name
                                                ? (Theme.of(context).brightness == Brightness.dark
                                                    ? const Color(0xFFE6C894)
                                                    : const Color(0xFF8B6B23))
                                                : (Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white60
                                                    : const Color(0xFF64748B)),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        height: 2.5,
                                        margin: const EdgeInsets.symmetric(horizontal: 6),
                                        decoration: BoxDecoration(
                                          color: statusGroup == name
                                              ? bookingGold
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ...[
                    if (tab == 0 &&
                        (widget.records == null || widget.banners != null))
                      BannerSlider(
                          stream: widget.banners ?? bookingBanners,
                          imageBuilder: widget.bannerImageBuilder,
                          accentColor: bookingGold,
                          onBookingVenue: (id, category) async {
                            await bookingRun(context, () async {
                              final venue = widget.loadVenue != null
                                  ? await widget.loadVenue!(id)
                                  : (await FirebaseFirestore.instance
                                          .doc('booking_venues/$id')
                                          .get())
                                      .data();
                              if (venue == null ||
                                  venue['active'] != true ||
                                  const ['pending', 'rejected']
                                      .contains(venue['verificationStatus']) ||
                                  (widget.loadVenue == null &&
                                      !isBookingVenueApprovedStatus(
                                          venue['verificationStatus'])) ||
                                  venue['category'] != category)
                                throw StateError('المكان غير متاح');
                              if (context.mounted)
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => (widget.venuePage
                                                ?.call(id, venue) ??
                                            BookingRequestScreen(
                                                venueId: id, venue: venue))));
                            });
                          }),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: widget.records?.call(tab) ??
                            query!.snapshots(includeMetadataChanges: true),
                        builder: (context, s) {
                          final requireVerifiedServer =
                              tab != 0 || widget.admin || !s.hasData || (s.data?.docs.isEmpty ?? true);
                          return BookingVerifiedGate(
                            hasData: s.hasData,
                            hasError: s.hasError,
                            error: s.error,
                            isFromCache: requireVerifiedServer &&
                                (s.data?.metadata.isFromCache ?? false),
                            hasPendingWrites:
                                s.data?.metadata.hasPendingWrites ?? false,
                            permissionDetail: tab == 0
                                ? 'تعذر تحميل قائمة الأماكن بسبب صلاحية الحساب أو الاتصال.'
                                : 'بيانات الحجوزات أو الإدارة تتطلب التحقق من الحساب عبر الخادم.',
                            onRetry: () => setState(() {}),
                            child: Builder(builder: (context) {
                              if (s.data!.docs.isEmpty &&
                                  !(tab == 0 && !widget.admin)) {
                                return const BookingStateView(
                                    title: 'لا توجد بيانات بعد',
                                    detail: 'ستظهر الطلبات هنا عند توفرها.',
                                    icon: Icons.inbox_outlined);
                              }
                          final sourceDocs = tab == 0 && !widget.admin
                              ? s.data!.docs.take(publicLimit)
                              : s.data!.docs;
                          final allowedStatuses = statusGroups[statusGroup] ?? [];
                          final docs = sourceDocs.where((d) {
                            if (tab == 0) {
                              final data = d.data();
                              if (!widget.admin &&
                                  (data['active'] == false ||
                                      const ['pending', 'rejected'].contains(
                                          data['verificationStatus']) ||
                                      (widget.records == null &&
                                          !isBookingVenueApprovedStatus(
                                              data['verificationStatus'])))) {
                                return false;
                              }
                              return filters.matches(data);
                            }
                            if (tab == 1) {
                              if (statusGroup == 'الكل' || allowedStatuses.isEmpty) return true;
                              final s = d.data()['status']?.toString();
                              return allowedStatuses.contains(s);
                            }
                            return true;
                          }).toList();
                          if (tab == 0)
                            docs.sort(
                                (a, b) => filters.compare(a.data(), b.data()));
                          if (docs.isEmpty && !(tab == 0 && !widget.admin)) {
                            if (tab == 1) {
                              final isDark = Theme.of(context).brightness == Brightness.dark;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 68,
                                          height: 68,
                                          decoration: BoxDecoration(
                                            color: bookingGold.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: bookingGold.withValues(alpha: 0.3)),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.calendar_month_rounded, size: 34, color: bookingGold),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          statusGroup == 'الكل'
                                              ? 'لم تسجل أي حجوزات بعد'
                                              : 'لا توجد حجوزات في قسم "$statusGroup" حاليًا',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          statusGroup == 'الكل'
                                              ? 'استكشف أفضل الشاليهات والمنتجعات الفاخرة بالأنبار واحجز موعدك القادم بسهولة.'
                                              : 'يمكنك الاطلاع على الأقسام الأخرى أو تصفح الأماكن المتاحة للحجز فوراً.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12.5,
                                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          key: const ValueKey('empty-state-browse-btn'),
                                          onPressed: () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              tab = 0;
                                              _bottomBarIndex = 0;
                                            });
                                          },
                                          icon: const Icon(Icons.explore_outlined, size: 18),
                                          label: const Text(
                                            'تصفح الأماكن المتاحة الآن',
                                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: bookingGold,
                                            foregroundColor: const Color(0xFF0F172A),
                                            elevation: 1,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                    'لا توجد أماكن تطابق الفلاتر؛ جرّب تخفيفها'));
                          }
                          if (tab == 0 && !widget.admin) {
                            return BookingBrowseContent(
                                featuredPreview: kDebugMode &&
                                    appFlavor == 'bookingsOfflinePreview' &&
                                    const bool.fromEnvironment(
                                        'BOOKING_OFFLINE_PREVIEW'),
                                featuredVenues: widget.diagnosticFeatured.isNotEmpty
                                    ? (widget.diagnosticFeatured
                                        .where(filters.matches)
                                        .toList()
                                      ..sort(filters.compare))
                                    : docs
                                        .where((d) =>
                                            d.data()['featured'] == true ||
                                            d.data()['isFeatured'] == true)
                                        .map((d) => <String, dynamic>{
                                              ...d.data(),
                                              'id': d.id
                                            })
                                        .toList(),
                                hasMore: s.data!.docs.length > publicLimit,
                                loading: s.connectionState ==
                                    ConnectionState.waiting,
                                onLoadMore: () =>
                                    setState(() => publicLimit += 12),
                                venues: docs
                                    .map((d) => <String, dynamic>{
                                          ...d.data(),
                                          'id': d.id
                                        })
                                    .toList(),
                                onOpen: (venue) => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => (widget.venuePage?.call(
                                                venue['id'] as String, venue) ??
                                            BookingRequestScreen(
                                                venueId: venue['id'] as String,
                                                venue: venue)))));
                          }
                          if (tab == 2)
                            return BookingOwnerPanel(
                                onManageVenues: () => setState(() => tab = 5),
                                bookings: docs
                                    .map((d) => <String, dynamic>{
                                          ...d.data(),
                                          'id': d.id
                                        })
                                    .toList(),
                                onOpen: (id) => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            (widget.bookingPage?.call(id) ??
                                                BookingDetailsScreen(
                                                    bookingId: id)))));
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
                                            builder: (_) => widget.admin ||
                                                    tab == 5
                                                ? (widget.venuePage
                                                        ?.call(doc.id, d) ??
                                                    BookingVenueEditor(
                                                        venueId: doc.id,
                                                        data: d,
                                                        ownerMode: tab == 5))
                                                : (widget.venuePage
                                                        ?.call(doc.id, d) ??
                                                    BookingRequestScreen(
                                                        venueId: doc.id,
                                                        venue: d)))));
                              }
                              if (tab == 3) {
                                final isVenue = d['bookingId'] == null ||
                                    d['bookingId'].toString().isEmpty;
                                final bId = d['bookingId']?.toString();
                                final vId = d['venueId']?.toString();
                                return BookingReportCard(
                                    data: d,
                                    onOpen: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => (!isVenue && bId != null && bId.isNotEmpty)
                                                ? (widget.bookingPage?.call(bId) ??
                                                    BookingDetailsScreen(bookingId: bId))
                                                : (widget.venuePage?.call(vId ?? '', d) ??
                                                    BookingVenueEditor(
                                                        venueId: vId,
                                                        data: d,
                                                        ownerMode: false)))),
                                    onResolve: d['status'] == 'open'
                                        ? () => bookingRun(
                                            context,
                                            () => doc.reference
                                                .update({'status': 'resolved'}))
                                        : null);
                              }
                              return BookingRecordCard(
                                  booking: d,
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => (widget.bookingPage
                                                  ?.call(doc.id) ??
                                              BookingDetailsScreen(
                                                  bookingId: doc.id)))));
                            }).toList()
                          ]);
                            }),
                          );
                        })
                  ],
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
      this.intentStore,
      this.currentUserId});
  final BookingRequestIntentStore? intentStore;
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
  bool confirmingRequest = false;
  Map<String, dynamic>? submittedIntent;
  String? submittedUid;
  bool identityChanged = false;
  bool intentReady = false;
  bool intentReadFailed = false;
  final GlobalKey<BookingVenueDetailsState> _venueDetailsKey = GlobalKey<BookingVenueDetailsState>();
  final ScrollController _venueScrollController = ScrollController();
  final ValueNotifier<bool> _isVenueTabPinned = ValueNotifier<bool>(false);
  late final BookingRequestIntentStore intentStore =
      widget.intentStore ?? FileBookingRequestIntentStore();
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
    if (isShiftsPricing && availableShifts.isNotEmpty && shiftId == null) {
      shiftId = availableShifts.first['id'] as String;
    }
    _venueScrollController.addListener(() {
      if (step == 0 && _venueScrollController.hasClients) {
        final shouldPin = _venueScrollController.offset > 360;
        if (_isVenueTabPinned.value != shouldPin) {
          _isVenueTabPinned.value = shouldPin;
        }
      }
    });
    restoreIntent();
    if (widget.currentUserId == null) {
      try {
        final u = FirebaseAuth.instance.currentUser;
        if (u != null) {
          if (u.displayName != null && u.displayName!.isNotEmpty) {
            guestName.text = u.displayName!;
          }
          if (u.phoneNumber != null && u.phoneNumber!.isNotEmpty) {
            guestPhone.text = u.phoneNumber!;
          }
        }
      } catch (_) {}
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        requestSession = FirebaseAuth.instance.authStateChanges().listen((user) {
          if (mounted && user?.uid != uid) invalidateIdentity();
        });
      } catch (_) {}
    }
  }

  Future<void> restoreIntent() async {
    final uid = currentUid();
    try {
      final pending =
          uid == null ? null : await intentStore.read(uid, widget.venueId);
      if (!mounted) return;
      if (currentUid() != uid) {
        invalidateIdentity();
        return;
      }
      if (pending != null) {
        submittedUid = uid;
        submittedIntent = Map<String, dynamic>.unmodifiable(pending);
        if (pending['start'] is num) {
          start = DateTime.fromMillisecondsSinceEpoch((pending['start'] as num).toInt());
        }
        if (pending['end'] is num) {
          end = DateTime.fromMillisecondsSinceEpoch((pending['end'] as num).toInt());
        }
        shiftId = pending['shiftId'];
        notes.text = pending['notes'] as String? ?? '';
        if (pending['guestName'] is String) guestName.text = pending['guestName'] as String;
        if (pending['guestPhone'] is String) guestPhone.text = pending['guestPhone'] as String;
        if (pending['guestCount'] is num) guestCount = (pending['guestCount'] as num).toInt();
        step = 3;
        accepted = true;
      }
      setState(() => intentReady = true);
    } catch (_) {
      if (mounted) setState(() => intentReadFailed = true);
    }
  }

  bool accepted = false, busy = false;
  String? guestNameError;
  String? guestPhoneError;
  String? shiftId;

  bool _validateGuestStep() {
    guestNameError = BookingFormValidator.requiredText(
      guestName.text,
      fieldName: 'الاسم الكامل للضيف',
      minLength: 2,
      maxLength: 100,
    );
    guestPhoneError = BookingFormValidator.phoneError(
      guestPhone.text,
      required: true,
    );
    return guestNameError == null && guestPhoneError == null;
  }
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
    if (submittedIntent?['price'] is int)
      return submittedIntent!['price'] as int;
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

  BookingPricingDraft? get pricingV2 =>
      BookingPricingDraft.fromVenue(widget.venue);

  bool get isShiftsPricing =>
      pricingV2 != null || widget.venue['pricingMode'] == 'shifts';

  List<Map<String, dynamic>> get availableShifts => pricingV2 != null
      ? pricingV2!.enabledShifts
      : [
          for (final s in widget.venue['shifts'] as List? ?? [])
            if (s is Map) Map<String, dynamic>.from(s)
        ];

  int get baseTotal {
    final v = widget.venue;
    final v2 = pricingV2;
    if (v2 != null && shiftId != null) {
      if (start != null && end != null) {
        return v2.quote(shiftId!, start!, end!)['total'] as int;
      }
      return v2.enabledShifts
          .firstWhere((s) => s['id'] == shiftId)['weekdayPrice'] as int;
    }
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
    if (availableShifts.isNotEmpty) {
      final shift = availableShifts.firstWhere(
        (s) => s['id'] == shiftId,
        orElse: () => availableShifts.first,
      );
      shiftId ??= shift['id'] as String?;
      final dates = bookingShiftDates(date, shift);
      start = dates[0];
      end = dates[1];
    } else {
      start = DateTime(date.year, date.month, date.day, 12, 0);
      end = start!.add(const Duration(days: 1));
    }
  }

  final notes = TextEditingController();
  final guestName = TextEditingController();
  final guestPhone = TextEditingController();
  int guestCount = 2;
  late final requestId = '${DateTime.now().microsecondsSinceEpoch}';
  @override
  void dispose() {
    requestSession?.cancel();
    _venueScrollController.dispose();
    _isVenueTabPinned.dispose();
    notes.dispose();
    guestName.dispose();
    guestPhone.dispose();
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

  void _openMonthYearPicker(BuildContext context) {
    HapticFeedback.selectionClick();
    final nowBaghdad = DateTime.now().toUtc().add(const Duration(hours: 3));
    final currentMonthBaghdad = DateTime(nowBaghdad.year, nowBaghdad.month);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final monthsList = <DateTime>[];
    for (var i = 0; i < 12; i++) {
      monthsList.add(DateTime(currentMonthBaghdad.year, currentMonthBaghdad.month + i));
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: bookingGold, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'الانتقال السريع إلى شهر محدد',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'اختر الشهر المطلوب للحجز (الأشهر القادمة فقط وفق توقيت بغداد):',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: monthsList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final m = monthsList[idx];
                    final isCurrent = m.year == calendarMonth.year && m.month == calendarMonth.month;
                    const monthNames = [
                      'يناير / كانون الثاني',
                      'فبراير / شباط',
                      'مارس / آذار',
                      'أبريل / نيسان',
                      'مايو / أيار',
                      'يونيو / حزيران',
                      'يوليو / تموز',
                      'أغسطس / آب',
                      'سبتمبر / أيلول',
                      'أكتوبر / تشرين الأول',
                      'نوفمبر / تشرين الثاني',
                      'ديسمبر / كانون الأول',
                    ];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      selected: isCurrent,
                      selectedTileColor: bookingGold.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: Icon(
                        isCurrent ? Icons.check_circle : Icons.calendar_today_outlined,
                        color: isCurrent ? bookingGold : (isDark ? Colors.white54 : Colors.grey),
                        size: 20,
                      ),
                      title: Text(
                        '${monthNames[m.month - 1]} ${m.year}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                          color: isCurrent ? (isDark ? bookingGold : const Color(0xFFB45309)) : null,
                        ),
                      ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(ctx);
                        setState(() {
                          calendarMonth = m;
                          availability = loadAvailability();
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    if (!intentReady)
      return BookingScaffold(
          appBar: AppBar(title: const Text('استعادة الطلب')),
          body: intentReadFailed
              ? const BookingStateView(
                  title: 'تعذر التحقق من الطلب المحفوظ',
                  detail: 'لم يُرسل طلب جديد. راجع حجوزاتك ثم أعد فتح المكان.')
              : const Center(child: CircularProgressIndicator()));
    final v = submittedIntent == null
        ? widget.venue
        : {
            ...widget.venue,
            'terms': submittedIntent!['acceptedTerms'],
            'deposit': submittedIntent!['deposit'],
            'cancellationPolicy': submittedIntent!['cancellationPolicy']
          };
    final validRange = start != null &&
        end != null &&
        start!.isBefore(end!) &&
        start!.isAfter(DateTime.now());
    return PopScope<Object?>(
        canPop: step == 0 || busy || submittedIntent != null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop &&
              !busy &&
              submittedIntent == null &&
              step > 0 &&
              mounted) setState(() => step--);
        },
        child: BookingScaffold(
          appBar: AppBar(
              title: Text(step == 0
                  ? '${v['name']}'
                  : step == 1
                      ? 'اختيار الموعد'
                      : step == 2
                          ? 'بيانات الحجز'
                          : 'مراجعة وتأكيد الحجز'),
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
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (busy)
                              const BookingActionReason(
                                  reason:
                                      'الإجراء معطل أثناء إرسال الطلب السابق.')
                            else if (step == 1 && !validRange)
                              const BookingActionReason(
                                  reason:
                                      'اختر الفترة ثم يوم الزيارة، أو حدد الدخول والخروج، لتفعيل متابعة الحجز.')
                            else if (step == 3 && !accepted)
                              const BookingActionReason(
                                  reason:
                                      'راجع الشروط وحدد الموافقة عليها لتفعيل إرسال الطلب.'),
                            if (step == 0)
                              Text(
                                  'يبدأ من ${bookingMoney(bookingStartingPrice(v))} · العربون ${bookingMoney(v['deposit'])}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            if (step == 1) ...[
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('المجموع الإجمالي للفترة:',
                                            style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Cairo')),
                                        Text(
                                          '${bookingMoney(total)} د.ع',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: bookingGold,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (validRange) ...[
                                      const SizedBox(width: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF16A34A), width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'العربون: ${bookingMoney(BookingPricingDraft.venueDeposit(v) ?? v['deposit'])}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF16A34A),
                                                fontFamily: 'Cairo',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            const SizedBox(height: 8),
                            if (step < 3)
                              FilledButton(
                                  key: const ValueKey('booking-next'),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: bookingGold,
                                      foregroundColor: const Color(0xFF1E293B),
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')),
                                  onPressed: busy || (step == 1 && !validRange)
                                      ? null
                                      : () {
                                          HapticFeedback.selectionClick();
                                          if (step == 2) {
                                            setState(() {
                                              if (_validateGuestStep()) {
                                                step++;
                                              }
                                            });
                                            return;
                                          }
                                          setState(() => step++);
                                        },
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                            step == 0
                                                ? Icons.calendar_month_outlined
                                                : step == 1
                                                    ? Icons.person_outline
                                                    : Icons.receipt_long_outlined,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Flexible(
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                    step == 0
                                                        ? 'احجز الآن'
                                                        : step == 1
                                                            ? 'متابعة لبيانات الحجز'
                                                            : 'متابعة لمراجعة الحجز',
                                                    maxLines: 1))),
                                      ])),
                            if (step == 3)
                              FilledButton(
                                  key: const ValueKey('booking-submit-request'),
                                  onPressed: busy ||
                                          confirmingRequest ||
                                          !accepted ||
                                          start == null ||
                                          end == null
                                      ? null
                                      : () async {
                                          if (busy || confirmingRequest) return;
                                          final priorUid = currentUid();
                                          if (submittedIntent == null) {
                                            setState(
                                                () => confirmingRequest = true);
                                            bool? confirmed;
                                            try {
                                              confirmed = await showModalBottomSheet<
                                                      bool>(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  useSafeArea: true,
                                                  showDragHandle: false,
                                                  builder: (_) =>
                                                      BookingRequestConfirmation(
                                                          venue: v,
                                                          total: total,
                                                          start: start,
                                                          end: end,
                                                          shiftName: isShiftsPricing &&
                                                                  shiftId !=
                                                                      null
                                                              ? '${availableShifts.firstWhere((s) => s['id'] == shiftId)['name']}'
                                                              : null));
                                            } finally {
                                              if (mounted)
                                                setState(() =>
                                                    confirmingRequest = false);
                                            }
                                            if (!mounted ||
                                                confirmed != true ||
                                                busy ||
                                                !accepted ||
                                                start == null ||
                                                end == null) return;
                                          }
                                          if (currentUid() != priorUid) {
                                            invalidateIdentity();
                                            return;
                                          }
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
                                            final v2Quote = pricingV2 != null &&
                                                    shiftId != null
                                                ? pricingV2!.quote(
                                                    shiftId!, start!, end!)
                                                : null;
                                            final payload = submittedIntent ??=
                                                Map<String,
                                                    dynamic>.unmodifiable({
                                              'venueId': widget.venueId,
                                              'requestId': requestId,
                                              'start':
                                                  start!.millisecondsSinceEpoch,
                                              'end':
                                                  end!.millisecondsSinceEpoch,
                                              'acceptedTerms': v['terms'],
                                              'price': total,
                                              'shiftId': shiftId,
                                              'cancellationPolicy':
                                                  v['cancellationPolicy'],
                                              'deposit': BookingPricingDraft.venueDeposit(v) ??
                                                  v2Quote?['deposit'] ??
                                                  v['deposit'],
                                              if (v2Quote != null)
                                                'pricingSnapshot':
                                                    v2Quote['pricing'],
                                               'guestName': guestName.text.trim(),
                                               'guestPhone':
                                                   BookingFormValidator.normalizeValidPhone(
                                                           guestPhone.text) ??
                                                       guestPhone.text.trim(),
                                               'guestCount': guestCount,
                                               'notes': notes.text
                                            });
                                            Map<String, dynamic> r;
                                            await intentStore.save(
                                                uid, widget.venueId, payload);
                                            if (currentUid() != uid) {
                                              invalidateIdentity();
                                              return;
                                            }
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
                                                  ].contains(e.code)) {
                                                await intentStore.clear(
                                                    uid,
                                                    widget.venueId,
                                                    payload['requestId']
                                                        as String);
                                                submittedIntent = null;
                                              }
                                              rethrow;
                                            }
                                            await intentStore.clear(
                                                uid,
                                                widget.venueId,
                                                payload['requestId'] as String);
                                            if (!mounted) return;
                                            if (currentUid() != uid) {
                                              invalidateIdentity();
                                              return;
                                            }
                                            if (context.mounted &&
                                                widget.onRequested != null) {
                                              widget.onRequested!(
                                                  r['id'] as String);
                                              return;
                                            }
                                            if (context.mounted) {
                                              Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          BookingDetailsScreen(
                                                              bookingId:
                                                                  r['id'])));
                                            }
                                          });
                                          if (mounted)
                                            setState(() => busy = false);
                                        },
                                  child: Text(busy
                                      ? 'جار إرسال الطلب…'
                                      : submittedIntent != null
                                          ? 'إعادة المحاولة بنفس الطلب'
                                          : 'إرسال طلب الحجز')),
                            if (step == 3 && submittedIntent != null)
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => Navigator.maybePop(context),
                                  child:
                                      const Text('العودة للتحقق من حجوزاتي')),
                          ])))))),
          body: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Stack(
                      children: [
                        ListView(
                            key: ValueKey('booking-step-$step'),
                            controller: _venueScrollController,
                            padding: const EdgeInsets.all(20),
                            children: [
                              if (step > 0)
                                BookingCheckoutHeader(step: (step - 1).clamp(0, 2)),
                              if (step == 0) ...[
                                BookingVenueDetails(
                                    key: _venueDetailsKey,
                                    venue: v),
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
                              key: const ValueKey('booking-calendar-section'),
                              title: 'اختيار الموعد والتوافر',
                              subtitle:
                                  'اختر اليوم المناسب من التقويم، ثم حدد الفترة للاطلاع على السعر والعربون.',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                   const BookingStatusLegend(),
                                  // Calendar Navigation & Body
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        IconButton(
                                            tooltip: 'الشهر السابق',
                                            onPressed: calendarMonth.isAfter(bookingBaghdadMonth())
                                                ? () => setState(() {
                                                      calendarMonth = DateTime(calendarMonth.year, calendarMonth.month - 1);
                                                      availability = loadAvailability();
                                                    })
                                                : null,
                                            icon: const Icon(Icons.chevron_right)),
                                        Expanded(
                                            child: InkWell(
                                              onTap: () => _openMonthYearPicker(context),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                          '${const [
                                                            'يناير',
                                                            'فبراير',
                                                            'مارس',
                                                            'أبريل',
                                                            'مايو',
                                                            'يونيو',
                                                            'يوليو',
                                                            'أغسطس',
                                                            'سبتمبر',
                                                            'أكتوبر',
                                                            'نوفمبر',
                                                            'ديسمبر'
                                                          ][calendarMonth.month - 1]} ${calendarMonth.year}',
                                                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
                                                          textAlign: TextAlign.center),
                                                      const SizedBox(width: 4),
                                                      const Icon(Icons.arrow_drop_down_rounded, color: bookingGold, size: 24),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            )),
                                        IconButton(
                                            tooltip: 'الشهر التالي',
                                            onPressed: () => setState(() {
                                                  calendarMonth = DateTime(calendarMonth.year, calendarMonth.month + 1);
                                                  availability = loadAvailability();
                                                }),
                                            icon: const Icon(Icons.chevron_left)),
                                      ]),
                                  FutureBuilder<Map<String, dynamic>>(
                                      future: availability,
                                      builder: (context, snapshot) {
                                        if (snapshot.hasError) {
                                          return TextButton(
                                              onPressed: () => setState(() => availability = loadAvailability()),
                                              child: const Text('تعذر تحميل التوافر — إعادة المحاولة'));
                                        }
                                        if (!snapshot.hasData) return const LinearProgressIndicator();
                                        final targetShift = shiftId != null
                                            ? availableShifts.firstWhere((s) => s['id'] == shiftId, orElse: () => availableShifts.first)
                                            : (availableShifts.isNotEmpty ? availableShifts.first : null);
                                        return BookingCalendar(
                                            selectedDay: start?.add(const Duration(hours: 3)),
                                            month: calendarMonth,
                                            slots: (snapshot.data!['slots'] as List).map((e) => Map<String, dynamic>.from(e)).toList(),
                                            intervalForDay: (day) => targetShift != null
                                                ? bookingShiftDates(day, targetShift)
                                                : [day, day.add(const Duration(days: 1))],
                                            onSelect: (day) => setState(() {
                                                   HapticFeedback.selectionClick();
                                                   final isSameDay = start != null &&
                                                       start!.year == day.year &&
                                                       start!.month == day.month &&
                                                       start!.day == day.day;
                                                   if (isSameDay) {
                                                     start = null;
                                                     end = null;
                                                   } else {
                                                     if (shiftId == null && availableShifts.isNotEmpty) {
                                                       shiftId = availableShifts.first['id'] as String;
                                                     }
                                                     setShiftDate(day);
                                                   }
                                                   accepted = false;
                                                 }));
                                      }),
                                  const SizedBox(height: 16),
                                  // Shifts Selection
                                  if (isShiftsPricing && availableShifts.isNotEmpty) ...[
                                    const Text('اختر الفترة المطلوبة:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 8),
                                    for (final shift in availableShifts)
                                      Card(
                                        elevation: shiftId == shift['id'] ? 2 : 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: shiftId == shift['id'] ? bookingGold : Theme.of(context).dividerColor,
                                            width: shiftId == shift['id'] ? 2 : 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: busy
                                              ? null
                                              : () => setState(() {
                                                    HapticFeedback.selectionClick();
                                                    shiftId = shift['id'] as String;
                                                    if (start != null) {
                                                      setShiftDate(start!);
                                                    }
                                                    accepted = false;
                                                  }),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            child: Builder(builder: (context) {
                                                final sName = shift['name']?.toString() ?? '';
                                                final visual = BookingShiftVisual.resolve(shift);
                                                final brightness = Theme.of(context).brightness;
                                                final shiftIcon = visual.icon;
                                                final shiftIconFg = visual.foreground(brightness);
                                                final shiftIconBg = visual.background(brightness);
                                                final shiftIconBorder = visual.border(brightness);
                                                final startMinute = shift['checkInMinute'] ?? shift['startMinute'];
                                                final endMinute = shift['checkOutMinute'] ?? shift['endMinute'];
                                                final timeText = (startMinute != null && endMinute != null)
                                                    ? '${bookingClock12(startMinute)} إلى ${bookingClock12(endMinute)}'
                                                    : '';
                                                return Row(
                                                  children: [
                                                    Icon(
                                                      shiftId == shift['id']
                                                          ? Icons.radio_button_checked
                                                          : Icons.radio_button_off,
                                                      color: shiftId == shift['id'] ? bookingGold : Colors.grey,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: shiftIconBg,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: shiftIconBorder, width: 0.8),
                                                      ),
                                                      child: Icon(shiftIcon, color: shiftIconFg, size: 18),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            sName,
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
                                                          ),
                                                          if (timeText.isNotEmpty)
                                                            Text(
                                                              timeText,
                                                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Cairo'),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(maxWidth: 110),
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        alignment: Alignment.centerLeft,
                                                        child: Text(
                                                          '${bookingMoney(shift['price'] ?? shift['weekdayPrice'])} د.ع',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, color: bookingGold, fontFamily: 'Cairo'),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }),
                                          ),
                                        ),
                                      ),
                                  ],
                                  // Live Financial Summary
                                  if (start != null && end != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: bookingGold.withValues(alpha: 0.5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.calculate_outlined, color: bookingGold, size: 20),
                                              const SizedBox(width: 8),
                                              const Flexible(child: Text('تفاصيل الحساب المالي المعتمد',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                            ],
                                          ),
                                          const Divider(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            child: Wrap(
                                              alignment: WrapAlignment.spaceBetween,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                const Text('السعر الإجمالي:'),
                                                Text(bookingMoney(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                           Builder(builder: (context) {
                                             final depositAmt = BookingPricingDraft.safeVenueDeposit(v);
                                             final remainingAmt = total - depositAmt;
                                             return Column(
                                               crossAxisAlignment: CrossAxisAlignment.stretch,
                                               children: [
                                                 SizedBox(
                                                   width: double.infinity,
                                                   child: Wrap(
                                                     alignment: WrapAlignment.spaceBetween,
                                                     crossAxisAlignment: WrapCrossAlignment.center,
                                                     children: [
                                                       const Text('العربون المطلوب للدفع:'),
                                                       Text(bookingMoney(depositAmt),
                                                           style: const TextStyle(fontWeight: FontWeight.bold, color: bookingGold)),
                                                     ],
                                                   ),
                                                 ),
                                                 const SizedBox(height: 6),
                                                 SizedBox(
                                                   width: double.infinity,
                                                   child: Wrap(
                                                     alignment: WrapAlignment.spaceBetween,
                                                     crossAxisAlignment: WrapCrossAlignment.center,
                                                     children: [
                                                       const Text('الرصيد المتبقي عند الوصول:'),
                                                       Text(bookingMoney(remainingAmt),
                                                           style: const TextStyle(fontWeight: FontWeight.bold)),
                                                     ],
                                                   ),
                                                 ),
                                               ],
                                             );
                                           }),
                                          Builder(builder: (context) {
                                            final sec = (v['securityDeposit'] as num?) ?? (v['insuranceDeposit'] as num?) ?? 0;
                                            if (sec <= 0) return const SizedBox.shrink();
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                const SizedBox(height: 6),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: Wrap(
                                                    alignment: WrapAlignment.spaceBetween,
                                                    crossAxisAlignment: WrapCrossAlignment.center,
                                                    children: [
                                                      const Text('مبلغ التأمين (ضمان الأضرار):'),
                                                      Text('${bookingMoney(sec)} د.ع',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                const Text(
                                                  'ملاحظة: يُسترد مبلغ التأمين بالكامل عند تسجيل الخروج وتسليم المكان بحالته الأصلية وفق شروط المالك.',
                                                  style: TextStyle(fontSize: 10.5, color: Colors.grey, fontFamily: 'Cairo'),
                                                ),
                                              ],
                                            );
                                          }),
                                          const Divider(height: 16),
                                          Text(
                                            'الدخول: ${start != null ? bookingVisitTime(start!.add(const Duration(hours: 3))) : "-"}\nالخروج: ${end != null ? bookingVisitTime(end!.add(const Duration(hours: 3))) : "-"} — توقيت بغداد',
                                            style: TextStyle(fontSize: 12, height: 1.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              )),
                        ],
                        if (step == 2) ...[
                          BookingSection(
                            key: const ValueKey('booking-guests-section'),
                            title: 'بيانات الحجز والضيف',
                            subtitle: 'أدخل معلومات الاتصال وعدد الضيوف وملاحظاتك لتأكيد الترتيبات مع المالك.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: guestName,
                                  onChanged: (_) {
                                    if (guestNameError != null) {
                                      setState(() => guestNameError = null);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'الاسم الكامل للضيف / الزبون',
                                    errorText: guestNameError,
                                    suffix: const Text('*',
                                        style: TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.bold)),
                                    prefixIcon: const Icon(Icons.person_outline, color: bookingGold),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: guestPhone,
                                  keyboardType: TextInputType.phone,
                                  textDirection: TextDirection.ltr,
                                  onChanged: (_) {
                                    if (guestPhoneError != null) {
                                      setState(() => guestPhoneError = null);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'رقم الهاتف للتواصل',
                                    hintText: '07XXXXXXXXX',
                                    errorText: guestPhoneError,
                                    suffix: const Text('*',
                                        style: TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.bold)),
                                    prefixIcon: const Icon(Icons.phone_outlined, color: bookingGold),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.group_outlined, color: bookingGold, size: 20),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'عدد الضيوف المتوقع:',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                        icon: const Icon(Icons.remove_circle_outline, size: 22),
                                        onPressed: guestCount > 1 ? () => setState(() => guestCount--) : null,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text('$guestCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                        icon: const Icon(Icons.add_circle_outline, size: 22),
                                        onPressed: guestCount < 100 ? () => setState(() => guestCount++) : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: notes,
                                  maxLength: 1000,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    labelText: 'ملاحظات خاصة للمالك (اختياري)',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (step == 3) ...[
                          if (submittedIntent != null)
                            const BookingStateView(
                                title: 'إعادة التحقق من الطلب',
                                detail:
                                    'عند انقطاع الرد، تعاد المحاولة بنفس البيانات ومعرّف الطلب لمنع إنشاء طلب آخر.'),
                          BookingVenueOverview(venue: v, total: total),
                          BookingArrivalSummary(start: start, end: end),
                          BookingSection(
                              title: 'موعد الزيارة',
                              child: Text(
                                  'الدخول: ${bookingVisitTime(start?.add(const Duration(hours: 3)))}\nالخروج: ${bookingVisitTime(end?.add(const Duration(hours: 3)))} — توقيت بغداد',
                                  style: const TextStyle(height: 1.8))),
                          BookingSection(
                              title: 'الشروط والتأكيد',
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(bookingCancellationText(
                                        v['cancellationPolicy'])),
                                    const SizedBox(height: 10),
                                    TextField(
                                        controller: notes,
                                        enabled:
                                            !busy && submittedIntent == null,
                                        maxLength: 1000,
                                        maxLines: 3,
                                        decoration: const InputDecoration(
                                            labelText: 'ملاحظات اختيارية')),
                                    CheckboxListTile(
                                        value: accepted,
                                        onChanged: busy ||
                                                submittedIntent != null
                                            ? null
                                            : (v) => setState(
                                                () => accepted = v ?? false),
                                        title: const Text(
                                            'أوافق على السعر والشروط وسياسة الإلغاء')),
                                  ])),
                        ],
                      ]),
                        if (step == 0)
                          ValueListenableBuilder<bool>(
                            valueListenable: _isVenueTabPinned,
                            builder: (context, isPinned, _) {
                              if (!isPinned) return const SizedBox.shrink();
                              return Positioned(
                                top: 8,
                                left: 20,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: .22),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: bookingGold.withValues(alpha: .5),
                                    ),
                                  ),
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: _venueDetailsKey.currentState?.selectedNotifier ?? ValueNotifier<int>(0),
                                    builder: (context, currentSelected, _) => SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          for (var i = 0; i < BookingVenueDetails.labels.length; i++)
                                            Padding(
                                              padding: const EdgeInsetsDirectional.only(end: 8),
                                              child: Semantics(
                                                selected: currentSelected == i,
                                                child: TextButton(
                                                  key: ValueKey('booking-pinned-tab-$i'),
                                                  style: TextButton.styleFrom(
                                                    minimumSize: const Size(48, 44),
                                                    foregroundColor: currentSelected == i
                                                        ? Theme.of(context).colorScheme.onSurface
                                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                                    backgroundColor: Colors.transparent,
                                                  ),
                                                  onPressed: () => _venueDetailsKey.currentState?.jump(i),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        bottom: BorderSide(
                                                          color: currentSelected == i
                                                              ? bookingGold
                                                              : Colors.transparent,
                                                          width: 3,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      BookingVenueDetails.labels[i],
                                                      softWrap: false,
                                                      style: TextStyle(
                                                        fontWeight: currentSelected == i
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                        fontFamily: 'Cairo',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                  ))),
        ));
  }
}

class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailsScreen(
      {super.key,
      required this.bookingId,
      this.currentUserId,
      this.sessions,
      this.roles,
      this.dataStream,
      this.displayVenue,
      this.events,
      this.paymentAccounts,
      this.pickReceiptBytes,
      this.readReceiptBytes,
      this.submitReceipt,
      this.chatPage,
      this.supportPage,
      this.scannerPage,
      this.call = bookingCall});
  final String? Function()? currentUserId;
  final Stream<String?>? sessions;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> Function(String)? roles;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? dataStream;
  final Map<String, dynamic>? displayVenue;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? events;
  final Stream<Map<String, dynamic>>? paymentAccounts;
  final Future<Uint8List?> Function()? pickReceiptBytes, readReceiptBytes;
  final Future<void> Function(Uint8List, String, String)? submitReceipt;
  final WidgetBuilder? chatPage, supportPage, scannerPage;
  final BookingMediaCall call;
  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  Uint8List? receiptBytes;
  String? receiptUid;
  int rating = 5;
  bool busy = false, admin = false, finance = false;
  String method = 'qicard';
  String? displayedNumber;
  Map<String, dynamic> accounts = {};
  StreamSubscription<Map<String, dynamic>>? accountListener;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? roleListener;
  StreamSubscription<String?>? sessionListener;
  String? privilegedUid;
  DocumentSnapshot<Map<String, dynamic>>? _cachedSnapshot;
  final transaction = TextEditingController(),
      reason = TextEditingController(),
      refundReference = TextEditingController();
  String? currentUid() => widget.currentUserId != null
      ? widget.currentUserId!()
      : FirebaseAuth.instance.currentUser?.uid;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _bookingStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _eventsStream;

  void _initStreams() {
    _bookingStream = widget.dataStream ??
        FirebaseFirestore.instance
            .doc('bookings/${widget.bookingId}')
            .snapshots(includeMetadataChanges: true);
    _eventsStream = widget.events ??
        FirebaseFirestore.instance
            .collection('booking_action_audit')
            .where('bookingId', isEqualTo: widget.bookingId)
            .snapshots(includeMetadataChanges: true);
  }

  @override
  void didUpdateWidget(covariant BookingDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookingId != widget.bookingId ||
        oldWidget.dataStream != widget.dataStream ||
        oldWidget.events != widget.events) {
      _initStreams();
    }
  }

  @override
  void initState() {
    super.initState();
    _initStreams();
    accountListener =
        (widget.paymentAccounts ?? SubscriptionPaymentAccounts.watch()).listen(
            (value) {
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

    sessionListener = (widget.sessions ??
            FirebaseAuth.instance.authStateChanges().map((u) => u?.uid))
        .listen((uid) {
      roleListener?.cancel();
      if (uid != receiptUid) receiptBytes = null;
      if (!mounted) return;
      setState(() {
        admin = false;
        finance = false;
        privilegedUid = null;
      });
      if (uid == null) return;
      roleListener = (widget.roles?.call(uid) ??
              FirebaseFirestore.instance
                  .doc('users/$uid')
                  .snapshots(includeMetadataChanges: true))
          .listen((s) {
        if (!mounted || currentUid() != uid) return;
        final data = s.data();
        if (data == null) return;
        final isBlocked = data['isBlocked'] == true;
        if (isBlocked) {
          setState(() {
            privilegedUid = null;
            admin = false;
            finance = false;
          });
          return;
        }
        setState(() {
          privilegedUid = uid;
          admin = data['isAdmin'] == true;
          finance = data['canReviewBookingPayments'] == true;
        });
      }, onError: (_) {
        if (!mounted || currentUid() != uid) return;
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

  Future<void> pickReceipt() async {
    final expectedUid = currentUid();
    if (busy || expectedUid == null) return;
    if (widget.pickReceiptBytes != null) {
      await guarded(() async {
        final bytes = await widget.pickReceiptBytes!();
        if (mounted && currentUid() == expectedUid)
          setState(() {
            receiptBytes = bytes;
            receiptUid = expectedUid;
          });
      });
      return;
    }
    await guarded(() async {
      final image = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (image == null) return;
      final bytes = await FlutterImageCompress.compressWithList(
          await image.readAsBytes(),
          format: CompressFormat.jpeg,
          quality: 85);
      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024)
        throw StateError('حجم الإيصال غير صالح');
      if (mounted && currentUid() == expectedUid)
        setState(() {
          receiptBytes = bytes;
          receiptUid = expectedUid;
        });
    });
  }

  Future<void> guarded(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await bookingRun(context, task);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> promptReason(String title, String hint, {bool isDestructive = false}) async {
    final controller = TextEditingController(text: reason.text);
    bool confirming = false;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        isDestructive ? Icons.warning_amber_rounded : Icons.info_outline,
                        color: isDestructive ? const Color(0xFFEF4444) : bookingGold,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isDestructive) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'تنبيه: هذا الإجراء نهائي ولا يمكن التراجع عنه. يتم تطبيق سياسة الحجز والاسترداد المعتمدة لهذا المكان فور التأكيد.',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Color(0xFFDC2626),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: confirming ? null : () => Navigator.pop(ctx, null),
                          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: confirming
                              ? null
                              : () {
                                  final text = controller.text.trim();
                                  if (text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('يرجى إدخال السبب للمتابعة')),
                                    );
                                    return;
                                  }
                                  setSheetState(() => confirming = true);
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(ctx, text);
                                },
                          child: Text(
                            confirming ? 'جار التأكيد…' : 'تأكيد الإجراء',
                            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> handleActionWithReason(String action) async {
    String title = 'تأكيد الإجراء';
    String hint = 'أدخل السبب...';
    bool isDestructive = false;
    if (action == 'reject') {
      title = 'رفض طلب الحجز';
      hint = 'وضح للمستأجر سبب رفض الطلب...';
      isDestructive = true;
    } else if (action == 'cancel') {
      title = 'إلغاء الحجز نهائياً';
      hint = 'أدخل سبب إلغاء هذا الحجز وتوضيح شروط الاسترداد...';
      isDestructive = true;
    } else if (action == 'rejectPayment') {
      title = 'رفض إيصال الدفع';
      hint = 'وضح سبب رفض الإيصال (مثال: غير واضح، المبلغ ناقص)...';
      isDestructive = true;
    }
    final entered = await promptReason(title, hint, isDestructive: isDestructive);
    if (entered == null) return;
    reason.text = entered;
    await act(action, {'reason': entered});
  }

  Future<void> act(String action,
      [Map<String, dynamic> extra = const {}]) async {
    if (['reject', 'cancel', 'rejectPayment'].contains(action) && !extra.containsKey('reason')) {
      await handleActionWithReason(action);
      return;
    }
    if (busy) return;
    setState(() => busy = true);
    await bookingRun(context, () async {
      await widget.call('actOnBooking', {
        'bookingId': widget.bookingId,
        'action': action,
        'reason': reason.text,
        ...extra
      });
      if (mounted) {
        final actionLabels = {
          'confirm': 'تم تأكيد الحجز بنجاح',
          'reject': 'تم رفض طلب الحجز',
          'cancel': 'تم إلغاء الحجز',
          'arrive': 'تم تسجيل وصول الضيف بنجاح',
          'complete': 'تم إنهاء الحجز وتسليم المكان بنجاح',
          'hold': 'تم تعليق الحجز لانتظار العربون',
        };
        final label = actionLabels[action] ?? 'تم تنفيذ الإجراء بنجاح';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: bookingGold, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Cairo'))),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('تفاصيل الحجز')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _bookingStream,
          builder: (context, s) {
            if (s.hasData && s.data != null && s.data!.data() != null) {
              _cachedSnapshot = s.data;
            }
            final snap = s.data ?? _cachedSnapshot;
            if (s.hasError && snap == null) {
              return const Center(child: Text('لا تملك صلاحية عرض هذا الحجز'));
            }
            if (snap == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final b = snap.data();
            if (b == null) return const Center(child: Text('الحجز غير موجود'));
            final uid = currentUid(),
                owner = uid == b['ownerId'],
                customer = uid == b['customerId'];
            if (!bookingCanDisplayDetails(
                uid: uid,
                booking: b,
                admin: admin,
                finance: finance,
                privilegedUid: privilegedUid)) {
              if (owner || customer) {
                // Owner or customer can view their booking
              } else {
                return const Center(child: Text('لا تملك صلاحية عرض هذا الحجز'));
              }
            }
            final holdDeadline = bookingHoldDeadline(b['holdUntil']);
            final held = b['status'] == 'held' &&
                holdDeadline != null &&
                holdDeadline.isAfter(DateTime.now());
            Widget button(String label, String action) => FilledButton(
                onPressed: busy ? null : () => act(action), child: Text(label));
            return SingleChildScrollView(
              key: PageStorageKey('booking-details-${widget.bookingId}'),
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (b['status'] == 'held' && holdDeadline == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: BookingStateView(
                          title: 'تعذر التحقق من مهلة العربون',
                          detail: 'حدّث الحجز أو تواصل مع الدعم قبل إرسال أي دفعة.',
                          icon: Icons.info_outline),
                    ),
                  if (b['status'] == 'held' && holdDeadline != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BookingHoldNotice(
                          compact: true,
                          until: holdDeadline,
                          onExpired: () {
                            if (mounted) setState(() {});
                          }),
                    ),
                Semantics(
                    liveRegion: true,
                    child: Text(bookingStatusLabel(b['status']),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700))),
                BookingReservationHeader(
                    booking: b,
                    id: widget.bookingId,
                    venue: widget.displayVenue),
                ExpansionTile(
                    maintainState: true,
                    title: const Text('بيانات الحجز الكاملة'),
                    children: [
                      BookingSummary(
                          booking: b,
                          status: bookingStatusLabel(b['status']))
                    ]),
                ExpansionTile(
                    maintainState: true,
                    key: const PageStorageKey('booking-tools-3'),
                    title: const Text('مراحل الحجز'),
                    children: [BookingProgress(status: canonicalBookingStatus(b['status']))]),
                if (customer && b['status'] == 'completed') ...[
                  DropdownButtonFormField<int>(
                      initialValue: rating,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'تقييم تجربة الحجز'),
                      items: [
                        for (var i = 1; i <= 5; i++)
                          DropdownMenuItem(value: i, child: Text('$i / 5', overflow: TextOverflow.ellipsis))
                      ],
                      onChanged:
                          busy ? null : (v) => setState(() => rating = v ?? 5)),
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => bookingRun(context, () async {
                                await widget.call('reviewCompletedBooking', {
                                  'bookingId': widget.bookingId,
                                  'rating': rating,
                                  'comment': reason.text
                                });
                              }),
                      child: const Text(
                          'إرسال التقييم — اكتب تعليقك في حقل الملاحظات')),
                ],

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _eventsStream,
                    builder: (context, events) {
                      if (events.hasError) {
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
                  BookingManualSettlement(
                      key:
                          ValueKey('owner-${widget.bookingId}-${b['version']}'),
                      bookingId: widget.bookingId,
                      action: 'settleOwner',
                      version: b['version'] is int ? b['version'] : null,
                      loadPreview: () => widget.call(
                              'getBookingFinancePreview', {
                            'bookingId': widget.bookingId,
                            'action': 'settleOwner'
                          }),
                      title: 'تسوية مستحقات المالك',
                      reference: refundReference,
                      busy: busy,
                      label: 'تسجيل تسوية مستحقات المالك يدويًا',
                      onSubmit: () => act('settleOwner',
                          {'settlementReference': refundReference.text})),
                if (customer && b['status'] == 'confirmed')
                  FilledButton.icon(
                      icon: const Icon(Icons.qr_code),
                      label: const Text('رمز الوصول — صالح 10 دقائق'),
                      onPressed: busy
                          ? null
                          : () => guarded(() async {
                                final issuedUid = currentUid();
                                if (issuedUid == null) return;
                                final result = await widget.call(
                                    'issueBookingCheckInCode',
                                    {'bookingId': widget.bookingId});
                                if (context.mounted &&
                                    currentUid() == issuedUid)
                                  await showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                          child: SingleChildScrollView(
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(24),
                                                  child: BookingQrPass(
                                                      code: result['code'],
                                                      issuedUid: issuedUid,
                                                      currentUserId: currentUid,
                                                      sessions: widget
                                                              .sessions ??
                                                          FirebaseAuth.instance
                                                              .authStateChanges()
                                                              .map((u) =>
                                                                  u?.uid),
                                                      expiresAt:
                                                          bookingHoldDeadline(
                                                              result[
                                                                  'expiresAt']))))));
                              })),

                if (['confirmed', 'arrived', 'completed', 'held'].contains(b['status'])) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    key: const ValueKey('booking-receipt-pdf-btn'),
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: bookingGold),
                    label: const Text('تحميل ومشاركة إيصال الحجز (PDF)',
                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bookingNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: busy
                        ? null
                        : () async {
                            HapticFeedback.selectionClick();
                            try {
                              final vSnap = widget.displayVenue ?? (b['venueSnapshot'] is Map ? Map<String, dynamic>.from(b['venueSnapshot']) : null);
                              await BookingReceiptService.shareReceipt(
                                booking: b,
                                bookingId: widget.bookingId,
                                venue: vSnap,
                                context: context,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('تعذر إنشاء الإيصال: $e')),
                                );
                              }
                            }
                          },
                  ),
                ],

                if (owner && ['confirmed', 'arrived'].contains(b['status']))
                  TextButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('مسح رمز الوصول بالكاميرا'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: widget.scannerPage ??
                                  (_) => BookingScannerScreen(
                                      bookingId: widget.bookingId)))),
                if (owner && b['status'] == 'confirmed')
                  button('تسجيل الوصول', 'arrive'),
                if (owner && b['status'] == 'confirmed')
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => bookingRun(context, () async {
                                await widget.call('verifyBookingCheckInCode', {
                                  'code': reason.text.trim(),
                                  'bookingId': widget.bookingId
                                });
                              }),
                      child: const Text(
                          'تحقق من رمز الوصول الملصق في حقل الملاحظات')),
                if (owner && ['confirmed', 'arrived'].contains(b['status']))
                  button('إنهاء الحجز بعد موعد الخروج', 'complete'),
                BookingAgreedPolicy(booking: b),
                if (b['pricing'] is Map &&
                    ((b['pricing'] as Map)['name'] != null ||
                        (b['pricing'] as Map)['kind'] != null ||
                        (b['pricing'] as Map)['id'] != null))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text('التسعير والفترة:'),
                        BookingPeriodBadge(shift: b['pricing']),
                      ],
                    ),
                  )
                else if (b['pricing'] != null)
                  Text(
                      'التسعير: ${b['pricing'] is Map ? (b['pricing']['name'] ?? b['pricing']['mode'] ?? '') : b['pricing']}'),
                BookingRecordedMoney(booking: b),
                if (b['reviewedBy'] != null)
                  Text('مراجع العربون: ${b['reviewedBy']}'),
                if (b['cancelledBy'] != null)
                  Text(
                      'ألغاه: ${b['cancelledBy']} — السبب: ${b['cancellationReason'] ?? b['reason']}'),
                if (b['refundReference'] != null)
                  Text(
                      'مرجع الاسترداد: ${b['refundReference']}\nالمراجع: ${b['refundSettledBy'] ?? 'الإدارة'}\nوقت التسوية: ${b['refundSettledAt'] is num ? DateTime.fromMillisecondsSinceEpoch((b['refundSettledAt'] as num).toInt()).toString() : (b['refundSettledAt'] ?? 'غير محدد')}'),
                if (finance &&
                    !owner &&
                    !customer &&
                    b['refundStatus'] == 'pending')
                  BookingManualSettlement(
                      key: ValueKey(
                          'refund-${widget.bookingId}-${b['version']}'),
                      bookingId: widget.bookingId,
                      action: 'settleRefund',
                      version: b['version'] is int ? b['version'] : null,
                      loadPreview: () => widget.call(
                              'getBookingFinancePreview', {
                            'bookingId': widget.bookingId,
                            'action': 'settleRefund'
                          }),
                      title: 'إعادة العربون المستحق',
                      reference: refundReference,
                      busy: busy,
                       label: 'تسجيل إعادة المبلغ يدوياً',
                      onSubmit: () => act('settleRefund',
                          {'refundReference': refundReference.text})),
                if (b['receiptPath'] != null &&
                    b['receiptPath'].toString().trim().isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('عرض الإيصال'),
                    onPressed: busy
                        ? null
                        : () => bookingRun(context, () async {
                              final bytes = widget.readReceiptBytes != null
                                  ? await widget.readReceiptBytes!()
                                  : await FirebaseStorage.instance
                                      .ref(b['receiptPath'].toString())
                                      .getData(10 * 1024 * 1024);
                              if (!context.mounted ||
                                  bytes == null ||
                                  bytes.isEmpty) {
                                return;
                              }
                              await showDialog<void>(
                                context: context,
                                builder: (ctx) => Dialog(
                                  child: InteractiveViewer(
                                    child: Image.memory(
                                      bytes,
                                      errorBuilder: (_, __, ___) =>
                                          const Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                            'تعذر عرض صورة الإيصال المالي'),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                  ),
                if (owner && b['status'] == 'requested') ...[
                  button('موافقة وحجز مؤقت', 'approve'),
                  button('رفض الطلب', 'reject')
                ],
                if (customer && held)
                  BookingPaymentPanel(
                      deposit: b['deposit'],
                      receiptBytes: receiptBytes,
                      onPickReceipt: pickReceipt,
                      accounts: accounts,
                      method: method,
                      transaction: transaction,
                      busy: busy,
                      onMethod: (value) => setState(() {
                            method = value;
                            displayedNumber = (accounts[method] as Map?)?['number']?.toString();
                          }),
                      onSubmit: busy ||
                              displayedNumber == null ||
                              receiptBytes == null
                          ? null
                          : () async {
                              if (busy) return;
                              final expectedNumber = displayedNumber;
                              final selectedMethod = method;
                              setState(() => busy = true);
                              await bookingRun(context, () async {
                                final bytes = receiptBytes!;
                                if (widget.submitReceipt != null) {
                                  await widget.submitReceipt!(
                                      bytes, selectedMethod, transaction.text);
                                  return;
                                }
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
                                  await widget
                                      .call('discardInvalidBookingReceipt', {
                                    'bookingId': widget.bookingId,
                                    'path': path,
                                  });
                                });

                                await widget.call('actOnBooking', {
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
                // الإجراءات السفلية الأربعة الموحدة
                if (owner || customer || admin) ...[
                  const SizedBox(height: 20),
                  const Text('إجراءات الحجز',
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 1. محادثة الحجز (تُفعل بعد تأكيد العربون)
                      Expanded(
                        child: _BookingUnifiedActionTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: const Color(0xFF64748B),
                          label: 'محادثة الحجز',
                          enabled: !busy && ['confirmed', 'arrived', 'completed'].contains(b['status']),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: widget.chatPage ??
                                      (_) => BookingChatScreen(
                                          bookingId: widget.bookingId))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 2. طلب دعم (يظهر مرة واحدة فقط)
                      Expanded(
                        child: _BookingUnifiedActionTile(
                          icon: Icons.support_agent_rounded,
                          iconColor: const Color(0xFF64748B),
                          label: 'طلب دعم',
                          enabled: !busy,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: widget.supportPage ??
                                      (_) => BookingSupportScreen(
                                          bookingId: widget.bookingId))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 3. إلغاء الحجز
                      Expanded(
                        child: _BookingUnifiedActionTile(
                          icon: Icons.cancel_outlined,
                          iconColor: const Color(0xFF64748B),
                          label: 'إلغاء الحجز',
                          enabled: !busy && ['requested', 'held', 'confirmed', 'payment_review'].contains(b['status']),
                          onTap: () => act('cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 4. إرسال بلاغ
                      Expanded(
                        child: _BookingUnifiedActionTile(
                          icon: Icons.flag_outlined,
                          iconColor: const Color(0xFF64748B),
                          label: 'إرسال بلاغ',
                          enabled: !busy,
                          onTap: () async {
                            final entered = await promptReason(
                                'تقديم بلاغ للإدارة',
                                'وضح سبب البلاغ للإدارة...');
                            if (entered == null || entered.trim().isEmpty) return;
                            if (!context.mounted) return;
                            await bookingRun(context, () async {
                              await widget.call('reportBooking', {
                                'bookingId': widget.bookingId,
                                'reason': entered.trim()
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('تم إرسال البلاغ بنجاح')));
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }));
}


class _BookingUnifiedActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _BookingUnifiedActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E222D) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: enabled
                    ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF5A6E7C))
                    : Colors.grey.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? (isDark ? Colors.white : const Color(0xFF1E293B))
                      : Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingVenueEditor extends StatefulWidget {
  final BookingMediaCall call;
  final VoidCallback? onSaved;
  final BookingMediaLocalHooks? localMediaHooks;
  final bool ownerMode;
  final String? venueId;
  final Map<String, dynamic> data;
  const BookingVenueEditor(
      {super.key,
      this.venueId,
      this.data = const {},
      this.ownerMode = false,
      this.call = bookingCall,
      this.localMediaHooks,
      this.onSaved});
  @override
  State<BookingVenueEditor> createState() => _BookingVenueEditorState();
}

class _BookingVenueEditorState extends State<BookingVenueEditor> {
  late bool morningActive;
  late final TextEditingController morningInCtrl;
  late final TextEditingController morningOutCtrl;
  late final TextEditingController morningPriceCtrl;
  late final String morningId;

  late bool eveningActive;
  late final TextEditingController eveningInCtrl;
  late final TextEditingController eveningOutCtrl;
  late final TextEditingController eveningPriceCtrl;
  late final String eveningId;

  late bool fullDayActive;
  late final TextEditingController fullDayInCtrl;
  late final TextEditingController fullDayOutCtrl;
  late final TextEditingController fullDayPriceCtrl;
  late final String fullDayId;

  @override
  void initState() {
    super.initState();
    final rawShifts = (widget.data['shifts'] as List? ?? []);
    Map? findShift(String kw) {
      for (final s in rawShifts) {
        if (s is Map) {
          final n = (s['name']?.toString() ?? '').toLowerCase();
          final id = (s['id']?.toString() ?? '').toLowerCase();
          if (n.contains(kw) || id.contains(kw)) {
            return s;
          }
        }
      }
      return null;
    }

    final mShift = findShift('صباح') ?? findShift('morning');
    final eShift = findShift('مساء') ?? findShift('مسائ') ?? findShift('night') ?? findShift('evening');
    final fShift = findShift('كامل') ?? findShift('يوم') ?? findShift('fullday');

    final bool hasExisting = rawShifts.isNotEmpty;

    morningActive = mShift != null || (!hasExisting && widget.data['pricingMode'] == 'shifts');
    morningId = mShift?['id']?.toString() ?? 'shift_morning_${DateTime.now().microsecondsSinceEpoch}';
    morningInCtrl = TextEditingController(text: bookingTime12(mShift?['checkInMinute'] ?? 480));
    morningOutCtrl = TextEditingController(text: bookingTime12(mShift?['checkOutMinute'] ?? 840));
    morningPriceCtrl = TextEditingController(text: (mShift?['price'] ?? 100000).toString());

    eveningActive = eShift != null || (!hasExisting && widget.data['pricingMode'] == 'shifts');
    eveningId = eShift?['id']?.toString() ?? 'shift_evening_${DateTime.now().microsecondsSinceEpoch}';
    eveningInCtrl = TextEditingController(text: bookingTime12(eShift?['checkInMinute'] ?? 900));
    eveningOutCtrl = TextEditingController(text: bookingTime12(eShift?['checkOutMinute'] ?? 1380));
    eveningPriceCtrl = TextEditingController(text: (eShift?['price'] ?? 150000).toString());

    fullDayActive = fShift != null;
    fullDayId = fShift?['id']?.toString() ?? 'shift_fullday_${DateTime.now().microsecondsSinceEpoch}';
    fullDayInCtrl = TextEditingController(text: bookingTime12(fShift?['checkInMinute'] ?? 480));
    fullDayOutCtrl = TextEditingController(text: bookingTime12(fShift?['checkOutMinute'] ?? 1380));
    fullDayPriceCtrl = TextEditingController(text: (fShift?['price'] ?? 250000).toString());
  }

  Future<void> _pickShiftTime(BuildContext context, TextEditingController controller) async {
    final current = bookingMinute(controller.text) ?? 480;
    final initialTime = TimeOfDay(hour: (current ~/ 60) % 24, minute: current % 60);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Localizations.override(
        context: context,
        locale: const Locale('ar'),
        child: child,
      ),
    );
    if (picked != null) {
      final totalMinutes = picked.hour * 60 + picked.minute;
      controller.text = bookingTime12(totalMinutes);
      setState(() {});
    }
  }
  late final fields = {
    for (final k in [
      'name',
      'ownerId',
      'location',
      'capacity',
      'bedrooms',
      'bathrooms',
      'pools',
      'parkingSpots',
      'area',
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
  late String pricingMode = () {
    final pm = widget.data['pricingMode']?.toString();
    if (['fixed', 'shifts', 'hourly'].contains(pm)) return pm!;
    return 'fixed';
  }();
  late String guestType = () {
    final gt = widget.data['guestType']?.toString();
    if (['families', 'youth', 'both'].contains(gt)) return gt!;
    return 'both';
  }();
  List<Map<String, dynamic>> get compiledShifts => [
    if (morningActive)
      {
        'id': morningId,
        'name': 'الفترة الصباحية',
        'checkInMinute': bookingMinute(morningInCtrl.text) ?? 480,
        'checkOutMinute': bookingMinute(morningOutCtrl.text) ?? 840,
        'price': int.tryParse(morningPriceCtrl.text) ?? 0,
      },
    if (eveningActive)
      {
        'id': eveningId,
        'name': 'الفترة المسائية',
        'checkInMinute': bookingMinute(eveningInCtrl.text) ?? 900,
        'checkOutMinute': bookingMinute(eveningOutCtrl.text) ?? 1380,
        'price': int.tryParse(eveningPriceCtrl.text) ?? 0,
      },
    if (fullDayActive)
      {
        'id': fullDayId,
        'name': 'يوم كامل',
        'checkInMinute': bookingMinute(fullDayInCtrl.text) ?? 480,
        'checkOutMinute': bookingMinute(fullDayOutCtrl.text) ?? 1380,
        'price': int.tryParse(fullDayPriceCtrl.text) ?? 0,
      },
  ];
  late final amenities = Set<String>.from(widget.data['amenities'] is Iterable ? widget.data['amenities'] : []);
  late String category = () {
    final c = widget.data['category']?.toString();
    if (['chalet', 'farm', 'hall', 'other'].contains(c)) return c!;
    return 'chalet';
  }();
  late bool active = widget.data['active'] ?? false;
  bool busy = false;
  final Map<String, String> _fieldErrors = {};
  bool _isRequiredEditorField(String key) =>
      key == 'name' ||
      key == 'location' ||
      key == 'terms' ||
      key == 'freeCancellationHours' ||
      key == 'lateRefundPercent' ||
      (!widget.ownerMode && (key == 'ownerId' || key == 'deposit')) ||
      (pricingMode == 'fixed' && key == 'price') ||
      (pricingMode == 'hourly' && key == 'hourlyPrice');
  bool _uploadingMedia = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  String? _uploadError;
  Future<void> Function()? _retryUploadTask;

  Future<void> _startMediaUpload({required bool video}) async {
    final task = () async {
      setState(() {
        _uploadingMedia = true;
        _uploadProgress = 0.05;
        _uploadStatus = video ? 'جارٍ اختيار مقطع الفيديو...' : 'جارٍ اختيار الصورة...';
        _uploadError = null;
      });
      Uint8List? bytes;
      if (widget.localMediaHooks != null) {
        widget.localMediaHooks!.checkLocalOnly();
        bytes = await widget.localMediaHooks!.pick(video);
      } else {
        final file = video
            ? await ImagePicker().pickVideo(source: ImageSource.gallery)
            : await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 2000,
                imageQuality: 90);
        if (file == null) {
          if (mounted) setState(() => _uploadingMedia = false);
          return;
        }
        if (await file.length() > (video ? 50 : 10) * 1024 * 1024) {
          throw StateError('حجم الملف يتجاوز الحد المسموح به (${video ? 50 : 10} ميغابايت)');
        }
        setState(() {
          _uploadProgress = 0.15;
          _uploadStatus = 'جارٍ ضغط ومعالجة الملف...';
        });
        bytes = video
            ? await file.readAsBytes()
            : await FlutterImageCompress.compressWithList(
                await file.readAsBytes(),
                format: CompressFormat.jpeg,
                quality: 85);
      }
      if (bytes == null || bytes.isEmpty) {
        if (mounted) setState(() => _uploadingMedia = false);
        return;
      }
      if (video) {
        await BookingMediaService.uploadVideo(
          bytes,
          widget.venueId!,
          widget.call,
          onProgress: (p, s) {
            if (mounted) {
              setState(() {
                _uploadProgress = p;
                _uploadStatus = s;
              });
            }
          },
        );
      } else {
        if (mounted) {
          setState(() {
            _uploadProgress = 0.5;
            _uploadStatus = 'جارٍ رفع الصورة إلى الخادم...';
          });
        }
        await BookingMediaService.uploadImage(
          bytes,
          widget.call,
          venueId: widget.venueId!,
        );
      }
      if (mounted) {
        setState(() {
          _uploadingMedia = false;
          _uploadProgress = 1.0;
          _uploadStatus = 'اكتمل الرفع بنجاح — بانتظار مراجعة الإدارة';
          _uploadError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الملف بانتظار مراجعة الإدارة')),
        );
      }
    };
    _retryUploadTask = () => editorTask(task);
    try {
      await editorTask(task);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingMedia = false;
          _uploadError = e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '');
        });
      }
    }
  }

  Widget _buildMediaUploadProgressCard() {
    if (!_uploadingMedia && _uploadError == null && _uploadStatus.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSuccess = !_uploadingMedia && _uploadError == null && _uploadProgress >= 1.0;
    final isError = _uploadError != null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFEF4444).withValues(alpha: 0.08)
            : isSuccess
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : isSuccess
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : bookingGold.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.cloud_upload_rounded,
                size: 20,
                color: isError
                    ? const Color(0xFFEF4444)
                    : isSuccess
                        ? const Color(0xFF10B981)
                        : bookingGold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isError
                      ? 'تعذر رفع الملف'
                      : isSuccess
                          ? 'اكتملت عملية الرفع'
                          : 'جارٍ رفع الوسائط...',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_uploadingMedia)
                Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: bookingGold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_uploadingMedia)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(bookingGold),
                minHeight: 6,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            isError ? (_uploadError ?? 'حدث خطأ أثناء الرفع') : _uploadStatus,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              color: isError
                  ? const Color(0xFFEF4444)
                  : (isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ),
          if (isError && _retryUploadTask != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFFEF4444),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('إعادة المحاولة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: busy ? null : () => _retryUploadTask!(),
              ),
            ),
          ],
        ],
      ),
    );
  }
  @override
  void dispose() {
    morningInCtrl.dispose();
    morningOutCtrl.dispose();
    morningPriceCtrl.dispose();
    eveningInCtrl.dispose();
    eveningOutCtrl.dispose();
    eveningPriceCtrl.dispose();
    fullDayInCtrl.dispose();
    fullDayOutCtrl.dispose();
    fullDayPriceCtrl.dispose();
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

  Stream<DocumentSnapshot<Map<String, dynamic>>> _venueMediaStream() {
    try {
      return mediaDocument(FirebaseFirestore.instance
          .doc('booking_venues/${widget.venueId}')
          .snapshots(includeMetadataChanges: true));
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _venueMediaReviewsStream() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      return mediaQuery(FirebaseFirestore.instance
          .collection('booking_media_reviews')
          .where('venueId', isEqualTo: widget.venueId)
          .where('ownerId', isEqualTo: uid)
          .snapshots(includeMetadataChanges: true));
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<T> mediaDocument<T>(Stream<T> source) {
    widget.localMediaHooks?.checkLocalOnly();
    return widget.localMediaHooks?.document(source) ?? source;
  }

  Stream<T> mediaQuery<T>(Stream<T> source) {
    widget.localMediaHooks?.checkLocalOnly();
    return widget.localMediaHooks?.query(source) ?? source;
  }

  Widget editorField(String key) {
    final e = MapEntry(key, fields[key]!);
    final isRequired = _isRequiredEditorField(key);
    return TextField(
        controller: e.value,
        onChanged: (_) {
          if (_fieldErrors.containsKey(key)) {
            setState(() => _fieldErrors.remove(key));
          }
        },
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5),
        decoration: InputDecoration(
            errorText: _fieldErrors[key],
            suffix: isRequired
                ? const Text('*',
                    style: TextStyle(
                        color: Color(0xFFDC2626), fontWeight: FontWeight.bold))
                : null,
            labelText: const {
              'capacity': 'السعة القصوى (ضيوف)',
              'bedrooms': 'عدد الغرف',
              'bathrooms': 'عدد الحمامات',
              'pools': 'عدد المسابح',
              'parkingSpots': 'عدد مواقف السيارات',
              'area': 'المساحة الإجمالية (م²)',
              'complexName': 'اسم المنتجع أو المجمع (اختياري)',
              'unitName': 'اسم الوحدة أو الشاليه الفرعي (مثل: شاليه 1 أو فيلا A)',
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
            }[e.key],
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5),
            floatingLabelStyle: const TextStyle(
                fontFamily: 'Cairo', fontSize: 11.0, fontWeight: FontWeight.bold),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        keyboardType: [
          'latitude',
          'longitude',
          'capacity',
          'bedrooms',
          'bathrooms',
          'pools',
          'parkingSpots',
          'area',
          'commissionPercent',
          'price',
          'deposit',
          'hourlyPrice',
          'freeCancellationHours',
          'lateRefundPercent'
        ].contains(e.key)
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : null,
        textDirection: ['latitude', 'longitude'].contains(e.key)
            ? TextDirection.ltr
            : null,
        enabled: !busy,
        readOnly: widget.ownerMode && e.key == 'commissionPercent',
        maxLines: e.key == 'terms' ? 4 : 1);
  }

  Widget _buildShiftCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isActive,
    required ValueChanged<bool> onToggle,
    required TextEditingController inCtrl,
    required TextEditingController outCtrl,
    required TextEditingController priceCtrl,
    required VoidCallback onPickIn,
    required VoidCallback onPickOut,
  }) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final visual = BookingShiftVisual.resolve(title);
    final accentColor = visual.accentColor;
    final iconFg = visual.foreground(brightness);
    final iconBg = visual.background(brightness);
    final iconBorder = visual.border(brightness);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? accentColor.withValues(alpha: 0.75)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: iconBorder,
                      width: 0.9,
                    ),
                  ),
                  child: Icon(visual.icon, color: iconFg, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: isActive
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : Theme.of(context).disabledColor,
                        ),
                      ),
                      Text(
                        isActive ? 'مفعلة للحجز' : 'معطلة (غير متاحة للحجز)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: isActive
                              ? (isDark ? Colors.white70 : Colors.black54)
                              : Theme.of(context).disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  activeThumbColor: accentColor,
                  onChanged: busy ? null : onToggle,
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: busy ? null : onPickIn,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'وقت الدخول',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Cairo',
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: accentColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    inCtrl.text.isEmpty ? 'اختر' : inCtrl.text,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: busy ? null : onPickOut,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'وقت الخروج',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Cairo',
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.logout_rounded, size: 14, color: accentColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    outCtrl.text.isEmpty ? 'اختر' : outCtrl.text,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                enabled: !busy,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'سعر الفترة (د.ع)',
                  labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                  floatingLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                  prefixIcon: Icon(Icons.payments_outlined, size: 18, color: accentColor),
                  suffixText: 'د.ع',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static int _tabForField(String key) {
    switch (key) {
      case 'deposit':
      case 'commissionPercent':
      case 'price':
      case 'hourlyPrice':
      case 'freeCancellationHours':
      case 'lateRefundPercent':
        return 1;
      case 'location':
      case 'latitude':
      case 'longitude':
        return 2;
      case 'terms':
        return 4;
      default:
        return 0;
    }
  }

  Widget saveButton(BuildContext tabContext) => FilledButton(
      onPressed: busy
          ? null
          : () async {
              if (busy) return;
              final errors = <String, String>{};
              void putErr(String k, String? msg) {
                if (msg != null) errors[k] = msg;
              }

              putErr(
                  'name',
                  BookingFormValidator.requiredText(fields['name']!.text,
                      fieldName: 'اسم المكان', minLength: 2, maxLength: 120));
              putErr(
                  'location',
                  BookingFormValidator.requiredText(fields['location']!.text,
                      fieldName: 'الموقع', minLength: 2, maxLength: 200));
              putErr(
                  'terms',
                  BookingFormValidator.requiredText(fields['terms']!.text,
                      fieldName: 'شروط المكان', minLength: 3, maxLength: 5000));
              if (!widget.ownerMode) {
                putErr(
                    'ownerId',
                    BookingFormValidator.requiredText(fields['ownerId']!.text,
                        fieldName: 'معرف حساب المالك',
                        minLength: 2,
                        maxLength: 128));
                putErr(
                    'deposit',
                    BookingFormValidator.intRangeError(fields['deposit']!.text,
                        fieldName: 'العربون بالدينار',
                        min: 1,
                        max: 1000000000));
              }
              if (pricingMode == 'fixed') {
                putErr(
                    'price',
                    BookingFormValidator.intRangeError(fields['price']!.text,
                        fieldName: 'السعر الثابت', min: 1, max: 1000000000));
              } else if (pricingMode == 'hourly') {
                putErr(
                    'hourlyPrice',
                    BookingFormValidator.intRangeError(
                        fields['hourlyPrice']!.text,
                        fieldName: 'سعر الساعة',
                        min: 1,
                        max: 1000000000));
              }
              putErr(
                  'freeCancellationHours',
                  BookingFormValidator.intRangeError(
                      fields['freeCancellationHours']!.text,
                      fieldName: 'الإلغاء المجاني',
                      min: 0,
                      max: 8760));
              putErr(
                  'lateRefundPercent',
                  BookingFormValidator.intRangeError(
                      fields['lateRefundPercent']!.text,
                      fieldName: 'استرداد العربون',
                      min: 0,
                      max: 100));
              for (final key in [
                'capacity',
                'bedrooms',
                'bathrooms',
                'pools',
                'parkingSpots',
                'area'
              ]) {
                putErr(
                    key,
                    BookingFormValidator.intRangeError(fields[key]!.text,
                        fieldName: key, min: 0, max: 100000, required: false));
              }
              final coordinateError = bookingCoordinateError(
                  fields['latitude']!.text, fields['longitude']!.text);
              if (coordinateError != null) {
                errors['latitude'] = coordinateError;
                errors['longitude'] = coordinateError;
              }
              if (errors.isNotEmpty) {
                setState(() {
                  _fieldErrors
                    ..clear()
                    ..addAll(errors);
                });
                DefaultTabController.maybeOf(tabContext)
                    ?.animateTo(_tabForField(errors.keys.first));
                ScaffoldMessenger.of(tabContext).showSnackBar(SnackBar(
                  content: Text(errors.values.first),
                ));
                return;
              }
              if (_fieldErrors.isNotEmpty) {
                setState(() => _fieldErrors.clear());
              }
              setState(() => busy = true);
              await bookingRun(tabContext, () async {
                if (pricingMode == 'shifts') {
                  if (!morningActive && !eveningActive && !fullDayActive) {
                    throw StateError('يجب تفعيل فترة واحدة على الأقل في نظام الفترات اليومية');
                  }
                  if (morningActive) {
                    final inM = bookingMinute(morningInCtrl.text);
                    final outM = bookingMinute(morningOutCtrl.text);
                    final p = int.tryParse(morningPriceCtrl.text) ?? 0;
                    if (inM == null || outM == null) throw StateError('يرجى تحديد أوقات الفترة الصباحية');
                    if (inM == outM) throw StateError('وقت الدخول والخروج للفترة الصباحية متطابق');
                    if (p <= 0) throw StateError('يرجى إدخال سعر صحيح للفترة الصباحية');
                  }
                  if (eveningActive) {
                    final inM = bookingMinute(eveningInCtrl.text);
                    final outM = bookingMinute(eveningOutCtrl.text);
                    final p = int.tryParse(eveningPriceCtrl.text) ?? 0;
                    if (inM == null || outM == null) throw StateError('يرجى تحديد أوقات الفترة المسائية');
                    if (inM == outM) throw StateError('وقت الدخول والخروج للفترة المسائية متطابق');
                    if (p <= 0) throw StateError('يرجى إدخال سعر صحيح للفترة المسائية');
                  }
                  if (fullDayActive) {
                    final inM = bookingMinute(fullDayInCtrl.text);
                    final outM = bookingMinute(fullDayOutCtrl.text);
                    final p = int.tryParse(fullDayPriceCtrl.text) ?? 0;
                    if (inM == null || outM == null) throw StateError('يرجى تحديد أوقات اليوم الكامل');
                    if (inM == outM) throw StateError('وقت الدخول والخروج لليوم الكامل متطابق');
                    if (p <= 0) throw StateError('يرجى إدخال سعر صحيح لليوم الكامل');
                  }
                  if (morningActive && eveningActive) {
                    final mOut = bookingMinute(morningOutCtrl.text) ?? 840;
                    final eIn = bookingMinute(eveningInCtrl.text) ?? 900;
                    if (mOut > eIn) {
                      throw StateError('وقت نهاية الفترة الصباحية يتداخل مع وقت بداية الفترة المسائية');
                    }
                  }
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
                  'capacity': int.tryParse(fields['capacity']!.text) ?? 0,
                  'bedrooms': int.tryParse(fields['bedrooms']!.text) ?? 0,
                  'bathrooms': int.tryParse(fields['bathrooms']!.text) ?? 0,
                  'pools': int.tryParse(fields['pools']!.text) ?? 0,
                  'parkingSpots': int.tryParse(fields['parkingSpots']!.text) ?? 0,
                  'area': int.tryParse(fields['area']!.text) ?? 0,
                  'amenities': amenities.toList(),
                  'pricingMode': pricingMode,
                  'shifts': compiledShifts,
                  'cancellationPolicy': {
                    'freeCancellationHours':
                        int.tryParse(fields['freeCancellationHours']!.text),
                    'lateRefundPercent':
                        int.tryParse(fields['lateRefundPercent']!.text)
                  },
                  'category': category,
                  'guestType': guestType,
                  'active': active,
                  'commissionBps':
                      ((double.tryParse(fields['commissionPercent']!.text) ??
                                  0) *
                              100)
                          .round(),
                  'latitude': double.tryParse(fields['latitude']!.text),
                  'longitude': double.tryParse(fields['longitude']!.text),
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
      child: const Text('حفظ بيانات المكان'));

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
                    Tab(text: 'البيانات الأساسية'),
                    Tab(text: 'الأسعار والفترات'),
                    Tab(text: 'الموقع الجغرافي'),
                    Tab(text: 'المزايا والمرافق'),
                    Tab(text: 'الوسائط والشروط')
                  ])),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Builder(
                builder: (tabContext) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            busy
                                ? 'الحفظ معطل أثناء تنفيذ الطلب.'
                                : 'يحفظ جميع التبويبات؛ لا تحتاج للانتقال إلى المراجعة للحفظ.',
                            style: const TextStyle(fontSize: 12, height: 1.6)),
                        saveButton(tabContext)
                      ]),
                ),
              )),
          body: TabBarView(children: [
            // 0: التفاصيل
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
                  DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'تصنيف المكان'),
                      items: [
                        for (final e in {
                          'chalet': 'شاليه',
                          'farm': 'مزرعة',
                          'hall': 'قاعة',
                          'other': 'أخرى'
                        }.entries)
                          DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value,
                                  maxLines: 1, overflow: TextOverflow.ellipsis))
                      ],
                      onChanged: busy ? null : (v) => setState(() => category = v!)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                      initialValue: guestType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'فئة الضيوف المسموح بها'),
                      items: const [
                        DropdownMenuItem(
                            value: 'families',
                            child: Text('عوائل فقط',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'youth',
                            child: Text('شباب فقط',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'both',
                            child: Text('عوائل وشباب',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: busy ? null : (v) => setState(() => guestType = v ?? 'both')),
                  editorField('name'),
                  editorField('complexName'),
                  editorField('unitName'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: editorField('capacity')),
                    const SizedBox(width: 8),
                    Expanded(child: editorField('bedrooms')),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: editorField('bathrooms')),
                    const SizedBox(width: 8),
                    Expanded(child: editorField('pools')),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: editorField('parkingSpots')),
                    const SizedBox(width: 8),
                    Expanded(child: editorField('area')),
                  ]),
                ]),

            // 1: الأسعار والفترات
            BookingEditorPage(
                title: 'أسعار واضحة لكل زيارة',
                detail: 'حدد نظام التسعير والعربون وسياسة الاسترداد قبل الحفظ.',
                icon: Icons.payments_outlined,
                children: [
                  if (widget.ownerMode)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bookingGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: bookingGold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: bookingGold, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('العربون المركزي المعتمد',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13)),
                                Text(
                                  'العربون يُحدد مركزيًا بواسطة إدارة عقارات الأنبار لضمان حقوق المالك والمستأجر (${fields['deposit']!.text.isNotEmpty ? fields['deposit']!.text : "50,000"} د.ع).',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontFamily: 'Cairo'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    editorField('deposit'),
                  editorField('commissionPercent'),
                  DropdownButtonFormField<String>(
                      initialValue: pricingMode,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'نوع التسعير'),
                      items: const [
                        DropdownMenuItem(
                            value: 'fixed',
                            child: Text('سعر ثابت',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'shifts',
                            child: Text('فترات يومية',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(
                            value: 'hourly',
                            child: Text('بالساعة',
                                maxLines: 1, overflow: TextOverflow.ellipsis))
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() => pricingMode = v!)),
                  if (pricingMode == 'fixed') editorField('price'),
                  if (pricingMode == 'hourly') editorField('hourlyPrice'),
                  if (pricingMode == 'shifts') ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: bookingGold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'حدد الفترات المتاحة للمكان (توقيت بغداد - 12 ساعة). يمكنك تفعيل أو تعطيل أي فترة وضبط أوقاتها وسعرها.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'Cairo',
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildShiftCard(
                      context: context,
                      title: 'الفترة الصباحية',
                      icon: Icons.wb_sunny_rounded,
                      isActive: morningActive,
                      onToggle: (v) => setState(() => morningActive = v),
                      inCtrl: morningInCtrl,
                      outCtrl: morningOutCtrl,
                      priceCtrl: morningPriceCtrl,
                      onPickIn: () => _pickShiftTime(context, morningInCtrl),
                      onPickOut: () => _pickShiftTime(context, morningOutCtrl),
                    ),
                    _buildShiftCard(
                      context: context,
                      title: 'الفترة المسائية',
                      icon: Icons.nights_stay_rounded,
                      isActive: eveningActive,
                      onToggle: (v) => setState(() => eveningActive = v),
                      inCtrl: eveningInCtrl,
                      outCtrl: eveningOutCtrl,
                      priceCtrl: eveningPriceCtrl,
                      onPickIn: () => _pickShiftTime(context, eveningInCtrl),
                      onPickOut: () => _pickShiftTime(context, eveningOutCtrl),
                    ),
                    _buildShiftCard(
                      context: context,
                      title: 'اليوم الكامل',
                      icon: Icons.timelapse_rounded,
                      isActive: fullDayActive,
                      onToggle: (v) => setState(() => fullDayActive = v),
                      inCtrl: fullDayInCtrl,
                      outCtrl: fullDayOutCtrl,
                      priceCtrl: fullDayPriceCtrl,
                      onPickIn: () => _pickShiftTime(context, fullDayInCtrl),
                      onPickOut: () => _pickShiftTime(context, fullDayOutCtrl),
                    ),
                  ],
                  editorField('freeCancellationHours'),
                  editorField('lateRefundPercent'),
                ]),

            // 2: الموقع
            BookingEditorPage(
                title: 'الموقع الجغرافي',
                detail: 'حدد الموقع الجغرافي على الخريطة لتسهيل وصول الضيوف.',
                icon: Icons.location_on_outlined,
                children: [
                  editorField('location'),
                  editorField('latitude'),
                  editorField('longitude'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, color: bookingGold, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'تحديد الموقع بدقة عبر الخريطة',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                              ),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: bookingGold,
                                foregroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.place, size: 14),
                              label: const Text('فتح الخريطة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              onPressed: () async {
                                final currentLat = double.tryParse(fields['latitude']!.text);
                                final currentLng = double.tryParse(fields['longitude']!.text);
                                final picked = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LocationPickerScreen(
                                      initialLocation: currentLat != null && currentLng != null
                                          ? PropertyLocation(
                                              latitude: currentLat,
                                              longitude: currentLng,
                                              city: 'الأنبار',
                                              district: fields['location']!.text,
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                                if (picked is PropertyLocation) {
                                  setState(() {
                                    fields['latitude']!.text = picked.latitude.toString();
                                    fields['longitude']!.text = picked.longitude.toString();
                                    if (fields['location']!.text.trim().isEmpty && picked.district.isNotEmpty) {
                                      fields['location']!.text = '${picked.city} — ${picked.district}';
                                    }
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        if (fields['latitude']!.text.isNotEmpty && fields['longitude']!.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'الإحداثيات: ${fields['latitude']!.text}, ${fields['longitude']!.text}',
                                  style: const TextStyle(fontSize: 12, fontFamily: 'Cairo'),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  fields['latitude']!.clear();
                                  fields['longitude']!.clear();
                                }),
                                child: const Text('مسح', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ]),

            // 3: المزايا
            BookingEditorPage(
                title: 'المزايا والمرافق',
                detail: 'اختر المرافق المتوفرة في المكان.',
                icon: Icons.checklist_rtl_outlined,
                children: [
                  const Text('المرافق المتاحة للضيوف:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in bookingAmenities.entries)
                        FilterChip(
                            label: Text(e.value, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                            selected: amenities.contains(e.key),
                            onSelected: (yes) => setState(() {
                                  if (yes) {
                                    amenities.add(e.key);
                                  } else {
                                    amenities.remove(e.key);
                                  }
                                })),
                    ],
                  ),
                ]),

            // 4: الوسائط والمراجعة
            BookingEditorPage(
                title: 'معرض المكان والشروط',
                detail: 'إدارة الوسائط والشروط وسياسة الإلغاء قبل الحفظ.',
                icon: Icons.perm_media_outlined,
                children: [
                  BookingMediaPanel(children: [
                    if (widget.venueId != null)
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _venueMediaStream(),
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
                          stream: _venueMediaReviewsStream(),
                          builder: (context, snapshot) => BookingVerifiedGate(
                                hasData: snapshot.hasData,
                                hasError: snapshot.hasError,
                                error: snapshot.error,
                                isFromCache:
                                    snapshot.data?.metadata.isFromCache ??
                                        false,
                                hasPendingWrites: snapshot
                                        .data?.metadata.hasPendingWrites ??
                                    false,
                                cachedDetail:
                                    'تحديث حالة الوسائط الخاصة يحتاج اتصالًا وحسابًا مصرحًا.',
                                permissionDetail:
                                    'مراجعة وسائط هذا المكان متاحة للمالك والإدارة فقط.',
                                onRetry: widget.localMediaHooks == null
                                    ? () => setState(() {})
                                    : null,
                                child: Builder(builder: (context) => Column(children: [
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
                            ])),
                          )),
                    if (widget.ownerMode && widget.venueId != null) ...[
                      Wrap(children: [
                        for (final video in [false, true])
                          TextButton.icon(
                              icon: Icon(video ? Icons.videocam : Icons.photo),
                              label: Text(video
                                  ? 'رفع فيديو للمراجعة (50 MB)'
                                  : 'رفع صورة للمراجعة (10 MB)'),
                              onPressed: (busy || _uploadingMedia)
                                  ? null
                                  : () => _startMediaUpload(video: video)),
                      ]),
                      _buildMediaUploadProgressCard(),
                    ],
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
                  editorField('terms'),
                  SwitchListTile(
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                      title: const Text('المكان معتمد وجاهز للنشر')),
                ]),
          ]),
        ),
      );
}

class BookingSettingsScreen extends StatefulWidget {
  const BookingSettingsScreen(
      {super.key,
      this.loadSettings,
      this.loadUsers,
      this.saveSettings,
      this.call = bookingCall});
  final Future<Map<String, dynamic>> Function()? loadSettings;
  final Future<List<Map<String, dynamic>>> Function()? loadUsers;
  final Future<void> Function(int)? saveSettings;
  final BookingMediaCall call;
  @override
  State<BookingSettingsScreen> createState() => _BookingSettingsScreenState();
}

class _BookingSettingsScreenState extends State<BookingSettingsScreen> {
  final hold = TextEditingController();
  final chaletDeposit = TextEditingController();
  final farmDeposit = TextEditingController();
  final hallDeposit = TextEditingController();
  final otherDeposit = TextEditingController();
  bool loaded = false, busy = false;
  String? error;
  late Future<List<Map<String, dynamic>>> users = readUsers();
  Future<List<Map<String, dynamic>>> readUsers() async {
    if (widget.loadUsers != null) return widget.loadUsers!();
    final result = await FirebaseFirestore.instance
        .collection('users')
        .get(const GetOptions(source: Source.server));
    return [
      for (final user in result.docs) {...user.data(), 'id': user.id}
    ];
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = widget.loadSettings != null
          ? await widget.loadSettings!()
          : (await FirebaseFirestore.instance
                      .doc('settings/bookings')
                      .get(const GetOptions(source: Source.server)))
                  .data() ??
              {};
      if (!mounted) return;
      hold.text = '${data['holdMinutes'] ?? 120}';
      setState(() {
        loaded = true;
        error = null;
      });
    } catch (_) {
      if (mounted)
        setState(() => error =
            'تعذر تحميل الإعدادات من الخادم. أعد الاتصال وحاول مجددًا.');
    }
  }

  @override
  void dispose() {
    hold.dispose();
    chaletDeposit.dispose();
    farmDeposit.dispose();
    hallDeposit.dispose();
    otherDeposit.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!loaded || busy) return;
    final minutes = int.tryParse(hold.text);
    if (minutes == null || minutes < 5 || minutes > 10080) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل مدة بين 5 و10080 دقيقة')));
      return;
    }
    setState(() => busy = true);
    await bookingRun(context, () async {
      if (widget.saveSettings != null) {
        await widget.saveSettings!(minutes);
      } else {
        await FirebaseFirestore.instance
            .doc('settings/bookings')
            .set({'holdMinutes': minutes});
        await FirebaseFirestore.instance
            .doc('settings/booking_categories')
            .set({
          'chalet': int.tryParse(chaletDeposit.text) ?? 50000,
          'farm': int.tryParse(farmDeposit.text) ?? 50000,
          'hall': int.tryParse(hallDeposit.text) ?? 100000,
          'other': int.tryParse(otherDeposit.text) ?? 50000,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> reviewer(String id, bool enabled) async {
    if (busy) return;
    setState(() => busy = true);
    await bookingRun(context, () async {
      await widget.call(
          'setBookingPaymentReviewer', {'userId': id, 'enabled': enabled});
      if (mounted) setState(() => users = readUsers());
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('إعدادات الحجوزات')),
      body: error != null
          ? BookingStateView(
              title: 'الإعدادات غير متاحة',
              detail: error!,
              icon: Icons.settings_outlined,
              action: TextButton(
                  onPressed: () {
                    setState(() => error = null);
                    load();
                  },
                  child: const Text('إعادة المحاولة')))
          : !loaded
              ? const Center(child: CircularProgressIndicator())
              : BookingSettingsPanel(
                  hold: hold,
                  chaletDeposit: chaletDeposit,
                  farmDeposit: farmDeposit,
                  hallDeposit: hallDeposit,
                  otherDeposit: otherDeposit,
                  busy: busy,
                  onSave: save,
                  onAccounts: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const PaymentAccountSettingsScreen())),
                  reviewers: FutureBuilder<List<Map<String, dynamic>>>(
                      future: users,
                      builder: (context, s) {
                        if (s.hasError)
                          return const Text(
                              'تعذر التحقق من المراجعين؛ لا يمكن تعديل الصلاحيات الآن.');
                        if (!s.hasData) return const LinearProgressIndicator();
                        if (s.data!.isEmpty)
                          return const Text('لا توجد حسابات متاحة.');
                        return Column(children: [
                          for (final user in s.data!)
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${user['name'] ?? user['id']}'),
                                value: user['canReviewBookingPayments'] == true,
                                onChanged: busy
                                    ? null
                                    : (enabled) =>
                                        reviewer(user['id'], enabled))
                        ]);
                      })));
}


class BookingBottomUtilitiesCard extends StatelessWidget {
  final bool admin;
  final String uid;

  const BookingBottomUtilitiesCard({
    super.key,
    required this.admin,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore_outlined, color: bookingGold, size: 22),
              const SizedBox(width: 8),
              const Flexible(child: Text(
                'أدوات وخدمات عقارات الأنبار',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'روابط سريعة للبحث المتقدم، استكشاف الخريطة، الدعم، وخدمات الملاك',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildUtilityPill(
                context: context,
                icon: Icons.map_outlined,
                label: 'استكشاف الخريطة',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingMapScreen()),
                ),
              ),
              _buildUtilityPill(
                context: context,
                icon: Icons.search_rounded,
                label: 'البحث المتقدم',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingSearchScreen()),
                ),
              ),
              _buildUtilityPill(
                context: context,
                icon: Icons.add_business_outlined,
                label: 'أضف مكانك',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingVenueEditor(
                      ownerMode: true,
                      data: {'ownerId': uid},
                    ),
                  ),
                ),
              ),
              _buildUtilityPill(
                context: context,
                icon: Icons.support_agent_rounded,
                label: 'الدعم والمساعدة',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingSupportScreen(admin: admin),
                  ),
                ),
              ),
              _buildUtilityPill(
                context: context,
                icon: Icons.swap_horiz_rounded,
                label: 'نقل الملكية',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingTransferInbox(admin: admin),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityPill({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: bookingGold),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
