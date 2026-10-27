import 'package:flutter/foundation.dart' show listEquals;
import 'booking_page_indicator.dart';
import 'booking_design.dart';
import 'package:intl/intl.dart' show NumberFormat;
export 'booking_state_view.dart';
import 'booking_media_image.dart';
import 'dart:io';
import 'booking_media_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_filters.dart';
import 'booking_pricing_draft.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

class BookingMediaGallery extends StatefulWidget {
  const BookingMediaGallery({super.key, required this.paths, this.overlay});
  final List<String> paths;
  final Widget? overlay;
  @override
  State<BookingMediaGallery> createState() => _BookingMediaGalleryState();
}

class _BookingMediaGalleryState extends State<BookingMediaGallery> {
  final controller = PageController();
  int page = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget media(String path) {
    if (path.endsWith('.mp4'))
      return ColoredBox(
          color: bookingNavy,
          child: Center(
              child: OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => _BookingVideo(path: path))),
                  icon: const Icon(Icons.play_circle_outline, size: 32),
                  label: const Text('مشاهدة فيديو المكان'))));
    if (path.startsWith('asset://') ||
        path.startsWith('https://') ||
        path.startsWith('booking_media_v3/') ||
        path.startsWith('booking_media/')) return BookingMediaImage(url: path);
    return FutureBuilder(
        future: FirebaseStorage.instance.ref(path).getData(10 * 1024 * 1024),
        builder: (context, s) {
          if (s.hasError) return const Center(child: Text('تعذر تحميل الصورة'));
          if (!s.hasData)
            return const Center(child: CircularProgressIndicator());
          return Image.memory(s.data!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Center(child: Text('تعذر عرض الصورة')));
        });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
                aspectRatio: 4 / 3,
                child: widget.paths.isEmpty
                    ? const ColoredBox(
                        color: bookingNavy,
                        child: Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              Icon(Icons.holiday_village_outlined,
                                  size: 58, color: bookingGold),
                              SizedBox(height: 12),
                              Text('صور المكان غير متاحة حاليًا',
                                  style: TextStyle(color: Colors.white70)),
                            ])))
                    : Stack(fit: StackFit.expand, children: [
                        if (widget.overlay != null) const SizedBox.shrink(),
                        PageView.builder(
                            controller: controller,
                            itemCount: widget.paths.length,
                            onPageChanged: (v) => setState(() => page = v),
                            itemBuilder: (_, i) => Semantics(
                                label:
                                    'وسائط المكان، العنصر ${i + 1} من ${widget.paths.length}',
                                child: widget.paths[i].endsWith('.mp4')
                                    ? media(widget.paths[i])
                                    : GestureDetector(
                                        onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => BookingScaffold(
                                                    appBar: AppBar(
                                                        title: const Text(
                                                            'صور المكان')),
                                                    body: Center(
                                                        child:
                                                            InteractiveViewer(child: media(widget.paths[i])))))),
                                        child: media(widget.paths[i])))),
                        if (widget.overlay != null)
                          PositionedDirectional(
                              top: 12, start: 12, child: widget.overlay!),
                        Positioned(
                            bottom: 12,
                            left: 12,
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: bookingNavy.withValues(alpha: .75),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text('${page + 1} / ${widget.paths.length}',
                                    style: const TextStyle(color: Colors.white)))),
                        if (widget.paths.length > 1)
                          Positioned(
                              bottom: 8,
                              right: 8,
                              child: Row(children: [
                                IconButton.filled(
                                    tooltip: 'الوسيط السابق',
                                    style: IconButton.styleFrom(
                                        backgroundColor:
                                            bookingNavy.withValues(alpha: .75),
                                        foregroundColor: Colors.white),
                                    onPressed: page > 0
                                        ? () => controller.previousPage(
                                            duration:
                                                const Duration(milliseconds: 240),
                                            curve: Curves.easeOut)
                                        : null,
                                    icon: const Icon(Icons.arrow_back_ios_new,
                                        size: 16)),
                                const SizedBox(width: 6),
                                IconButton.filled(
                                    tooltip: 'الوسيط التالي',
                                    style: IconButton.styleFrom(
                                        backgroundColor:
                                            bookingNavy.withValues(alpha: .75),
                                        foregroundColor: Colors.white),
                                    onPressed: page < widget.paths.length - 1
                                        ? () => controller.nextPage(
                                            duration:
                                                const Duration(milliseconds: 240),
                                            curve: Curves.easeOut)
                                        : null,
                                    icon: const Icon(Icons.arrow_forward_ios,
                                        size: 16))
                              ]))
                      ]))),
        BookingPageIndicator(
            count: widget.paths.length,
            page: page,
            onPage: (i) => controller.animateToPage(i,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut))
      ]);
}

