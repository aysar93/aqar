import 'dart:async';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'booking_page_indicator.dart';
import 'booking_design.dart';
import 'booking_geo_utils.dart';
import 'booking_reference_checkout.dart' show bookingSafeDateTime;
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

bool isBookingVideoPath(String path) {
  final clean = path.split('?').first.toLowerCase();
  return clean.endsWith('.mp4') ||
      clean.endsWith('.mov') ||
      clean.endsWith('.m4v') ||
      clean.endsWith('.webm');
}

class BookingMediaGallery extends StatefulWidget {
  const BookingMediaGallery({super.key, required this.paths, this.overlay, this.venueId});
  final List<String> paths;
  final Widget? overlay;
  final String? venueId;
  @override
  State<BookingMediaGallery> createState() => _BookingMediaGalleryState();
}

class _BookingMediaGalleryState extends State<BookingMediaGallery> {
  final controller = PageController();
  int page = 0;
  Timer? _autoTimer;
  bool _userInteracted = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    if (widget.paths.length <= 1) return;
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!mounted || !controller.hasClients) return;
      if (_userInteracted) {
        t.cancel();
        return;
      }
      final next = (page + 1) % widget.paths.length;
      controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Widget media(String path) {
    if (isBookingVideoPath(path)) {
      return _BookingInlineVideo(path: path);
    }
    if (path.startsWith('asset://') ||
        path.startsWith('https://') ||
        path.startsWith('http://') ||
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
                    : Listener(
                        onPointerDown: (_) {
                          if (!_userInteracted) {
                            _userInteracted = true;
                            _autoTimer?.cancel();
                          }
                        },
                        child: Stack(fit: StackFit.expand, children: [
                          PageView.builder(
                              controller: controller,
                              itemCount: widget.paths.length,
                              onPageChanged: (v) {
                                setState(() => page = v);
                              },
                              itemBuilder: (_, i) {
                                final isVideo = isBookingVideoPath(widget.paths[i]);
                                return Semantics(
                                  label: isVideo
                                      ? 'فيديو المكان، العنصر ${i + 1} من ${widget.paths.length}'
                                      : 'صورة المكان، العنصر ${i + 1} من ${widget.paths.length}',
                                  child: isVideo
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            media(widget.paths[i]),
                                            PositionedDirectional(
                                              top: 14,
                                              start: 14,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: bookingNavy.withValues(alpha: .85),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: bookingGold.withValues(alpha: .7)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.videocam_rounded, size: 16, color: bookingGold),
                                                    SizedBox(width: 5),
                                                    Text(
                                                      'مشاهدة فيديو المكان',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        fontFamily: 'Cairo',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : GestureDetector(
                                          onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => BookingScaffold(
                                                      appBar: AppBar(
                                                          title: const Text('صور المكان')),
                                                      body: Center(
                                                          child: InteractiveViewer(
                                                              child: media(widget.paths[i])))))),
                                          child: media(widget.paths[i]),
                                        ),
                                );
                              }),
                          // Favorite button
                          PositionedDirectional(
                            top: 12,
                            end: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: bookingNavy.withValues(alpha: .75),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: _isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                                onPressed: () {
                                  setState(() => _isFavorite = !_isFavorite);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 1),
                                      content: Text(_isFavorite ? 'تمت إضافة المكان إلى المفضلة' : 'تمت الإزالة من المفضلة'),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: _isFavorite ? const Color(0xFFEF4444) : Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
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
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))),
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
                                ])),
                        ])))),
        const SizedBox(height: 8),
        BookingPageIndicator(
            count: widget.paths.length,
            page: page,
            onPage: (i) {
              _userInteracted = true;
              _autoTimer?.cancel();
              controller.animateToPage(i,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut);
            })
      ]);
}

class _BookingInlineVideo extends StatefulWidget {
  const _BookingInlineVideo({required this.path});
  final String path;
  @override
  State<_BookingInlineVideo> createState() => _BookingInlineVideoState();
}

