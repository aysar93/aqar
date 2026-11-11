import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

import 'booking_media_image.dart';
import 'booking_media_service.dart';

/// Describes a resolved video playback source ready for `VideoPlayerController`.
class BookingResolvedVideoSource {
  const BookingResolvedVideoSource.network(
    Uri this.uri, {
    this.headers = const {},
  }) : file = null;

  const BookingResolvedVideoSource.file(File this.file)
      : uri = null,
        headers = const {};

  final Uri? uri;
  final File? file;
  final Map<String, String> headers;
}

/// Permission or authorization failure when resolving a restricted booking video.
class BookingVideoPermissionException implements Exception {
  BookingVideoPermissionException([
    this.message = 'ليس لديك صلاحية مشاهدة هذا الفيديو',
  ]);
  final String message;

  @override
  String toString() => message;
}

/// Unifies video path/URL resolution, trusted Bearer header attachment,
/// token-refresh retry on 401/expired credentials, and temp-file cleanup
/// across Reels and inline booking video players on both Android and iOS.
class BookingVideoResolver {
  BookingVideoResolver._();

  static bool isGatewayVideoPath(String raw) {
    final trimmed = raw.trim();
    return trimmed.startsWith('booking_media_v3/') ||
        trimmed.startsWith('booking_media/');
  }

  static bool isNetworkVideoUrl(String raw) {
    final trimmed = raw.trim().toLowerCase();
    return trimmed.startsWith('https://') || trimmed.startsWith('http://');
  }

  static bool isGsUrl(String raw) => raw.trim().toLowerCase().startsWith('gs://');