class _BookingVideo extends StatefulWidget {
  const _BookingVideo({required this.path});
  final String path;
  @override
  State<_BookingVideo> createState() => _BookingVideoState();
}

class _BookingVideoState extends State<_BookingVideo> {
  VideoPlayerController? controller;
  File? localVideo;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      if (widget.path.startsWith('booking_media_v3/') ||
          widget.path.startsWith('booking_media/')) {
        final file = await BookingMediaService.downloadVideo(
            FirebaseStorage.instance.bucket, widget.path);
        if (!mounted) {
          await file.parent.delete(recursive: true);
          return;
        }
        localVideo = file;
        final c = VideoPlayerController.file(file);
        controller = c;
        await c.initialize();
        if (mounted) setState(() {});
        return;
      }
      final url = widget.path.startsWith('booking_media_v3/')
          ? BookingMediaService.videoUrl(
              FirebaseStorage.instance.bucket, widget.path)
          : widget.path.startsWith('https://')
              ? widget.path
              : await FirebaseStorage.instance
                  .ref(widget.path)
                  .getDownloadURL();
      if (!mounted) return;
      final token = (widget.path.startsWith('https://') ||
              widget.path.startsWith('booking_media_v3/'))
          ? await FirebaseAuth.instance.currentUser?.getIdToken()
          : null;
      final c = VideoPlayerController.networkUrl(Uri.parse(url),
          httpHeaders: token == null ? {} : {'Authorization': 'Bearer $token'});
      controller = c;
      await c.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تشغيل الفيديو');
    }
  }

  @override
  void dispose() {
    final file = localVideo;
    final disposed = controller?.dispose();
    if (file != null) {
      (disposed ?? Future<void>.value())
          .then((_) => file.parent.delete(recursive: true))
          .catchError((_) => file.parent);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('فيديو المكان')),
      body: Center(
          child: error != null
              ? Text(error!)
              : controller?.value.isInitialized != true
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      AspectRatio(
                          aspectRatio: controller!.value.aspectRatio,
                          child: VideoPlayer(controller!)),
                      IconButton(
                          onPressed: () => setState(() {
                                controller!.value.isPlaying
                                    ? controller!.pause()
                                    : controller!.play();
                              }),
                          icon: Icon(controller!.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow))
                    ])));
}

String bookingMoney(dynamic value) => value is num && value.isFinite
    ? '${NumberFormat('#,##0.########', 'en').format(value)} د.ع'
    : 'غير متوفر';
String bookingVisitTime(DateTime? value) => value == null
    ? 'لم يحدد'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour % 12 == 0 ? 12 : value.hour % 12}:${value.minute.toString().padLeft(2, '0')} ${value.hour < 12 ? 'ص' : 'م'}';

