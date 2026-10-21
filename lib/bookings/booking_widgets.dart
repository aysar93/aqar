import 'package:intl/intl.dart' show NumberFormat;
export 'booking_state_view.dart';
import 'booking_media_image.dart';
import 'dart:io';
import 'booking_media_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_filters.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

class BookingMediaGallery extends StatefulWidget {
  const BookingMediaGallery({super.key, required this.paths});
  final List<String> paths;
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
    if (path.startsWith('https://') ||
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
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
          aspectRatio: 16 / 10,
          child: widget.paths.isEmpty
              ? const ColoredBox(
                  color: bookingNavy,
                  child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.holiday_village_outlined,
                        size: 58, color: bookingGold),
                    SizedBox(height: 12),
                    Text('صور المكان غير متاحة حاليًا',
                        style: TextStyle(color: Colors.white70)),
                  ])))
              : Stack(fit: StackFit.expand, children: [
                  PageView.builder(
                      controller: controller,
                      itemCount: widget.paths.length,
                      onPageChanged: (v) => setState(() => page = v),
                      itemBuilder: (_, i) => Semantics(
                          label:
                              'وسائط المكان، العنصر ${i + 1} من ${widget.paths.length}',
                          child: media(widget.paths[i]))),
                  Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: bookingNavy,
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
                              onPressed: page > 0
                                  ? () => controller.previousPage(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOut)
                                  : null,
                              icon: const Icon(Icons.chevron_right)),
                          const SizedBox(width: 8),
                          IconButton.filled(
                              tooltip: 'الوسيط التالي',
                              onPressed: page < widget.paths.length - 1
                                  ? () => controller.nextPage(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOut)
                                  : null,
                              icon: const Icon(Icons.chevron_left)),
                        ])),
                ])));
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
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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
const bookingGold = Color(0xFFB8943B);

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
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, color: bookingNavy)),
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

