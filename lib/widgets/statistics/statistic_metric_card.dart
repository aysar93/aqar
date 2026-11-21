import 'package:flutter/material.dart';
import '../../theme/statistics_text_styles.dart';

/// بطاقة صغيرة لعرض مؤشر واحد من مؤشرات السوق.
///
/// أمثلة:
/// - عدد العقارات
/// - الوسيط
/// - أعلى سعر
/// - أقل سعر
/// - متوسط سعر المتر
class StatisticMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  /// وصف اختياري أسفل القيمة.
  final String? subtitle;

  /// لون مخصص للأيقونة.
  ///
  /// إذا لم يتم تحديده يستخدم اللون الذهبي.
  final Color? accentColor;

  /// هل البطاقة في حالة مميزة؟
  ///
  /// تستخدم لاحقًا إذا أردنا إبراز مؤشر معين.
  final bool highlighted;

  const StatisticMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accentColor,
    this.highlighted = false,
  });

  static const Color _gold = Color(0xFFC5A16B);
  static const Color _cardColor = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final accent = accentColor ?? _gold;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? _cardColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? accent.withValues(alpha: 0.32)
              : onSurface.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.20),
                  ),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onSurface.withValues(
                      alpha: 0.62,
                    ),
                    fontSize: StatisticsTextStyles.sectionSubtitleSize,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onSurface,
                fontSize: StatisticsTextStyles.metricSize,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onSurface.withValues(
                  alpha: 0.42,
                ),
                fontSize: StatisticsTextStyles.secondarySize,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
