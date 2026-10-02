import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/analytics_models.dart';

class AnalyticsStatCard extends StatelessWidget {
  const AnalyticsStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.onTap,
  });
  final String title, value;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 22),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(value,
                      maxLines: 1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          height: 1.2,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textGrey, fontSize: 13)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ],
            ),
          ),
        ),
      );
}

class PeriodSelector extends StatelessWidget {
  const PeriodSelector(
      {super.key, required this.value, required this.onChanged});
  final AnalyticsPeriod value;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: AnalyticsPeriod.values.map((period) {
            final selected = period == value;
            return Expanded(
              child: Material(
                color: selected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (!selected) onChanged(period);
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Text(period.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.backgroundColor
                              : AppTheme.textGrey,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

class VisitsBars extends StatelessWidget {
  const VisitsBars({super.key, required this.points});
  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 110,
        child: Center(
            child: Text('لا توجد جلسات مسجلة خلال الفترة',
                style: TextStyle(color: Colors.white54))),
      );
    }
    final maximum =
        points.map((point) => point.value).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: points.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final point = points[index];
          return SizedBox(
            width: 42,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${point.value}',
                    style: const TextStyle(
                        color: AppTheme.textGrey, fontSize: 11)),
                const SizedBox(height: 8),
                Container(
                  width: 24,
                  height: 90 * point.value / (maximum == 0 ? 1 : maximum),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(point.label,
                    maxLines: 1,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );
  }
}
