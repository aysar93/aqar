import 'dart:async';
import 'dart:io';

import 'package:aqar/bookings/booking_access_guard.dart';
import 'package:aqar/bookings/booking_form_validator.dart';
import 'package:aqar/bookings/booking_management.dart';
import 'package:aqar/bookings/booking_operations.dart';
import 'package:aqar/bookings/booking_owner_calendar_view.dart';
import 'package:aqar/bookings/booking_receipt_service.dart';
import 'package:aqar/bookings/booking_reels_screen.dart';
import 'package:aqar/bookings/booking_screen.dart';
import 'package:aqar/bookings/booking_shift_visual.dart';
import 'package:aqar/bookings/booking_venue_details.dart';
import 'package:aqar/bookings/booking_video_resolver.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'support/booking_intent_store_fake.dart';

// ignore: subtype_of_sealed_class
class _FakeDocSnap extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnap(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

class _FakeVideoPlayerController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  _FakeVideoPlayerController({
    this.shouldThrowOnInitialize,
    Size size = const Size(1080, 1920),
    Duration duration = const Duration(seconds: 12),
  })  : _targetSize = size,
        _targetDuration = duration,
        super(const VideoPlayerValue.uninitialized());

  final Object? shouldThrowOnInitialize;
  final Size _targetSize;
  final Duration _targetDuration;
  bool initializedCalled = false;
  bool disposed = false;
  bool playing = false;
  bool looping = false;
  double volume = 1.0;

  @override
  Future<void> initialize() async {
    initializedCalled = true;
    if (shouldThrowOnInitialize != null) {
      throw shouldThrowOnInitialize!;
    }
    value = VideoPlayerValue(
      duration: _targetDuration,
      size: _targetSize,
      isInitialized: true,
    );
  }

  @override
  Future<void> play() async {
    playing = true;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> setLooping(bool looping) async {
    this.looping = looping;
    value = value.copyWith(isLooping: looping);
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _rtlApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF0F172A),
    ),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, body) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(textDirection: TextDirection.rtl, child: body!),
    ),
    home: child,
  );
}

