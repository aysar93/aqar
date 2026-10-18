import 'package:flutter/material.dart';
import '../../core/design/aqar_design.dart';
import 'aqar_breakpoints.dart';

class AqarText {
  AqarText._();

  // =============================
  // Display
  // =============================

  static double hero(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 32 : 28;

  static double display(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 28 : 24;

  static double headline(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 24 : 20;

  static double title(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 22 : 18;

  static double subtitle(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 20 : 16;

  // =============================
  // Body
  // =============================

  static double body(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 16 : 14;

  static double bodySmall(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 14 : 13;

  static double caption(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 13 : 12;

  static double overline(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 12 : 10;

  // =============================
  // Project Helpers
  // =============================

  static double pageTitle(BuildContext context) => headline(context);

  static double sectionTitle(BuildContext context) => title(context);

  static double cardTitle(BuildContext context) => subtitle(context);

  static double detailsSectionTitle(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 22 : 20;

  static double detailsBody(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 16 : 15;

  static double detailsSubTitle(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 18 : 16;

  static double featureText(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 15 : 14;

  static double mapButton(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 14 : 13;

  static double officeTitle(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 24 : 22;

  static double officeSubTitle(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 16 : 15;

  static double contactButton(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 17 : 16;

  static double detailsLabel(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 14 : 13;

  static double detailsValue(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 19 : 17;

  static double propertyTitle(BuildContext context) => subtitle(context);

  static double bannerTitle(BuildContext context) => title(context);

  static double detailsPrice(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 17 : 15;

  static double detailsStatus(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 12 : 11;

  static double price(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 22 : 18;

  static double searchHint(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 14 : 12;

  static double searchInput(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 15 : 13;

  static double category(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 12 : 11;

  static double propertyBadge(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 13 : 12;

  static double button(BuildContext context) => body(context);

  static double small(BuildContext context) => bodySmall(context);

  static double tiny(BuildContext context) => overline(context);
}
