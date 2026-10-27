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
    'بانتظار': [
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
        query = FirebaseFirestore.instance
            .collection('booking_venues')
            .where('ownerId', isEqualTo: uid);
      } else if (tab == 0) {
        query = FirebaseFirestore.instance.collection('booking_venues');
        if (!widget.admin)
          query = query.where('active', isEqualTo: true).limit(publicLimit + 1);
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
                        (widget.admin
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
                                                const BookingSettingsScreen())))
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
                                PopupMenuButton<int>(
                                    tooltip: 'أدوات الحجوزات',
                                    icon: const Icon(Icons.grid_view_outlined),
                                    onSelected: (value) =>
                                        setState(() => tab = value),
                                    itemBuilder: (_) => [
                                          for (final e in <int, String>{
                                            0: 'الأماكن',
                                            1: 'حجوزاتي',
                                            2: 'لوحة المالك',
                                            5: 'أماكني وأسعاري',
                                            6: 'مهام الموظف',
                                            if (finance) 4: 'المراجعة المالية'
                                          }.entries)
                                            PopupMenuItem(
                                                value: e.key,
                                                child: Text(e.value))
                                        ])
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
                  if (tab != 2 && tab != 0)
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: !widget.admin && tab == 0
                            ? const BookingBrowseHeader()
                            : BookingWorkspaceHeader(
                                title: widget.admin
                                    ? 'مركز إدارة الحجوزات'
                                    : tab == 2
                                        ? 'لوحة المالك'
                                        : 'مكان يليق بيومك',
                                subtitle: widget.admin
                                    ? 'راجع الأماكن والطلبات والتوثيق من مساحة واحدة.'
                                    : 'شاليهات ومزارع وقاعات · اختر المكان والموعد المناسبين لك.')),
                  if (widget.admin || (tab != 0 && tab != 1)) ...workspaceTools(uid),
                  if (tab == 0)
                    BookingFilterBar(
                        welcome: !widget.admin,
                        // The ordinary app-bar menu moves into the gold hero
                        // only for discovery. App-bar overrides remain
                        // respected by diagnostic and embedded callers.
                        heroAction: isDiscovery &&
                                (widget.appBarActions == null ||
                                    widget.appBarActions!.isNotEmpty)
                            ? PopupMenuButton<int>(
                                tooltip: 'أدوات الحجوزات',
                                icon: const Icon(Icons.grid_view_outlined),
                                style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A)
                                        .withValues(alpha: .10),
                                    foregroundColor: const Color(0xFF0F172A)),
                                onSelected: (value) =>
                                    setState(() => tab = value),
                                itemBuilder: (_) => [
                                      for (final e in <int, String>{
                                        0: 'الأماكن',
                                        1: 'حجوزاتي',
                                        2: 'لوحة المالك',
                                        5: 'أماكني وأسعاري',
                                        6: 'مهام الموظف',
                                        if (finance) 4: 'المراجعة المالية'
                                      }.entries)
                                        PopupMenuItem(
                                            value: e.key, child: Text(e.value))
                                    ])
                            : null,
                        filters: filters,
                        onChanged: () => setState(() {})),
                  if (tab == 1 && !widget.admin)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final name in statusGroups.keys)
                            ChoiceChip(
                              avatar: Icon(
                                const {
                                  'الكل': Icons.all_inbox_rounded,
                                  'قيد المراجعة': Icons.hourglass_top_rounded,
                                  'المؤكدة': Icons.check_circle_outline_rounded,
                                  'السابقة': Icons.history_rounded,
                                  'الملغاة': Icons.cancel_outlined,
                                }[name] ?? Icons.filter_alt_outlined,
                                size: 16,
                                color: statusGroup == name
                                    ? (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFE6C894)
                                        : const Color(0xFF6B4E1B))
                                    : (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white70
                                        : const Color(0xFF475569)),
                              ),
                              label: Text(
                                name,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: statusGroup == name
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 12.5,
                                  color: statusGroup == name
                                      ? (Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFFE6C894)
                                          : const Color(0xFF6B4E1B))
                                      : (Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white70
                                          : const Color(0xFF475569)),
                                ),
                              ),
                              selected: statusGroup == name,
                              selectedColor: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF303343)
                                  : const Color(0xFFF0E7D8),
                              backgroundColor: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E222D)
                                  : Colors.white,
                              side: BorderSide(
                                color: statusGroup == name
                                    ? const Color(0xFFC5A16B)
                                    : (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white12
                                        : const Color(0xFFE2E8F0)),
                                width: statusGroup == name ? 1.4 : 1.0,
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onSelected: (_) =>
                                  setState(() => statusGroup = name),
                            ),
                        ],
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
                            return const Center(
                                child: Text('تعذر تحميل البيانات'));
                          }
                          if (!s.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
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
                          final docs = sourceDocs
                              .where(
                                  (d) => tab != 0 || filters.matches(d.data()))
                              .toList();
                          if (tab == 0)
                            docs.sort(
                                (a, b) => filters.compare(a.data(), b.data()));
                          if (docs.isEmpty && !(tab == 0 && !widget.admin))
                            return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                    'لا توجد أماكن تطابق الفلاتر؛ جرّب تخفيفها'));
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
                              if (tab == 3)
                                return BookingReportCard(
                                    data: d,
                                    onOpen: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => (widget.bookingPage
                                                    ?.call(
                                                        '${d['bookingId']}') ??
                                                BookingDetailsScreen(
                                                    bookingId:
                                                        '${d['bookingId']}')))),
                                    onResolve: d['status'] == 'open'
                                        ? () => bookingRun(
                                            context,
                                            () => doc.reference
                                                .update({'status': 'resolved'}))
                                        : null);
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
    restoreIntent();
    if (widget.currentUserId == null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      requestSession = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (mounted && user?.uid != uid) invalidateIdentity();
      });
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
        start = DateTime.fromMillisecondsSinceEpoch(pending['start']);
        end = DateTime.fromMillisecondsSinceEpoch(pending['end']);
        shiftId = pending['shiftId'];
        notes.text = pending['notes'] as String? ?? '';
        step = 2;
        accepted = true;
      }
      setState(() => intentReady = true);
    } catch (_) {
      if (mounted) setState(() => intentReadFailed = true);
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
                            if (busy)
                              const BookingActionReason(
                                  reason:
                                      'الإجراء معطل أثناء إرسال الطلب السابق.')
                            else if (step == 1 && !validRange)
                              const BookingActionReason(
                                  reason:
                                      'اختر الفترة ثم يوم الزيارة، أو حدد الدخول والخروج، لتفعيل مراجعة الطلب.')
                            else if (step == 2 && !accepted)
                              const BookingActionReason(
                                  reason:
                                      'راجع الشروط وحدد الموافقة عليها لتفعيل إرسال الطلب.'),
                            if (step == 0)
                              Text(
                                  'يبدأ من ${bookingMoney(bookingStartingPrice(v))} · العربون ${bookingMoney(v['deposit'])}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (step < 2)
                              FilledButton.icon(
                                  key: const ValueKey('booking-next'),
                                  icon:
                                      const Icon(Icons.calendar_month_outlined),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white),
                                  onPressed: busy || (step == 1 && !validRange)
                                      ? null
                                      : () => setState(() => step++),
                                  label: Text(step == 0
                                      ? 'احجز الآن'
                                      : 'مراجعة السعر والطلب')),
                            if (step == 2)
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
                            if (step == 2 && submittedIntent != null)
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => Navigator.maybePop(context),
                                  child:
                                      const Text('العودة للتحقق من حجوزاتي')),
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
                          BookingVenueDetails(venue: v),
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
                                  // Color Legend Card
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                                    ),
                                    child: const Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 16,
                                      runSpacing: 6,
                                      children: [
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(Icons.circle, size: 12, color: Color(0xFF22C55E)),
                                          SizedBox(width: 5),
                                          Text('متاح', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ]),
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(Icons.circle, size: 12, color: Color(0xFFEAB308)),
                                          SizedBox(width: 5),
                                          Text('قيد المراجعة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ]),
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(Icons.circle, size: 12, color: Color(0xFFEF4444)),
                                          SizedBox(width: 5),
                                          Text('محجوز', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ]),
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(Icons.circle, size: 12, color: Color(0xFF94A3B8)),
                                          SizedBox(width: 5),
                                          Text('غير متاح', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ]),
                                      ],
                                    ),
                                  ),
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
                                              child: Text(
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
                                                  textAlign: TextAlign.center)),
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
                                                    shiftId = shift['id'] as String;
                                                    if (start != null) {
                                                      setShiftDate(start!);
                                                    }
                                                    accepted = false;
                                                  }),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  shiftId == shift['id']
                                                      ? Icons.radio_button_checked
                                                      : Icons.radio_button_off,
                                                  color: shiftId == shift['id'] ? bookingGold : Colors.grey,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        shift['name'] ?? '',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                      ),
                                                      Text(
                                                        ' إلى ',
                                                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  pricingV2 != null
                                                      ? ' /  د.ع'
                                                      : ' د.ع',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: bookingGold),
                                                ),
                                              ],
                                            ),
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
                                          const Row(
                                            children: [
                                              Icon(Icons.calculate_outlined, color: bookingGold, size: 20),
                                              SizedBox(width: 8),
                                              Text('تفاصيل الحساب المالي المعتمد',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            ],
                                          ),
                                          const Divider(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('السعر الإجمالي:'),
                                              Text(bookingMoney(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('العربون المطلوب للدفع:'),
                                              Text(bookingMoney(BookingPricingDraft.venueDeposit(v) ?? v['deposit']),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: bookingGold)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('الرصيد المتبقي عند الوصول:'),
                                              Text(
                                                  bookingMoney(total - ((BookingPricingDraft.venueDeposit(v) ?? v['deposit']) as num).toInt()),
                                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const Divider(height: 16),
                                          Text(
                                            'الدخول: \nالخروج:  — توقيت بغداد',
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
                      ]))),
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
  final transaction = TextEditingController(),
      reason = TextEditingController(),
      refundReference = TextEditingController();
  String? currentUid() => widget.currentUserId != null
      ? widget.currentUserId!()
      : FirebaseAuth.instance.currentUser?.uid;
  @override
  void initState() {
    super.initState();
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

  Future<String?> promptReason(String title, String hint) async {
    final controller = TextEditingController(text: reason.text);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('تأكيد', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> handleActionWithReason(String action) async {
    String title = 'تأكيد الإجراء';
    String hint = 'أدخل السبب...';
    if (action == 'reject') {
      title = 'رفض طلب الحجز';
      hint = 'وضح للمستأجر سبب رفض الطلب...';
    } else if (action == 'cancel') {
      title = 'إلغاء الحجز';
      hint = 'أدخل سبب إلغاء هذا الحجز...';
    } else if (action == 'rejectPayment') {
      title = 'رفض إيصال الدفع';
      hint = 'وضح سبب رفض الإيصال (مثال: غير واضح، المبلغ ناقص)...';
    }
    final entered = await promptReason(title, hint);
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
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('تفاصيل الحجز')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: widget.dataStream ??
              FirebaseFirestore.instance
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
            final uid = currentUid(),
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
                BookingReservationHeader(
                    booking: b,
                    id: widget.bookingId,
                    venue: widget.displayVenue),
                ExpansionTile(
                    title: const Text('بيانات الحجز الكاملة'),
                    children: [
                      BookingSummary(
                          booking: b,
                          status: bookingStatuses[b['status']] ?? b['status'])
                    ]),
                ExpansionTile(
                    key: const PageStorageKey('booking-tools-3'),
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
                                await widget.call('reviewCompletedBooking', {
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
                              builder: widget.chatPage ??
                                  (_) => BookingChatScreen(
                                      bookingId: widget.bookingId))),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('محادثة الحجز')),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: widget.events ??
                        FirebaseFirestore.instance
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
                TextButton.icon(
                    icon: const Icon(Icons.support_agent),
                    label: const Text('طلب دعم لهذا الحجز'),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: widget.supportPage ??
                                (_) => BookingSupportScreen(
                                    bookingId: widget.bookingId)))),
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
                if (b['pricing'] != null)
                  Text(
                      'التسعير: ${b['pricing']['name'] ?? b['pricing']['mode']}'),
                BookingRecordedMoney(booking: b),
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
                if (b['receiptPath'] != null)
                  TextButton(
                      onPressed: () => bookingRun(context, () async {
                            final bytes = widget.readReceiptBytes != null
                                ? await widget.readReceiptBytes!()
                                : await FirebaseStorage.instance
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
                            displayedNumber = accounts[method]['number'];
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
                if ((owner || customer || admin) &&
                    ['requested', 'held', 'confirmed', 'payment_review']
                        .contains(b['status']))
                  button('إلغاء الحجز', 'cancel'),
                if (owner || customer)
                  OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => bookingRun(context, () async {
                                await widget.call('reportBooking', {
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
    return TextField(
        controller: e.value,
        decoration: InputDecoration(
            labelText: const {
          'capacity': 'السعة القصوى للضيوف (0 = غير محددة)',
          'bedrooms': 'عدد الغرف',
          'complexName': 'اسم المنتجع أو المجمع (اختياري)',
          'unitName': 'اسم الوحدة أو الشاليه الفرعي (مثل: شاليه 1 أو فيلا A داخل المجمع)',
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
        keyboardType: [
          'latitude',
          'longitude',
          'capacity',
          'bedrooms',
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

  Widget saveButton() => FilledButton(
      onPressed: busy
          ? null
          : () async {
              if (busy) return;
              setState(() => busy = true);
              await bookingRun(context, () async {
                final coordinateError = bookingCoordinateError(
                    fields['latitude']!.text, fields['longitude']!.text);
                if (coordinateError != null) throw StateError(coordinateError);
                for (final key in ['capacity', 'bedrooms']) {
                  if (fields[key]!.text.isNotEmpty &&
                      (int.tryParse(fields[key]!.text) == null ||
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
                  'capacity': int.tryParse(fields['capacity']!.text) ?? 0,
                  'bedrooms': int.tryParse(fields['bedrooms']!.text) ?? 0,
                  'amenities': amenities.toList(),
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
                    'freeCancellationHours':
                        int.tryParse(fields['freeCancellationHours']!.text),
                    'lateRefundPercent':
                        int.tryParse(fields['lateRefundPercent']!.text)
                  },
                  'category': category,
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
                    Tab(text: 'البيانات'),
                    Tab(text: 'الموقع والمرافق'),
                    Tab(text: 'الأسعار والفترات'),
                    Tab(text: 'الوسائط'),
                    Tab(text: 'المراجعة والحفظ')
                  ])),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
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
                        saveButton()
                      ]))),
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
                          stream: mediaDocument(FirebaseFirestore.instance
                              .doc('booking_venues/${widget.venueId}')
                              .snapshots(includeMetadataChanges: true)),
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
                          stream: mediaQuery(FirebaseFirestore.instance
                              .collection('booking_media_reviews')
                              .where('venueId', isEqualTo: widget.venueId)
                              .where('ownerId',
                                  isEqualTo:
                                      FirebaseAuth.instance.currentUser!.uid)
                              .snapshots(includeMetadataChanges: true)),
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
                                        Uint8List? bytes;
                                        if (widget.localMediaHooks != null) {
                                          widget.localMediaHooks!
                                              .checkLocalOnly();
                                          bytes = await widget.localMediaHooks!
                                              .pick(video);
                                        } else {
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
                                          bytes = video
                                              ? await file.readAsBytes()
                                              : await FlutterImageCompress
                                                  .compressWithList(
                                                      await file.readAsBytes(),
                                                      format:
                                                          CompressFormat.jpeg,
                                                      quality: 90);
                                        }
                                        if (bytes == null) return;
                                        if (video) {
                                          await BookingMediaService.uploadVideo(
                                              bytes,
                                              widget.venueId!,
                                              widget.call);
                                        } else {
                                          await BookingMediaService.uploadImage(
                                              bytes, widget.call,
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
                ]),
          ])));
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
          const Row(
            children: [
              Icon(Icons.explore_outlined, color: bookingGold, size: 22),
              SizedBox(width: 8),
              Text(
                'أدوات وخدمات عقارات الأنبار',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
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