const bookingStatusNames = {
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

const bookingNavy = Color(0xFF0F172A);
const bookingGold = Color(0xFFC5A16B);

class BookingSummary extends StatelessWidget {
  const BookingSummary(
      {super.key, required this.booking, required this.status});
  final Map<String, dynamic> booking;
  final String status;
  String money(dynamic value) => bookingMoney(value);
  String time(dynamic value) {
    if (value is! num || !value.isFinite) return 'غير متوفر';
    try {
      return bookingVisitTime(
          DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
              .add(const Duration(hours: 3)));
    } on RangeError {
      return 'غير متوفر';
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${booking['venueName']}',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        Text(
            '${venueCategory(booking['category'])} · ${booking['location'] ?? 'غير متوفر'}',
            style: const TextStyle(height: 1.7)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Chip(label: Text(status))),
        for (final group in [
          {
            'الدخول — بغداد': time(booking['start']),
            'الخروج — بغداد': time(booking['end'])
          },
          {
            'الإجمالي': money(booking['total']),
            'العربون': money(booking['deposit']),
            'المدفوع المعتمد': money(booking['paid']),
            'المتبقي': money(booking['remaining'])
          },
          {
            'الزبون': '${booking['customerName'] ?? 'غير متوفر'}',
            'رقم الزبون': '${booking['customerPhone'] ?? 'غير متوفر'}',
            'المالك': '${booking['ownerName'] ?? 'غير متوفر'}',
            'رقم المالك': '${booking['ownerPhone'] ?? 'غير متوفر'}'
          },
          {
            'الشروط': '${booking['terms'] ?? 'غير متوفر'}',
            'الملاحظات': '${booking['notes'] ?? "—"}'
          },
        ])
          Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in group.entries)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.key,
                                        style: const TextStyle(
                                            color: Colors.blueGrey)),
                                    Text(entry.value,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            height: 1.6,
                                            fontWeight: FontWeight.w600))
                                  ]))
                      ]))),
      ]);
}

String venueCategory(dynamic value) =>
    const {
      'chalet': 'شاليه',
      'hall': 'قاعة',
      'farm': 'مزرعة',
      'other': 'مكان'
    }[value] ??
    'مكان';

const bookingCardTitleStyle =
    TextStyle(fontSize: 16, height: 1.3, fontWeight: FontWeight.w700);
const bookingCardLocationStyle = TextStyle(fontSize: 12, height: 1.3);
String? bookingGuestLabel(dynamic value) => const {
      'families': 'عوائل فقط',
      'youth': 'شباب فقط',
      'both': 'عوائل وشباب'
    }[value];
num? bookingCardPrice(Map<String, dynamic> v) {
  try {
    final n = bookingValidStartingPrice(v);
    return n != null && n > 0 && n.isFinite ? n : null;
  } catch (_) {
    return null;
  }
}

List<String> bookingCardShifts(Map<String, dynamic> v) {
  final v2 = BookingPricingDraft.fromVenue(v);
  if (v2 != null) {
    final names = [for (final s in v2.enabledShifts) '${s['name']}'];
    return [
      ...names.take(2),
      if (names.length > 2) '+${names.length - 2} فترات'
    ];
  }
  if (v['pricingMode'] != 'shifts') return [];
  final names = [
    for (final s in v['shifts'] as List? ?? [])
      if (s is Map &&
          s['name'] is String &&
          (s['name'] as String).trim().isNotEmpty)
        '${s['name']}'
  ];
  return [...names.take(2), if (names.length > 2) '+${names.length - 2} فترات'];
}

TextSpan bookingCardPriceSpan(Map<String, dynamic> v) => TextSpan(
        style: const TextStyle(
            fontSize: 17, height: 1.3, fontWeight: FontWeight.w700),
        children: [
          TextSpan(
              text: bookingCardPrice(v) == null
                  ? 'السعر غير متوفر'
                  : bookingMoney(bookingCardPrice(v))),
          if (bookingCardPrice(v) != null)
            TextSpan(
                text:
                    ' / ${BookingPricingDraft.fromVenue(v) != null || v['pricingMode'] == 'shifts' ? 'للفترة' : v['pricingMode'] == 'hourly' ? 'للساعة' : 'للحجز'}',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w500))
        ]);
