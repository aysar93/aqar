import 'package:flutter/material.dart';
import '../../core/design/aqar_design.dart';
import 'aqar_breakpoints.dart';

class AqarSizes {
  AqarSizes._();

  // ==========================
  // Icons
  // ==========================

  static double iconXs(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 16 : 14;

  static double iconSm(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 20 : 18;

  static double iconMd(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 22 : 20;

  static double icon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 24 : 22;

  static double iconLg(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 28 : 26;

  static double iconXl(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 32 : 30;

  // ==========================
  // Header
  // ==========================

  static double headerButton(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 52 : 44;

  static double headerIcon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 22 : 20;

  static double avatar(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 42 : 34;

  static double avatarRadius(BuildContext context) => avatar(context) / 2;

  static double avatarIcon(BuildContext context) => icon(context);

// ==========================
// Search
// ==========================

  static double searchCircle(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 40 : 34;

  static double searchIcon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 22 : 18;

  static double filterButton(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 46 : 40;

  static double filterIcon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 22 : 18;

  // ==========================
  // Categories
  // ==========================

  static double categoryWidth(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 74 : 64;

  static double categoryHeight(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 88 : 80;

  static double categoryIcon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 22 : 20;

  static double categorySectionHeight(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 100 : 92;

  static double categoryCirclePadding(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 10 : 8;

  static double categoryIndicatorWidth(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 40 : 34;

  static double categoryIndicatorHeight(BuildContext context) => 3;

  // ==========================
  // Property Cards
  // ==========================

  static double propertyCardWidth(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 220 : 190;

  static double propertyImageHeight(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 175 : 160;

  static double detailsInfoIcon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 26 : 24;

  static double detailsInfoRadius(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 16 : 14;

  static double featureIcon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 20 : 18;

  static double featureRadius(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 16 : 14;

  static double officeAvatar(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 64 : 56;

  static double officeAvatarIcon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 34 : 30;

  static double propertyStatusDot(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 8 : 7;

  static double propertyLocationIcon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 18 : 16;

  static double propertyPriceIcon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 20 : 18;

  static double detailsImageHeight(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 360 : 300;

  static double detailsTopButton(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 52 : 46;

  static double detailsTopIcon(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 24 : 20;

  static double detailsPriceCardWidth(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 175 : 155;

  static double detailsDot(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 9 : 7;

  // ==========================
  // Banner
  // ==========================

  static double bannerHeight(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 165 : 138;

  // ==========================
  // Buttons
  // ==========================

  static double buttonHeight(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 54 : 48;

  // ==========================
  // Bottom Navigation
  // ==========================

  static double bottomBarHeight(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 82 : 72;

  // ==========================
  // Horizontal Sections
  // ==========================

  static double horizontalSectionHeight(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 325 : 300;

  static double horizontalCardsHeight(BuildContext context) =>
      AqarBreakpoints.isTablet(context) ? 255 : 225;
}
