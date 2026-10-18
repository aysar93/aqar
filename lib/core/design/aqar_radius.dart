import 'package:flutter/material.dart';
import '../../core/design/aqar_design.dart';
import 'aqar_breakpoints.dart';

class AqarRadius {
  AqarRadius._();

  // =============================
  // Values
  // =============================

  static double xs(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 8 : 6;

  static double sm(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 12 : 8;

  static double md(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 18 : 12;

  static double lg(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 24 : 16;

  static double xl(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 32 : 20;

  static double xxl(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 40 : 24;

  // =============================
  // Common BorderRadius
  // =============================

  static BorderRadius card(BuildContext context) =>
      BorderRadius.circular(md(context));

  static BorderRadius button(BuildContext context) =>
      BorderRadius.circular(sm(context));

  static BorderRadius dialog(BuildContext context) =>
      BorderRadius.circular(lg(context));

  static BorderRadius bottomSheet(BuildContext context) =>
      BorderRadius.vertical(
        top: Radius.circular(xl(context)),
      );

  static BorderRadius sheet(BuildContext context) => bottomSheet(context);

  static BorderRadius category(BuildContext context) =>
      BorderRadius.circular(lg(context));

  static BorderRadius categoryIndicator(BuildContext context) =>
      BorderRadius.circular(xl(context));

  static BorderRadius avatar(BuildContext context) =>
      BorderRadius.circular(xxl(context));

  static BorderRadius image(BuildContext context) =>
      BorderRadius.circular(lg(context));
}