double bookingCompactCardHeight(
    BuildContext context, Map<String, dynamic> venue, double width) {
  final inner = width - 24;
  double measure(InlineSpan span, double w, {int? lines}) {
    final p = TextPainter(
        text: TextSpan(
            style: DefaultTextStyle.of(context).style, children: [span]),
        textDirection: TextDirection.rtl,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: lines)
      ..layout(maxWidth: w);
    final h = p.height;
    p.dispose();
    return h;
  }

  var meta = 0.0;
  if (bookingGuestLabel(venue['guestType']) != null)
    meta += measure(
            TextSpan(
                text: bookingGuestLabel(venue['guestType']),
                style: const TextStyle(fontSize: 11.5, height: 1.3)),
            inner - 20,
            lines: 1) +
        6;
  final labels = bookingCardShifts(venue);
  if (labels.isNotEmpty) {
    meta += measure(
            TextSpan(
                text: labels.join(' · '),
                style: const TextStyle(fontSize: 11, height: 1.25)),
            inner - 16,
            lines: 1) +
        12;
  }
  return width / 1.95 +
      20 +
      measure(
          TextSpan(
              text: '${venue['name'] ?? ''}', style: bookingCardTitleStyle),
          inner,
          lines: 1) +
      3 +
      measure(
          TextSpan(
              text: '${venue['location'] ?? ''}',
              style: bookingCardLocationStyle),
          inner - 20,
          lines: 1) +
      6 +
      meta +
      measure(bookingCardPriceSpan(venue), inner, lines: 1) +
      4;
}

class BookingCardMedia extends StatefulWidget {
  const BookingCardMedia(
      {super.key,
      required this.paths,
      required this.name,
      this.featured = false,
      this.compact = false,
      required this.category});
  final List<String> paths;
  final String name, category;
  final bool featured, compact;
  @override
  State<BookingCardMedia> createState() => _BookingCardMediaState();
}

class _BookingCardMediaState extends State<BookingCardMedia> {
  @override
  void didUpdateWidget(covariant BookingCardMedia old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name || !listEquals(old.paths, widget.paths)) {
      page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) controller.jumpToPage(0);
      });
    }
  }

  final controller = PageController();
  int page = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paths =
        widget.paths.where((p) => !p.toLowerCase().endsWith('.mp4')).toList();
    return AspectRatio(
        aspectRatio: 1.95,
        child: Stack(fit: StackFit.expand, children: [
          if (paths.isEmpty)
            ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.holiday_village_outlined, size: 40))
          else if (widget.compact)
            Semantics(
                image: true,
                label: 'صورة ${widget.name}، 1 من ${paths.length}',
                child: BookingMediaImage(url: paths.first))
          else
            PageView.builder(
                controller: controller,
                itemCount: paths.length,
                onPageChanged: (i) => setState(() => page = i),
                itemBuilder: (_, i) => Semantics(
                    image: true,
                    label: 'صورة ${widget.name}، ${i + 1} من ${paths.length}',
                    child: BookingMediaImage(url: paths[i]))),
          PositionedDirectional(
              top: 10,
              end: 10,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: widget.featured
                          ? bookingGold
                          : bookingNavy.withValues(alpha: .85),
                      borderRadius: BorderRadius.circular(9)),
                  child: Text(widget.featured ? 'مميز' : widget.category,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color:
                              widget.featured ? bookingNavy : Colors.white)))),
          if (!widget.compact && paths.length > 1)
            Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: bookingNavy.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(18)),
                        child: SizedBox(
                            width: (paths.length < 7 ? paths.length : 7) * 14.0 + 12.0,
                            height: 22,
                            child: Theme(
                                data: Theme.of(context).copyWith(
                                    colorScheme: Theme.of(context)
                                        .colorScheme
                                        .copyWith(onSurfaceVariant: Colors.white)),
                                child: BookingPageIndicator(
                                    count: paths.length,
                                    page: page,
                                    onPage: (i) => controller.animateToPage(i,
                                        duration: const Duration(milliseconds: 180),
                                        curve: Curves.easeOut)))))))
        ]));
  }
}

