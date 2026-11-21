import 'booking_offline_preview/pricing_editor.dart';
// Offline diagnostic entry. Production main.dart never imports this file.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aqar/banners/banner_model.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_design.dart';
import 'package:aqar/bookings/booking_widgets.dart';
import 'package:aqar/bookings/booking_workspace.dart';
import 'package:aqar/bookings/booking_admin_tasks.dart';
import 'package:aqar/bookings/booking_operations.dart';
import 'package:aqar/bookings/booking_management.dart';
import 'package:aqar/bookings/booking_media_image.dart';
import 'booking_offline_preview/data.dart';
import 'booking_offline_preview/network_guard.dart';
import 'booking_offline_preview/receipt_data.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;

Stream<T> localValue<T>(T value) => Stream<T>.multi((c) {
      c.add(value);
      c.close();
    }, isBroadcast: true);

final offlineTrace = <Map<String, dynamic>>[];
Future<void> trace(String event, [String? value]) async {
  if (!Platform.isAndroid) return;
  offlineTrace.add({
    'at': DateTime.now().toUtc().toIso8601String(),
    'event': event,
    if (value != null) 'value': value
  });
  final d = await getApplicationSupportDirectory();
  await File('${d.path}/offline-preview-audit.json').writeAsString(jsonEncode({
    'networkGuard': 'deny-all',
    'firebaseInitialized': Firebase.apps.isNotEmpty,
    'httpAttemptsBlocked': OfflineHttpGuard.blocked,
    'events': offlineTrace
  }));
}

void main() {
  if (!kDebugMode ||
      appFlavor != 'bookingsOfflinePreview' ||
      !const bool.fromEnvironment('BOOKING_OFFLINE_PREVIEW'))
    throw StateError('OFFLINE_DIAGNOSTIC_BUILD_REQUIRED');
  HttpOverrides.global = OfflineHttpGuard();
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    unawaited(trace('flutter-error', details.exceptionAsString()));
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    unawaited(trace('unhandled-error', '$e'));
    return false;
  };
  unawaited(trace('startup', 'offline-preview-2026104409'));
  runApp(OfflineBookingPreview());
}

class OfflineBookingPreview extends StatelessWidget {
  OfflineBookingPreview({super.key, PreviewData? data})
      : data = data ?? PreviewData();
  final PreviewData data;
  final previewScale = ValueNotifier<double?>(null);
  final navigator = GlobalKey<NavigatorState>();
  static const routes = <String, String>{
    'home': 'الرئيسية',
    'bookings': 'حجوزاتي',
    'owner': 'لوحة المالك',
    'admin': 'الإدارة',
    'finance': 'المالية',
    'payment': 'دفع العربون',
    'review': 'المراجعة المالية',
    'chat': 'المحادثات',
    'support': 'الدعم',
    'notifications': 'الإشعارات المحلية',
    'images': 'حالات الصور',
    'empty': 'حجوزات فارغة',
    'offline': 'حالة انقطاع البيانات',
    'denied': 'عدم الصلاحية',
    'prices': 'إدارة الأسعار'
  };
  void open(String route) {
    unawaited(trace('route', route));
    navigator.currentState!
        .push(MaterialPageRoute(builder: (_) => page(route)));
  }

  void toast(String text) {
    final context = navigator.currentContext!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> p) async {
    unawaited(trace('local-call', name));
    return data.call(name, p);
  }

