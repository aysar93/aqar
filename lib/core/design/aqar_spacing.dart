import 'package:flutter/material.dart';
import '../../core/design/aqar_design.dart';
import 'aqar_breakpoints.dart';

class AqarSpacing {
  AqarSpacing._();

  // =============================
  // Values
  // =============================

  static double xs(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 8 : 4;

  static double sm(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 12 : 8;

  static double md(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 18 : 12;

  static double lg(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 24 : 16;

  static double xl(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 32 : 24;

  static double xxl(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 40 : 32;

  static double xxxl(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 56 : 48;

  // =============================
  // Horizontal Padding
  // =============================

  static double screen(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 24 : 16;

  // =============================
  // EdgeInsets
  // =============================

  static EdgeInsets page(BuildContext context) => EdgeInsets.symmetric(
        horizontal: screen(context),
        vertical: md(context),
      );

  static EdgeInsets card(BuildContext context) => EdgeInsets.all(md(context));

  static EdgeInsets section(BuildContext context) => EdgeInsets.symmetric(
        vertical: lg(context),
      );

  static EdgeInsets horizontal(BuildContext context) => EdgeInsets.symmetric(
        horizontal: screen(context),
      );

  static EdgeInsets vertical(BuildContext context) => EdgeInsets.symmetric(
        vertical: md(context),
      );

  static EdgeInsets allSm(BuildContext context) => EdgeInsets.all(sm(context));

  static EdgeInsets allMd(BuildContext context) => EdgeInsets.all(md(context));

  static EdgeInsets allLg(BuildContext context) => EdgeInsets.all(lg(context));

  // =============================
  // Gaps
  // =============================

  static SizedBox gapXs(BuildContext context) => SizedBox(height: xs(context));

  static SizedBox gapSm(BuildContext context) => SizedBox(height: sm(context));

  static SizedBox gapMd(BuildContext context) => SizedBox(height: md(context));

  static SizedBox gapLg(BuildContext context) => SizedBox(height: lg(context));

  static SizedBox gapXl(BuildContext context) => SizedBox(height: xl(context));

  static SizedBox gapXXl(BuildContext context) =>
      SizedBox(height: xxl(context));

  // =============================
  // Sections
  // =============================

  static double sectionLarge(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 40 : 32;
}
