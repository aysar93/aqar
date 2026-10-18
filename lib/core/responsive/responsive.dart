import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isTablet(BuildContext context) => screenWidth(context) >= 700;

  static bool isPhone(BuildContext context) => screenWidth(context) < 700;

  static double w(BuildContext context, double ratio) =>
      screenWidth(context) * ratio;

  static double h(BuildContext context, double ratio) =>
      screenHeight(context) * ratio;

  static double radius(BuildContext context, double value) {
    final width = screenWidth(context);

    if (width >= 700) {
      return value * 1.25;
    }

    if (width >= 430) {
      return value * 1.08;
    }

    if (width <= 360) {
      return value * 0.90;
    }

    return value;
  }

  static double icon(BuildContext context, double value) {
    final width = screenWidth(context);

    if (width >= 700) {
      return value * 1.20;
    }

    if (width <= 360) {
      return value * 0.90;
    }

    return value;
  }

  static double font(BuildContext context, double value) {
    final width = screenWidth(context);

    if (width >= 700) {
      return value * 1.20;
    }

    if (width >= 430) {
      return value * 1.05;
    }

    if (width <= 360) {
      return value * 0.92;
    }

    return value;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = screenWidth(context);

    if (width >= 700) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 18);
    }

    if (width >= 430) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    }

    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }

  static double propertyCardWidth(BuildContext context) {
    final width = screenWidth(context);

    if (width >= 700) {
      return width * .55;
    }

    return width * .82;
  }

  static double categoryWidth(BuildContext context) {
    final width = screenWidth(context);

    if (width >= 700) {
      return 120;
    }

    if (width <= 360) {
      return 82;
    }

    return 92;
  }

  static double headerButton(BuildContext context) {
    final width = screenWidth(context);

    if (width >= 700) {
      return 62;
    }

    if (width <= 360) {
      return 48;
    }

    return 54;
  }

  static double searchHeight(BuildContext context) {
    final width = screenWidth(context);

    if (width <= 360) {
      return 56;
    }

    if (width >= 700) {
      return 70;
    }

    return 62;
  }
}
