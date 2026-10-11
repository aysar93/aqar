import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:aqar/bookings/booking_location.dart';

class FakeGps extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requested = LocationPermission.whileInUse;
  int requests = 0, fixes = 0;
  Object? failure;
  LocationSettings? settings;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    fixes++;
    settings = locationSettings;
    if (failure != null) throw failure!;
    return Position(
        latitude: 33.4,
        longitude: 43.3,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0);
  }
}

void main() {
  test(
      'validates paired finite coordinates including boundaries and legacy values',
      () {
    expect(bookingCoordinateError('', ''), isNull);
    expect(bookingCoordinateError(' -90 ', '180'), isNull);
    for (final values in [
      ['91', '0'],
      ['0', '181'],
      ['NaN', '0'],
      ['Infinity', '0'],
      ['', '43'],
      ['33', ''],
      ['abc', '43']
    ]) {
      expect(bookingCoordinateError(values[0], values[1]), isNotNull);
    }
    expect(bookingCoordinates({'latitude': '33', 'longitude': 43}), isNull);
    expect(bookingCoordinates({}), isNull);
    expect(bookingDistanceKm(const LatLng(33, 43), const LatLng(33, 43)), 0);
    expect(bookingDistanceKm(const LatLng(33, 43), const LatLng(34, 43)),
        greaterThan(100));
  });
  test('Android and iOS use destination only with fallback on missing app',
      () async {
    final point = LatLng(33.4, 43.3);
    expect(bookingDirectionUris(point, ios: false).first.scheme, 'geo');
    expect(bookingDirectionUris(point, ios: true).first.host, 'maps.apple.com');
    final tried = <Uri>[];
    expect(
        await bookingOpenDirections(point, ios: false, launch: (uri) async {
          tried.add(uri);
          if (uri.scheme == 'geo') throw StateError('missing');
          return true;
        }),
        isTrue);
    expect(tried.last.queryParameters['destination'], '33.4,43.3');
    expect(tried.last.queryParameters.containsKey('origin'), isFalse);
    expect(await bookingOpenDirections(point, launch: (_) async => false),
        isFalse);
  });
  group('foreground permission and GPS flow', () {
    late FakeGps gps;
    late GeolocatorPlatform original;
    setUp(() {
      original = GeolocatorPlatform.instance;
      gps = FakeGps();
      GeolocatorPlatform.instance = gps;
    });
    tearDown(() => GeolocatorPlatform.instance = original);
    test('GPS disabled does not request permission or position', () async {
      gps.enabled = false;
      await expectLater(
          BookingLocationService().locate(),
          throwsA(isA<BookingLocationFailure>()
              .having((e) => e.locationSettings, 'settings', true)));
      expect(gps.requests, 0);
      expect(gps.fixes, 0);
    });
    test('denied and denied forever never fetch position', () async {
      gps.requested = LocationPermission.denied;
      await expectLater(BookingLocationService().locate(),
          throwsA(isA<BookingLocationFailure>()));
      expect(gps.requests, 1);
      expect(gps.fixes, 0);
      gps.permission = LocationPermission.deniedForever;
      await expectLater(
          BookingLocationService().locate(),
          throwsA(isA<BookingLocationFailure>()
              .having((e) => e.appSettings, 'settings', true)));
      expect(gps.requests, 1);
      expect(gps.fixes, 0);
    });
    test(
        'grant gets one bounded fix, existing permission is not prompted again',
        () async {
      expect(await BookingLocationService().locate(), const LatLng(33.4, 43.3));
      expect(gps.requests, 1);
      expect(gps.fixes, 1);
      expect(gps.settings!.timeLimit, const Duration(seconds: 15));
      gps.permission = LocationPermission.whileInUse;
      await BookingLocationService().locate();
      expect(gps.requests, 1);
      expect(gps.fixes, 2);
    });
    test('timeout and native failure give recoverable messages', () async {
      gps.permission = LocationPermission.whileInUse;
      gps.failure = TimeoutException('gps');
      await expectLater(
          BookingLocationService().locate(),
          throwsA(isA<BookingLocationFailure>()
              .having((e) => e.message, 'message', contains('مهلة'))));
      gps.failure = StateError('native');
      await expectLater(BookingLocationService().locate(),
          throwsA(isA<BookingLocationFailure>()));
    });
  });
}