class BookingVenueCard extends StatelessWidget {
  const BookingVenueCard(
      {super.key,
      required this.venue,
      required this.onTap,
      this.compact = false,
      this.featured = false});
  final Map<String, dynamic> venue;
  final VoidCallback onTap;
  final bool compact, featured;
  @override
  Widget build(BuildContext context) {
    final paths = List<String>.from(venue['mediaPaths'] ?? []);
    final cover = venue['coverUrl'];
    if (cover is String && cover.isNotEmpty && !paths.contains(cover))
      paths.insert(0, cover);
    final guest = bookingGuestLabel(venue['guestType']),
        shifts = bookingCardShifts(venue),
        muted = Theme.of(context).colorScheme.onSurfaceVariant,
        isVenueFeatured =
            venue['featured'] == true || venue['isFeatured'] == true;
    return Card(
        margin: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
        elevation: Theme.of(context).brightness == Brightness.light ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: .09),
        child: InkWell(
            onTap: onTap,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BookingCardMedia(
                      paths: paths,
                      name: '${venue['name'] ?? ''}',
                      category: venueCategory(venue['category']),
                      compact: compact,
                      featured: isVenueFeatured),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Name
                            Text('${venue['name'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: bookingCardTitleStyle),
                            const SizedBox(height: 3),

                            // 2. Location
                            Row(children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: muted),
                              const SizedBox(width: 4),
                              Expanded(
                                  child: Text('${venue['location'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: bookingCardLocationStyle.copyWith(
                                          color: muted)))
                            ]),
                            const SizedBox(height: 6),

                            // 3. Shifts
                            if (shifts.isNotEmpty)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: compact
                                      ? Row(children: [
                                          for (var i = 0;
                                              i < shifts.length;
                                              i++) ...[
                                            if (i > 0)
                                              const SizedBox(width: 6),
                                            Flexible(
                                                child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest
                                                            .withValues(
                                                                alpha: .5),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6)),
                                                    child: Text(shifts[i],
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            height: 1.25))))
                                          ]
                                        ])
                                      : Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            for (final name in shifts)
                                              Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest
                                                          .withValues(
                                                              alpha: .5),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6)),
                                                  child: Text(name,
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          height: 1.25)))
                                          ])),

                            // 4. Reception Type
                            if (guest != null)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(children: [
                                    Icon(Icons.groups_outlined,
                                        size: 14, color: muted),
                                    const SizedBox(width: 4),
                                    Expanded(
                                        child: Text(guest,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                height: 1.3,
                                                color: muted)))
                                  ])),

                            // 5. Price
                            Text.rich(
                              bookingCardPriceSpan(venue),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            // If not compact: Deposit strictly removed
                            if (!compact) ...[
                              const Divider(height: 16),
                              if ((venue['capacity'] as num? ?? 0) > 0)
                                Text('السعة ${venue['capacity']} ضيف'),
                              const SizedBox(height: 4),
                              const Text('استكشف المكان والتوافر')
                            ]
                          ]))
                ])));
  }
}

