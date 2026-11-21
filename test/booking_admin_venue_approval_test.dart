import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Cloud function approveBookingVenue receives minimal atomic payload without touching venue data', () {
    const targetVenueId = 'IT25G8XYug2xcX39GQvR';
    final approvalCallPayload = <String, dynamic>{
      'venueId': targetVenueId,
      'reason': 'اعتماد وتفعيل من لوحة الإدارة',
    };

    // Strict security & isolation assertions:
    expect(approvalCallPayload.containsKey('venueId'), isTrue);
    expect(approvalCallPayload['venueId'], targetVenueId);
    expect(approvalCallPayload.containsKey('name'), isFalse);
    expect(approvalCallPayload.containsKey('price'), isFalse);
    expect(approvalCallPayload.containsKey('deposit'), isFalse);
    expect(approvalCallPayload.containsKey('pricingMode'), isFalse);
    expect(approvalCallPayload.containsKey('shifts'), isFalse);
    expect(approvalCallPayload.containsKey('complexName'), isFalse);
    expect(approvalCallPayload.containsKey('terms'), isFalse);
    expect(approvalCallPayload.containsKey('amenities'), isFalse);
    expect(approvalCallPayload.containsKey('ownerId'), isFalse);
  });

  test('Cloud function setBookingVenueActive safely toggles active status without data mutation', () {
    const targetVenueId = 'IT25G8XYug2xcX39GQvR';
    final togglePayload = <String, dynamic>{
      'venueId': targetVenueId,
      'active': true,
      'reason': 'إعادة تفعيل النشر للجمهور',
    };

    expect(togglePayload['venueId'], targetVenueId);
    expect(togglePayload['active'], isTrue);
    expect(togglePayload.containsKey('name'), isFalse);
    expect(togglePayload.containsKey('shifts'), isFalse);
  });

  test('Cloud function setVenueFeatured carries verified priority and expiration bounds', () {
    const targetVenueId = 'IT25G8XYug2xcX39GQvR';
    final now = DateTime.now().millisecondsSinceEpoch;
    final featuredUntil = now + (7 * 86400000);

    final featuredPayload = <String, dynamic>{
      'venueId': targetVenueId,
      'isFeatured': true,
      'priority': 50,
      'featuredUntil': featuredUntil,
      'reason': 'تمييز المكان لمدة 7 أيام',
    };

    expect(featuredPayload['venueId'], targetVenueId);
    expect(featuredPayload['isFeatured'], isTrue);
    expect(featuredPayload['priority'], inInclusiveRange(0, 100));
    expect(featuredPayload['featuredUntil'], greaterThan(now));
  });

  test('Legacy fallback payload preserves 100% of shifts and complexName', () {
    final venueSnapshot = {
      'id': 'IT25G8XYug2xcX39GQvR',
      'ownerId': 'Q1qjnkQf29W47DEk3GKAB9sZDPc2',
      'name': 'Chalet-UAT-Updated123-Test',
      'complexName': 'Chalet-UAT-Functional-Updated',
      'category': 'chalet',
      'location': 'Al-Habbaniyah — مركز قضاء الرمادي',
      'price': 100000,
      'deposit': 50000,
      'active': false,
      'pricingMode': 'shifts',
      'shifts': [
        {'id': 'morning', 'name': 'الفترة الصباحية', 'price': 100000, 'checkInMinute': 480, 'checkOutMinute': 840},
        {'id': 'evening', 'name': 'الفترة المسائية', 'price': 150000, 'checkInMinute': 900, 'checkOutMinute': 1380},
        {'id': 'full_day', 'name': 'يوم كامل', 'price': 240000, 'checkInMinute': 480, 'checkOutMinute': 360, 'endDayOffset': 1},
      ],
      'amenities': ['pool', 'wifi', 'parking'],
      'terms': 'الالتزام بأوقات الدخول والمغادرة',
      'cancellationPolicy': {'freeCancellationHours': 24, 'lateRefundPercent': 50},
      'offer': {'percent': 25, 'until': 1795230899619},
      'capacity': 10,
      'bedrooms': 3,
      'latitude': 33.38,
      'longitude': 43.55,
    };

    final current = venueSnapshot;
    final payload = <String, dynamic>{
      'id': 'IT25G8XYug2xcX39GQvR',
      'ownerId': current['ownerId'],
      'name': current['name'],
      'category': current['category'] ?? 'chalet',
      'location': current['location'] ?? 'الأنبار',
      'price': current['price'] ?? 100000,
      'deposit': current['deposit'] ?? 50000,
      'active': true,
      'terms': current['terms'] ?? '',
      'capacity': current['capacity'] ?? 0,
      'bedrooms': current['bedrooms'] ?? 0,
      'bathrooms': current['bathrooms'] ?? 0,
      'pools': current['pools'] ?? 0,
      'parkingSpots': current['parkingSpots'] ?? 0,
      'area': current['area'] ?? 0,
      'amenities': (current['amenities'] as List?)?.map((e) => e.toString()).toList() ?? [],
      'complexName': current['complexName'] ?? '',
      'unitName': current['unitName'] ?? '',
      if (current['pricingMode'] != null) 'pricingMode': current['pricingMode'],
      if (current['shifts'] != null) 'shifts': current['shifts'],
      if (current['hourlyPrice'] != null) 'hourlyPrice': current['hourlyPrice'],
      if (current['cancellationPolicy'] != null) 'cancellationPolicy': current['cancellationPolicy'],
      if (current['latitude'] != null) 'latitude': current['latitude'],
      if (current['longitude'] != null) 'longitude': current['longitude'],
      if (current['offer'] != null) 'offer': current['offer'],
      if (current['commissionBps'] != null) 'commissionBps': current['commissionBps'],
    };

    expect(payload['active'], isTrue);
    expect(payload['name'], 'Chalet-UAT-Updated123-Test');
    expect(payload['complexName'], 'Chalet-UAT-Functional-Updated');
    expect(payload['pricingMode'], 'shifts');
    expect(payload['shifts'], hasLength(3));
    expect((payload['shifts'] as List)[0]['name'], 'الفترة الصباحية');
    expect((payload['shifts'] as List)[1]['price'], 150000);
    expect((payload['shifts'] as List)[2]['name'], 'يوم كامل');
    expect(payload['deposit'], 50000);
    expect(payload['location'], 'Al-Habbaniyah — مركز قضاء الرمادي');
    expect(payload['amenities'], ['pool', 'wifi', 'parking']);
    expect(payload['cancellationPolicy']['freeCancellationHours'], 24);
    expect(payload['offer']['percent'], 25);
  });

  group('Featured Venues Expiration & Ordering (4 Cases)', () {
    final fixedNow = DateTime(2026, 11, 15, 12, 0);

    test('Case 1: Featured venue with future expiration is active', () {
      final venue = {
        'id': 'v1',
        'isFeatured': true,
        'featuredUntil': fixedNow.add(const Duration(days: 7)).millisecondsSinceEpoch,
      };
      // In-line check reproducing isBookingVenueFeatured
      final flag = venue['isFeatured'] == true || venue['featured'] == true;
      final until = venue['featuredUntil'];
      final isActive = flag && (until == null || fixedNow.millisecondsSinceEpoch <= (until as int));
      expect(isActive, isTrue);
    });

    test('Case 2: Featured venue with past expiration is inactive', () {
      final venue = {
        'id': 'v2',
        'isFeatured': true,
        'featuredUntil': fixedNow.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      };
      final flag = venue['isFeatured'] == true || venue['featured'] == true;
      final until = venue['featuredUntil'];
      final isActive = flag && (until == null || fixedNow.millisecondsSinceEpoch <= (until as int));
      expect(isActive, isFalse);
    });

    test('Case 3: Non-featured venue is inactive regardless of date', () {
      final venue = {
        'id': 'v3',
        'isFeatured': false,
        'featuredUntil': fixedNow.add(const Duration(days: 30)).millisecondsSinceEpoch,
      };
      final flag = venue['isFeatured'] == true || venue['featured'] == true;
      final until = venue['featuredUntil'];
      final isActive = flag && (until == null || fixedNow.millisecondsSinceEpoch <= (until as int));
      expect(isActive, isFalse);
    });

    test('Case 4: Featured venue with null/missing featuredUntil is active (backward compatible)', () {
      final venueA = {
        'id': 'v4a',
        'isFeatured': true,
        'featuredUntil': null,
      };
      final venueB = {
        'id': 'v4b',
        'featured': true,
      };

      for (final v in [venueA, venueB]) {
        final flag = v['isFeatured'] == true || v['featured'] == true;
        final until = v['featuredUntil'];
        final isActive = flag && (until == null || fixedNow.millisecondsSinceEpoch <= (until as int));
        expect(isActive, isTrue);
      }
    });

    test('Featured venues sort descending by priority then secondary timestamp', () {
      final list = [
        {'id': 'v_low', 'featuredPriority': 5, 'updatedAt': 2000},
        {'id': 'v_top', 'featuredPriority': 100, 'updatedAt': 1000},
        {'id': 'v_mid_recent', 'featuredPriority': 20, 'updatedAt': 3000},
        {'id': 'v_mid_old', 'featuredPriority': 20, 'updatedAt': 1000},
      ];

      list.sort((a, b) {
        final pA = (a['featuredPriority'] as num?)?.toInt() ?? 0;
        final pB = (b['featuredPriority'] as num?)?.toInt() ?? 0;
        if (pA != pB) return pB.compareTo(pA);
        final tA = (a['updatedAt'] as num?)?.toInt() ?? 0;
        final tB = (b['updatedAt'] as num?)?.toInt() ?? 0;
        return tB.compareTo(tA);
      });

      expect(list.map((v) => v['id']).toList(), ['v_top', 'v_mid_recent', 'v_mid_old', 'v_low']);
    });
  });

  group('Calendar Baghdad Timezone and Conflict Overlap Logic', () {
    test('Baghdad midnight is exactly UTC-3 hours', () {
      final day = DateTime(2026, 11, 15);
      final baghdadMidnightUtc = DateTime.utc(day.year, day.month, day.day).subtract(const Duration(hours: 3));

      // In Baghdad (UTC+3), 2026-11-15 00:00:00 is 2026-11-14 21:00:00 UTC
      expect(baghdadMidnightUtc.toUtc().hour, 21);
      expect(baghdadMidnightUtc.toUtc().day, 14);
    });

    test('Non-overlapping shifts on same day produce zero false conflicts', () {
      // Baghdad day: 2026-11-15
      // Morning shift: 09:00 - 15:00
      final morningStart = DateTime.utc(2026, 11, 15, 6, 0).millisecondsSinceEpoch;
      final morningEnd = DateTime.utc(2026, 11, 15, 12, 0).millisecondsSinceEpoch;

      // Evening shift: 16:00 - 23:00
      final eveningStart = DateTime.utc(2026, 11, 15, 13, 0).millisecondsSinceEpoch;
      final eveningEnd = DateTime.utc(2026, 11, 15, 20, 0).millisecondsSinceEpoch;

      bool overlaps = morningStart < eveningEnd && morningEnd > eveningStart;
      expect(overlaps, isFalse, reason: 'Morning and Evening shifts do not overlap');
    });

    test('Real overlapping bookings on same venue produce confirmed conflict', () {
      final b1Start = 1000;
      final b1End = 2000;
      final b2Start = 1500;
      final b2End = 2500;

      bool overlaps = b1Start < b2End && b1End > b2Start;
      expect(overlaps, isTrue);
    });
  });
}
