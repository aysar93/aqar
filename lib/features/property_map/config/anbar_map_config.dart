import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// الإعدادات الجغرافية المركزية لخريطة محافظة الأنبار.
///
/// أي شاشة تحتاج إلى:
/// - نقطة البداية.
/// - حدود حركة الخريطة.
/// - مستويات التكبير.
/// تعتمد على هذا الملف بدل تكرار القيم.
///
/// هذا الملف مستقل عن Google Maps ويستخدم flutter_map.
class AnbarMapConfig {
  AnbarMapConfig._();

  /// مركز ابتدائي مناسب لعرض محافظة الأنبار.
  ///
  /// هذه النقطة تستخدم فقط لبدء الخريطة
  /// وليست موقع عقار.
  static const LatLng initialCenter = LatLng(
    33.3500,
    42.4500,
  );

  /// مستوى التكبير عند فتح خريطة البحث.
  static const double initialZoom = 7.0;

  /// مستوى التكبير عند فتح محدد موقع العقار.
  static const double locationPickerZoom = 15.5;

  /// مستوى التكبير عند عرض عقار منفرد.
  static const double propertyZoom = 16.0;

  /// أقل Zoom نسمح به.
  static const double minZoom = 6.0;

  /// أعلى Zoom نسمح به.
  static const double maxZoom = 19.0;

  /// الحد الجنوبي الغربي لمنطقة تشغيل الخريطة.
  static const LatLng southWest = LatLng(
    31.4500,
    38.7500,
  );

  /// الحد الشمالي الشرقي لمنطقة تشغيل الخريطة.
  static const LatLng northEast = LatLng(
    35.1500,
    44.7500,
  );

  /// الحدود التشغيلية لخريطة الأنبار.
  ///
  /// تستخدم لمنع المستخدم من الابتعاد بالخريطة
  /// خارج المنطقة المطلوبة بشكل غير ضروري.
  ///
  /// التحقق النهائي من كون موقع العقار صالحًا
  /// يبقى من مسؤولية MapBoundsService.
  static final LatLngBounds cameraBounds = LatLngBounds(
    southWest,
    northEast,
  );

  /// إنشاء حدود تحتوي نقطة واحدة.
  ///
  /// يمكن استخدامها لاحقًا عند الحاجة إلى
  /// fitCamera أو حساب مجال حول عقار محدد.
  static LatLngBounds boundsForPosition(
    LatLng position,
  ) {
    return LatLngBounds(
      position,
      position,
    );
  }

  /// ضبط Zoom ليبقى ضمن الحدود المسموحة.
  static double clampZoom(double zoom) {
    return zoom
        .clamp(
          minZoom,
          maxZoom,
        )
        .toDouble();
  }

  /// هل النقطة داخل الحدود التشغيلية العامة؟
  ///
  /// هذا فحص مستطيل سريع فقط.
  /// التحقق الجغرافي النهائي يبقى في MapBoundsService.
  static bool isInsideCameraBounds(
    LatLng position,
  ) {
    return position.latitude >= southWest.latitude &&
        position.latitude <= northEast.latitude &&
        position.longitude >= southWest.longitude &&
        position.longitude <= northEast.longitude;
  }
}