class BookingProgress extends StatelessWidget {
  const BookingProgress({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    const stages = [
      'requested',
      'held',
      'payment_review',
      'confirmed',
      'arrived',
      'completed'
    ];
    const labels = [
      'الطلب',
      'الموافقة',
      'مراجعة العربون',
      'التأكيد',
      'الوصول',
      'الانتهاء'
    ];
    final current = stages.indexOf(status);
    return Column(children: [
      for (var i = 0; i < stages.length; i++)
        ListTile(
            dense: true,
            leading: Icon(
                i <= current
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: i <= current ? bookingGold : Colors.grey),
            title: Text(labels[i]),
            selected: i == current)
    ]);
  }
}

class BookingCalendar extends StatelessWidget {
  const BookingCalendar(
      {super.key,
      required this.month,
      required this.slots,
      required this.onSelect,
      required this.intervalForDay,
      this.selectedDay});
  final DateTime month;
  final DateTime? selectedDay;
  final List<Map<String, dynamic>> slots;
  final List<DateTime> Function(DateTime) intervalForDay;
  final void Function(DateTime) onSelect;
  String state(DateTime day) {
    final range = intervalForDay(day);
    var result = 'available';
    for (final slot in slots) {
      if (range[0].millisecondsSinceEpoch < slot['end'] &&
          slot['start'] < range[1].millisecondsSinceEpoch) {
        if (slot['state'] == 'unavailable') return 'unavailable';
        if (slot['state'] == 'confirmed')
          result = 'confirmed';
        else if (result == 'available') result = 'pending';
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    const names = {
      'available': 'متوفر',
      'pending': 'قيد الانتظار',
      'confirmed': 'مؤكد',
      'unavailable': 'غير متاح'
    };
    const colors = {
      'available': Colors.white,
      'pending': Color(0xFFDFC18E),
      'confirmed': Color(0xFF90C6AC),
      'unavailable': Color(0xFF94A3B8)
    };
    const icons = {
      'available': Icons.event_available,
      'pending': Icons.schedule,
      'confirmed': Icons.check_circle_outline,
      'unavailable': Icons.lock_outline
    };
    final legendColors = Theme.of(context).brightness == Brightness.dark
        ? colors
        : const {
            'available': Color(0xFF0F172A),
            'pending': Color(0xFF795522),
            'confirmed': Color(0xFF236445),
            'unavailable': Color(0xFF5F6F85)
          };
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = (DateTime(month.year, month.month, 1).weekday + 1) % 7;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ][month.month - 1]} ${month.year} — توقيت بغداد',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, children: [
        for (final key in names.keys)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icons[key],
                size: 18,
                color: key == 'available'
                    ? Theme.of(context).colorScheme.onSurface
                    : legendColors[key]),
            const SizedBox(width: 4),
            Flexible(
                child: Text(names[key]!,
                    style: TextStyle(
                        color: key == 'available'
                            ? Theme.of(context).colorScheme.onSurface
                            : legendColors[key])))
          ])
      ]),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, bounds) {
        final scale = MediaQuery.textScalerOf(context);
        const columns = 7;
        final width = (bounds.maxWidth - 4 * (columns - 1)) / columns;
        final height = 42 + scale.scale(18);
        return Wrap(spacing: 4, runSpacing: 4, children: [
          if (columns == 7) ...[
            for (final label in [
              'سبت',
              'أحد',
              'اثن',
              'ثلا',
              'أرب',
              'خمي',
              'جمع'
            ])
              SizedBox(
                  width: width,
                  child: Center(
                      child: Semantics(
                          label: const {
                            'سبت': 'السبت',
                            'أحد': 'الأحد',
                            'اثن': 'الاثنين',
                            'ثلا': 'الثلاثاء',
                            'أرب': 'الأربعاء',
                            'خمي': 'الخميس',
                            'جمع': 'الجمعة'
                          }[label],
                          child: ExcludeSemantics(
                              child: Text(
                                  width < 40 ? label.substring(0, 2) : label,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(fontSize: 12)))))),
            for (var i = 0; i < offset; i++)
              SizedBox(width: width, height: height),
          ],
          for (var n = 1; n <= count; n++)
            SizedBox(
                width: width,
                height: height,
                child: Builder(builder: (context) {
                  final day = DateTime(month.year, month.month, n);
                  final value = state(day);
                  final selected = day.year == selectedDay?.year &&
                      day.month == selectedDay?.month &&
                      day.day == selectedDay?.day;
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final dayDate = DateTime(day.year, day.month, day.day);
                  final isPast = dayDate.isBefore(today);
                  final canSelect = !isPast && !['confirmed', 'unavailable'].contains(value);
                  return Semantics(
                      selected: selected,
                      label: '$n ${names[value]}',
                      child: Tooltip(
                          message: names[value]!,
                          child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  disabledForegroundColor:
                                      Theme.of(context).brightness == Brightness.dark
                                          ? colors[value]
                                          : bookingNavy,
                                  side: BorderSide(
                                      color: selected
                                          ? bookingGold
                                          : const Color(0xFFCBD5E1),
                                      width: selected ? 2 : 1),
                                  backgroundColor:
                                      Theme.of(context).brightness == Brightness.dark
                                          ? (value == 'available'
                                              ? const Color(0xFF182338)
                                              : colors[value]!
                                                  .withValues(alpha: .16))
                                          : colors[value],
                                  foregroundColor:
                                      Theme.of(context).brightness == Brightness.dark
                                          ? (value == 'available'
                                              ? const Color(0xFFF1F3F7)
                                              : colors[value])
                                          : bookingNavy),
                              onPressed: canSelect ? () => onSelect(day) : null,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text('$n',
                                            maxLines: 1,
                                            softWrap: false,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600))),
                                    Icon(
                                        selected
                                            ? Icons.radio_button_checked
                                            : icons[value],
                                        size: 14)
                                  ]))));
                })),
        ]);
      }),
    ]);
  }
}

