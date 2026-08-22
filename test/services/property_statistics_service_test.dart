import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/models/property_model.dart';
import 'package:aqar/services/property_statistics_service.dart';

void main() {
  group('PropertyStatisticsService.analyzeProperties', () {
    test('يفصل البيع عن الإيجار ويحسب الشرائح بصورة مستقلة', () {
      final analytics = PropertyStatisticsService.analyzeProperties(
        currentProperties: [
          _property('1', adType: 'للبيع', price: 120000000, area: 200),
          _property('2', adType: 'للبيع', price: 180000000, area: 300),
          _property('3', adType: 'للإيجار', price: 750000, area: 150),
        ],
      );

      expect(analytics.segmentStatistics['للبيع']?.propertyCount, 2);
      expect(analytics.segmentStatistics['للإيجار']?.propertyCount, 1);
      expect(analytics.segmentStatistics['للبيع']?.averagePrice, 150000000);
      expect(analytics.priceBandsBySegment['للبيع']?['100–249 مليون'], 2);
      expect(analytics.priceBandsBySegment['للإيجار']?['500–999 ألف'], 1);
    });

    test('لا يصنف اتجاه المنطقة عندما تكون العينة غير كافية', () {
      final analytics = PropertyStatisticsService.analyzeProperties(
        currentProperties: List.generate(
          4,
          (index) => _property('$index', price: 120000000),
        ),
        previousProperties: List.generate(
          4,
          (index) => _property('p$index', price: 100000000),
        ),
      );

      expect(analytics.growingAreas, isEmpty);
      expect(analytics.insufficientTrendAreas, hasLength(1));
    });

    test('يصنف المنطقة بعد توفر خمس عينات في الفترتين', () {
      final analytics = PropertyStatisticsService.analyzeProperties(
        currentProperties: List.generate(
          5,
          (index) => _property('$index', price: 120000000),
        ),
        previousProperties: List.generate(
          5,
          (index) => _property('p$index', price: 100000000),
        ),
      );

      expect(analytics.growingAreas, hasLength(1));
      expect(analytics.growingAreas.first.changePercentage, closeTo(20, .001));
    });

    test('يستبعد السعر الشاذ فقط بعد توفر الحد الأدنى للعينة', () {
      final prices = <double>[
        100000000,
        102000000,
        104000000,
        106000000,
        108000000,
        110000000,
        112000000,
        900000000,
      ];
      final analytics = PropertyStatisticsService.analyzeProperties(
        currentProperties: List.generate(
          prices.length,
          (index) => _property('$index', price: prices[index]),
        ),
      );

      expect(analytics.excludedPriceOutlierCount, 1);
      expect(analytics.propertyCount, 7);
    });
  });
}

PropertyModel _property(
  String id, {
  String adType = 'للبيع',
  double price = 100000000,
  int area = 200,
}) {
  return PropertyModel(
    id: id,
    title: 'عقار $id',
    imageUrl: '',
    images: const [],
    location: 'الرمادي - التأميم',
    city: 'الرمادي',
    areaName: 'التأميم',
    landmark: '',
    propertyType: 'بيت',
    adType: adType,
    price: price,
    negotiable: false,
    rooms: 3,
    bathrooms: 2,
    area: area,
    livingRooms: 1,
    parking: 1,
    buildYear: 2020,
    description: '',
    features: const [],
    documentType: '',
    furnitureStatus: '',
    ownerPhone: '',
    ownerWhatsapp: '',
    publisherUid: '',
    publisherName: '',
    publisherPhotoUrl: '',
    publisherEmail: '',
    publisherPhone: '',
    publisherWhatsapp: '',
    officeId: '',
    officeName: '',
    officeLogoUrl: '',
    isOfficeProperty: false,
    isPromoted: false,
    isVerified: false,
    isFeatured: false,
    isFavorite: false,
    availabilityStatus: 'available',
    views: 0,
    propertyNumber: 0,
    latitude: 0,
    longitude: 0,
    createdAt: null,
    status: 'approved',
  );
}
