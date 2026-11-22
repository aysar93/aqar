import 'package:flutter/material.dart';

import '../../theme/statistics_text_styles.dart';

class StatisticsHeader extends StatelessWidget {
  final int propertyCount;
  final DateTime? generatedAt;

  const StatisticsHeader({
    super.key,
    required this.propertyCount,
    this.generatedAt,
  });

  static const Color _gold = Color(0xFFC5A16B);
  static const Color _cardColor = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _cardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _gold.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إحصائيات السوق العقاري',
                      style: StatisticsTextStyles.pageTitle.copyWith(
                        color: onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'تحليل أسعار العقارات اعتمادًا على بيانات السوق المنشورة في التطبيق',
                      style: StatisticsTextStyles.pageSubtitle.copyWith(
                        color: onSurface.withValues(
                          alpha: 0.65,
                        ),
                        fontSize: 12.5,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: onSurface.withValues(
              alpha: 0.07,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.home_work_outlined,
                text: _propertyCountText,
              ),
              if (generatedAt != null)
                _InfoChip(
                  icon: Icons.update_rounded,
                  text: 'آخر تحديث ${_formatUpdateTime(generatedAt!)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _gold.withValues(alpha: 0.28),
        ),
      ),
      child: const Icon(
        Icons.analytics_outlined,
        color: _gold,
        size: 26,
      ),
    );
  }

  String get _propertyCountText {
    if (propertyCount <= 0) {
      return 'لا توجد عقارات';
    }

    if (propertyCount == 1) {
      return 'عقار واحد';
    }

    if (propertyCount == 2) {
      return 'عقاران';
    }

    return '$propertyCount عقار';
  }

  String _formatUpdateTime(DateTime date) {
    final now = DateTime.now();

    final sameDay =
        now.year == date.year && now.month == date.month && now.day == date.day;

    if (sameDay) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return 'اليوم $hour:$minute';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  static const Color _gold = Color(0xFFC5A16B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: onSurface.withValues(
          alpha: 0.055,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: onSurface.withValues(
            alpha: 0.07,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: _gold,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: StatisticsTextStyles.chip.copyWith(
              color: onSurface.withValues(
                alpha: 0.75,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