class BookingScaffold extends StatelessWidget {
  const BookingScaffold(
      {super.key,
      this.appBar,
      this.body,
      this.bottomNavigationBar,
      this.edgeToEdge = false});
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? body;

  /// Used only by the discovery landing route. Other booking pages retain
  /// their established system-bar and SafeArea behavior.
  final bool edgeToEdge;
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: bookingDesignTheme(Theme.of(context)),
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              extendBodyBehindAppBar: edgeToEdge,
              bottomNavigationBar: bottomNavigationBar == null
                  ? null
                  : SafeArea(top: false, child: bottomNavigationBar!),
              appBar: appBar,
              body: edgeToEdge
                  // ListView applies MediaQuery.padding automatically when it
                  // is primary. Remove only that automatic inset; the hero
                  // still reads viewPadding and reserves its own safe content
                  // space while its gold background reaches y=0.
                  ? MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: body ?? const SizedBox.shrink())
                  : SafeArea(child: body ?? const SizedBox.shrink()))),
    );
  }
}

/// Shared by the live booking request and the offline design review.
class BookingVenueOverview extends StatelessWidget {
  const BookingVenueOverview(
      {super.key, required this.venue, required this.total});
  final Map<String, dynamic> venue;
  final num total;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${venue['name'] ?? 'تفاصيل المكان'}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        Text('${venue['location']} · المالك: ${venue['ownerName']}',
            style: TextStyle(
                height: 1.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        Card(
            margin: EdgeInsets.zero,
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('تفاصيل السعر',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      for (final entry in {
                        'السعر المحدد': total,
                        'العربون': venue['deposit'],
                        'المتبقي بعد اعتماد العربون':
                            total - (venue['deposit'] as num)
                      }.entries)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 24,
                                runSpacing: 6,
                                children: [
                                  Text(entry.key),
                                  Text(bookingMoney(entry.value),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700))
                                ])),
                      const Divider(height: 24),
                      const Text('الشروط قبل الحجز',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('${venue['terms']}',
                          style: const TextStyle(height: 1.8)),
                    ]))),
        const SizedBox(height: 20),
      ]);
}

class BookingMetricCard extends StatelessWidget {
  const BookingMetricCard(
      {super.key,
      required this.title,
      required this.value,
      required this.icon});
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Icon(icon, color: bookingGold),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.w700)),
                ]))
          ])));
}

class BookingVenueVideoPreview extends StatelessWidget {
  const BookingVenueVideoPreview({super.key, required this.path, this.poster});
  final String path;
  final String? poster;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(fit: StackFit.expand, children: [
            if (poster != null)
              BookingMediaImage(url: poster!)
            else
              const ColoredBox(color: bookingNavy),
            ColoredBox(color: Colors.black.withValues(alpha: .18)),
            Center(
                child: IconButton.filled(
                    tooltip: 'تشغيل فيديو المكان',
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .90),
                        foregroundColor: bookingNavy),
                    iconSize: 38,
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => _BookingVideo(path: path))),
                    icon: const Icon(Icons.play_arrow_rounded)))
          ])));
}
