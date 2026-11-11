import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/share_origin.dart';
import 'booking_widgets.dart';
import 'booking_filters.dart';
import 'booking_location.dart';
import 'booking_mini_map.dart';
import 'booking_pricing_draft.dart';
import 'booking_screen.dart' show bookingCall;
String bookingClock12(dynamic minute) {
  if (minute is! int || minute < 0 || minute >= 1440) return 'وقت غير محدد';
  final h = minute ~/ 60;
  return '${h % 12 == 0 ? 12 : h % 12}:${(minute % 60).toString().padLeft(2, '0')} ${h < 12 ? 'ص' : 'م'}';
}
class BookingVenuePrices extends StatelessWidget {
  const BookingVenuePrices(
      {super.key, required this.venue, this.localPreview = false});
  final bool localPreview;
  final Map<String, dynamic> venue;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final v2 = BookingPricingDraft.fromVenue(venue);
    Widget rate(String title, String time, dynamic price, IconData icon, Color iconColor,
            {String? subtitlePrice}) =>
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: LayoutBuilder(builder: (context, bounds) {
              final wide = bounds.maxWidth >= 300 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.2;
              final amount = Column(
                  crossAxisAlignment:
                      wide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(bookingMoney(price),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    if (subtitlePrice != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitlePrice,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: muted)),
                    ]
                  ]);
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: iconColor.withValues(alpha: .3))),
                        child: Icon(icon,
                            color: iconColor,
                            size: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(time,
                              style: TextStyle(fontSize: 13, color: muted)),
                          if (!wide) ...[const SizedBox(height: 8), amount]
                        ])),
                    if (wide) ...[
                      const SizedBox(width: 12),
                      Flexible(child: amount)
                    ]
                  ]);
            }));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
          localPreview
              ? 'أسعار عينة محلية غير مفعّلة'
              : 'التعرفة الحالية المعتمدة',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      if (v2 != null) ...[
        for (final s in v2.enabledShifts) ...[
          Builder(builder: (context) {
            final visual = BookingShiftVisual.resolve(s);
            final iconColor = visual.foreground(Theme.of(context).brightness);
            return rate(
                '${s['name']}',
                '${bookingClock12(s['startMinute'])} — ${bookingClock12(s['endMinute'])}${s['endDayOffset'] == 1 ? ' (اليوم التالي)' : ''}',
                s['weekdayPrice'],
                visual.icon,
                iconColor,
                subtitlePrice: s['weekendPrice'] != s['weekdayPrice']
                    ? 'نهاية الأسبوع: ${bookingMoney(s['weekendPrice'])}'
                    : 'سعر موحّد طوال الأسبوع');
          }),
          const Divider(height: 1)
        ],
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
                'أيام عطلة نهاية الأسبوع: ${v2.weekendDaysText} (توقيت بغداد).',
                style: TextStyle(fontSize: 13, color: muted))),
      ] else if (venue['pricingMode'] == 'shifts') ...[
        for (final raw in venue['shifts'] as List? ?? [])
          if (raw is Map) ...[
            Builder(builder: (context) {
              final sName = '${raw['name'] ?? ''}';
              final visual = BookingShiftVisual.resolve(raw);
              final iconColor = visual.foreground(Theme.of(context).brightness);
              return rate(
                  sName,
                  '${bookingClock12(raw['checkInMinute'])} — ${bookingClock12(raw['checkOutMinute'])}',
                  raw['price'],
                  visual.icon,
                  iconColor);
            }),
            const Divider(height: 1)
          ],
        if (!localPreview)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('الأسعار المعتمدة لجميع أيام الأسبوع.',
                  style: TextStyle(fontSize: 13, color: muted))),
      ] else
        rate(
            venue['pricingMode'] == 'hourly' ? 'للساعة' : 'للحجز',
            '',
            venue[venue['pricingMode'] == 'hourly' ? 'hourlyPrice' : 'price'],
            Icons.payments_outlined,
            bookingGold),
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: bookingGold.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(12)),
          child: Text(
              'العربون المطلوب: ${bookingMoney(v2?.deposit ?? venue['deposit'])}',
              style: const TextStyle(fontWeight: FontWeight.w700))),
      const SizedBox(height: 10),
      Text('يظهر المبلغ النهائي بعد اختيار الموعد والفترة.',
          style: TextStyle(fontSize: 13, color: muted, height: 1.6))
    ]);
  }
}
class BookingVenueDetails extends StatefulWidget {
  const BookingVenueDetails({super.key, required this.venue});
  final Map<String, dynamic> venue;
  static const labels = [
    'التفاصيل',
    'الأسعار',
    'الموقع',
    'المزايا',
    'شروط الحجز'
  ];
  @override
  State<BookingVenueDetails> createState() => BookingVenueDetailsState();
}
class BookingVenueDetailsState extends State<BookingVenueDetails> {
  void _openVenueReportDialog(BuildContext context, Map<String, dynamic> venue) {
    final reasons = [
      'معلومات أو أسعار مضللة',
      'مكان غير موجود على أرض الواقع',
      'انتهاك حقوق الملكية الفكرية أو صور غير حقيقية',
      'مخالفة الشروط والآداب العامة',
      'سبب آخر',
    ];
    String selectedReason = reasons[0];
    final detailsController = TextEditingController();
    String? detailsError;
    bool sending = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Directionality(
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
                  const Row(
                    children: [
                      Icon(Icons.flag_outlined, color: bookingGold, size: 22),
                      SizedBox(width: 8),
                      Text('الإبلاغ عن المكان',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('المكان: ${venue['name'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  const Text('اختر سبب البلاغ:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  for (final r in reasons)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(r, style: const TextStyle(fontSize: 13)),
                      value: r,
                      groupValue: selectedReason,
                      onChanged: (val) => setDlgState(() => selectedReason = val!),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsController,
                    maxLines: 3,
                    maxLength: 500,
                    onChanged: (_) {
                      if (detailsError != null) {
                        setDlgState(() => detailsError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: selectedReason == 'سبب آخر'
                          ? 'تفاصيل إضافية (مطلوبة) *'
                          : 'تفاصيل إضافية (اختياري)',
                      errorText: detailsError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: sending ? null : () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: bookingNavy, foregroundColor: Colors.white),
                          onPressed: sending
                              ? null
                              : () async {
                                  if (selectedReason == 'سبب آخر' &&
                                      detailsController.text.trim().length < 5) {
                                    setDlgState(() => detailsError =
                                        'يرجى توضيح تفاصيل البلاغ (5 أحرف على الأقل)');
                                    return;
                                  }
                                  final uid = FirebaseAuth.instance.currentUser?.uid;
                                  if (uid == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('يرجى تسجيل الدخول لتقديم بلاغ')),
                                    );
                                    return;
                                  }
                                  setDlgState(() => sending = true);
                                  try {
                                    await bookingCall('reportBookingVenue', {
                                      'venueId': venue['id'] ?? '',
                                      'reason': selectedReason,
                                      'details': detailsController.text.trim(),
                                    });
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'تم إرسال البلاغ بنجاح وسيتم تدقيقه من الإدارة')),
                                      );
                                    }
                                  } catch (e) {
                                    setDlgState(() => sending = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'تعذر إرسال البلاغ، يرجى المحاولة لاحقاً')),
                                      );
                                    }
                                  }
                                },
                          child: Text(sending ? 'جارٍ الإرسال...' : 'إرسال البلاغ'),
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

  final anchors = List.generate(5, (_) => GlobalKey());
  final stackKey = GlobalKey();
  final selectedNotifier = ValueNotifier<int>(0);
  final stickyOffsetNotifier = ValueNotifier<double>(0.0);
  int get selected => selectedNotifier.value;
  double get stickyOffset => stickyOffsetNotifier.value;
  ScrollPosition? position;
  bool jumping = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != position) {
      position?.removeListener(track);
      position = next;
      position?.addListener(track);
    }
  }
  @override
  void dispose() {
    position?.removeListener(track);
    selectedNotifier.dispose();
    stickyOffsetNotifier.dispose();
    super.dispose();
  }
  void syncScroll({required bool updateActive}) {
    if (!mounted) return;
    if (updateActive) {
      final viewport = position?.context.storageContext.findRenderObject();
      final top =
          viewport is RenderBox ? viewport.localToGlobal(Offset.zero).dy : 0.0;
      var active = 0;
      for (var i = 0; i < anchors.length; i++) {
        final box = anchors[i].currentContext?.findRenderObject();
        if (box is RenderBox &&
            box.hasSize &&
            box.localToGlobal(Offset.zero).dy <= top + 180) {
          active = i;
        }
      }
      if (active != selectedNotifier.value) {
        selectedNotifier.value = active;
      }
    }
  }
  void track() {
    if (!mounted) return;
    syncScroll(updateActive: !jumping);
  }
  static const labels = [
    'التفاصيل',
    'الأسعار',
    'الموقع',
    'المزايا',
    'شروط الحجز'
  ];
  Future<void> jump(int index) async {
    jumping = true;
    selectedNotifier.value = index;
    final c = anchors[index].currentContext;
    if (c != null)
      await Scrollable.ensureVisible(c,
          alignment: .12,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260));
    jumping = false;
    syncScroll(updateActive: false);
  }
  Widget section(int i, Widget content) => Card(
      key: anchors[i],
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(i == 2 ? 'الموقع على الخريطة' : labels[i],
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            content
          ])));
  @override
  Widget build(BuildContext context) {
    final v = widget.venue;
    final List<String> media = [];
    void collectMedia(dynamic list) {
      if (list is Iterable) {
        for (final item in list) {
          final s = item?.toString().trim() ?? '';
          if (s.isNotEmpty && !media.contains(s)) media.add(s);
        }
      }
    }
    collectMedia(v['mediaPaths']);
    collectMedia(v['images']);
    collectMedia(v['photos']);
    final cover = v['coverUrl']?.toString().trim();
    if (cover != null && cover.isNotEmpty && !media.contains(cover)) {
      media.insert(0, cover);
    }
    final video = (v['videoUrl'] ?? v['video'])?.toString().trim();
    if (video != null && video.isNotEmpty && !media.contains(video)) {
      media.add(video);
    }
    collectMedia(v['videos']);
    collectMedia(v['videoUrls']);
    final point = bookingCoordinates(v);
    final guest = const {
      'families': 'عوائل فقط',
      'youth': 'شباب فقط',
      'both': 'عوائل وشباب'
    }[v['guestType']];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BookingMediaGallery(
          paths: media,
          overlay: Builder(
              builder: (shareCtx) => IconButton.filled(
                  tooltip: 'مشاركة المكان',
                  style: IconButton.styleFrom(
                      backgroundColor: bookingNavy.withValues(alpha: .72),
                      foregroundColor: Colors.white),
                  onPressed: () => Share.share(
                        '${v['name']}\n${v['location'] ?? ''}',
                        sharePositionOrigin: shareOrigin(shareCtx),
                      ),
                  icon: const Icon(Icons.ios_share_outlined)))),
      const SizedBox(height: 14),
      Text('${v['name'] ?? ''}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: bookingGold,
            fontFamily: 'Cairo',
          )),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: bookingGold),
            const SizedBox(width: 4),
            Expanded(
              child: Text('${v['location'] ?? 'العنوان غير متوفر'}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13.5,
                      fontFamily: 'Cairo',
                      height: 1.4)),
            ),
          ],
        ),
      ),
      Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('نوع الضيوف: ${guest ?? 'غير محدد'}',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(
                '${media.where((p) => !isBookingVideoPath(p)).length} صور · ${media.where((p) => isBookingVideoPath(p)).length} فيديو',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
      const SizedBox(height: 16),
      // Navigation Tab Bar (Fluid, zero jitter, perfectly responsive)
      Container(
        margin: const EdgeInsets.only(top: 14, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: .6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ValueListenableBuilder<int>(
            valueListenable: selectedNotifier,
            builder: (context, currentSelected, _) => Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Semantics(
                      selected: currentSelected == i,
                      child: TextButton(
                        key: ValueKey('booking-section-$i'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: currentSelected == i
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => jump(i),
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 12, top: 12),
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
                            labels[i],
                            softWrap: false,
                            style: TextStyle(
                              fontWeight: currentSelected == i
                                  ? FontWeight.w700
                                  : FontWeight.w500,
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


                      Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              border: Border.all(
                                  color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(18)),
                          child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((v['area'] as num? ?? 0) > 0)
                                      _Spec(
                                          icon: const Icon(Icons.straighten_rounded,
                                              size: 22, color: bookingGold),
                                          label: Text('${v['area']} م²')),
                                    if ((v['bedrooms'] as num? ?? 0) > 0)
                                      _Spec(
                                          icon: const Icon(Icons.bed_rounded,
                                              size: 22, color: bookingGold),
                                          label: Text('${v['bedrooms']} غرف')),
                                    if ((v['capacity'] as num? ?? 0) > 0)
                                      _Spec(
                                          icon: const Icon(Icons.groups_rounded,
                                              size: 22, color: bookingGold),
                                          label: Text('${v['capacity']} ضيف')),
                                    if ((v['bathrooms'] as num? ?? 0) > 0)
                                      _Spec(
                                          icon: const Icon(
                                              Icons.bathtub_rounded,
                                              size: 22, color: bookingGold),
                                          label:
                                              Text('${v['bathrooms']} حمام')),
                                    if ((v['pools'] as num? ?? 0) > 0 || (v['amenities'] as List? ?? []).contains('pool'))
                                      _Spec(
                                          icon: const Icon(Icons.pool_rounded,
                                              size: 22, color: bookingGold),
                                          label: Text((v['pools'] as num? ?? 0) > 0 ? '${v['pools']} مسبح' : 'مسبح')),
                                    if ((v['parkingSpots'] as num? ?? 0) > 0 || (v['amenities'] as List? ?? []).contains('parking'))
                                      _Spec(
                                          icon: const Icon(
                                              Icons.directions_car_rounded,
                                              size: 22, color: bookingGold),
                                          label: Text((v['parkingSpots'] as num? ?? 0) > 0 ? '${v['parkingSpots']} موقف' : 'موقف سيارات')),
                                  ]))),
                      const SizedBox(height: 20),
                      section(
                          0,
                          BookingVenueDescription(
                              text:
                                  '${v['description'] ?? 'لم يُضف وصف لهذا المكان.'}')),
                      section(1, BookingVenuePrices(venue: v)),
                      section(
                          2,
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 20, color: bookingGold),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(
                                          '${v['location'] ?? 'العنوان غير متوفر'}',
                                          style: const TextStyle(
                                              fontSize: 15, height: 1.6))),
                                ]),
                                if (point != null) ...[
                                  const SizedBox(height: 12),
                                  BookingVenueMiniMap(point: point, venue: v),
                                ] else
                                  Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white10
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'إحداثيات المكان غير مسجلة على الخريطة حالياً؛ تواصل مع المالك للاسترشاد.',
                                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'Cairo'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                              ])),
                      section(
                          3,
                          BookingAmenityGrid(
                              amenities:
                                  List<String>.from(v['amenities'] ?? []))),
                      section(
                          4,
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.gavel_rounded, size: 20, color: bookingGold),
                                    const SizedBox(width: 8),
                                    const Flexible(child: Text('الشروط والتعليمات المعتمدة',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                const Divider(height: 20),
                                for (final line in ('${v['terms'] ?? 'تطبق الشروط العامة للحجز والالتزام بمواعيد الدخول والخروج والمحافظة على المكان ومحتوياته.'}').split('\n'))
                                  if (line.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 8),
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: bookingGold,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              line.trim(),
                                              style: const TextStyle(fontSize: 14, height: 1.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                              ],
                            ),
                          )),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: OutlinedButton.icon(
                          key: const ValueKey('booking-report-venue-btn'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _openVenueReportDialog(context, v),
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text('الإبلاغ عن هذا المكان',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
    ]);
  }
}
class _Spec extends StatelessWidget {
  const _Spec({required this.icon, required this.label});
  final Widget icon, label;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 90,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            IconTheme(
                data: IconThemeData(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 24),
                child: icon),
            const SizedBox(height: 8),
            DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
                child: label)
          ])));
}
class BookingVenueDescription extends StatefulWidget {
  const BookingVenueDescription({super.key, required this.text});
  final String text;
  @override
  State<BookingVenueDescription> createState() =>
      _BookingVenueDescriptionState();
}
class _BookingVenueDescriptionState extends State<BookingVenueDescription> {
  bool expanded = false;
  @override
  void didUpdateWidget(covariant BookingVenueDescription old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) expanded = false;
  }
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final style = DefaultTextStyle.of(context)
            .style
            .merge(const TextStyle(fontSize: 15, height: 1.8));
        final measured = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: 4,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context))
          ..layout(maxWidth: bounds.maxWidth);
        final more = measured.didExceedMaxLines;
        measured.dispose();
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.text,
                  maxLines: expanded ? null : 4,
                  overflow:
                      expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: style),
              if (more)
                Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                        onPressed: () => setState(() => expanded = !expanded),
                        child: Text(expanded ? 'عرض أقل' : 'المزيد')))
            ]);
      });
}
class BookingAmenityGrid extends StatelessWidget {
  const BookingAmenityGrid({super.key, required this.amenities});
  final List<String> amenities;
  static const icons = {
    'pool': Icons.pool_outlined,
    'parking': Icons.local_parking_outlined,
    'wifi': Icons.wifi,
    'kitchen': Icons.countertops_outlined,
    'accessible': Icons.accessible,
    'playground': Icons.child_care_outlined,
    'gamingRoom': Icons.sports_esports_outlined,
    'grill': Icons.outdoor_grill_outlined,
    'outdoorSeating': Icons.deck_outlined,
    'garden': Icons.park_outlined,
    'generator': Icons.power_outlined,
    'security': Icons.security_outlined,
    'airConditioning': Icons.ac_unit,
    'view': Icons.landscape_outlined,
    'heating': Icons.thermostat_outlined,
    'sauna': Icons.hot_tub_outlined,
    'jacuzzi': Icons.bathtub_outlined,
  };
  @override
  Widget build(BuildContext context) {
    final sourceList = amenities.isNotEmpty
        ? amenities
        : const ['pool', 'wifi', 'parking', 'outdoorSeating', 'grill', 'garden'];
    final known = sourceList.where(bookingAmenities.containsKey).toList();
    if (known.isEmpty) return const Text('لم تُدرج مزايا لهذا المكان.');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(builder: (c, b) {
      final count =
          b.maxWidth >= 350 && MediaQuery.textScalerOf(c).scale(1) < 1.4
              ? 3
              : 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final a in known)
          SizedBox(
              width: (b.maxWidth - (count - 1) * 10) / count,
              child: Container(
                  constraints: const BoxConstraints(minHeight: 96),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icons[a] ?? Icons.check_circle_outline, size: 28, color: bookingGold),
                      const SizedBox(height: 8),
                      Text(bookingAmenities[a]!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cairo',
                            height: 1.35,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ))
                    ])))
      ]);
    });
  }
}
