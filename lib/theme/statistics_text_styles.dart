import 'package:flutter/material.dart';

/// نظام الخطوط الموحد لواجهات إحصائيات السوق العقاري.
///
/// الهدف:
/// - منع انتشار أحجام الخطوط داخل ملفات الـ Widgets.
/// - تحسين وضوح النصوص العربية.
/// - إمكانية تعديل أحجام جميع نصوص الإحصائيات من مكان واحد.
class StatisticsTextStyles {
  StatisticsTextStyles._();

  // ============================================================
  // Font Sizes
  // ============================================================

  /// العنوان الرئيسي للشاشة.
  static const double pageTitleSize = 19;

  /// الوصف الموجود أسفل العنوان الرئيسي.
  static const double pageSubtitleSize = 12;

  /// عنوان القسم.
  static const double sectionTitleSize = 16;

  /// الوصف الموجود أسفل عنوان القسم.
  static const double sectionSubtitleSize = 11.5;

  /// عنوان البطاقة.
  static const double cardTitleSize = 13;

  /// النص الأساسي داخل البطاقات.
  static const double bodySize = 12;

  /// النصوص الثانوية.
  static const double secondarySize = 11;

  /// الملاحظات والتوضيحات الصغيرة.
  ///
  /// لا ننزل عن 10.5 حتى تبقى العربية واضحة.
  static const double captionSize = 10.5;

  /// الأرقام المهمة مثل الأسعار.
  static const double metricSize = 17;

  /// الأرقام الكبيرة والرئيسية.
  static const double largeMetricSize = 21;

  /// النص داخل الـ Chips.
  static const double chipSize = 11.5;

  /// الأزرار.
  static const double buttonSize = 12;

  // ============================================================
  // Colors
  // ============================================================

  static const Color primaryText = Colors.white;

  static Color get secondaryText => Colors.white.withValues(alpha: 0.62);

  static Color get mutedText => Colors.white.withValues(alpha: 0.48);

  static Color get subtleText => Colors.white.withValues(alpha: 0.40);

  // ============================================================
  // Page
  // ============================================================

  static const TextStyle pageTitle = TextStyle(
    color: primaryText,
    fontSize: pageTitleSize,
    fontWeight: FontWeight.w900,
    height: 1.25,
  );

  static TextStyle get pageSubtitle => TextStyle(
        color: secondaryText,
        fontSize: pageSubtitleSize,
        fontWeight: FontWeight.w500,
        height: 1.55,
      );

  // ============================================================
  // Sections
  // ============================================================

  static const TextStyle sectionTitle = TextStyle(
    color: primaryText,
    fontSize: sectionTitleSize,
    fontWeight: FontWeight.w800,
    height: 1.3,
  );

  static TextStyle get sectionSubtitle => TextStyle(
        color: mutedText,
        fontSize: sectionSubtitleSize,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  // ============================================================
  // Cards
  // ============================================================

  static const TextStyle cardTitle = TextStyle(
    color: primaryText,
    fontSize: cardTitleSize,
    fontWeight: FontWeight.w800,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    color: primaryText,
    fontSize: bodySize,
    fontWeight: FontWeight.w500,
    height: 1.55,
  );

  static TextStyle get secondary => TextStyle(
        color: secondaryText,
        fontSize: secondarySize,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle get caption => TextStyle(
        color: mutedText,
        fontSize: captionSize,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  // ============================================================
  // Numbers / Prices
  // ============================================================

  static const TextStyle metric = TextStyle(
    color: primaryText,
    fontSize: metricSize,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static const TextStyle largeMetric = TextStyle(
    color: primaryText,
    fontSize: largeMetricSize,
    fontWeight: FontWeight.w900,
    height: 1.2,
  );

  // ============================================================
  // Chips / Buttons
  // ============================================================

  static TextStyle get chip => TextStyle(
        color: secondaryText,
        fontSize: chipSize,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );

  static const TextStyle button = TextStyle(
    fontSize: buttonSize,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );
}
