import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

LatLng? bookingCoordinates(Map<String, dynamic> venue) {
  final lat = venue['latitude'], lon = venue['longitude'];
  if (lat is! num ||
      lon is! num ||
      !lat.isFinite ||
      !lon.isFinite ||
      lat < -90 ||
      lat > 90 ||
      lon < -180 ||
      lon > 180) {
    return null;
  }
  return LatLng(lat.toDouble(), lon.toDouble());
}

String? bookingCoordinateError(String latitude, String longitude) {
  if (latitude.trim().isEmpty && longitude.trim().isEmpty) {
    return null;
  }
  if (bookingCoordinates({
        'latitude': double.tryParse(latitude.trim()),
        'longitude': double.tryParse(longitude.trim())
      }) ==
      null) {
    return 'أدخل خط العرض من ‎-90 إلى 90 وخط الطول من ‎-180 إلى 180، أو اتركهما فارغين.';
  }
  return null;
}

double bookingDistanceKm(LatLng from, LatLng to) =>
    const Distance()(from, to) / 1000;

class BookingLocationFailure implements Exception {
  final String message;
  final bool appSettings, locationSettings;
  const BookingLocationFailure(this.message,
      {this.appSettings = false, this.locationSettings = false});
}

/// One foreground fix, kept by the map screen only. No writes or subscriptions.
class BookingLocationService {
  Future<LatLng> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const BookingLocationFailure(
            'خدمة الموقع معطلة. فعّل GPS ثم حاول مجددًا؛ يمكنك متابعة الخريطة والحجز.',
            locationSettings: true);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const BookingLocationFailure(
            'إذن الموقع مرفوض. يمكنك تفعيله من إعدادات التطبيق أو متابعة الحجز.',
            appSettings: true);
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const BookingLocationFailure(
            'لم يُمنح إذن الموقع. الخريطة والحجوزات متاحة دون موقعك.');
      }
      final fix = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 15)));
      final point = bookingCoordinates(
          {'latitude': fix.latitude, 'longitude': fix.longitude});
      if (point == null) {
        throw const BookingLocationFailure(
            'تعذر تحديد موقع صالح. حاول مجددًا.');
      }
      return point;
    } on BookingLocationFailure {
      rethrow;
    } on TimeoutException {
      throw const BookingLocationFailure(
          'انتهت مهلة تحديد الموقع. تحقق من GPS وحاول مجددًا.');
    } catch (_) {
      throw const BookingLocationFailure(
          'تعذر تحديد الموقع. تحقق من GPS والأذونات ثم حاول مجددًا.');
    }
  }
}

List<Uri> bookingDirectionUris(LatLng point, {required bool ios}) {
  final coordinates = '${point.latitude},${point.longitude}';
  return [
    if (ios)
      Uri.https('maps.apple.com', '/', {'daddr': coordinates, 'dirflg': 'd'})
    else
      Uri.parse('geo:$coordinates?q=$coordinates'),
    Uri.https('www.google.com', '/maps/dir/',
        {'api': '1', 'destination': coordinates}),
  ];
}

Future<bool> bookingOpenDirections(LatLng point,
    {Future<bool> Function(Uri)? launch, bool? ios}) async {
  for (final uri in bookingDirectionUris(point,
      ios: ios ?? defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      if (await (launch?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication))) {
        return true;
      }
    } catch (_) {/* Try the web maps fallback. */}
  }
  return false;
}

Future<bool> bookingOpenGoogleMaps(LatLng point) async {
  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<bool> bookingOpenWaze(LatLng point) async {
  final uri = Uri.parse('https://waze.com/ul?ll=${point.latitude},${point.longitude}&navigate=yes');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