class _BookingInlineVideoState extends State<_BookingInlineVideo> {
  VideoPlayerController? controller;
  File? localVideo;
  String? error;
  bool loading = true;

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
        if (mounted) setState(() => loading = false);
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
      final isFirebaseStorage = url.contains('firebasestorage.googleapis.com') ||
          url.contains('storage.googleapis.com');
      final token = isFirebaseStorage
          ? await FirebaseAuth.instance.currentUser?.getIdToken()
          : null;
      final c = VideoPlayerController.networkUrl(Uri.parse(url),
          httpHeaders: token == null ? {} : {'Authorization': 'Bearer $token'});
      controller = c;
      await c.initialize();
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'تعذر تشغيل الفيديو؛ تحقق من الاتصال بالإنترنت.';
        });
      }
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
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        color: bookingNavy,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 36),
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: () {
                setState(() {
                  loading = true;
                  error = null;
                });
                load();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (loading || controller?.value.isInitialized != true) {
      return Container(
        color: bookingNavy,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: bookingGold),
            SizedBox(height: 12),
            Text('جارٍ تحميل الفيديو...', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }

    final c = controller!;
    return GestureDetector(
      onTap: () {
        setState(() {
          c.value.isPlaying ? c.pause() : c.play();
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 44, color: Colors.white),
              ),
            ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        c.value.isPlaying ? 'إيقاف' : 'تشغيل',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingScaffold(
                          appBar: AppBar(title: const Text('فيديو المكان')),
                          body: Center(
                            child: InteractiveViewer(
                              child: AspectRatio(
                                aspectRatio: c.value.aspectRatio,
                                child: VideoPlayer(c),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _BookingVideo = _BookingInlineVideo;

String bookingMoney(dynamic value) {
  num? n;
  if (value is num && value.isFinite) {
    n = value;
  } else if (value is String) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    n = num.tryParse(cleaned);
  }
  return (n != null && n.isFinite)
      ? '${NumberFormat('#,##0.########', 'en').format(n)} د.ع'
      : 'غير متوفر';
}

String bookingVisitTime(DateTime? value) => value == null
    ? 'لم يحدد'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour % 12 == 0 ? 12 : value.hour % 12}:${value.minute.toString().padLeft(2, '0')} ${value.hour < 12 ? 'ص' : 'م'}';

String canonicalBookingStatus(dynamic raw) {
  if (raw == null) return 'unknown';
  final s = raw.toString().trim().toLowerCase();
  if (const {'confirmed', 'مؤكد', 'حجز مؤكد'}.contains(s)) return 'confirmed';
  if (const {'cancelled', 'canceled', 'ملغي', 'ملغى', 'تم الإلغاء'}.contains(s)) return 'cancelled';
  if (const {'rejected', 'مرفوض', 'تم الرفض'}.contains(s)) return 'rejected';
  if (const {'expired', 'منتهي', 'انتهت المهلة'}.contains(s)) return 'expired';
  if (const {'held', 'معلق', 'حجز مؤقت'}.contains(s)) return 'held';
  if (const {'payment_review', 'مراجعة العربون', 'مراجعة الدفع'}.contains(s)) return 'payment_review';
  if (const {'arrived', 'تم الوصول', 'واصل'}.contains(s)) return 'arrived';
  if (const {'completed', 'مكتمل', 'منتهي الزيارة'}.contains(s)) return 'completed';
  if (const {'cancel_requested', 'طلب إلغاء'}.contains(s)) return 'cancel_requested';
  if (const {'payment_rejected', 'إيصال مرفوض'}.contains(s)) return 'payment_rejected';
  if (const {'requested', 'طلب جديد', 'بانتظار المالك'}.contains(s)) return 'requested';
  return s;
}

String bookingStatusLabel(dynamic raw) {
  if (raw == null) return 'حالة غير معروفة';
  final canon = canonicalBookingStatus(raw);
  return bookingStatusNames[canon] ?? (raw.toString().isNotEmpty ? raw.toString() : 'حالة غير معروفة');
}

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
    final dt = bookingSafeDateTime(value);
    return dt != null
        ? bookingVisitTime(dt.toUtc().add(const Duration(hours: 3)))
        : 'غير متوفر';
  }

  @override
  Widget build(BuildContext context) {
    final name = booking['venueName'] ?? booking['venueTitle'] ?? booking['title'] ?? 'شاليه / مكان';
    final loc = booking['location'] ?? booking['venueLocation'] ?? 'غير متوفر';
    final safeStatus = status.trim().isNotEmpty ? status : 'غير محدد';
    final totalVal = booking['total'] ?? booking['price'] ?? booking['totalPrice'];
    final depositVal = booking['deposit'] ?? booking['depositAmount'];
    final remainingVal = booking['remaining'] ?? booking['remainingAmount'];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$name',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface)),
      Text(
          '${venueCategory(booking['category'])} · $loc',
          style: const TextStyle(height: 1.7)),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Chip(label: Text(safeStatus))),
      for (final group in [
        {
          'الدخول — بغداد': time(booking['start']),
          'الخروج — بغداد': time(booking['end'])
        },
        {
          'الإجمالي': money(totalVal),
          'العربون': money(depositVal),
          'المدفوع المعتمد': money(booking['paid']),
          'المتبقي': money(remainingVal)
        },
        {
          'الزبون': '${booking['customerName'] ?? booking['guestName'] ?? 'غير متوفر'}',
          'رقم الزبون': '${booking['customerPhone'] ?? booking['phone'] ?? 'غير متوفر'}',
          'المالك': '${booking['ownerName'] ?? 'غير متوفر'}',
          'رقم المالك': '${booking['ownerPhone'] ?? 'غير متوفر'}'
        },
        {
          'الشروط': '${booking['terms'] ?? 'غير متوفر'}',
          'الملاحظات': '${booking['notes'] ?? booking['customerNotes'] ?? "—"}'
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
Widget buildCardShiftBadge(BuildContext context, String shiftName) {
  final isMorning = shiftName.contains('صباح') || shiftName.toLowerCase().contains('morning');
  final isEvening = shiftName.contains('مساء') || shiftName.contains('مسائ') || shiftName.toLowerCase().contains('night') || shiftName.toLowerCase().contains('evening');
  final isFullDay = shiftName.contains('كامل') || shiftName.toLowerCase().contains('fullday');
  final icon = isMorning
      ? Icons.wb_sunny_rounded
      : isEvening
          ? Icons.nights_stay_rounded
          : Icons.timelapse_rounded;
  // لون أخضر موحّد لمستطيلات الفترات
  const color = Color(0xFF10B981);
  final shortLabel = isMorning
      ? 'صباحي'
      : isEvening
          ? 'مسائي'
          : isFullDay
              ? 'يوم كامل'
              : shiftName.replaceAll('الفترة', '').trim();

  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: isDark ? 0.18 : 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          shortLabel,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
            height: 1.2,
          ),
        ),
      ],
    ),
  );
}

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
  List<String> rawNames = [];
  if (v2 != null) {
    rawNames = [for (final s in v2.enabledShifts) '${s['name']}'];
  } else if (v['pricingMode'] == 'shifts') {
    rawNames = [
      for (final s in v['shifts'] as List? ?? [])
        if (s is Map &&
            s['name'] is String &&
            (s['name'] as String).trim().isNotEmpty)
          '${s['name']}'
    ];
  }
  final cleanNames = <String>[];
  for (final n in rawNames) {
    final mapped = n.contains('صباح')
        ? 'صباحي'
        : n.contains('مساء')
            ? 'مسائي'
            : n.contains('كامل')
                ? 'يوم كامل'
                : n.replaceAll('الفترة', '').trim();
    if (mapped.isNotEmpty && !cleanNames.contains(mapped)) {
      cleanNames.add(mapped);
    }
  }
  return cleanNames;
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
      this.liveBadge,
      required this.category});
  final List<String> paths;
  final String name, category;
  final bool featured, compact;
  final String? liveBadge;
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
    final rawPaths =
        widget.paths.where((p) => !p.toLowerCase().endsWith('.mp4')).toList();
    // Micro-carousel: up to 3 images previewable horizontally
    final paths = rawPaths.take(3).toList();
    return AspectRatio(
        aspectRatio: 1.85,
        child: Stack(fit: StackFit.expand, children: [
          if (paths.isEmpty)
            ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.holiday_village_outlined, size: 40))
          else if (paths.length == 1)
            Semantics(
                image: true,
                label: 'صورة ${widget.name}، 1 من 1',
                child: BookingMediaImage(url: paths.first))
          else
            PageView.builder(
                controller: controller,
                itemCount: paths.length,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (i) => setState(() => page = i),
                itemBuilder: (_, i) => Semantics(
                    image: true,
                    label: 'صورة ${widget.name}، ${i + 1} من ${paths.length}',
                    child: BookingMediaImage(url: paths[i]))),

          // Live Availability Badge (متاح اليوم / متاح نهاية الأسبوع)
          if (widget.liveBadge != null)
            PositionedDirectional(
              top: 10,
              start: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.liveBadge!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Category / Featured Badge
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

          // Image Counter (e.g. 1 / 3)
          if (paths.length > 1)
            PositionedDirectional(
              bottom: 6,
              end: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: bookingNavy.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${page + 1} / ${paths.length}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),

          // Page Dot Indicator
          if (paths.length > 1)
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
        liveBadge = BookingGeoUtils.getLiveAvailabilityBadge(venue),
        distanceInfo = BookingGeoUtils.getDistanceInfo(venue),
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
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BookingCardMedia(
                      paths: paths,
                      name: '${venue['name'] ?? ''}',
                      category: venueCategory(venue['category']),
                      compact: compact,
                      liveBadge: liveBadge,
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

                            // 2. Location & Guest Badge
                            Row(children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: muted),
                              const SizedBox(width: 4),
                              Expanded(
                                  child: Text('${venue['location'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: bookingCardLocationStyle.copyWith(
                                          color: muted))),
                              if (guest != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: bookingGold.withValues(alpha: .15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: bookingGold.withValues(alpha: .35),
                                        width: 0.8),
                                  ),
                                  child: Text(
                                    guest,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC5A16B),
                                    ),
                                  ),
                                ),
                              ],
                            ]),

                            // 2b. Approximate Distance from Reference City
                            if (distanceInfo != null) ...[
                              const SizedBox(height: 3),
                              Row(children: [
                                const Icon(Icons.near_me_outlined,
                                    size: 13, color: Color(0xFFD4AF37)),
                                const SizedBox(width: 4),
                                Text(
                                  distanceInfo.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ]),
                            ],
                            const SizedBox(height: 6),

                            // 3. Shifts (horizontal badges with distinct sun/moon icons)
                            if (shifts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    for (final s in shifts)
                                      buildCardShiftBadge(context, s),
                                  ],
                                ),
                              ),

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

