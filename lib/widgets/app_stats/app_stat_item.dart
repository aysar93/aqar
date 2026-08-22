import 'package:flutter/material.dart';

class AppStatItem extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  final Color color;
  final Duration animationDuration;

  final double iconSize;
  final double iconContainerSize;
  final double valueFontSize;
  final double labelFontSize;

  final double iconValueSpacing;
  final double valueLabelSpacing;

  const AppStatItem({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = const Color(0xFFD4AF37),
    this.animationDuration = const Duration(milliseconds: 1100),

    // أحجام Compact
    this.iconSize = 14,
    this.iconContainerSize = 28,
    this.valueFontSize = 16,
    this.labelFontSize = 9.5,
    this.iconValueSpacing = 3,
    this.valueLabelSpacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(),
          SizedBox(height: iconValueSpacing),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: value.toDouble(),
            ),
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) {
              return Text(
                _formatNumber(animatedValue.round()),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: color,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                  fontFeatures: const [
                    FontFeature.tabularFigures(),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: valueLabelSpacing),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: labelFontSize,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: iconContainerSize,
      height: iconContainerSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.10),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: color,
      ),
    );
  }

  String _formatNumber(int number) {
    final value = number.abs().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(value[i]);
    }

    return number < 0 ? '-$buffer' : buffer.toString();
  }
}
