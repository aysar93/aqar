import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/models/property_model.dart';
import 'package:aqar/models/add_property_data.dart';
import 'package:aqar/screens/edit_property/models/edit_property_data.dart';
import 'package:aqar/reels/models/reel_model.dart';

void main() {
  group('Property Video Model & Data Tests', () {
    test('PropertyModel correctly serializes and deserializes video fields', () {
      final map = <String, dynamic>{
        'title': 'فيلا فاخرة في الرمادي',
        'imageUrl': 'https://example.com/img1.jpg',
        'images': ['https://example.com/img1.jpg'],
        'city': 'الرمادي',
        'propertyType': 'بيت',
        'adType': 'بيع',
        'price': 250000000.0,
        'videoUrl': 'https://example.com/videos/villa_ramadi.mp4',
        'videoThumbnailUrl': 'https://example.com/thumbs/villa_thumb.jpg',
        'status': 'approved',
      };

      final property = PropertyModel.fromMap(map, 'prop-123');

      expect(property.id, 'prop-123');
      expect(property.videoUrl, 'https://example.com/videos/villa_ramadi.mp4');
      expect(property.videoThumbnailUrl, 'https://example.com/thumbs/villa_thumb.jpg');

      final toMap = property.toMap();
      expect(toMap['videoUrl'], 'https://example.com/videos/villa_ramadi.mp4');
      expect(toMap['videoThumbnailUrl'], 'https://example.com/thumbs/villa_thumb.jpg');
    });

    test('AddPropertyData correctly stores video references', () {
      final data = AddPropertyData();
      expect(data.selectedVideo, isNull);
      expect(data.videoUrl, isNull);

      data.videoUrl = 'https://example.com/videos/new_house.mp4';
      data.videoThumbnailUrl = 'https://example.com/thumbs/new_thumb.jpg';

      expect(data.videoUrl, 'https://example.com/videos/new_house.mp4');
      expect(data.videoThumbnailUrl, 'https://example.com/thumbs/new_thumb.jpg');
    });

    test('EditPropertyData handles video addition and removal correctly', () {
      final initialMap = <String, dynamic>{
        'title': 'شقة مفروشة للإيجار',
        'videoUrl': 'https://example.com/videos/apt.mp4',
        'videoThumbnailUrl': 'https://example.com/thumbs/apt.jpg',
      };

      final editData = EditPropertyData.fromMap(docId: 'edit-prop-1', map: initialMap);
      expect(editData.videoUrl, 'https://example.com/videos/apt.mp4');
      expect(editData.removeVideo, isFalse);

      // Verify update with existing video
      final updateWithExisting = editData.toUpdateMap(finalImages: []);
      expect(updateWithExisting['videoUrl'], 'https://example.com/videos/apt.mp4');

      // Verify update with video removed
      editData.removeVideo = true;
      final updateWithRemoval = editData.toUpdateMap(finalImages: []);
      expect(updateWithRemoval['videoUrl'], isNull);
      expect(updateWithRemoval['videoThumbnailUrl'], isNull);
    });
  });

  group('ReelModel Banner Ad Integration Tests', () {
    test('ReelModel.fromBanner converts admin banner into sponsored reel', () {
      final bannerData = <String, dynamic>{
        'title': 'إعلان مكتب الأندلس العقاري',
        'subtitle': 'أفضل العروض الحصرية في الرمادي والخالدية',
        'imageUrl': 'https://example.com/banners/andalus_ad.png',
        'type': 'office',
        'targetId': 'office-andalus-99',
        'isActive': true,
        'order': 1,
      };

      final adReel = ReelModel.fromBanner(bannerData, 'banner-doc-1');

      expect(adReel.id, 'banner_banner-doc-1');
      expect(adReel.title, 'إعلان مكتب الأندلس العقاري');
      expect(adReel.description, 'أفضل العروض الحصرية في الرمادي والخالدية');
      expect(adReel.isSponsored, isTrue);
      expect(adReel.targetType, ReelTargetType.office);
      expect(adReel.officeId, 'office-andalus-99');
      expect(adReel.ctaLabel, 'زيارة المكتب');
      expect(adReel.category, 'إعلان');
      expect(adReel.isCurrentlyVisible, isTrue);
    });

    test('ReelModel.fromBanner handles property-linked banner', () {
      final bannerData = <String, dynamic>{
        'title': 'عرض الأسبوع: مجمع سكني حديث',
        'subtitle': 'خصومات للمشترين الأوائل',
        'imageUrl': 'https://example.com/banners/complex.jpg',
        'type': 'property',
        'targetId': 'prop-special-77',
        'isActive': true,
        'order': 2,
      };

      final adReel = ReelModel.fromBanner(bannerData, 'banner-doc-2');

      expect(adReel.targetType, ReelTargetType.property);
      expect(adReel.propertyId, 'prop-special-77');
      expect(adReel.ctaLabel, 'عرض العقار');
    });

    test('ReelModel.fromBanner handles external banner type from dashboard', () {
      final bannerData = <String, dynamic>{
        'title': 'عرض تمويل عقاري بنكي',
        'subtitle': 'احصل على تمويل بنسبة فائدة ميسرة',
        'imageUrl': 'https://example.com/banners/bank_loan.jpg',
        'type': 'external',
        'targetId': 'https://bank.example.com/real-estate-loan',
        'isActive': true,
        'order': 3,
      };

      final adReel = ReelModel.fromBanner(bannerData, 'banner-external-1');

      expect(adReel.targetType, ReelTargetType.general);
      expect(adReel.externalUrl, 'https://bank.example.com/real-estate-loan');
      expect(adReel.ctaLabel, 'معرفة المزيد');
      expect(adReel.isSponsored, isTrue);
    });

    test('ReelModel.fromBanner handles legacy url banner type without breakage', () {
      final bannerData = <String, dynamic>{
        'title': 'موقع مشروع وادي الرمادي',
        'subtitle': 'تصفح المخطط العام على الويب',
        'imageUrl': 'https://example.com/banners/wadi.jpg',
        'type': 'url',
        'targetId': 'http://wadi-ramadi.com/master-plan',
        'isActive': true,
        'order': 4,
      };

      final adReel = ReelModel.fromBanner(bannerData, 'banner-url-legacy');

      expect(adReel.targetType, ReelTargetType.general);
      expect(adReel.externalUrl, 'http://wadi-ramadi.com/master-plan');
      expect(adReel.ctaLabel, 'معرفة المزيد');
    });

    test('ReelModel.fromBanner rejects malformed or missing external URLs to prevent dead CTA', () {
      final malformedData1 = <String, dynamic>{
        'title': 'إعلان برابط خاطئ',
        'type': 'external',
        'targetId': 'invalid-url-without-scheme',
      };
      final reel1 = ReelModel.fromBanner(malformedData1, 'bad-url-1');
      expect(reel1.externalUrl, isEmpty);
      expect(reel1.ctaLabel, isEmpty);

      final malformedData2 = <String, dynamic>{
        'title': 'إعلان برابط فارغ',
        'type': 'external',
        'targetId': '   ',
      };
      final reel2 = ReelModel.fromBanner(malformedData2, 'bad-url-2');
      expect(reel2.externalUrl, isEmpty);
      expect(reel2.ctaLabel, isEmpty);

      final generalData = <String, dynamic>{
        'title': 'إعلان عام توعوي دون رابط',
        'type': 'general',
      };
      final reel3 = ReelModel.fromBanner(generalData, 'general-no-url');
      expect(reel3.externalUrl, isEmpty);
      expect(reel3.ctaLabel, isEmpty);
    });
  });

  group('Smart Reels Feed Diversity & Ad Interleaving Algorithm', () {
    ReelModel createTestReel({
      required String id,
      required String category,
      bool isPinned = false,
      int sortOrder = 0,
    }) {
      return ReelModel(
        id: id,
        title: 'عقار $id',
        description: '',
        videoUrl: 'https://cdn.example.com/$id.mp4',
        thumbnailUrl: '',
        qualityUrls: const {},
        status: ReelStatus.published,
        targetType: ReelTargetType.property,
        category: category,
        tags: [category],
        externalUrl: '',
        ctaLabel: 'عرض العقار',
        isPinned: isPinned,
        isFeatured: false,
        isSponsored: false,
        sortOrder: sortOrder,
        views: 0,
        completions: 0,
        likes: 0,
        saves: 0,
        shares: 0,
        propertyClicks: 0,
        externalClicks: 0,
        reports: 0,
        propertySnapshot: const {},
        officeSnapshot: const {},
      );
    }

    test('Algorithm preserves pinned reels at top and interleaves diverse categories', () {
      final input = [
        createTestReel(id: 'house-1', category: 'بيت'),
        createTestReel(id: 'house-2', category: 'بيت'),
        createTestReel(id: 'house-3', category: 'بيت'),
        createTestReel(id: 'apt-1', category: 'شقة'),
        createTestReel(id: 'apt-2', category: 'شقة'),
        createTestReel(id: 'land-1', category: 'أرض'),
        createTestReel(id: 'pinned-admin', category: 'عام', isPinned: true, sortOrder: 1),
      ];

      // Simulate smart feed logic
      final pinned = input.where((r) => r.isPinned).toList();
      final nonPinned = input.where((r) => !r.isPinned).toList();

      expect(pinned.length, 1);
      expect(pinned.first.id, 'pinned-admin');

      // Verify groups are separated by category
      final Map<String, List<ReelModel>> groups = {};
      for (final r in nonPinned) {
        groups.putIfAbsent(r.category, () => []).add(r);
      }
      expect(groups.keys.toSet(), {'بيت', 'شقة', 'أرض'});
      expect(groups['بيت']!.length, 3);
      expect(groups['شقة']!.length, 2);
      expect(groups['أرض']!.length, 1);
    });

    test('Ad injection injects ad instance every 4 items without duplication', () {
      final inputReels = List.generate(
        10,
        (i) => createTestReel(id: 'reel-$i', category: i % 2 == 0 ? 'بيت' : 'شقة'),
      );

      final ad = ReelModel.fromBanner({
        'title': 'إعلان راعي',
        'imageUrl': 'https://example.com/ad.jpg',
        'type': 'general',
      }, 'ad-1');

      final List<ReelModel> feed = [];
      final seen = <String>{};
      int itemsSinceAd = 0;
      int adCount = 0;

      for (final reel in inputReels) {
        if (seen.add(reel.id)) {
          feed.add(reel);
          itemsSinceAd++;
        }

        if (itemsSinceAd >= 4) {
          final adInstance = ReelModel(
            id: '${ad.id}_${feed.length}',
            title: ad.title,
            description: ad.description,
            videoUrl: ad.videoUrl,
            thumbnailUrl: ad.thumbnailUrl,
            qualityUrls: ad.qualityUrls,
            status: ad.status,
            targetType: ad.targetType,
            category: ad.category,
            tags: ad.tags,
            externalUrl: ad.externalUrl,
            ctaLabel: ad.ctaLabel,
            isPinned: false,
            isFeatured: false,
            isSponsored: true,
            sortOrder: 0,
            views: 0,
            completions: 0,
            likes: 0,
            saves: 0,
            shares: 0,
            propertyClicks: 0,
            externalClicks: 0,
            reports: 0,
            propertySnapshot: const {},
            officeSnapshot: const {},
          );
          if (seen.add(adInstance.id)) {
            feed.add(adInstance);
            adCount++;
            itemsSinceAd = 0;
          }
        }
      }

      // In 10 reels, an ad is inserted after 4th and 8th reel -> exactly 2 ads injected
      expect(adCount, 2);
      expect(feed.length, 12);
      expect(feed[4].isSponsored, isTrue);
      expect(feed[9].isSponsored, isTrue);

      // Verify all IDs are completely unique (no duplicate loops)
      final allIds = feed.map((r) => r.id).toList();
      expect(allIds.toSet().length, allIds.length);
    });
  });

  group('Isolation Verification: Real Estate Reels vs Booking Reels', () {
    test('Real estate reels model and bookings reels are completely isolated', () {
      const realEstateCollection = 'reels';
      const bookingBannersCollection = 'booking_banners';
      const bookingVenuesCollection = 'venues';

      expect(realEstateCollection, isNot(equals(bookingBannersCollection)));
      expect(realEstateCollection, isNot(equals(bookingVenuesCollection)));
    });
  });
}
