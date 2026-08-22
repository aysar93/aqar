import 'package:flutter/material.dart';

import '../../theme/statistics_text_styles.dart';

/// مستوى الثقة المبسط بناءً على حجم العينة.
///
/// هذا التصنيف مخصص لتوضيح حجم البيانات للمستخدم،
/// وليس مقياسًا إحصائيًا علميًا لهامش الخطأ.
enum DataConfidenceLevel {
  veryLimited,
  limited,
  moderate,
  good,
  strong,
}

/// شارة توضح قوة البيانات المستخدمة في الإحصائية.
///
/// مثال:
/// 3 عقارات   -> بيانات محدودة جدًا
/// 8 عقارات   -> بيانات محدودة
/// 25 عقارًا  -> بيانات متوسطة
/// 60 عقارًا  -> بيانات جيدة
/// 150 عقارًا -> بيانات قوية
class DataConfidenceBadge extends StatelessWidget {
  final int sampleSize;

  /// إذا كانت لدينا عينة مستقلة لسعر المتر يمكن تمريرها هنا.
  final int? pricePerSquareMeterSampleSize;

  /// إظهار وصف إضافي تحت الشارة.
  final bool showDescription;

  const DataConfidenceBadge({
    super.key,
    required this.sampleSize,
    this.pricePerSquareMeterSampleSize,
    this.showDescription = true,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _green = Color(0xFF22C55E);
  static const Color _orange = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFEF4444);
  static const Color _blue = Color(0xFF38BDF8);

  @override
  Widget build(BuildContext context) {
    final level = confidenceLevel(sampleSize);
    final color = _colorForLevel(level);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _titleForLevel(level),
                        style: TextStyle(
                          color: color,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _SampleBadge(
                      sampleSize: sampleSize,
                      color: color,
                    ),
                  ],
                ),
                if (showDescription) ...[
                  const SizedBox(height: 6),
                  Text(
                    _descriptionForLevel(level),
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.56,
                      ),
                      fontSize: StatisticsTextStyles.captionSize,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
                if (_shouldShowPricePerMeterNote) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.square_foot_rounded,
                        size: 14,
                        color: Colors.white.withValues(
                          alpha: 0.42,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'سعر المتر محسوب من '
                          '$pricePerSquareMeterSampleSize '
                          'من أصل $sampleSize عقار',
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: 0.42,
                            ),
                            fontSize: StatisticsTextStyles.captionSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        _iconForLevel(
          confidenceLevel(sampleSize),
        ),
        color: color,
        size: 19,
      ),
    );
  }

  bool get _shouldShowPricePerMeterNote {
    final count = pricePerSquareMeterSampleSize;

    if (count == null) {
      return false;
    }

    if (sampleSize <= 0 || count <= 0) {
      return false;
    }

    return count < sampleSize;
  }

  /// تحديد مستوى البيانات حسب حجم العينة.
  static DataConfidenceLevel confidenceLevel(
    int sampleSize,
  ) {
    if (sampleSize < 5) {
      return DataConfidenceLevel.veryLimited;
    }

    if (sampleSize < 15) {
      return DataConfidenceLevel.limited;
    }

    if (sampleSize < 40) {
      return DataConfidenceLevel.moderate;
    }

    if (sampleSize < 100) {
      return DataConfidenceLevel.good;
    }

    return DataConfidenceLevel.strong;
  }

  String _titleForLevel(
    DataConfidenceLevel level,
  ) {
    switch (level) {
      case DataConfidenceLevel.veryLimited:
        return 'بيانات محدودة جدًا';

      case DataConfidenceLevel.limited:
        return 'بيانات محدودة';

      case DataConfidenceLevel.moderate:
        return 'حجم بيانات متوسط';

      case DataConfidenceLevel.good:
        return 'حجم بيانات جيد';

      case DataConfidenceLevel.strong:
        return 'حجم بيانات قوي';
    }
  }

  String _descriptionForLevel(
    DataConfidenceLevel level,
  ) {
    switch (level) {
      case DataConfidenceLevel.veryLimited:
        return 'عدد العقارات قليل جدًا، لذلك ينبغي التعامل مع الأسعار المعروضة كمؤشر أولي للسوق.';

      case DataConfidenceLevel.limited:
        return 'تتوفر بيانات أولية، لكن زيادة عدد العقارات ستجعل قراءة السوق أكثر تمثيلًا.';

      case DataConfidenceLevel.moderate:
        return 'حجم العينة يسمح بتكوين صورة أفضل عن الأسعار، مع بقاء احتمال تأثر النتائج باختلاف العقارات.';

      case DataConfidenceLevel.good:
        return 'تستند الإحصائية إلى عدد جيد من العقارات ضمن الفلاتر المحددة.';

      case DataConfidenceLevel.strong:
        return 'تستند الإحصائية إلى حجم كبير نسبيًا من البيانات ضمن الفلاتر المحددة.';
    }
  }

  Color _colorForLevel(
    DataConfidenceLevel level,
  ) {
    switch (level) {
      case DataConfidenceLevel.veryLimited:
        return _red;

      case DataConfidenceLevel.limited:
        return _orange;

      case DataConfidenceLevel.moderate:
        return _gold;

      case DataConfidenceLevel.good:
        return _blue;

      case DataConfidenceLevel.strong:
        return _green;
    }
  }

  IconData _iconForLevel(
    DataConfidenceLevel level,
  ) {
    switch (level) {
      case DataConfidenceLevel.veryLimited:
        return Icons.warning_amber_rounded;

      case DataConfidenceLevel.limited:
        return Icons.info_outline_rounded;

      case DataConfidenceLevel.moderate:
        return Icons.analytics_outlined;

      case DataConfidenceLevel.good:
        return Icons.verified_outlined;

      case DataConfidenceLevel.strong:
        return Icons.verified_rounded;
    }
  }
}

class _SampleBadge extends StatelessWidget {
  final int sampleSize;
  final Color color;

  const _SampleBadge({
    required this.sampleSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        _sampleText,
        style: TextStyle(
          color: color,
          fontSize: StatisticsTextStyles.captionSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String get _sampleText {
    if (sampleSize <= 0) {
      return '0 عقار';
    }

    if (sampleSize == 1) {
      return 'عقار واحد';
    }

    if (sampleSize == 2) {
      return 'عقاران';
    }

    return '$sampleSize عقار';
  }
}
