import 'package:flutter/material.dart';

/// عرض تقييم المكتب.
///
/// يدعم:
/// - متوسط التقييم.
/// - عدد المراجعات.
/// - النجوم.
/// - التقييمات التفصيلية من 1 إلى 5.
/// - الضغط على التقييمات عند الحاجة.
class OfficeRating extends StatelessWidget {
  final double rating;
  final int reviewCount;

  /// توزيع التقييمات:
  ///
  /// المفتاح = عدد النجوم
  /// القيمة = عدد المراجعات
  ///
  /// مثال:
  /// {
  ///   5: 20,
  ///   4: 8,
  ///   3: 2,
  ///   2: 0,
  ///   1: 1,
  /// }
  final Map<int, int> ratingDistribution;

  final VoidCallback? onReviewsTap;

  /// حجم النجمة.
  final double starSize;

  const OfficeRating({
    super.key,
    this.rating = 0,
    this.reviewCount = 0,
    this.ratingDistribution = const <int, int>{},
    this.onReviewsTap,
    this.starSize = 19,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedRating = _normalizedRating;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTitle(context),
          const SizedBox(height: 16),
          _buildRatingSummary(
            context,
            normalizedRating,
          ),
          if (_hasDistribution) ...[
            const SizedBox(height: 18),
            _buildDistribution(
              context,
            ),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // العنوان
  // ═════════════════════════════════════════════

  Widget _buildTitle(
    BuildContext context,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'تقييم المكتب',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.star_rounded,
            size: 20,
            color: Color(0xFFD4AF37),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // ملخص التقييم
  // ═════════════════════════════════════════════

  Widget _buildRatingSummary(
    BuildContext context,
    double normalizedRating,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                normalizedRating.toStringAsFixed(1),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(height: 5),
              _buildStars(
                context,
                normalizedRating,
              ),
              const SizedBox(height: 5),
              InkWell(
                onTap: onReviewsTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  child: Text(
                    '$reviewCount مراجعة',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        _buildRatingCircle(
          context,
          normalizedRating,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // دائرة التقييم
  // ═════════════════════════════════════════════

  Widget _buildRatingCircle(
    BuildContext context,
    double rating,
  ) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.55),
          width: 2,
        ),
        color: const Color(0xFFD4AF37).withValues(alpha: 0.06),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.star_rounded,
            color: Color(0xFFD4AF37),
            size: 27,
          ),
          const SizedBox(height: 2),
          Text(
            rating.toStringAsFixed(1),
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // النجوم
  // ═════════════════════════════════════════════

  Widget _buildStars(
    BuildContext context,
    double rating,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) {
          final starNumber = index + 1;

          IconData icon;

          if (rating >= starNumber) {
            icon = Icons.star_rounded;
          } else if (rating >= starNumber - 0.5) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_border_rounded;
          }

          return Icon(
            icon,
            size: starSize,
            color: const Color(0xFFD4AF37),
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════
  // توزيع التقييمات
  // ═════════════════════════════════════════════

  Widget _buildDistribution(
    BuildContext context,
  ) {
    final total = _distributionTotal;

    return Column(
      children: List.generate(
        5,
        (index) {
          final stars = 5 - index;

          final count = ratingDistribution[stars] ?? 0;

          final percentage = total <= 0 ? 0.0 : count / total;

          return Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$stars',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: Color(0xFFD4AF37),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildProgressBar(
                    context,
                    percentage,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    count.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════
  // شريط النسبة
  // ═════════════════════════════════════════════

  Widget _buildProgressBar(
    BuildContext context,
    double value,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        minHeight: 7,
        value: value.clamp(0.0, 1.0),
        backgroundColor: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.25),
        valueColor: const AlwaysStoppedAnimation<Color>(
          Color(0xFFD4AF37),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // القيم المساعدة
  // ═════════════════════════════════════════════

  double get _normalizedRating {
    if (rating.isNaN || rating.isInfinite) {
      return 0;
    }

    return rating.clamp(0.0, 5.0);
  }

  bool get _hasDistribution {
    return ratingDistribution.isNotEmpty;
  }

  int get _distributionTotal {
    return ratingDistribution.values.fold(
      0,
      (total, value) => total + (value < 0 ? 0 : value),
    );
  }
}