  Widget tools() => Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final key in [
          'home',
          'bookings',
          'owner',
          'admin',
          'finance',
          'prices',
          'support'
        ])
          TextButton(onPressed: () => open(key), child: Text(routes[key]!))
      ]));
  List<BannerModel> get banners => [
        for (final i in [0, 1, 2, 3])
          BannerModel(
              id: 'local-banner-$i',
              title: i == 3
                  ? 'أماكن للمناسبات العائلية والاستراحة في مناطق الأنبار — عنوان طويل للاختبار فقط'
                  : data.venues[i]['name'],
              subtitle: 'صورة وبيانات معاينة محلية، دون أي اتصال خارجي',
              imageUrl: 'local',
              type: data.venues[i]['category'],
              targetId: data.venues[i]['id'],
              isActive: true,
              order: i)
      ];
  Widget workspace(
          {int tab = 0,
          bool admin = false,
          bool empty = false,
          bool unavailable = false,
          String role = 'customer'}) =>
      BookingScreen(
          key: ValueKey('$tab-$admin-$empty-$unavailable-$role'),
          admin: admin,
          initialTab: tab,
          currentUserId: () =>
              role == 'owner' ? 'preview-owner' : 'preview-customer',
          records: (t) =>
              data.records(t, empty: empty, unavailable: unavailable),
          tools: tools(),
          appBarActions: const [],
          adminTaskRecords: {
            for (final k in bookingTaskCollections.keys)
              k: localValue(LocalRecords(k == 'requests'
                  ? data.bookings
                      .where((b) => b['status'] == 'requested')
                      .toList()
                  : []))
          },
          onAdminTask: (task) {
            if (task == 'requests') {
              open('bookings');
            } else {
              navigator.currentState!.push(MaterialPageRoute(
                  builder: (_) => BookingScaffold(
                      appBar:
                          AppBar(title: const Text('مهام المراجعة المحلية')),
                      body: const BookingStateView(
                          title: 'لا مهام أخرى معلقة',
                          detail:
                              'بيانات معاينة محلية فقط؛ لا بيانات خادم.'))));
            }
          },
          banners: localValue(banners),
          diagnosticFeatured: [
            for (final v in data.venues.take(3)) {...v, 'featured': true}
          ],
          bannerImageBuilder: (b) => Image.asset(
              'assets/images/defaults/${b.type == 'hall' ? 'building' : b.type == 'farm' ? 'farm' : 'house'}.png',
              fit: BoxFit.cover),
          loadVenue: (id) async => data.venue(id),
          venuePage: request,
          bookingPage: (id) => details(id, role: admin ? 'admin' : role));
  Widget request(String id, Map<String, dynamic> v) => BookingRequestScreen(
      venueId: id,
      venue: v,
      currentUserId: () => 'preview-customer',
      intentStore: data.intents,
      call: call,
      onRequested: (id) {
        toast('محاكاة محلية فقط — لم يُرسل الطلب إلى أي خادم');
        navigator.currentState!
            .pushReplacement(MaterialPageRoute(builder: (_) => details(id)));
      });
  Future<Uint8List> receipt(int amount) => offlineReceipt(amount: amount);
  Widget details(String id, {String role = 'customer'}) {
    final uid = 'preview-$role';
    return BookingDetailsScreen(
        bookingId: id,
        currentUserId: () => uid,
        sessions: localValue(uid),
        roles: (_) => localValue(LocalDocument(uid, {
              'isBlocked': false,
              'isAdmin': role == 'admin',
              'canReviewBookingPayments': role == 'finance'
            })),
        dataStream: data.watch(id),
        displayVenue: data.venue(data.booking(id)['venueId']),
        events: localValue(LocalRecords([
          {'id': 'event-$id', 'action': 'request', 'version': 1}
        ])),
        paymentAccounts: localValue(localAccounts),
        call: call,
        scannerPage: (_) => const BookingScaffold(
            body: BookingStateView(
                title: 'التحقق الحقيقي من QR غير متاح في المعاينة',
                detail:
                    'لا مصادقة ولا اتصال؛ لا يمثل رمز المعاينة صلاحية وصول.')),
        chatPage: (_) => chat(id),
        supportPage: (_) => SupportPreview(
            onSaved: () => toast('تم حفظ تذكرة داخل الذاكرة فقط')),
        pickReceiptBytes: () async {
          unawaited(trace('local-receipt-pick'));
          return receipt(data.booking(id)['deposit'] as int);
        },
        readReceiptBytes: () => receipt(data.booking(id)['deposit'] as int),
        submitReceipt: (bytes, method, number) async {
          final b = data.booking(id);
          b['status'] = 'payment_review';
          b['receiptPath'] = 'offline-receipt';
          data.changed();
          unawaited(trace('local-receipt-review', id));
          toast('تمت المحاكاة محليًا — لا إرسال أو دفع حقيقي');
        });
  }

  Widget chat(String id) => BookingChatScreen(
      bookingId: id,
      currentUserId: () => 'preview-customer',
      sessions: localValue('preview-customer'),
      messages: (_) => data.changes.stream
          .map((_) => LocalRecords(data.messages))
          .startWithLocal(LocalRecords(data.messages)),
      call: call);
  Widget page(String name) {
    if (name == 'home') return workspace();
    if (name == 'bookings') return workspace(tab: 1);
    if (name == 'owner') return workspace(tab: 2, role: 'owner');
    if (name == 'admin') return workspace(admin: true);
    if (name == 'finance')
      return BookingScaffold(
          appBar: AppBar(title: const Text('دفتر المالية — معاينة')),
          body: BookingLedgerContent(entries: [
            {
              'action': 'confirmPayment',
              'bookingId': 'preview-booking-4',
              'reference': 'مرجع محلي غير مالي',
              'depositCollected': data.bookings[3]['deposit'],
              'refundPaid': 0,
              'ownerPaid': 0,
              'platformCommission': 0
            }
          ]));
    if (name == 'payment') return details('preview-booking-2');
    if (name == 'review') return details('preview-booking-3', role: 'finance');
    if (name == 'chat') return chat('preview-booking-1');
    if (name == 'support')
      return SupportPreview(onSaved: () => toast('تذكرة محلية فقط؛ لم تُرسل'));
    if (name == 'notifications')
      return BookingScaffold(
          appBar: AppBar(title: const Text('إشعارات محلية — دون Push')),
          body: ListView(children: [
            for (final b in data.bookings)
              ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(
                      '${b['venueName']} — ${bookingStatusNames[b['status']]}'),
                  subtitle: const Text('بيانات معاينة · اضغط لفتح الحجز نفسه'),
                  onTap: () => navigator.currentState!.push(
                      MaterialPageRoute(builder: (_) => details(b['id']))))
          ]));
    if (name == 'images') return const ImageCasesPreview();
    if (name == 'empty') return workspace(tab: 1, empty: true);
    if (name == 'offline') return workspace(unavailable: true);
    if (name == 'denied') return details('preview-booking-1', role: 'other');
    if (name == 'prices')
      return PricesPreview(
          data: data, onSaved: () => toast('حُفظ التعديل داخل الذاكرة فقط'));
    throw StateError('Unknown local route');
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      theme: bookingDesignTheme(ThemeData.light(useMaterial3: true)),
      darkTheme: bookingDesignTheme(ThemeData.dark(useMaterial3: true)),
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => ValueListenableBuilder<double?>(
          valueListenable: previewScale,
          builder: (context, scale, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: scale == null
                      ? MediaQuery.textScalerOf(context)
                      : TextScaler.linear(scale)),
              child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: SafeArea(
                                bottom: false,
                                child: Row(children: [
                                  const SizedBox(width: 12),
                                  const Expanded(
                                      child: Text(
                                          'معاينة تجريبية · البيانات غير حقيقية',
                                          style: TextStyle(fontSize: 12))),
                                  TextButton.icon(
                                      icon:
                                          const Icon(Icons.grid_view_outlined),
                                      label: const Text('شاشات المعاينة'),
                                      onPressed: () => showModalBottomSheet<
                                              void>(
                                          context: navigator.currentContext!,
                                          showDragHandle: true,
                                          builder: (sheet) => ListView(
                                                  shrinkWrap: true,
                                                  children: [
                                                    ListTile(
                                                        title: const Text(
                                                            'تكبير النص 150%'),
                                                        onTap: () {
                                                          previewScale.value =
                                                              1.5;
                                                          Navigator.pop(sheet);
                                                        }),
                                                    ListTile(
                                                        title: const Text(
                                                            'حجم النص الأصلي'),
                                                        onTap: () {
                                                          previewScale.value =
                                                              null;
                                                          Navigator.pop(sheet);
                                                        }),
                                                    for (final e
                                                        in routes.entries)
                                                      ListTile(
                                                          title: Text(e.value),
                                                          onTap: () {
                                                            Navigator.pop(
                                                                sheet);
                                                            open(e.key);
                                                          })
                                                  ])))
                                ]))),
                        Expanded(
                            child: Semantics(
                                container: true,
                                explicitChildNodes: true,
                                child: MediaQuery(
                                    data: MediaQuery.of(context).copyWith(
                                        padding: MediaQuery.of(context)
                                            .padding
                                            .copyWith(top: 0),
                                        textScaler: scale == null
                                            ? MediaQuery.textScalerOf(context)
                                            : TextScaler.linear(scale)),
                                    child: child!)))
                      ])))),
      home: _PreviewIntro(onEnter: () => open('home')));
}

