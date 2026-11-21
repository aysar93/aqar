import 'dart:math' as math;

class VenueDistanceInfo {
  final int distanceKm;
  final String cityName;

  const VenueDistanceInfo({required this.distanceKm, required this.cityName});

  String get label => 'تبعد $distanceKm كم عن مركز $cityName';
}

class BookingGeoUtils {
  static const List<Map<String, dynamic>> _referenceCities = [
    {'name': 'الرمادي', 'lat': 33.4233, 'lng': 43.2974},
    {'name': 'الفلوجة', 'lat': 33.3540, 'lng': 43.7844},
    {'name': 'الحبانية', 'lat': 33.3756, 'lng': 43.5786},
    {'name': 'هيت', 'lat': 33.6428, 'lng': 42.8256},
  ];

  static double? _parseCoord(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val.trim());
    return null;
  }

  /// Extract valid latitude & longitude from venue data map without throwing
  static ({double lat, double lng})? extractCoordinates(Map<String, dynamic> venue) {
    double? lat;
    double? lng;

    lat = _parseCoord(venue['latitude']) ?? _parseCoord(venue['lat']);
    lng = _parseCoord(venue['longitude']) ?? _parseCoord(venue['lng']) ?? _parseCoord(venue['lon']);

    if ((lat == null || lng == null) && venue['locationGeo'] is Map) {
      final m = venue['locationGeo'] as Map;
      lat = _parseCoord(m['latitude']) ?? _parseCoord(m['lat']);
      lng = _parseCoord(m['longitude']) ?? _parseCoord(m['lng']) ?? _parseCoord(m['lon']);
    }

    // Validate bounds for Iraq/Anbar region (approx lat 28-39, lng 38-50)
    if (lat != null && lng != null && lat > 28.0 && lat < 39.0 && lng > 38.0 && lng < 50.0) {
      return (lat: lat, lng: lng);
    }
    return null;
  }

  /// Calculates Haversine distance in kilometers
  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth radius in km
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Returns distance info from nearest Anbar reference city, or null if coordinates are not available
  static VenueDistanceInfo? getDistanceInfo(Map<String, dynamic> venue) {
    final coords = extractCoordinates(venue);
    if (coords == null) return null;

    double minDistance = double.infinity;
    String closestCity = 'الرمادي';

    for (final city in _referenceCities) {
      final d = haversineDistance(
        coords.lat,
        coords.lng,
        city['lat'] as double,
        city['lng'] as double,
      );
      if (d < minDistance) {
        minDistance = d;
        closestCity = city['name'] as String;
      }
    }

    final distanceKm = minDistance.round();
    if (distanceKm <= 0 || distanceKm > 300) return null;

    return VenueDistanceInfo(distanceKm: distanceKm, cityName: closestCity);
  }

  /// Returns live availability badge text based on real venue data & Baghdad time
  static String? getLiveAvailabilityBadge(Map<String, dynamic> venue) {
    if (venue['active'] != true) return null;
    if (venue['isAvailableToday'] == false) return null;

    // Check blackout or manual unavailability
    final manualClosed = venue['isClosed'] == true || venue['paused'] == true;
    if (manualClosed) return null;

    // Baghdad time check (UTC+3)
    final nowBaghdad = DateTime.now().toUtc().add(const Duration(hours: 3));
    final isWeekend = nowBaghdad.weekday == DateTime.thursday ||
        nowBaghdad.weekday == DateTime.friday ||
        nowBaghdad.weekday == DateTime.saturday;

    if (isWeekend) {
      return 'متاح نهاية الأسبوع';
    } else {
      return 'متاح اليوم';
    }
  }
}