Future<void> _loadFonts() async {
  await (FontLoader('SplashTajawal')
        ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
}

const Map<String, dynamic> _sampleVenue = <String, dynamic>{
  'name': 'شاليه النخيل التجريبي',
  'category': 'chalet',
  'location': 'الرمادي · الأنبار',
  'capacity': 14,
  'bedrooms': 3,
  'amenities': ['pool', 'parking'],
  'price': 180000,
  'deposit': 50000,
  'terms': 'الحفاظ على النظافة والالتزام بموعد المغادرة.',
  'pricing': {
    'version': 2,
    'timeZone': 'Asia/Baghdad',
    'deposit': 50000,
    'weekendDays': [4, 5],
    'shifts': [
      {
        'kind': 'morning',
        'name': 'الفترة الصباحية',
        'enabled': true,
        'startMinute': 540,
        'endMinute': 1080,
        'endDayOffset': 0,
        'weekdayPrice': 150000,
        'weekendPrice': 180000,
      },
      {
        'kind': 'evening',
        'name': 'الفترة المسائية',
        'enabled': true,
        'startMinute': 1140,
        'endMinute': 120,
        'endDayOffset': 1,
        'weekdayPrice': 170000,
        'weekendPrice': 200000,
      },
      {
        'kind': 'full_day',
        'name': 'اليوم الكامل',
        'enabled': true,
        'startMinute': 540,
        'endMinute': 540,
        'endDayOffset': 1,
        'weekdayPrice': 280000,
        'weekendPrice': 330000,
      },
    ],
  },
  'cancellationPolicy': {'freeCancellationHours': 24, 'lateRefundPercent': 50},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Workstream A - Video & Reels Resolution, Auth Retry & Cleanup', () {
    test('resolves public HTTPS URL without leaking auth headers', () async {
      var tokenCalls = 0;
      final source = await BookingVideoResolver.resolve(
        'https://cdn.example.com/videos/tour.mp4',
        getIdToken: ({bool forceRefresh = false}) async {
          tokenCalls++;
          return 'secret-token';
        },
      );
      expect(source.file, isNull);
      expect(source.uri.toString(), 'https://cdn.example.com/videos/tour.mp4');
      expect(source.headers, isEmpty);
      expect(tokenCalls, 0);
    });

    test('attaches Bearer token only for trusted Cloud Functions hosts',
        () async {
      final refreshFlags = <bool>[];
      final source = await BookingVideoResolver.resolve(
        'https://us-central1-demo.cloudfunctions.net/bookingMedia?path=a.mp4',
        forceRefreshToken: true,
        getIdToken: ({bool forceRefresh = false}) async {
          refreshFlags.add(forceRefresh);
          return 'refreshed-jwt-token';
        },
      );
      expect(source.file, isNull);
      expect(source.headers, {'Authorization': 'Bearer refreshed-jwt-token'});
      expect(refreshFlags, [true]);
    });

    test('downloads booking_media_v3 and booking_media paths and cleans up dir',
        () async {
      for (final prefix in ['booking_media_v3', 'booking_media']) {
        final tempDir =
            await Directory.systemTemp.createTemp('aqar_video_test_');
        final videoFile = File('${tempDir.path}/clip.mp4');
        await videoFile.writeAsBytes([0, 1, 2, 3]);

        final seenBuckets = <String>[];
        final source = await BookingVideoResolver.resolve(
          '$prefix/venue_1/tour.mp4',
          bucket: 'staging-bucket',
          downloadGatewayVideo: (bucket, path,
              {bool forceRefreshToken = false}) async {
            seenBuckets.add(bucket);
            expect(path, '$prefix/venue_1/tour.mp4');
            return videoFile;
          },
        );
        expect(seenBuckets, ['staging-bucket']);
        expect(source.uri, isNull);
        expect(source.file?.path, videoFile.path);
        expect(await tempDir.exists(), isTrue);

        await BookingVideoResolver.cleanupTempFile(source.file);
        expect(await tempDir.exists(), isFalse);
      }
    });

    test('resolves gs:// and relative paths and rejects unsafe traversal paths',
        () async {
      final gsSource = await BookingVideoResolver.resolve(
        'gs://staging-bucket/venues/v1/walkthrough.mp4',
        resolveStorageUrl: (p) async =>
            'https://firebasestorage.googleapis.com/v0/b/staging-bucket/o/walkthrough.mp4?alt=media',
      );
      expect(gsSource.file, isNull);
      expect(gsSource.uri.toString(), contains('firebasestorage.googleapis.com'));

      final relSource = await BookingVideoResolver.resolve(
        'venues/v1/walkthrough.mp4',
        resolveStorageUrl: (p) async {
          expect(p, 'venues/v1/walkthrough.mp4');
          return 'https://firebasestorage.googleapis.com/v0/b/staging-bucket/o/rel.mp4?alt=media';
        },
      );
      expect(relSource.file, isNull);
      expect(relSource.uri.toString(), contains('firebasestorage.googleapis.com'));

      await expectLater(
        () => BookingVideoResolver.resolve('../private/secret.mp4'),
        throwsFormatException,
      );
      await expectLater(
        () => BookingVideoResolver.resolve('   '),
        throwsFormatException,
      );
    });

    test('retries once with forceRefreshToken on 401 and disposes failed attempt',
        () async {
      final refreshFlags = <bool>[];
      final controllers = <_FakeVideoPlayerController>[];
      final result = await BookingVideoResolver.openInitializedController(
        'https://us-central1-demo.cloudfunctions.net/bookingMedia?path=a.mp4',
        sourceResolver: (raw, {required bool forceRefreshToken}) async {
          refreshFlags.add(forceRefreshToken);
          return BookingResolvedVideoSource.network(
            Uri.parse(raw),
            headers: {
              'Authorization':
                  'Bearer ${forceRefreshToken ? 'fresh' : 'expired'}',
            },
          );
        },
        controllerFactory: (source) {
          final isExpired =
              source.headers['Authorization']?.contains('expired') ?? false;
          final ctrl = _FakeVideoPlayerController(
            shouldThrowOnInitialize:
                isExpired ? StateError('HTTP 401 unauthenticated') : null,
          );
          controllers.add(ctrl);
          return ctrl;
        },
      );

      expect(refreshFlags, [false, true]);
      expect(controllers, hasLength(2));
      expect(controllers[0].disposed, isTrue);
      expect(controllers[1].disposed, isFalse);
      expect(controllers[1].value.isInitialized, isTrue);
      expect(result.controller, same(controllers[1]));
    });

    test('does not retry 403 permission exception and localizes playback errors',
        () async {
      var attempts = 0;
      await expectLater(
        () => BookingVideoResolver.openInitializedController(
          'booking_media_v3/v1/private.mp4',
          sourceResolver: (raw, {required bool forceRefreshToken}) async {
            attempts++;
            throw BookingVideoPermissionException(
              'ليس لديك صلاحية مشاهدة هذا الفيديو',
            );
          },
        ),
        throwsA(isA<BookingVideoPermissionException>()),
      );
      expect(attempts, 1);

      expect(
        BookingVideoResolver.describePlaybackError(
          BookingVideoPermissionException(
              'ليس لديك صلاحية مشاهدة هذا الفيديو'),
        ),
        'ليس لديك صلاحية مشاهدة هذا الفيديو',
      );
      expect(
        BookingVideoResolver.describePlaybackError(
            StateError('HTTP 404 object-not-found')),
        'المقطع غير متاح أو تم حذفه',
      );
      expect(
        BookingVideoResolver.describePlaybackError(const FormatException('bad')),
        'رابط أو صيغة الفيديو غير صالحة',
      );
      expect(
        BookingVideoResolver.describePlaybackError(
            const SocketException('timeout')),
        'تعذر تشغيل الفيديو؛ تحقق من الاتصال بالإنترنت وأعد المحاولة',
      );
    });

    test('cancellation during init disposes controller and deletes temp file',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('aqar_video_cancel_');
      final videoFile = File('${tempDir.path}/clip.mp4');
      await videoFile.writeAsBytes([1, 2, 3]);
      var cancelled = false;
      _FakeVideoPlayerController? createdController;

      await expectLater(
        () => BookingVideoResolver.openInitializedController(
          'booking_media_v3/v1/clip.mp4',
          isCancelled: () => cancelled,
          sourceResolver: (raw, {required bool forceRefreshToken}) async =>
              BookingResolvedVideoSource.file(videoFile),
          controllerFactory: (src) {
            cancelled = true;
            createdController = _FakeVideoPlayerController();
            return createdController!;
          },
        ),
        throwsStateError,
      );

      expect(createdController?.disposed, isTrue);
      expect(await tempDir.exists(), isFalse);
    });

    test('extractEligibleVenueReels detects mp4, mov, m4v, webm and /videos/',
        () {
      final docs = [
        _FakeDocSnap('v-mp4', {
          'name': 'شاليه MP4',
          'active': true,
          'verificationStatus': 'approved',
          'mediaPaths': ['img.jpg', 'https://cdn.example.com/a.MP4?alt=media'],
        }),
        _FakeDocSnap('v-mov', {
          'name': 'شاليه MOV',
          'active': true,
          'verificationStatus': 'approved',
          'mediaPaths': ['https://cdn.example.com/iphone_clip.MOV'],
        }),
        _FakeDocSnap('v-m4v', {
          'name': 'شاليه M4V',
          'active': true,
          'verificationStatus': 'approved',
          'mediaPaths': ['booking_media_v3/v3/clip.m4v'],
        }),
        _FakeDocSnap('v-webm', {
          'name': 'شاليه WEBM',
          'active': true,
          'verificationStatus': 'approved',
          'mediaPaths': ['https://cdn.example.com/tour.webm'],
        }),
        _FakeDocSnap('v-dir', {
          'name': 'شاليه مجلد فيديو',
          'active': true,
          'verificationStatus': 'approved',
          'mediaPaths': ['https://cdn.example.com/venues/videos/stream_1'],
        }),
        _FakeDocSnap('v-pending', {
          'name': 'شاليه غير معتمد',
          'active': true,
          'verificationStatus': 'pending',
          'mediaPaths': ['https://cdn.example.com/skip.mp4'],
        }),
      ];

      final reels = BookingReelItem.extractEligibleVenueReels(docs);
      expect(reels.map((r) => r.venueId).toList(),
          ['v-mp4', 'v-mov', 'v-m4v', 'v-webm', 'v-dir']);
    });

    testWidgets(
        'BookingReelCard surfaces permission errors, retries, and cleans up cancelled loads on dispose',
        (tester) async {
      await _loadFonts();
      final completer =
          Completer<({VideoPlayerController controller, File? localFile})>();
      var loadCalls = 0;

      final reel = BookingReelItem(
        id: 'r1',
        venueId: 'v1',
        ownerId: 'o1',
        venueName: 'شاليه الريلز',
        category: 'chalet',
        location: 'الرمادي',
        price: 150000,
        videoUrl: 'booking_media_v3/v1/reel.mp4',
        likesCount: 0,
        commentsCount: 0,
        sharesCount: 0,
        viewsCount: 0,
        createdAt: DateTime(2026, 11, 1),
      );

      await tester.pumpWidget(_rtlApp(Scaffold(
        body: BookingReelCard(
          reel: reel,
          isActive: true,
          isMuted: true,
          onToggleMute: () {},
          videoLoader: (url, isCancelled) async {
            loadCalls++;
            if (loadCalls == 1) {
              throw BookingVideoPermissionException(
                  'ليس لديك صلاحية مشاهدة هذا الفيديو');
            }
            return completer.future;
          },
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('ليس لديك صلاحية مشاهدة هذا الفيديو'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(loadCalls, 2);

      // Unmount card while second load is still in flight
      await tester.pumpWidget(_rtlApp(const Scaffold(body: SizedBox())));
      late Directory tempDir;
      late File tempFile;
      await tester.runAsync(() async {
        tempDir = await Directory.systemTemp.createTemp('aqar_reel_dispose_');
        tempFile = File('${tempDir.path}/reel.mp4');
        await tempFile.writeAsBytes([9, 8, 7]);
      });
      final fakeCtrl = _FakeVideoPlayerController();
      completer.complete((controller: fakeCtrl, localFile: tempFile));
      await tester.pumpAndSettle();

      expect(fakeCtrl.disposed, isTrue);
      var existsAfterDispose = true;
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
        existsAfterDispose =
            await tester.runAsync(() => tempDir.exists()) ?? true;
        if (!existsAfterDispose) break;
      }
      expect(existsAfterDispose, isFalse);
    });
  });

  group('Workstream B - Responsive Dropdowns & Zero Overflow across Widths',
      () {
    testWidgets('BookingVenueEditor renders cleanly on 320px at 1.5x RTL',
        (tester) async {
      await _loadFonts();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_rtlApp(
        BookingVenueEditor(
          ownerMode: true,
          call: (n, d) async => {},
        ),
        textScale: 1.5,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('BookingRequestScreen Step 2 fits 320/360/390/430 at 1.5x RTL',
        (tester) async {
      await _loadFonts();
      for (final width in [320.0, 360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_rtlApp(
          BookingRequestScreen(
            key: ValueKey('booking-req-$width'),
            venueId: 'v1',
            venue: _sampleVenue,
            intentStore: MemoryIntentStore(),
            currentUserId: () => 'u-test',
            call: (name, data) async {
              if (name == 'getBookingAvailability') {
                return {'slots': []};
              }
              return {'count': 0, 'average': 0, 'reviews': []};
            },
          ),
          textScale: 1.5,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Overflow on Step 0 at width=$width');
        // Advance Step 0 -> Step 1 -> select a day -> Step 2
        await tester.tap(find.byKey(const ValueKey('booking-next')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('booking-step-1')), findsOneWidget,
            reason: 'Did not advance to Step 1 at width=$width');
        expect(tester.takeException(), isNull,
            reason: 'Overflow on Step 1 before date at width=$width');
        final step1Scrollable = find.descendant(
          of: find.byKey(const ValueKey('booking-step-1')),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.byTooltip('الشهر التالي'),
          150,
          scrollable: step1Scrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('الشهر التالي'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('15'),
          150,
          scrollable: step1Scrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('15'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Overflow on Step 1 after date at width=$width');
        await tester.tap(find.byKey(const ValueKey('booking-next')));
        await tester.pumpAndSettle();
        expect(find.text('متابعة لمراجعة الحجز'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Overflow on Step 2 at width=$width');
      }
    });
  });

  group('Workstream C - PDF Receipt Sharing & iPadOS Share Anchor Bounds', () {
    test('resolveShareBounds never returns zero/empty rect', () {
      final fallbackNull = BookingReceiptService.resolveShareBounds(null);
      expect(fallbackNull.isEmpty, isFalse);
      expect(fallbackNull.width, greaterThan(0));
      expect(fallbackNull.height, greaterThan(0));

      final fallbackZero =
          BookingReceiptService.resolveShareBounds(null, Rect.zero);
      expect(fallbackZero.isEmpty, isFalse);

      const customRect = Rect.fromLTWH(40, 80, 120, 44);
      expect(BookingReceiptService.resolveShareBounds(null, customRect),
          customRect);
    });

    testWidgets('shareReceipt forwards real %PDF- bytes and widget anchor bounds',
        (tester) async {
      await _loadFonts();
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Uint8List? sharedBytes;
      String? sharedFilename;
      Rect? sharedBounds;

      await tester.pumpWidget(_rtlApp(Scaffold(
        body: Center(
          child: Builder(
            builder: (btnCtx) => ElevatedButton(
              onPressed: () async {
                await BookingReceiptService.shareReceipt(
                  bookingId: 'BK-9001',
                  booking: const {
                    'customerName': 'أحمد علي',
                    'guestCount': 6,
                    'totalPrice': 180000,
                    'deposit': 50000,
                    'status': 'confirmed',
                  },
                  venue: _sampleVenue,
                  context: btnCtx,
                  sharePdfHandler: ({
                    required Uint8List bytes,
                    required String filename,
                    Rect? bounds,
                  }) async {
                    sharedBytes = bytes;
                    sharedFilename = filename;
                    sharedBounds = bounds;
                    return true;
                  },
                );
              },
              child: const Text('مشاركة الإيصال'),
            ),
          ),
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('مشاركة الإيصال'));
      await tester.pumpAndSettle();

      expect(sharedBytes, isNotNull);
      expect(String.fromCharCodes(sharedBytes!.take(5)), '%PDF-');
      expect(sharedFilename, 'ايصال_حجز_BK-9001.pdf');
      expect(sharedBounds, isNotNull);
      expect(sharedBounds!.isEmpty, isFalse);
      expect(sharedBounds!.width, greaterThan(0));
      expect(sharedBounds!.height, greaterThan(0));
    });
  });

  group('Workstream D - Fail-Closed Permission & Connection Guard', () {
    test('classifySnapshot distinguishes auth, cache grace, offline, permission and index',
        () {
      const noData = AsyncSnapshot<String>.nothing();
      final authWait = BookingAccessGuard.classifySnapshot(
        snapshot: noData,
        isFromCache: false,
        hasPendingWrites: false,
        currentUid: '',
      );
      expect(authWait.status, BookingAccessStatus.unauthenticated);
      expect(authWait.canRetry, isFalse);

      const withData = AsyncSnapshot<String>.withData(ConnectionState.active, 'ok');
      expect(
        BookingAccessGuard.classifySnapshot(
          snapshot: withData,
          isFromCache: true,
          hasPendingWrites: true,
          currentUid: 'u1',
        ).status,
        BookingAccessStatus.pendingSync,
      );
      expect(
        BookingAccessGuard.classifySnapshot(
          snapshot: withData,
          isFromCache: true,
          hasPendingWrites: false,
          cacheGraceElapsed: false,
          currentUid: 'u1',
        ).status,
        BookingAccessStatus.verifyingCache,
      );
      expect(
        BookingAccessGuard.classifySnapshot(
          snapshot: withData,
          isFromCache: true,
          hasPendingWrites: false,
          cacheGraceElapsed: true,
          currentUid: 'u1',
        ).status,
        BookingAccessStatus.offlineCache,
      );
      expect(
        BookingAccessGuard.classifySnapshot(
          snapshot: withData,
          isFromCache: false,
          hasPendingWrites: false,
          currentUid: 'u1',
        ).isVerified,
        isTrue,
      );

      final permErr = AsyncSnapshot<String>.withError(
          ConnectionState.active, StateError('[cloud_firestore/permission-denied]'));
      expect(
        BookingAccessGuard.classifySnapshot(
          snapshot: permErr,
          isFromCache: false,
          hasPendingWrites: false,
          currentUid: 'u1',
        ).status,
        BookingAccessStatus.permissionDenied,
      );

      final indexErr = AsyncSnapshot<String>.withError(
          ConnectionState.active, StateError('[cloud_firestore/failed-precondition]'));
      expect(
        BookingAccessGuard.classifySnapshot(
          snapshot: indexErr,
          isFromCache: false,
          hasPendingWrites: false,
          currentUid: 'u1',
        ).status,
        BookingAccessStatus.backendError,
      );
    });

    testWidgets(
        'BookingVerifiedGate hides cached/pending/errored content and unlocks only on server verification',
        (tester) async {
      await _loadFonts();
      var retries = 0;

      Widget buildGate({
        required bool hasData,
        bool hasError = false,
        Object? error,
        required bool isFromCache,
        required bool hasPendingWrites,
      }) =>
          _rtlApp(Scaffold(
            body: BookingVerifiedGate(
              hasData: hasData,
              hasError: hasError,
              error: error,
              isFromCache: isFromCache,
              hasPendingWrites: hasPendingWrites,
              graceDuration: const Duration(milliseconds: 200),
              onRetry: () => retries++,
              child: const Text('بيانات خاصة محمية'),
            ),
          ));

      // Pending writes fail closed immediately
      await tester.pumpWidget(buildGate(
        hasData: true,
        isFromCache: true,
        hasPendingWrites: true,
      ));
      expect(find.text('بيانات خاصة محمية'), findsNothing);
      expect(find.text('جاري مزامنة التغييرات'), findsOneWidget);

      // Initial cached snapshot waits during grace, then shows offline banner
      await tester.pumpWidget(buildGate(
        hasData: true,
        isFromCache: true,
        hasPendingWrites: false,
      ));
      expect(find.text('بيانات خاصة محمية'), findsNothing);
      expect(find.text('جاري التحقق من الصلاحية'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('بيانات خاصة محمية'), findsNothing);
      expect(find.text('يلزم اتصال للتحقق من الصلاحية'), findsOneWidget);
      await tester.tap(find.text('إعادة التحقق'));
      await tester.pump();
      expect(retries, 1);

      // Server-verified snapshot unlocks private child
      await tester.pumpWidget(buildGate(
        hasData: true,
        isFromCache: false,
        hasPendingWrites: false,
      ));
      expect(find.text('بيانات خاصة محمية'), findsOneWidget);
    });
  });

  group('Workstream E - Mandatory Fields & Inline Validation', () {
    test('BookingFormValidator validates text, phone normalization, and integer ranges',
        () {
      expect(BookingFormValidator.requiredText('   ', fieldName: 'الاسم'),
          isNotNull);
      expect(BookingFormValidator.requiredText('أ', fieldName: 'الاسم', minLength: 2),
          contains('الحد الأدنى 2'));
      expect(BookingFormValidator.requiredText('سالم', fieldName: 'الاسم', minLength: 2),
          isNull);

      expect(BookingFormValidator.normalizeValidPhone('1234'), isNull);
      expect(BookingFormValidator.normalizeValidPhone('٠٧٧٠١٢٣٤٥٦٧'),
          '+9647701234567');
      expect(BookingFormValidator.normalizeValidPhone('+964 780-111-2233'),
          '+9647801112233');
      expect(BookingFormValidator.normalizeValidPhone('00964 750 123 4567'),
          '+9647501234567');

      expect(BookingFormValidator.phoneError(''), isNotNull);
      expect(BookingFormValidator.phoneError('0790', required: true), isNotNull);
      expect(BookingFormValidator.phoneError('', required: false), isNull);

      expect(
        BookingFormValidator.intRangeError('51',
            fieldName: 'نسبة الخصم', min: 0, max: 50),
        isNotNull,
      );
      expect(
        BookingFormValidator.intRangeError('25',
            fieldName: 'نسبة الخصم', min: 0, max: 50),
        isNull,
      );
    });

    testWidgets(
        'BookingRequestScreen Step 2 blocks invalid guest inputs inline without wiping typed data and normalizes valid Arabic digits',
        (tester) async {
      await _loadFonts();
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final submitted = <Map<String, dynamic>>[];
      final requestedIds = <String>[];
      await tester.pumpWidget(_rtlApp(BookingRequestScreen(
        venueId: 'v1',
        venue: _sampleVenue,
        intentStore: MemoryIntentStore(),
        currentUserId: () => 'u-guest-test',
        onRequested: requestedIds.add,
        call: (name, data) async {
          if (name == 'getBookingAvailability') return {'slots': []};
          if (name == 'getPublishedBookingReviews') {
            return {'count': 0, 'average': 0, 'reviews': []};
          }
          if (name == 'requestBooking') {
            submitted.add(Map.of(data));
            return {'id': 'bk-valid'};
          }
          return {};
        },
      )));
      await tester.pumpAndSettle();

      // Step 0 -> Step 1 -> pick shift/day -> Step 2
      await tester.tap(find.byKey(const ValueKey('booking-next')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('الشهر التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('الشهر التالي'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('booking-next')));
      await tester.pumpAndSettle();

      final nameFinder =
          find.widgetWithText(TextField, 'الاسم الكامل للضيف / الزبون');
      final phoneFinder = find.widgetWithText(TextField, 'رقم الهاتف للتواصل');
      final notesFinder =
          find.widgetWithText(TextField, 'ملاحظات خاصة للمالك (اختياري)');

      // Enter optional note + invalid whitespace name + short phone
      await tester.enterText(nameFinder, '   ');
      await tester.enterText(phoneFinder, '0770');
      await tester.ensureVisible(notesFinder);
      await tester.pumpAndSettle();
      await tester.enterText(notesFinder, 'وصول عائلي مبكر');
      await tester.tap(find.byKey(const ValueKey('booking-next')));
      await tester.pumpAndSettle();

      // Stays on Step 2 with inline errorText and preserves sibling notes text
      expect(find.text('متابعة لمراجعة الحجز'), findsOneWidget);
      expect(tester.widget<TextField>(nameFinder).decoration?.errorText,
          isNotNull);
      expect(tester.widget<TextField>(phoneFinder).decoration?.errorText,
          isNotNull);
      expect(tester.widget<TextField>(notesFinder).controller?.text,
          'وصول عائلي مبكر');

      // Typing clears error dynamically and valid Arabic digits proceed to Step 3
      await tester.enterText(nameFinder, 'سالم العراقي');
      await tester.pump();
      expect(tester.widget<TextField>(nameFinder).decoration?.errorText, isNull);
      await tester.enterText(phoneFinder, '٠٧٧٠١٢٣٤٥٦٧');
      await tester.pump();
      expect(tester.widget<TextField>(phoneFinder).decoration?.errorText, isNull);

      await tester.tap(find.byKey(const ValueKey('booking-next')));
      await tester.pumpAndSettle();
      expect(find.text('مراجعة وتأكيد الحجز'), findsOneWidget);

      await tester.scrollUntilVisible(find.byType(CheckboxListTile), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('إرسال طلب الحجز'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إرسال طلب الحجز'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
          find.byKey(const ValueKey('booking-confirm-sheet-send')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('booking-confirm-sheet-send')));
      await tester.pumpAndSettle();

      expect(submitted, hasLength(1));
      expect(submitted.first['guestName'], 'سالم العراقي');
      expect(submitted.first['guestPhone'], '+9647701234567');
      expect(requestedIds, ['bk-valid']);
    });

    testWidgets(
        'BookingVenueEditor, BookingSupportForm, BookingStaffPermissions & BookingOwnerTools validate mandatory fields inline',
        (tester) async {
      await _loadFonts();
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. BookingVenueEditor blocks blank submit without clearing optional text
      var editorSaves = 0;
      await tester.pumpWidget(_rtlApp(BookingVenueEditor(
        ownerMode: true,
        call: (n, d) async {
          editorSaves++;
          return {};
        },
      )));
      await tester.pumpAndSettle();
      final complexFinder =
          find.widgetWithText(TextField, 'اسم المنتجع أو المجمع (اختياري)');
      await tester.ensureVisible(complexFinder);
      await tester.enterText(complexFinder, 'مجمع الواحة');
      await tester.tap(find.text('حفظ بيانات المكان'));
      await tester.pumpAndSettle();
      expect(editorSaves, 0);
      expect(tester.widget<TextField>(complexFinder).controller?.text,
          'مجمع الواحة');

      // 2. BookingSupportForm validates subject & message inline
      final subj = TextEditingController();
      final msg = TextEditingController();
      addTearDown(subj.dispose);
      addTearDown(msg.dispose);
      var supportSubmits = 0;
      await tester.pumpWidget(_rtlApp(Scaffold(
        body: SingleChildScrollView(
          child: BookingSupportForm(
            subject: subj,
            message: msg,
            busy: false,
            onSubmit: () => supportSubmits++,
          ),
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('فتح تذكرة دعم'));
      await tester.pumpAndSettle();
      expect(supportSubmits, 0);
      expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'موضوع الطلب'))
              .decoration
              ?.errorText,
          isNotNull);
      await tester.enterText(
          find.widgetWithText(TextField, 'موضوع الطلب'), 'مشكلة في الحجز');
      await tester.enterText(
          find.widgetWithText(TextField, 'تفاصيل المشكلة'),
          'لم يظهر الإيصال في قائمة الحجوزات');
      await tester.tap(find.text('فتح تذكرة دعم'));
      await tester.pumpAndSettle();
      expect(supportSubmits, 1);

      // 3. BookingStaffPermissions requires staff UID inline, allows empty scopes revocation
      final staffUid = TextEditingController();
      addTearDown(staffUid.dispose);
      var staffSaves = 0;
      await tester.pumpWidget(_rtlApp(Scaffold(
        body: SingleChildScrollView(
          child: BookingStaffPermissions(
            controller: staffUid,
            scopes: const {},
            busy: false,
            onChanged: (_, __) {},
            onSave: () => staffSaves++,
          ),
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ الصلاحيات'));
      await tester.pumpAndSettle();
      expect(staffSaves, 0);
      await tester.enterText(
          find.widgetWithText(TextField, 'UID حساب الموظف'), 'staff_uid_42');
      await tester.tap(find.text('حفظ الصلاحيات'));
      await tester.pumpAndSettle();
      expect(staffSaves, 1);

      // 4. BookingOwnerTools validates offer discount (0..50) and new owner UID inline
      await tester.pumpWidget(_rtlApp(const BookingOwnerTools(
        venueId: 'v1',
        ownerControls: true,
        closures: Stream.empty(),
      )));
      await tester.pumpAndSettle();
      final discountFinder =
          find.widgetWithText(TextField, 'خصم مؤقت 0–50٪ لمدة 7 أيام');
      await tester.scrollUntilVisible(discountFinder, 180,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(discountFinder);
      await tester.pumpAndSettle();
      await tester.enterText(discountFinder, '85');
      await tester.ensureVisible(find.text('حفظ العرض — الصفر يلغي الخصم'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ العرض — الصفر يلغي الخصم'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(discountFinder).decoration?.errorText,
          isNotNull);

      final ownerFinder = find.widgetWithText(TextField, 'UID المالك الجديد');
      await tester.scrollUntilVisible(ownerFinder, 180,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('تقديم طلب نقل ملكية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تقديم طلب نقل ملكية'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(ownerFinder).decoration?.errorText,
          isNotNull);
    });
  });

  group('Workstream F - Distinct Morning/Evening/Full-Day Period Icons & Light/Dark Contrast',
      () {
    test('BookingShiftVisual classifies all period kinds with distinct icons and colors',
        () {
      final morning = BookingShiftVisual.resolve({
        'kind': 'morning',
        'name': 'الفترة الصباحية',
        'startMinute': 540,
        'endMinute': 1080,
      });
      final evening = BookingShiftVisual.resolve({
        'kind': 'evening',
        'name': 'الفترة المسائية',
        'startMinute': 1140,
        'endMinute': 120,
      });
      final fullDay = BookingShiftVisual.resolve({
        'kind': 'full_day',
        'name': 'اليوم الكامل',
        'startMinute': 540,
        'endMinute': 540,
      });

      expect(morning.kind, BookingShiftKind.morning);
      expect(evening.kind, BookingShiftKind.evening);
      expect(fullDay.kind, BookingShiftKind.fullDay);
      expect(
          {morning.icon, evening.icon, fullDay.icon}, hasLength(3));
      expect(
        BookingShiftVisual.classify(checkInMinute: 1200, checkOutMinute: 120),
        BookingShiftKind.evening,
      );

      for (final b in [Brightness.light, Brightness.dark]) {
        expect(morning.foreground(b), isNot(morning.background(b)));
        expect(evening.foreground(b), isNot(evening.background(b)));
        expect(fullDay.foreground(b), isNot(fullDay.background(b)));
      }
      expect(morning.foreground(Brightness.light),
          isNot(morning.foreground(Brightness.dark)));
      expect(evening.foreground(Brightness.light),
          isNot(evening.foreground(Brightness.dark)));
    });

    testWidgets(
        'BookingPeriodBadge, BookingVenuePrices & BookingOwnerCalendarView render distinct shift icons across Light and Dark modes',
        (tester) async {
      await _loadFonts();
      final nowBaghdad = DateTime.now().toUtc().add(const Duration(hours: 3));
      final todayAt10 = DateTime.utc(
          nowBaghdad.year, nowBaghdad.month, nowBaghdad.day, 7, 0);
      final todayAt20 = DateTime.utc(
          nowBaghdad.year, nowBaghdad.month, nowBaghdad.day, 17, 0);

      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(_rtlApp(
          Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BookingPeriodBadge(shift: 'الفترة الصباحية'),
                      BookingPeriodBadge(shift: 'الفترة المسائية'),
                      BookingPeriodBadge(shift: 'اليوم الكامل'),
                    ],
                  ),
                  const BookingVenuePrices(venue: _sampleVenue),
                  SizedBox(
                    height: 520,
                    child: BookingOwnerCalendarView(
                      ownerId: 'owner-1',
                      venues: const [
                        {'id': 'v1', 'name': 'شاليه النخيل', 'shifts': []},
                      ],
                      initialBookingsForTest: [
                        {
                          'id': 'b-m',
                          'venueId': 'v1',
                          'venueName': 'شاليه النخيل',
                          'customerName': 'زبون صباحي',
                          'shiftName': 'الفترة الصباحية',
                          'status': 'confirmed',
                          'start': todayAt10.millisecondsSinceEpoch,
                          'end': todayAt10
                              .add(const Duration(hours: 6))
                              .millisecondsSinceEpoch,
                          'totalPrice': 150000,
                        },
                        {
                          'id': 'b-e',
                          'venueId': 'v1',
                          'venueName': 'شاليه النخيل',
                          'customerName': 'زبون مسائي',
                          'shiftName': 'الفترة المسائية',
                          'status': 'confirmed',
                          'start': todayAt20.millisecondsSinceEpoch,
                          'end': todayAt20
                              .add(const Duration(hours: 6))
                              .millisecondsSinceEpoch,
                          'totalPrice': 170000,
                        },
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          brightness: brightness,
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.wb_sunny_rounded), findsWidgets);
        expect(find.byIcon(Icons.nights_stay_rounded), findsWidgets);
        expect(find.byIcon(Icons.timelapse_rounded), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