  static bool isSafeRelativeStoragePath(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('/') ||
        trimmed.contains('..') ||
        trimmed.contains('\\')) {
      return false;
    }
    return !trimmed.contains('://');
  }

  static Future<String?> safeIdToken({bool forceRefresh = false}) async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
    } catch (_) {
      return null;
    }
  }

  static String safeBucket() {
    try {
      return FirebaseStorage.instance.bucket;
    } catch (_) {
      return '';
    }
  }

  /// Resolves [rawPathOrUrl] into either an authenticated local downloaded file
  /// (for `booking_media_v3/` and `booking_media/` gateway paths) or a
  /// normalized network [Uri] with Bearer headers attached **only** for trusted
  /// Firebase/Cloud Functions hosts.
  static Future<BookingResolvedVideoSource> resolve(
    String rawPathOrUrl, {
    bool forceRefreshToken = false,
    Future<File> Function(String bucket, String path, {bool forceRefreshToken})?
        downloadGatewayVideo,
    Future<String> Function(String path)? resolveStorageUrl,
    Future<String?> Function({bool forceRefresh})? getIdToken,
    String? bucket,
  }) async {
    final source = rawPathOrUrl.trim();
    if (source.isEmpty) {
      throw const FormatException('رابط الفيديو غير متاح');
    }

    if (isGatewayVideoPath(source)) {
      final b = bucket ?? safeBucket();
      final downloader = downloadGatewayVideo ??
          (String bkt, String p, {bool forceRefreshToken = false}) =>
              BookingMediaService.downloadVideo(
                bkt,
                p,
                forceRefreshToken: forceRefreshToken,
              );
      final file = await downloader(b, source, forceRefreshToken: forceRefreshToken);
      return BookingResolvedVideoSource.file(file);
    }

    if (isNetworkVideoUrl(source)) {
      final uri = Uri.tryParse(source);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw const FormatException('رابط الفيديو غير صالح');
      }
      final trusted = BookingMediaImage.isTrustedMediaUrl(uri.toString());
      final token = trusted
          ? await (getIdToken ?? safeIdToken)(forceRefresh: forceRefreshToken)
          : null;
      return BookingResolvedVideoSource.network(
        uri,
        headers: (token != null && token.isNotEmpty)
            ? {'Authorization': 'Bearer $token'}
            : const {},
      );
    }

    if (isGsUrl(source)) {
      final resolver = resolveStorageUrl ??
          (p) => FirebaseStorage.instance.refFromURL(p).getDownloadURL();
      final downloadUrl = await resolver(source);
      final uri = Uri.parse(downloadUrl);
      return BookingResolvedVideoSource.network(uri);
    }

    if (!isSafeRelativeStoragePath(source)) {
      throw const FormatException('مسار الفيديو غير صالح');
    }

    final resolver = resolveStorageUrl ??
        (p) => FirebaseStorage.instance.ref(p).getDownloadURL();
    final downloadUrl = await resolver(source);
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('تعذر استخراج رابط الفيديو');
    }
    return BookingResolvedVideoSource.network(uri);
  }

  /// Creates and initializes a [VideoPlayerController], automatically retrying
  /// once with a force-refreshed ID token if the initial attempt fails with an
  /// authentication error (401 / unauthenticated / expired token).
  static Future<({VideoPlayerController controller, File? localFile})>
      openInitializedController(
    String rawPathOrUrl, {
    bool Function()? isCancelled,
    Future<BookingResolvedVideoSource> Function(
      String raw, {
      required bool forceRefreshToken,
    })? sourceResolver,
    VideoPlayerController Function(BookingResolvedVideoSource source)?
        controllerFactory,
  }) async {
    Future<({VideoPlayerController controller, File? localFile})> attempt({
      required bool forceRefreshToken,
    }) async {
      final source = await (sourceResolver != null
          ? sourceResolver(
              rawPathOrUrl,
              forceRefreshToken: forceRefreshToken,
            )
          : resolve(
              rawPathOrUrl,
              forceRefreshToken: forceRefreshToken,
            ));

      if (isCancelled?.call() == true) {
        if (source.file != null) {
          await cleanupTempFile(source.file);
        }
        throw StateError('cancelled');
      }

      final factory = controllerFactory ??
          (BookingResolvedVideoSource src) {
            if (src.file != null) {
              return VideoPlayerController.file(src.file!);
            }
            return VideoPlayerController.networkUrl(
              src.uri!,
              httpHeaders: src.headers,
            );
          };

      final controller = factory(source);
      try {
        await controller.initialize();
        if (isCancelled?.call() == true) {
          await disposeControllerAndFile(controller, source.file);
          throw StateError('cancelled');
        }
        return (controller: controller, localFile: source.file);
      } catch (_) {
        await disposeControllerAndFile(controller, source.file);
        rethrow;
      }
    }

    try {
      return await attempt(forceRefreshToken: false);
    } on BookingVideoPermissionException {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final looksUnauthorized =
          msg.contains('401') ||
          msg.contains('unauthenticated') ||
          msg.contains('expired') ||
          msg.contains('token');
      if (looksUnauthorized && isCancelled?.call() != true) {
        return attempt(forceRefreshToken: true);
      }
      rethrow;
    }
  }

  static Future<void> cleanupTempFile(File? file) async {
    if (file == null) return;
    try {
      final parent = file.parent;
      if (await parent.exists()) {
        await parent.delete(recursive: true);
      }
    } catch (_) {}
  }

  static Future<void> disposeControllerAndFile(
    VideoPlayerController? controller,
    File? file,
  ) async {
    try {
      await controller?.dispose();
    } catch (_) {}
    await cleanupTempFile(file);
  }

  static String describePlaybackError(Object error) {
    if (error is BookingVideoPermissionException) {
      return error.message;
    }
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('403') ||
        lower.contains('permission') ||
        lower.contains('unauthorized') ||
        lower.contains('صلاحية')) {
      return 'ليس لديك صلاحية مشاهدة هذا الفيديو';
    }
    if (lower.contains('404') ||
        lower.contains('not-found') ||
        lower.contains('object-not-found')) {
      return 'المقطع غير متاح أو تم حذفه';
    }
    if (error is FormatException ||
        lower.contains('رابط الفيديو غير') ||
        lower.contains('مسار الفيديو غير صالح')) {
      return 'رابط أو صيغة الفيديو غير صالحة';
    }
    if (lower.contains('timeout') ||
        lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('اتصال')) {
      return 'تعذر تشغيل الفيديو؛ تحقق من الاتصال بالإنترنت وأعد المحاولة';
    }
    return 'تعذر تشغيل الفيديو';
  }
}