extension _Initial<T> on Stream<T> {
  Stream<T> startWithLocal(T initial) async* {
    yield initial;
    yield* this;
  }
}

class SupportPreview extends StatefulWidget {
  const SupportPreview({super.key, required this.onSaved});
  final VoidCallback onSaved;
  @override
  State<SupportPreview> createState() => _SupportPreviewState();
}

class _SupportPreviewState extends State<SupportPreview> {
  final subject = TextEditingController(), message = TextEditingController();
  bool sent = false;
  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => BookingScaffold(
      appBar: AppBar(title: const Text('دعم الحجوزات — معاينة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        BookingSupportForm(
            subject: subject,
            message: message,
            busy: false,
            onSubmit: () {
              setState(() => sent = true);
              widget.onSaved();
            }),
        if (sent)
          BookingSupportTicket(data: {
            'subject': subject.text,
            'message': message.text,
            'status': 'open'
          })
      ]));
}

class ImageCasesPreview extends StatefulWidget {
  const ImageCasesPreview({super.key});
  @override
  State<ImageCasesPreview> createState() => _ImageCasesPreviewState();
}

class _ImageCasesPreviewState extends State<ImageCasesPreview> {
  bool recovered = false, loaded = false;
  @override
  Widget build(BuildContext c) => BookingScaffold(
      appBar: AppBar(title: const Text('حالات الصور المحلية')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('صورة ناجحة — أصل محلي داخل APK'),
        const SizedBox(
            height: 200,
            child: BookingMediaImage(
                url: 'asset://assets/images/defaults/house.png')),
        const SizedBox(height: 16),
        const Text('صور متعددة'),
        const BookingMediaGallery(paths: [
          'asset://assets/images/defaults/house.png',
          'asset://assets/images/defaults/building.png'
        ]),
        const SizedBox(height: 16),
        const Text('صورة مفقودة، ثم إعادة محاولة محلية'),
        SizedBox(
            height: 180,
            child: BookingMediaImage(
                key: ValueKey(recovered),
                url: recovered
                    ? 'asset://assets/images/defaults/farm.png'
                    : 'asset://assets/images/defaults/missing-preview.png')),
        TextButton(
            onPressed: () => setState(() => recovered = true),
            child: const Text('إعادة المحاولة محليًا')),
        const Text('حالة تحميل محلية مضبوطة'),
        SizedBox(
            height: 120,
            child: loaded
                ? const BookingMediaImage(
                    url: 'asset://assets/images/defaults/farm.png')
                : const BookingMediaImage(url: 'asset://missing')
                    .placeholder(c, loading: true)),
        TextButton(
            onPressed: () => setState(() => loaded = true),
            child: const Text('إكمال التحميل المحلي')),
        const Text('لا صور'),
        const BookingMediaGallery(paths: [])
      ]));
}

