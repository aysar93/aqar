import 'package:aqar/bookings/admin/booking_reel_editor_screen.dart';
import 'package:aqar/bookings/admin/booking_reel_media_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookingReelMediaService validation and isolation', () {
    test('accepts valid mp4 within 50MB', () {
      final res = BookingReelMediaService.validateVideoFile(
        fileName: 'chalet_tour.mp4',
        sizeBytes: 12 * 1024 * 1024,
      );
      expect(res.isValid, isTrue);
      expect(res.errorMessage, isNull);
    });

    test('rejects unsupported file formats', () {
      final mov = BookingReelMediaService.validateVideoFile(
        fileName: 'tour.mov',
        sizeBytes: 5 * 1024 * 1024,
      );
      expect(mov.isValid, isFalse);
      expect(mov.errorMessage, contains('MP4'));

      final img = BookingReelMediaService.validateVideoFile(
        fileName: 'photo.jpg',
        sizeBytes: 1024 * 1024,
      );
      expect(img.isValid, isFalse);
    });

    test('rejects files larger than 50MB and empty files', () {
      final tooLarge = BookingReelMediaService.validateVideoFile(
        fileName: 'huge.mp4',
        sizeBytes: 50 * 1024 * 1024 + 1,
      );
      expect(tooLarge.isValid, isFalse);
      expect(tooLarge.errorMessage, contains('50'));

      final empty = BookingReelMediaService.validateVideoFile(
        fileName: 'empty.mp4',
        sizeBytes: 0,
      );
      expect(empty.isValid, isFalse);
    });

    test('validates external URLs and rejects local file paths', () {
      expect(BookingReelMediaService.validateExternalVideoUrl(''), isNotNull);
      expect(
        BookingReelMediaService.validateExternalVideoUrl(
            'file:///storage/emulated/0/video.mp4'),
        isNotNull,
      );
      expect(
        BookingReelMediaService.validateExternalVideoUrl(
            'https://example.com/reel.mp4'),
        isNull,
      );
    });

    test('builds isolated booking_reels_media storage path', () {
      final path = BookingReelMediaService.buildStoragePath(
        venueId: 'venue-123',
        authorUid: 'admin-1',
        timestampMs: 1700000000,
      );
      expect(path, 'booking_reels_media/venue-123/admin-1/reel_1700000000.mp4');

      final fallback = BookingReelMediaService.buildStoragePath(
        venueId: '',
        authorUid: 'admin-1',
        timestampMs: 1700000001,
      );
      expect(fallback,
          'booking_reels_media/admin_reels/admin-1/reel_1700000001.mp4');
    });
  });

  group('BookingReelEditorScreen UI', () {
    testWidgets('shows studio upload button and external URL mode toggle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BookingReelEditorScreen(),
        ),
      );

      expect(find.text('اختيار فيديو من الاستديو'), findsOneWidget);
      expect(find.text('رفع من الاستديو'), findsOneWidget);
      expect(find.text('رابط فيديو خارجي'), findsOneWidget);

      await tester.tap(find.text('رابط فيديو خارجي'));
      await tester.pumpAndSettle();

      expect(find.text('رابط الفيديو الخارجي *'), findsOneWidget);
    });

    testWidgets('edit mode with external URL opens in external mode pre-filled',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BookingReelEditorScreen(
            reelId: 'reel-1',
            existing: {
              'title': 'جولة تجريبية',
              'videoUrl': 'https://example.com/demo.mp4',
              'active': true,
            },
          ),
        ),
      );

      expect(find.text('تعديل ريل الحجوزات'), findsOneWidget);
      expect(find.text('https://example.com/demo.mp4'), findsOneWidget);
    });
  });
}
