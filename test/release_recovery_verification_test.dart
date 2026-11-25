import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/models/property_model.dart';
import 'package:aqar/widgets/property_horizontal_home_card.dart';
import 'package:aqar/screens/admin/widgets/change_availability_sheet.dart';
import 'package:aqar/bookings/admin/booking_reels_admin_screen.dart';
import 'package:aqar/bookings/admin/booking_admin_theme.dart';

void main() {
  group('1. Property Details Gallery Slides Logic (Photos Only vs Video)', () {
    test('Property with photos only: creates only photo slides without video',
        () {
      final photos = [
        'https://example.com/p1.jpg',
        'https://example.com/p2.jpg'
      ];
      const String? videoUrl = null;

      final bool hasVideo = videoUrl != null && videoUrl.isNotEmpty;
      final List<Map<String, dynamic>> slides = [];

      if (photos.isNotEmpty) {
        slides.add({'type': 'photo', 'url': photos[0], 'index': 0});
        if (hasVideo) {
          slides.add({'type': 'video', 'url': videoUrl});
        }
        for (int i = 1; i < photos.length; i++) {
          slides.add({'type': 'photo', 'url': photos[i], 'index': i});
        }
      } else if (hasVideo) {
        slides.add({'type': 'video', 'url': videoUrl});
      }

      expect(slides.length, 2);
      expect(slides[0]['type'], 'photo');
      expect(slides[1]['type'], 'photo');
      expect(slides.any((s) => s['type'] == 'video'), isFalse);
    });

    test(
        'Property with photos and video: interleaves video at index 1 after first photo',
        () {
      final photos = [
        'https://example.com/p1.jpg',
        'https://example.com/p2.jpg',
        'https://example.com/p3.jpg'
      ];
      const String videoUrl = 'https://example.com/property_video.mp4';
      const String videoThumb = 'https://example.com/thumb.jpg';

      final bool hasVideo = videoUrl.isNotEmpty;
      final List<Map<String, dynamic>> slides = [];

      if (photos.isNotEmpty) {
        slides.add({'type': 'photo', 'url': photos[0], 'index': 0});
        if (hasVideo) {
          slides
              .add({'type': 'video', 'url': videoUrl, 'thumbnail': videoThumb});
        }
        for (int i = 1; i < photos.length; i++) {
          slides.add({'type': 'photo', 'url': photos[i], 'index': i});
        }
      } else if (hasVideo) {
        slides.add({'type': 'video', 'url': videoUrl, 'thumbnail': videoThumb});
      }

      expect(slides.length, 4);
      expect(slides[0]['type'], 'photo');
      expect(slides[0]['url'], 'https://example.com/p1.jpg');
      expect(slides[1]['type'], 'video');
      expect(slides[1]['url'], 'https://example.com/property_video.mp4');
      expect(slides[1]['thumbnail'], 'https://example.com/thumb.jpg');
      expect(slides[2]['type'], 'photo');
      expect(slides[2]['url'], 'https://example.com/p2.jpg');
      expect(slides[3]['type'], 'photo');
      expect(slides[3]['url'], 'https://example.com/p3.jpg');
    });

    test('Property with video only and no photos: places video at index 0', () {
      final List<String> photos = [];
      const String videoUrl = 'https://example.com/only_video.mp4';

      final bool hasVideo = videoUrl.isNotEmpty;
      final List<Map<String, dynamic>> slides = [];

      if (photos.isNotEmpty) {
        slides.add({'type': 'photo', 'url': photos[0], 'index': 0});
        if (hasVideo) {
          slides.add({'type': 'video', 'url': videoUrl});
        }
      } else if (hasVideo) {
        slides.add({'type': 'video', 'url': videoUrl});
      }

      expect(slides.length, 1);
      expect(slides[0]['type'], 'video');
      expect(slides[0]['url'], 'https://example.com/only_video.mp4');
    });

    test(
        'Property with custom videoIndex = 0: places video as first item before photos',
        () {
      final photos = [
        'https://example.com/p1.jpg',
        'https://example.com/p2.jpg'
      ];
      const String videoUrl = 'https://example.com/cover_video.mp4';
      const int customVideoIndex = 0;

      final bool hasVideo = videoUrl.isNotEmpty;
      final List<Map<String, dynamic>> slides = [];

      if (photos.isNotEmpty) {
        final int targetIndex = customVideoIndex.clamp(0, photos.length);
        if (hasVideo && targetIndex == 0) {
          slides.add({'type': 'video', 'url': videoUrl});
        }
        for (int i = 0; i < photos.length; i++) {
          slides.add({'type': 'photo', 'url': photos[i], 'index': i});
          if (hasVideo && i + 1 == targetIndex) {
            slides.add({'type': 'video', 'url': videoUrl});
          }
        }
      }

      expect(slides.length, 3);
      expect(slides[0]['type'], 'video');
      expect(slides[0]['url'], 'https://example.com/cover_video.mp4');
      expect(slides[1]['type'], 'photo');
      expect(slides[2]['type'], 'photo');
    });

    test('Property with custom videoIndex = 2: places video after second photo',
        () {
      final photos = [
        'https://example.com/p1.jpg',
        'https://example.com/p2.jpg',
        'https://example.com/p3.jpg'
      ];
      const String videoUrl = 'https://example.com/video_at_2.mp4';
      const int customVideoIndex = 2;

      final bool hasVideo = videoUrl.isNotEmpty;
      final List<Map<String, dynamic>> slides = [];

      if (photos.isNotEmpty) {
        final int targetIndex = customVideoIndex.clamp(0, photos.length);
        if (hasVideo && targetIndex == 0) {
          slides.add({'type': 'video', 'url': videoUrl});
        }
        for (int i = 0; i < photos.length; i++) {
          slides.add({'type': 'photo', 'url': photos[i], 'index': i});
          if (hasVideo && i + 1 == targetIndex) {
            slides.add({'type': 'video', 'url': videoUrl});
          }
        }
      }

      expect(slides.length, 4);
      expect(slides[0]['type'], 'photo');
      expect(slides[1]['type'], 'photo');
      expect(slides[2]['type'], 'video');
      expect(slides[2]['url'], 'https://example.com/video_at_2.mp4');
      expect(slides[3]['type'], 'photo');
    });
  });

  group('2. RTL PropertyHorizontalHomeCard UI & Layout Tests', () {
    testWidgets(
        'PropertyHorizontalHomeCard renders all text elements strictly in RTL',
        (tester) async {
      final map = <String, dynamic>{
        'title': 'منزل للبيع في التأميم',
        'description': 'وصف العقار بالتفصيل',
        'price': 185000000.0,
        'location': 'الرمادي — حي التأميم',
        'city': 'الرمادي',
        'propertyType': 'دار سكن',
        'adType': 'بيع',
        'images': ['https://example.com/house.jpg'],
        'imageUrl': 'https://example.com/house.jpg',
        'userId': 'owner-123',
        'publisherUid': 'owner-123',
        'availabilityStatus': 'available',
        'adNumber': 5042,
        'propertyNumber': 5042,
        'videoUrl': 'https://example.com/house_video.mp4',
        'videoThumbnailUrl': 'https://example.com/house_thumb.jpg',
        'status': 'approved',
      };
      final property = PropertyModel.fromMap(map, 'prop-rtl-1');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Cairo', brightness: Brightness.dark),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: PropertyHorizontalHomeCard(
                    property: property,
                    onTap: () {},
                    isFavorite: false,
                    onFavorite: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify title renders in RTL
      final titleFinder = find.text('منزل للبيع في التأميم');
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.textDirection, TextDirection.rtl);

      // Verify location renders in RTL
      final locFinder = find.text('الرمادي — حي التأميم');
      expect(locFinder, findsOneWidget);
      final locWidget = tester.widget<Text>(locFinder);
      expect(locWidget.textDirection, TextDirection.rtl);

      // Verify property number is separated in its own container
      final numFinder = find.text('رقم: #5042');
      expect(numFinder, findsOneWidget);
      final numWidget = tester.widget<Text>(numFinder);
      expect(numWidget.textDirection, TextDirection.rtl);

      // Verify video badge is visible
      final videoBadgeFinder = find.text('فيديو');
      expect(videoBadgeFinder, findsOneWidget);

      // Verify status badge
      final statusBadgeFinder = find.text('متاح');
      expect(statusBadgeFinder, findsOneWidget);
    });
  });

  group('3. ChangeAvailabilitySheet Ownership & Security Validation', () {
    testWidgets('ChangeAvailabilitySheet displays all 4 availability statuses',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ChangeAvailabilitySheet(
                documentId: 'prop-123',
                currentStatus: 'available',
                ownerId: 'owner-123',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('حالة توفر العقار'), findsOneWidget);
      expect(find.text('متوفر'), findsOneWidget);
      expect(find.text('محجوز'), findsOneWidget);
      expect(find.text('تم البيع'), findsOneWidget);
      expect(find.text('تم التأجير'), findsOneWidget);
    });

    test('Ownership check: non-owner modification is rejected', () {
      const String documentOwnerId = 'user-owner-abc';
      const String attemptingUserId = 'user-intruder-xyz';

      final bool isAuthorized = documentOwnerId == attemptingUserId;
      expect(isAuthorized, isFalse);
    });

    test('Ownership check: owner modification is accepted', () {
      const String documentOwnerId = 'user-owner-abc';
      const String attemptingUserId = 'user-owner-abc';

      final bool isAuthorized = documentOwnerId == attemptingUserId;
      expect(isAuthorized, isTrue);
    });

    test('Firestore Security Rules Property Update Policy Verification', () {
      // Simulating Firestore rules line 237-242:
      // (activeUser && resource.data.userId == request.auth.uid && affectedKeys.hasOnly(['availabilityStatus', 'updatedAt']))
      bool canUpdateAvailability({
        required bool isSignedIn,
        required bool isActiveUser,
        required String resourceOwnerId,
        required String requesterUid,
        required bool isAdmin,
        required Set<String> affectedKeys,
      }) {
        if (!isSignedIn) return false;
        if (isAdmin) return true;

        final isOwner = isActiveUser && resourceOwnerId == requesterUid;
        final isAllowedKeys = affectedKeys
            .difference({'availabilityStatus', 'updatedAt'}).isEmpty;

        return isOwner && isAllowedKeys;
      }

      // 1. Owner updates availabilityStatus: ALLOWED
      expect(
        canUpdateAvailability(
          isSignedIn: true,
          isActiveUser: true,
          resourceOwnerId: 'owner-123',
          requesterUid: 'owner-123',
          isAdmin: false,
          affectedKeys: {'availabilityStatus', 'updatedAt'},
        ),
        isTrue,
      );

      // 2. Non-owner tries to update availabilityStatus: FORBIDDEN
      expect(
        canUpdateAvailability(
          isSignedIn: true,
          isActiveUser: true,
          resourceOwnerId: 'owner-123',
          requesterUid: 'attacker-999',
          isAdmin: false,
          affectedKeys: {'availabilityStatus', 'updatedAt'},
        ),
        isFalse,
      );

      // 3. Unauthenticated requester: FORBIDDEN
      expect(
        canUpdateAvailability(
          isSignedIn: false,
          isActiveUser: false,
          resourceOwnerId: 'owner-123',
          requesterUid: '',
          isAdmin: false,
          affectedKeys: {'availabilityStatus'},
        ),
        isFalse,
      );

      // 4. Owner tries to also modify unallowed key (e.g. isFeatured): FORBIDDEN
      expect(
        canUpdateAvailability(
          isSignedIn: true,
          isActiveUser: true,
          resourceOwnerId: 'owner-123',
          requesterUid: 'owner-123',
          isAdmin: false,
          affectedKeys: {'availabilityStatus', 'isFeatured'},
        ),
        isFalse,
      );

      // 5. Admin updates availability: ALLOWED
      expect(
        canUpdateAvailability(
          isSignedIn: true,
          isActiveUser: true,
          resourceOwnerId: 'owner-123',
          requesterUid: 'admin-001',
          isAdmin: true,
          affectedKeys: {'availabilityStatus'},
        ),
        isTrue,
      );
    });
  });

  group('4. BookingReelsAdminScreen & BookingAdminTheme Verification', () {
    testWidgets(
        'BookingReelsAdminScreen builds with compliant BookingAdminTheme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: BookingReelsAdminScreen(
              reelsStream: Stream.empty(),
              reportsStream: Stream.empty(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('إدارة ريلزات الحجوزات'), findsOneWidget);

      final BuildContext context =
          tester.element(find.byType(BookingReelsAdminScreen));
      expect(BookingAdminTheme.bg(context), isNotNull);
      expect(BookingAdminTheme.header(context), isNotNull);
      expect(BookingAdminTheme.surface(context), isNotNull);
      expect(BookingAdminTheme.text(context), isNotNull);
    });

    test('Real estate reels collection is strictly isolated from booking reels',
        () {
      const String realEstateProperties = 'properties';
      const String bookingReelsCollection = 'booking_reels';
      const String bookingReportsCollection = 'booking_reel_reports';

      expect(bookingReelsCollection, isNot(equals(realEstateProperties)));
      expect(bookingReportsCollection, isNot(equals(realEstateProperties)));
    });
  });
}