class PricesPreview extends StatefulWidget {
  const PricesPreview({super.key, required this.data, required this.onSaved});
  final PreviewData data;
  final VoidCallback onSaved;
  @override
  State<PricesPreview> createState() => _PricesPreviewState();
}

class _PricesPreviewState extends State<PricesPreview> {
  late final price =
      TextEditingController(text: '${widget.data.venues.first['price']}');
  @override
  void dispose() {
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Material(
          child: BookingEditorPage(
              title: 'الأسعار — معاينة محلية',
              detail: 'مكونات المحرر المشتركة؛ دون نشر أو تعديل خادم',
              icon: Icons.price_change_outlined,
              children: [
            Text(widget.data.venues.first['name']),
            TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'السعر التجريبي')),
            FilledButton(
                onPressed: () {
                  final n = int.tryParse(price.text);
                  if (n != null) {
                    widget.data.venues.first['price'] = n;
                    for (final shift
                        in widget.data.venues.first['shifts'] as List) {
                      shift['price'] =
                          n + (shift['id'] == 'evening' ? 25000 : 0);
                    }
                    widget.data.changed();
                    widget.onSaved();
                  }
                },
                child: const Text('حفظ داخل الذاكرة')),
            const ExpansionTile(
                title: Text('مسودة تسعير نهاية الأسبوع واليوم الكامل'),
                children: [BookingDraftPricingEditor()])
          ]));
}

class _PreviewIntro extends StatelessWidget {
  const _PreviewIntro({required this.onEnter});
  final VoidCallback onEnter;
  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('معاينة نظام الحجوزات')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 24),
        const Icon(Icons.visibility_outlined, size: 52),
        const SizedBox(height: 24),
        const Text('نسخة تجريبية — البيانات غير حقيقية',
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text(
            'لا تسجيل دخول ولا Firebase ولا مدفوعات. جميع الإجراءات داخل ذاكرة الهاتف.',
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: onEnter, child: const Text('الدخول إلى المعاينة'))
      ]));
}
