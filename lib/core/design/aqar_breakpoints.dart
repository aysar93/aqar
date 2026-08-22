import 'package:flutter/material.dart';

class AqarBreakpoints {
  AqarBreakpoints._();

  /// أقل من 600 = هاتف
  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  /// من 600 إلى أقل من 900 = تابلت
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 900;
  }

  /// 900 فأكثر = شاشة كبيرة
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  /// هاتف صغير
  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  /// هاتف عادي
  static bool isNormalPhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 360 && width < 400;
  }

  /// هاتف كبير
  static bool isLargePhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 400 && width < 600;
  }

  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;
}
