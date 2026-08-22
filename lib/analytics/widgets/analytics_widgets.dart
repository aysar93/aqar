import 'package:flutter/material.dart';
import '../models/analytics_models.dart';

class AnalyticsStatCard extends StatelessWidget {
  const AnalyticsStatCard(
      {super.key,
      required this.title,
      required this.value,
      required this.icon,
      required this.color,
      this.onTap});
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                      backgroundColor: color.withValues(alpha: .15),
                      child: Icon(icon, color: color)),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(title,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              )),
        ),
      );
}

class PeriodSelector extends StatelessWidget {
  const PeriodSelector(
      {super.key, required this.value, required this.onChanged});
  final AnalyticsPeriod value;
  final ValueChanged<AnalyticsPeriod> onChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<AnalyticsPeriod>(
          segments: AnalyticsPeriod.values
              .map((p) => ButtonSegment(value: p, label: Text(p.label)))
              .toList(),
          selected: {value},
          onSelectionChanged: (v) => onChanged(v.first),
          showSelectedIcon: false,
          style: const ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(Colors.white)),
        ),
      );
}

class VisitsBars extends StatelessWidget {
  const VisitsBars({super.key, required this.points});
  final List<ChartPoint> points;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty)
      return const SizedBox(
          height: 130,
          child: Center(
              child: Text('لا توجد زيارات في هذه الفترة',
                  style: TextStyle(color: Colors.white54))));
    final max = points.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return SizedBox(
        height: 170,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          reverse: true,
          itemCount: points.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final point = points[i];
            return SizedBox(
                width: 38,
                child:
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${point.value}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 5),
                  Container(
                      width: 24,
                      height: 100 * point.value / (max == 0 ? 1 : max),
                      decoration: BoxDecoration(
                          color: const Color(0xffD4AF37),
                          borderRadius: BorderRadius.circular(7))),
                  const SizedBox(height: 7),
                  Text(point.label,
                      maxLines: 1,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 10))
                ]));
          },
        ));
  }
}
