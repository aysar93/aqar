import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// نتيجة التحقق من ملف الفيديو قبل رفعه.
class BookingReelVideoValidation {
  final bool isValid;
  final String? errorMessage;

  const BookingReelVideoValidation.valid()
      : isValid = true,
        errorMessage = null;

  const BookingReelVideoValidation.invalid(this.errorMessage) : isValid = false;
}

/// نتيجة رفع فيديو ريل الحجوزات إلى Firebase Storage.
class BookingReelUploadResult {
  final String downloadUrl;
  final String storagePath;
  final String fileName;
  final int sizeBytes;

  const BookingReelUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.fileName,
    required this.sizeBytes,
  });
}

/// خدمة معزولة تماماً لإدارة رفع وحذف فيديوهات ريلز الحجوزات.
/// تستخدم مسار Firebase Storage المخصص:
/// `booking_reels_media/{venueId}/{authorUid}/{fileName}`
/// ولا تلمس مساحة تخزين ريلز العقارات (Cloudflare R2) بأي شكل.
class BookingReelMediaService {
  /// الحد الأقصى لحجم الفيديو وفق قواعد Storage (50 ميجابايت).
  static const int maxVideoBytes = 50 * 1024 * 1024;

  /// الصيغ المدعومة وفق قواعد Storage (`video/mp4`).
  static const Set<String> allowedExtensions = {'mp4'};

  /// التحقق من اسم الملف وصيغته وحجمه قبل بدء الرفع.
  static BookingReelVideoValidation validateVideoFile({
    required String fileName,
    required int sizeBytes,
  }) {
    if (sizeBytes <= 0) {
      return const BookingReelVideoValidation.invalid(
        'الملف المختار فارغ أو تالف ولا يمكن رفعه.',
      );
    }
    if (sizeBytes > maxVideoBytes) {
      return const BookingReelVideoValidation.invalid(
        'حجم الفيديو يتجاوز الحد المسموح (50 ميجابايت كحد أقصى).',
      );
    }
    final ext = fileExtension(fileName);
    if (!allowedExtensions.contains(ext)) {
      return const BookingReelVideoValidation.invalid(
        'صيغة الفيديو غير مدعومة؛ يرجى اختيار ملف MP4.',
      );
    }
    return const BookingReelVideoValidation.valid();
  }

  /// التحقق من أن الرابط الخارجي رابط ويب صالح وليس مساراً محلياً على الجهاز.
  static String? validateExternalVideoUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return 'رابط الفيديو مطلوب';
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return 'الرابط غير صحيح — يجب أن يبدأ بـ https://';
    }
    return null;
  }

  /// بناء مسار تخزين معزول متوافق مع `storage.rules`:
  /// `booking_reels_media/{venueId}/{authorUid}/{fileName}`
  static String buildStoragePath({
    required String venueId,
    required String authorUid,
    int? timestampMs,
  }) {
    final safeVenue = venueId.trim().isEmpty
        ? 'admin_reels'
        : venueId.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final safeUid = authorUid.trim().isEmpty
        ? 'admin'
        : authorUid.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    return 'booking_reels_media/$safeVenue/$safeUid/reel_$ts.mp4';
  }

  /// استخراج اسم الملف من المسار دون الاعتماد على حزمة خارجية.
  static String fileBaseName(String filePath) {
    final parts = filePath.split(RegExp(r'[/\\]')).where((e) => e.isNotEmpty);
    return parts.isEmpty ? filePath : parts.last;
  }

  /// استخراج الامتداد بالأحرف الصغيرة دون النقطة.
  static String fileExtension(String fileName) {
    final base = fileBaseName(fileName);
    final dot = base.lastIndexOf('.');
    if (dot < 0 || dot == base.length - 1) return '';
    return base.substring(dot + 1).toLowerCase();
  }

  /// تنسيق حجم الملف للعرض للمستخدم.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  /// تنسيق مدة الفيديو للعرض للمستخدم.
  static String formatDuration(Duration? duration) {
    if (duration == null || duration <= Duration.zero) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// بدء مهمة رفع الفيديو إلى Firebase Storage مع متابعة التقدم.
  static UploadTask startUploadTask({
    required File file,
    required String storagePath,
  }) {
    final ref = FirebaseStorage.instance.ref(storagePath);
    return ref.putFile(
      file,
      SettableMetadata(contentType: 'video/mp4'),
    );
  }

  /// حذف ملف فيديو سابق من مساحة `booking_reels_media/` فقط.
  /// لا يمس أي مسارات أخرى ولا يفشل العملية الرئيسية عند تعذر الحذف.
  static Future<void> deleteStorageObjectIfOwned(String? storagePath) async {
    final path = storagePath?.trim() ?? '';
    if (path.isEmpty || !path.startsWith('booking_reels_media/')) {
      return;
    }
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } catch (_) {
      // تجاهل أخطاء الحذف غير الحرجة (مثل عدم وجود الملف مسبقاً)
    }
  }
}