/// Single source of truth for appointment status legend
class BookingStatusLegend extends StatelessWidget {
  const BookingStatusLegend({super.key});

  static const Map<String, String> names = {
    'available': 'متاح',
    'pending': 'قيد المراجعة',
    'confirmed': 'محجوز',
    'unavailable': 'غير متاح',
  };

  static const Map<String, Color> colors = {
    'available': Color(0xFF22C55E),
    'pending': Color(0xFFD4AF37),
    'confirmed': Color(0xFFEF4444),
    'unavailable': Color(0xFF94A3B8),
  };

  static const Map<String, ({String label, Color color})> items = {
    'available': (label: 'متاح', color: Color(0xFF22C55E)),
    'pending': (label: 'قيد المراجعة', color: Color(0xFFD4AF37)),
    'confirmed': (label: 'محجوز', color: Color(0xFFEF4444)),
    'unavailable': (label: 'غير متاح', color: Color(0xFF94A3B8)),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('booking-status-legend'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 6,
        children: items.values.map((item) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 12, color: item.color),
              const SizedBox(width: 5),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class BookingCalendar extends StatelessWidget {
  const BookingCalendar(
      {super.key,
      required this.month,
      required this.slots,
      required this.onSelect,
      required this.intervalForDay,
      this.selectedDay,
      this.showLegend = false});
  final DateTime month;
  final DateTime? selectedDay;
  final List<Map<String, dynamic>> slots;
  final List<DateTime> Function(DateTime) intervalForDay;
  final void Function(DateTime) onSelect;
  final bool showLegend;

  static const names = BookingStatusLegend.names;
  static const colors = BookingStatusLegend.colors;

  String state(DateTime day) {
    // 1. Baghdad time check for past dates (+3 hours)
    final nowBaghdad = DateTime.now().toUtc().add(const Duration(hours: 3));
    final todayBaghdad = DateTime(nowBaghdad.year, nowBaghdad.month, nowBaghdad.day);
    final dayBaghdad = DateTime(day.year, day.month, day.day);
    if (dayBaghdad.isBefore(todayBaghdad)) {
      return 'unavailable';
    }

    final range = intervalForDay(day);
    if (range.length >= 2 && range[1].millisecondsSinceEpoch <= DateTime.now().millisecondsSinceEpoch) {
      return 'unavailable';
    }

    var result = 'available';
    for (final slot in slots) {
      final slotStart = slot['start'] is num ? (slot['start'] as num).toInt() : 0;
      final slotEnd = slot['end'] is num ? (slot['end'] as num).toInt() : 0;
      if (range[0].millisecondsSinceEpoch < slotEnd &&
          slotStart < range[1].millisecondsSinceEpoch) {
        final slotState = slot['state']?.toString();
        if (slotState == 'unavailable') return 'unavailable';
        if (slotState == 'confirmed') {
          result = 'confirmed';
        } else if (result == 'available') {
          result = 'pending';
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = (DateTime(month.year, month.month, 1).weekday + 1) % 7;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (showLegend) const BookingStatusLegend(),
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
                  final nowBaghdad = DateTime.now().toUtc().add(const Duration(hours: 3));
                  final isToday = day.year == nowBaghdad.year &&
                      day.month == nowBaghdad.month &&
                      day.day == nowBaghdad.day;
                  final canSelect = value == 'available';
                  final statusColor = colors[value]!;
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Semantics(
                      selected: selected,
                      enabled: canSelect,
                      label: '$n ${names[value]} ${isToday ? 'اليوم' : ''}',
                      child: Tooltip(
                          message: '${names[value]}${isToday ? ' (اليوم)' : ''}',
                          child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  side: selected
                                      ? const BorderSide(color: bookingGold, width: 2.4)
                                      : (isToday
                                          ? BorderSide(color: isDark ? Colors.white70 : bookingNavy, width: 1.5)
                                          : BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 1)),
                                  backgroundColor: value == 'available'
                                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                      : (value == 'unavailable'
                                          ? (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF1F5F9))
                                          : (isDark ? statusColor.withValues(alpha: 0.18) : statusColor.withValues(alpha: 0.12))),
                                  disabledBackgroundColor: value == 'available'
                                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                      : (value == 'unavailable'
                                          ? (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF1F5F9))
                                          : (isDark ? statusColor.withValues(alpha: 0.18) : statusColor.withValues(alpha: 0.12))),
                                  foregroundColor: isDark ? Colors.white : bookingNavy,
                                  disabledForegroundColor: value == 'unavailable'
                                      ? const Color(0xFF94A3B8)
                                      : (isDark ? Colors.white : bookingNavy)),
                              onPressed: canSelect ? () => onSelect(day) : null,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text('$n',
                                            maxLines: 1,
                                            softWrap: false,
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: isToday || selected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                color: value == 'unavailable'
                                                    ? const Color(0xFF94A3B8)
                                                    : (isDark ? const Color(0xFFF1F3F7) : bookingNavy)))),
                                    const SizedBox(height: 3),
                                    Container(
                                        width: selected ? 8 : 7,
                                        height: selected ? 8 : 7,
                                        decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                            border: selected
                                                ? Border.all(color: isDark ? Colors.black : Colors.white, width: 1)
                                                : null))
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
                child: Builder(builder: (context) {
                  final rawDep = venue['deposit'];
                  final depNum = rawDep is num
                      ? rawDep
                      : (num.tryParse(rawDep?.toString() ?? '') ?? 0);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('تفاصيل السعر',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      for (final entry in {
                        'السعر المحدد': total,
                        'العربون': rawDep ?? depNum,
                        'المتبقي بعد اعتماد العربون': total - depNum
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
                    ],
                  );
                }))),
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
