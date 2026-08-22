import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/statistics_text_styles.dart';
import '../../models/statistics/price_history_point.dart';

/// مخطط حركة أسعار العقارات عبر الزمن.
///
/// يعتمد على CustomPainter من Flutter مباشرة،
/// لذلك لا يحتاج إلى أي package إضافية.
///
/// يعرض:
/// - متوسط السعر لكل نقطة زمنية.
/// - اتجاه حركة السعر.
/// - أعلى وأقل قيمة.
/// - تاريخ البداية والنهاية.
/// - تفاصيل النقطة عند الضغط عليها.
class PriceTrendChart extends StatefulWidget {
  final List<PriceHistoryPoint> points;

  /// ارتفاع منطقة الرسم نفسها.
  final double chartHeight;

  const PriceTrendChart({
    super.key,
    required this.points,
    this.chartHeight = 190,
  });

  @override
  State<PriceTrendChart> createState() => _PriceTrendChartState();
}

class _PriceTrendChartState extends State<PriceTrendChart> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardColor = Color(0xFF1E293B);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);

  int? _selectedIndex;

  List<PriceHistoryPoint> get _points {
    final values = widget.points
        .where((point) => point.averagePrice.isFinite)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return values;
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;

    if (points.isEmpty || !points.any((point) => point.hasData)) {
      return _buildEmptyState();
    }

    final selectedIndex = _safeSelectedIndex(points.length);

    final selectedPoint =
        selectedIndex == null || !points[selectedIndex].hasData
            ? null
            : points[selectedIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(points),
          const SizedBox(height: 18),
          if (selectedPoint != null) ...[
            _SelectedPointCard(point: selectedPoint),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: widget.chartHeight,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _selectNearestPoint(
                      localPosition: details.localPosition,
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      pointCount: points.length,
                    );
                  },
                  onHorizontalDragUpdate: (details) {
                    _selectNearestPoint(
                      localPosition: details.localPosition,
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      pointCount: points.length,
                    );
                  },
                  child: CustomPaint(
                    painter: _PriceTrendPainter(
                      points: points,
                      selectedIndex: selectedIndex,
                    ),
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildDateLabels(points),
          if (points.any((point) => !point.hasData)) ...[
            const SizedBox(height: 10),
            Text(
              'الفجوات في الخط تمثل فترات لا تحتوي على بيانات كافية، ولا يتم وصلها حتى لا يظهر اتجاه مضلل.',
              style: StatisticsTextStyles.caption,
            ),
          ],
          const SizedBox(height: 14),
          _buildFooter(points),
        ],
      ),
    );
  }

  Widget _buildHeader(List<PriceHistoryPoint> points) {
    final dataPoints = points.where((point) => point.hasData).toList();
    final first = dataPoints.first.averagePrice;
    final last = dataPoints.last.averagePrice;

    final change = first > 0 ? ((last - first) / first) * 100 : 0.0;

    final increasing = change > 0;
    final decreasing = change < 0;

    final trendColor = increasing
        ? _green
        : decreasing
            ? _red
            : _gold;

    final trendIcon = increasing
        ? Icons.trending_up_rounded
        : decreasing
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.show_chart_rounded, color: _gold, size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'حركة الأسعار',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: StatisticsTextStyles.sectionTitleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'متوسط سعر العقارات خلال الفترة المحددة',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: StatisticsTextStyles.captionSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (dataPoints.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: trendColor.withValues(alpha: 0.20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trendIcon, size: 15, color: trendColor),
                const SizedBox(width: 4),
                Text(
                  '${change.abs().toStringAsFixed(1)}%',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: StatisticsTextStyles.captionSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDateLabels(List<PriceHistoryPoint> points) {
    if (points.length == 1) {
      return Center(
        child: Text(
          _formatDate(points.first.date),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: StatisticsTextStyles.captionSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Row(
      children: [
        Text(
          _formatDate(points.first.date),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: StatisticsTextStyles.captionSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          _formatDate(points.last.date),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: StatisticsTextStyles.captionSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(List<PriceHistoryPoint> points) {
    final values = points
        .where((point) => point.hasData)
        .map((point) => point.averagePrice)
        .toList();

    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ChartMetric(
              title: 'أعلى متوسط',
              value: _compactPrice(maximum),
              icon: Icons.arrow_upward_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withValues(alpha: 0.06),
          ),
          Expanded(
            child: _ChartMetric(
              title: 'أقل متوسط',
              value: _compactPrice(minimum),
              icon: Icons.arrow_downward_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.show_chart_rounded,
              color: _gold.withValues(alpha: 0.65),
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا تتوفر حركة أسعار',
            style: TextStyle(
              color: Colors.white,
              fontSize: StatisticsTextStyles.cardTitleSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'لا توجد بيانات زمنية كافية لإنشاء المخطط ضمن الفلاتر الحالية',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: StatisticsTextStyles.captionSize,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  int? _safeSelectedIndex(int length) {
    if (_selectedIndex == null ||
        length <= 0 ||
        _selectedIndex! < 0 ||
        _selectedIndex! >= length) {
      return null;
    }

    return _selectedIndex;
  }

  void _selectNearestPoint({
    required Offset localPosition,
    required Size size,
    required int pointCount,
  }) {
    if (pointCount <= 0 || size.width <= 0 || size.height <= 0) {
      return;
    }

    int index;

    if (pointCount == 1) {
      index = 0;
    } else {
      const horizontalPadding = 10.0;

      final drawableWidth = math.max(1.0, size.width - (horizontalPadding * 2));

      final x = (localPosition.dx - horizontalPadding).clamp(
        0.0,
        drawableWidth,
      );

      index = ((x / drawableWidth) * (pointCount - 1)).round().clamp(
            0,
            pointCount - 1,
          );
    }

    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _compactPrice(double value) {
    if (value <= 0) {
      return '0 د.ع';
    }

    if (value >= 1000000000) {
      return '${_compactNumber(value / 1000000000)} مليار';
    }

    if (value >= 1000000) {
      return '${_compactNumber(value / 1000000)} مليون';
    }

    if (value >= 1000) {
      return '${_compactNumber(value / 1000)} ألف';
    }

    return '${value.round()} د.ع';
  }

  static String _compactNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }
}

class _SelectedPointCard extends StatelessWidget {
  final PriceHistoryPoint point;

  const _SelectedPointCard({required this.point});

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _gold.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, color: _gold, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(point.date),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: StatisticsTextStyles.captionSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatFullPrice(point.averagePrice)} د.ع',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: StatisticsTextStyles.bodySize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${point.propertyCount} عقار',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: StatisticsTextStyles.captionSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatFullPrice(double value) {
    if (value <= 0) {
      return '0';
    }

    final digits = value.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);

      final remaining = digits.length - i - 1;

      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }
}

class _ChartMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ChartMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: StatisticsTextStyles.captionSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: StatisticsTextStyles.secondarySize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceTrendPainter extends CustomPainter {
  final List<PriceHistoryPoint> points;
  final int? selectedIndex;

  const _PriceTrendPainter({required this.points, required this.selectedIndex});

  static const Color _gold = Color(0xFFD4AF37);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    const horizontalPadding = 10.0;
    const verticalPadding = 12.0;

    final chartWidth = math.max(1.0, size.width - (horizontalPadding * 2));

    final chartHeight = math.max(1.0, size.height - (verticalPadding * 2));

    final values = points
        .where((point) => point.hasData)
        .map((point) => point.averagePrice)
        .toList();

    var minimum = values.reduce(math.min);
    var maximum = values.reduce(math.max);

    if (minimum == maximum) {
      final padding = maximum == 0 ? 1.0 : maximum.abs() * 0.05;

      minimum -= padding;
      maximum += padding;
    } else {
      final range = maximum - minimum;
      final padding = range * 0.10;

      minimum -= padding;
      maximum += padding;
    }

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = verticalPadding + (chartHeight / 4) * i;

      canvas.drawLine(
        Offset(horizontalPadding, y),
        Offset(size.width - horizontalPadding, y),
        gridPaint,
      );
    }

    final offsets = <Offset?>[];

    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : horizontalPadding + (chartWidth * i / (points.length - 1));

      if (!points[i].hasData) {
        offsets.add(null);
        continue;
      }

      final normalized =
          (points[i].averagePrice - minimum) / (maximum - minimum);

      final y = verticalPadding + chartHeight - (normalized * chartHeight);

      offsets.add(Offset(x, y));
    }

    final dataOffsets = offsets.whereType<Offset>().toList();
    if (dataOffsets.isEmpty) {
      return;
    }

    final linePath = Path();
    var startsNewSegment = true;
    for (final offset in offsets) {
      if (offset == null) {
        startsNewSegment = true;
        continue;
      }
      if (startsNewSegment) {
        linePath.moveTo(offset.dx, offset.dy);
        startsNewSegment = false;
      } else {
        linePath.lineTo(offset.dx, offset.dy);
      }
    }

    final linePaint = Paint()
      ..color = _gold
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(linePath, linePaint);

    final pointPaint = Paint()
      ..color = _gold
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < offsets.length; i++) {
      final offset = offsets[i];
      if (offset == null) continue;
      final selected = selectedIndex == i;

      if (selected) {
        final selectedLinePaint = Paint()
          ..color = _gold.withValues(alpha: 0.22)
          ..strokeWidth = 1;

        canvas.drawLine(
          Offset(offset.dx, verticalPadding),
          Offset(offset.dx, size.height - verticalPadding),
          selectedLinePaint,
        );

        final haloPaint = Paint()
          ..color = _gold.withValues(alpha: 0.13)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(offset, 10, haloPaint);
      }

      canvas.drawCircle(offset, selected ? 5.5 : 3.5, pointPaint);

      canvas.drawCircle(offset, selected ? 5.5 : 3.5, pointBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PriceTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
