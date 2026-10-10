import 'booking_media_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_filters.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

class BookingMediaGallery extends StatelessWidget {
  const BookingMediaGallery({super.key, required this.paths});
  final List<String> paths;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final path in paths)
          if (path.endsWith('.mp4'))
            TextButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _BookingVideo(path: path))),
                icon: const Icon(Icons.play_circle),
                label: const Text('مشاهدة فيديو المكان'))
          else if (path.startsWith('https://'))
            Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(18),
                    child: BookingMediaImage(url: path)))
          else
            FutureBuilder(
                future: FirebaseStorage.instance
                    .ref(path)
                    .getData(10 * 1024 * 1024),
                builder: (context, s) {
                  if (s.hasError) return const Text('تعذر تحميل الصورة');
                  if (!s.hasData) return const LinearProgressIndicator();
                  return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.memory(s.data!, fit: BoxFit.cover)));
                }),
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
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final url =
          widget.path.startsWith('https://') ? widget.path : await FirebaseStorage.instance.ref(widget.path).getDownloadURL();
      if (!mounted) return;
      final token = widget.path.startsWith('https://') ? await FirebaseAuth.instance.currentUser?.getIdToken() : null;
      final c = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: token == null ? {} : {'Authorization': 'Bearer $token'});
      controller = c;
      await c.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تشغيل الفيديو');
    }
  }

  @override
  void dispose() {
    controller?.dispose();
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

const bookingNavy = Color(0xFF0F172A);
const bookingGold = Color(0xFFB8943B);

class BookingSummary extends StatelessWidget {
  const BookingSummary(
      {super.key, required this.booking, required this.status});
  final Map<String, dynamic> booking;
  final String status;
  String time(dynamic value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
          .add(const Duration(hours: 3))
          .toString()
          .substring(0, 16)
      : '—';
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${booking['venueName']}',
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, color: bookingNavy)),
        Text('${venueCategory(booking['category'])} · ${booking['location']}',
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
            'الإجمالي': '${booking['total']} د.ع',
            'العربون': '${booking['deposit']} د.ع',
            'المدفوع المعتمد': '${booking['paid']} د.ع',
            'المتبقي': '${booking['remaining']} د.ع'
          },
          {
            'الزبون': '${booking['customerName']}',
            'رقم الزبون': '${booking['customerPhone']}',
            'المالك': '${booking['ownerName']}',
            'رقم المالك': '${booking['ownerPhone']}'
          },
          {
            'الشروط': '${booking['terms']}',
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
            onTap: onTap,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                          color: bookingNavy,
                          child: venue['coverUrl'] is String &&
                                  (venue['coverUrl'] as String)
                                      .startsWith('https://')
                              ? Image.network(venue['coverUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.holiday_village_outlined,
                                      color: bookingGold,
                                      size: 64))
                              : const Icon(Icons.holiday_village_outlined,
                                  color: bookingGold, size: 64))),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(venueCategory(venue['category']),
                                style: const TextStyle(
                                    color: bookingGold,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('${venue['name'] ?? ''}',
                                style: const TextStyle(
                                    color: bookingNavy,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('${venue['location'] ?? ''}',
                                style: const TextStyle(height: 1.6)),
                            if ((venue['capacity'] as num? ?? 0) > 0)
                              Text(
                                  'السعة ${venue['capacity']} ضيف — الغرف ${venue['bedrooms'] ?? 0}'),
                            if ((venue['unitName'] ?? '').toString().isNotEmpty)
                              Text(
                                  '${venue['complexName'] ?? ''} — ${venue['unitName']}'),
                            const Divider(height: 28),
                            Text(
                                '${venue['pricingMode'] == 'shifts' ? 'يبدأ من ' : ''}${bookingStartingPrice(venue)} د.ع ${venue['pricingMode'] == 'shifts' ? 'للشفت' : venue['pricingMode'] == 'hourly' ? 'للساعة' : 'للحجز'}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: bookingNavy)),
                            Text('العربون ${venue['deposit']} د.ع',
                                style: const TextStyle(height: 1.6)),
                            const SizedBox(height: 12),
                            const Text('التفاصيل والتوافر ←',
                                style: TextStyle(
                                    color: bookingGold,
                                    fontWeight: FontWeight.w700)),
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
      required this.intervalForDay});
  final DateTime month;
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
      LayoutBuilder(
          builder: (context, bounds) =>
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (var n = 1; n <= count; n++)
                  SizedBox(
                      width: (bounds.maxWidth -
                              4 *
                                  (((bounds.maxWidth /
                                              (MediaQuery.textScalerOf(context)
                                                          .scale(14) *
                                                      2.5 +
                                                  16))
                                          .floor()
                                          .clamp(3, 7)) -
                                      1)) /
                          ((bounds.maxWidth /
                                  (MediaQuery.textScalerOf(context).scale(14) *
                                          2.5 +
                                      16))
                              .floor()
                              .clamp(3, 7)),
                      height: 72 + MediaQuery.textScalerOf(context).scale(24),
                      child: Builder(builder: (context) {
                        final day = DateTime(month.year, month.month, n),
                            value = state(day),
                            range = intervalForDay(day);
                        final future = range[0].isAfter(DateTime.now());
                        return Semantics(
                            label: '$n ${names[value]}',
                            child: Tooltip(
                                message: names[value]!,
                                child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        backgroundColor: colors[value],
                                        foregroundColor: bookingNavy),
                                    onPressed: future &&
                                            !['confirmed', 'unavailable']
                                                .contains(value)
                                        ? () => onSelect(day)
                                        : null,
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('$n'),
                                          Icon(icons[value], size: 16)
                                        ]))));
                      }))
              ])),
    ]);
  }
}

class BookingScaffold extends StatelessWidget {
  const BookingScaffold({super.key, this.appBar, this.body});
  final PreferredSizeWidget? appBar;
  final Widget? body;
  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light(useMaterial3: true);
    return Theme(
      data: base.copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: bookingNavy),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        textTheme: base.textTheme
            .apply(bodyColor: bookingNavy, displayColor: bookingNavy),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 0),
        appBarTheme: const AppBarTheme(
            backgroundColor: bookingNavy, foregroundColor: Colors.white),
        inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder()),
      ),
      child: Scaffold(appBar: appBar, body: body),
    );
  }
}
