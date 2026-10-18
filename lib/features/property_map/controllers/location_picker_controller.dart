import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/anbar_map_config.dart';
import '../models/property_location.dart';
import '../services/map_bounds_service.dart';
import '../utils/map_validators.dart';

/// يدير عملية اختيار موقع العقار على الخريطة.
///
/// التصميم المقصود:
/// - المؤشر ثابت في منتصف الشاشة.
/// - المستخدم يحرك الخريطة تحته.
/// - عند توقف الحركة نحفظ مركز الخريطة.
/// - لا نسمح بتأكيد موقع غير صالح أو خارج النطاق.
class LocationPickerController extends ChangeNotifier {
  final MapBoundsService boundsService;

  final MapController _mapController = MapController();

  String _city;
  String _district;
  String _landmark;

  LatLng _selectedPosition;

  double _zoom;

  bool _isCameraMoving = false;
  bool _disposed = false;

  LocationPickerController({
    this.boundsService = const MapBoundsService(),
    String city = '',
    String district = '',
    String landmark = '',
    LatLng? initialPosition,
    double initialZoom = AnbarMapConfig.locationPickerZoom,
  })  : _city = city.trim(),
        _district = district.trim(),
        _landmark = landmark.trim(),
        _selectedPosition = initialPosition ?? AnbarMapConfig.initialCenter,
        _zoom = AnbarMapConfig.clampZoom(
          initialZoom,
        );

  MapController get mapController => _mapController;

  String get city => _city;

  String get district => _district;

  String get landmark => _landmark;

  LatLng get selectedPosition => _selectedPosition;

  double get latitude => _selectedPosition.latitude;

  double get longitude => _selectedPosition.longitude;

  double get zoom => _zoom;

  bool get isCameraMoving => _isCameraMoving;

  bool get isInsideAnbar {
    return boundsService.containsLatLng(
      _selectedPosition,
    );
  }

  PropertyLocation get location {
    return PropertyLocation(
      city: _city,
      district: _district,
      landmark: _landmark,
      latitude: latitude,
      longitude: longitude,
    );
  }

  String? get validationMessage {
    final baseValidation = MapValidators.validateLocation(
      location,
    );

    if (baseValidation != null) {
      return baseValidation;
    }

    if (!isInsideAnbar) {
      return 'الموقع المحدد خارج نطاق محافظة الأنبار';
    }

    return null;
  }

  bool get canConfirm => validationMessage == null;

  void updateCity(String value) {
    final next = value.trim();

    if (next == _city) {
      return;
    }

    _city = next;

    // عند تغيير المدينة لا نحتفظ بمنطقة
    // قد تكون تابعة لاختيار سابق.
    _district = '';

    _notify();
  }

  void updateDistrict(String value) {
    final next = value.trim();

    if (next == _district) {
      return;
    }

    _district = next;
    _notify();
  }

  void updateLandmark(String value) {
    final next = value.trim();

    if (next == _landmark) {
      return;
    }

    _landmark = next;
    _notify();
  }

  void updateAddress({
    required String city,
    required String district,
    String landmark = '',
  }) {
    _city = city.trim();
    _district = district.trim();
    _landmark = landmark.trim();

    _notify();
  }

  /// تستدعى أثناء تحريك flutter_map.
  ///
  /// نستقبل مركز الخريطة ومستوى التكبير مباشرة
  /// بدل CameraPosition الخاص بـ Google Maps.
  void onMapMove({
    required LatLng center,
    required double zoom,
  }) {
    final wasMoving = _isCameraMoving;

    _isCameraMoving = true;
    _selectedPosition = center;
    _zoom = AnbarMapConfig.clampZoom(zoom);

    // نعيد بناء الواجهة مرة واحدة فقط عند بدء الحركة،
    // وليس مع كل بكسل تتحركه الكاميرا.
    if (!wasMoving) {
      _notify();
    }
  }

  /// تستدعى عند توقف حركة الخريطة.
  void onMapIdle() {
    if (!_isCameraMoving) {
      return;
    }

    _isCameraMoving = false;
    _notify();
  }

  /// تحديث مركز الخريطة من الحالة الحالية.
  ///
  /// تستخدمها الشاشة عند الحاجة إلى مزامنة
  /// موقع المؤشر مع الكاميرا الحالية.
  void updateMapPosition({
    required LatLng center,
    required double zoom,
  }) {
    _selectedPosition = center;

    _zoom = AnbarMapConfig.clampZoom(
      zoom,
    );

    _notify();
  }

  /// نقل المؤشر برمجيًا إلى نقطة محددة.
  Future<void> moveTo(
    LatLng position, {
    double? zoom,
  }) async {
    final safePosition = boundsService.clampToAnbarBounds(
      position,
    );

    final targetZoom = AnbarMapConfig.clampZoom(
      zoom ?? _zoom,
    );

    _selectedPosition = safePosition;
    _zoom = targetZoom;

    _notify();

    _mapController.move(
      safePosition,
      targetZoom,
    );
  }

  /// إعادة الخريطة إلى نقطة البداية.
  Future<void> reset() async {
    await moveTo(
      AnbarMapConfig.initialCenter,
      zoom: AnbarMapConfig.locationPickerZoom,
    );
  }

  /// يعيد الموقع النهائي بعد التحقق.
  ///
  /// الشاشة تستدعي هذه الدالة قبل Navigator.pop.
  PropertyLocation? confirmLocation() {
    if (!canConfirm) {
      return null;
    }

    return location;
  }

  void _notify() {
    if (_disposed) {
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;

    _mapController.dispose();

    super.dispose();
  }
}