class BookingVenueCard extends StatelessWidget {
  const BookingVenueCard({super.key, required this.venue, required this.onTap});
  final Map<String, dynamic> venue;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
            onTap: onTap,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(children: [
                    AspectRatio(
                        aspectRatio: 1.8,
                        child: ColoredBox(
                            color: bookingNavy,
                            child: venue['coverUrl'] is String &&
                                    (venue['coverUrl'] as String)
                                        .startsWith('https://')
                                ? Image.network(venue['coverUrl'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(
                                            Icons.holiday_village_outlined,
                                            color: bookingGold,
                                            size: 64)))
                                : const Center(
                                    child: Icon(Icons.holiday_village_outlined,
                                        color: bookingGold, size: 64)))),
                    Positioned(
                        top: 16,
                        right: 16,
                        child: Chip(
                            label: Text(venueCategory(venue['category'])))),
                  ]),
                  Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${venue['name'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 23, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('⌖  ${venue['location'] ?? ''}',
                                style: const TextStyle(
                                    color: Color(0xFF64748B), height: 1.6)),
                            const SizedBox(height: 12),
                            Wrap(spacing: 16, runSpacing: 8, children: [
                              if ((venue['capacity'] as num? ?? 0) > 0)
                                Text('السعة ${venue['capacity']} ضيف'),
                              if ((venue['bedrooms'] as num? ?? 0) > 0)
                                Text('${venue['bedrooms']} غرف'),
                              if ((venue['unitName'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                    '${venue['complexName'] ?? ''} — ${venue['unitName']}'),
                            ]),
                            const Divider(height: 30),
                            Text(
                                '${venue['pricingMode'] == 'shifts' ? 'يبدأ من ' : ''}${bookingMoney(bookingStartingPrice(venue))}',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w700)),
                            Text(
                                '${venue['pricingMode'] == 'shifts' ? 'للشفت' : venue['pricingMode'] == 'hourly' ? 'للساعة' : 'للحجز'} · العربون ${bookingMoney(venue['deposit'])}',
                                style: const TextStyle(
                                    color: Color(0xFF64748B), height: 1.7)),
                            const SizedBox(height: 14),
                            const Row(children: [
                              Expanded(
                                  child: Text('استكشف المكان والتوافر',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700))),
                              Icon(Icons.arrow_back,
                                  size: 20, color: bookingGold)
                            ]),
                          ])),
                ])),
      );
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
      'pending': Color(0xFFFFE082),
      'confirmed': Color(0xFFA5D6A7),
      'unavailable': Color(0xFFCFD8DC)
    };
    const icons = {
      'available': Icons.event_available,
      'pending': Icons.schedule,
      'confirmed': Icons.check_circle_outline,
      'unavailable': Icons.lock_outline
    };
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = (DateTime(month.year, month.month, 1).weekday + 1) % 7;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${month.year} / ${month.month} — توقيت بغداد',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, children: [
        for (final key in names.keys)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icons[key], size: 18),
            const SizedBox(width: 4),
            Flexible(child: Text(names[key]!))
          ])
      ]),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, bounds) {
        final scale = MediaQuery.textScalerOf(context);
        final columns = scale.scale(14) <= 18 && bounds.maxWidth >= 280
            ? 7
            : (bounds.maxWidth / (scale.scale(14) * 2.5 + 16))
                .floor()
                .clamp(3, 7);
        final width = (bounds.maxWidth - 4 * (columns - 1)) / columns;
        final height = 48 + scale.scale(24);
        return Wrap(spacing: 4, runSpacing: 4, children: [
          if (columns == 7) ...[
            for (final label in [
              'السبت',
              'الأحد',
              'الاثنين',
              'الثلاثاء',
              'الأربعاء',
              'الخميس',
              'الجمعة'
            ])
              SizedBox(
                  width: width,
                  child: Center(
                      child:
                          Text(label, style: const TextStyle(fontSize: 12)))),
            for (var i = 0; i < offset; i++)
              SizedBox(width: width, height: height),
          ],
          for (var n = 1; n <= count; n++)
            SizedBox(
                width: width,
                height: height,
                child: Builder(builder: (context) {
                  final day = DateTime(month.year, month.month, n);
                  final value = state(day), range = intervalForDay(day);
                  final selected = day.year == selectedDay?.year &&
                      day.month == selectedDay?.month &&
                      day.day == selectedDay?.day;
                  final future = range[0].isAfter(DateTime.now());
                  return Semantics(
                      selected: selected,
                      label: '$n ${names[value]}',
                      child: Tooltip(
                          message: names[value]!,
                          child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  disabledForegroundColor: bookingNavy,
                                  side: BorderSide(
                                      color: selected
                                          ? bookingGold
                                          : const Color(0xFFCBD5E1),
                                      width: selected ? 2 : 1),
                                  backgroundColor: selected
                                      ? const Color(0xFFF4EAD0)
                                      : colors[value],
                                  foregroundColor: bookingNavy),
                              onPressed: future &&
                                      !['confirmed', 'unavailable']
                                          .contains(value)
                                  ? () => onSelect(day)
                                  : null,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('$n'),
                                    Icon(icons[value], size: 16)
                                  ]))));
                })),
        ]);
      }),
    ]);
  }
}

class BookingScaffold extends StatelessWidget {
  const BookingScaffold(
      {super.key, this.appBar, this.body, this.bottomNavigationBar});
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? body;
  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light(useMaterial3: true);
    return Theme(
      data: base.copyWith(
        colorScheme: ColorScheme.fromSeed(
                seedColor: bookingNavy,
                primary: bookingNavy,
                secondary: bookingGold)
            .copyWith(
                secondaryContainer: const Color(0xFFF4EAD0),
                onSecondaryContainer: bookingNavy),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size(48, 52),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(
                    fontFamily: 'SplashTajawal', fontWeight: FontWeight.w700))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)))),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        chipTheme: base.chipTheme.copyWith(
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFFF4EAD0),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            labelStyle: const TextStyle(
                fontFamily: 'SplashTajawal', color: bookingNavy)),
        textTheme: base.textTheme.apply(
            fontFamily: 'SplashTajawal',
            bodyColor: bookingNavy,
            displayColor: bookingNavy),
        cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24))),
        appBarTheme: const AppBarTheme(
            backgroundColor: bookingNavy, foregroundColor: Colors.white),
        inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.all(18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)))),
      ),
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              bottomNavigationBar: bottomNavigationBar == null
                  ? null
                  : SafeArea(top: false, child: bottomNavigationBar!),
              appBar: appBar,
              body: SafeArea(child: body ?? const SizedBox.shrink()))),
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
            style: const TextStyle(height: 1.8, color: Color(0xFF64748B))),
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
                  Text(title, style: const TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 23, fontWeight: FontWeight.w700)),
                ]))
          ])));
}
