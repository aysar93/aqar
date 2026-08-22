import 'package:flutter/material.dart';

/// واجهة التحميل الخاصة بإحصائيات السوق.
///
/// تعرض Skeleton قريبًا من شكل المحتوى الحقيقي
/// حتى لا تتغير بنية الصفحة بشكل مفاجئ بعد وصول البيانات.
class StatisticsLoading extends StatefulWidget {
  const StatisticsLoading({
    super.key,
  });

  @override
  State<StatisticsLoading> createState() => _StatisticsLoadingState();
}

class _StatisticsLoadingState extends State<StatisticsLoading>
    with SingleTickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);

  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ),
    );

    _animation = Tween<double>(
      begin: 0.30,
      end: 0.72,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.repeat(
      reverse: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSkeleton(),
            const SizedBox(height: 14),
            _buildFilterSkeleton(),
            const SizedBox(height: 14),
            _buildOverviewSkeleton(),
            const SizedBox(height: 14),
            _buildConfidenceSkeleton(),
            const SizedBox(height: 18),
            _buildSectionTitleSkeleton(
              width: 135,
            ),
            const SizedBox(height: 12),
            _buildMetricsSkeleton(),
            const SizedBox(height: 20),
            _buildSectionTitleSkeleton(
              width: 120,
            ),
            const SizedBox(height: 12),
            _buildChartSkeleton(),
            const SizedBox(height: 20),
            _buildSectionTitleSkeleton(
              width: 145,
            ),
            const SizedBox(height: 12),
            _buildAreaSkeleton(),
            const SizedBox(height: 12),
            _buildAreaSkeleton(),
          ],
        );
      },
    );
  }

  Widget _buildHeaderSkeleton() {
    return _SkeletonCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _box(
                width: 48,
                height: 48,
                radius: 15,
                gold: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(
                      width: 180,
                      height: 16,
                    ),
                    const SizedBox(height: 9),
                    _box(
                      width: double.infinity,
                      height: 10,
                    ),
                    const SizedBox(height: 6),
                    _box(
                      width: 190,
                      height: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _box(
            width: double.infinity,
            height: 1,
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _box(
                width: 90,
                height: 28,
                radius: 20,
              ),
              const SizedBox(width: 8),
              _box(
                width: 125,
                height: 28,
                radius: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSkeleton() {
    return _SkeletonCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _box(
            width: 42,
            height: 42,
            radius: 13,
            gold: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(
                  width: 120,
                  height: 12,
                ),
                const SizedBox(height: 8),
                _box(
                  width: 210,
                  height: 9,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _box(
            width: 30,
            height: 30,
            radius: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSkeleton() {
    return _SkeletonCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _box(
                width: 42,
                height: 42,
                radius: 13,
                gold: true,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(
                      width: 150,
                      height: 13,
                    ),
                    const SizedBox(height: 7),
                    _box(
                      width: 105,
                      height: 9,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          _box(
            width: 205,
            height: 27,
          ),
          const SizedBox(height: 8),
          _box(
            width: 75,
            height: 9,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _box(
                width: 82,
                height: 30,
                radius: 20,
                gold: true,
              ),
              const SizedBox(width: 10),
              _box(
                width: 145,
                height: 9,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _box(
            width: double.infinity,
            height: 1,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _box(
                  width: double.infinity,
                  height: 35,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _box(
                  width: double.infinity,
                  height: 35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceSkeleton() {
    return _SkeletonCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _box(
            width: 36,
            height: 36,
            radius: 11,
            gold: true,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _box(
                        width: 130,
                        height: 12,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _box(
                      width: 55,
                      height: 22,
                      radius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _box(
                  width: double.infinity,
                  height: 9,
                ),
                const SizedBox(height: 6),
                _box(
                  width: 210,
                  height: 9,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSkeleton() {
    return Row(
      children: [
        Expanded(
          child: _metricCardSkeleton(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCardSkeleton(),
        ),
      ],
    );
  }

  Widget _metricCardSkeleton() {
    return _SkeletonCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _box(
                width: 36,
                height: 36,
                radius: 11,
                gold: true,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _box(
                  width: double.infinity,
                  height: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _box(
            width: 110,
            height: 17,
          ),
          const SizedBox(height: 7),
          _box(
            width: 75,
            height: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildChartSkeleton() {
    return _SkeletonCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _box(
                width: 40,
                height: 40,
                radius: 12,
                gold: true,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(
                      width: 105,
                      height: 12,
                    ),
                    const SizedBox(height: 7),
                    _box(
                      width: 180,
                      height: 9,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 165,
            child: Stack(
              children: [
                for (var i = 0; i < 5; i++)
                  Positioned(
                    top: i * 38,
                    left: 0,
                    right: 0,
                    child: _box(
                      width: double.infinity,
                      height: 1,
                    ),
                  ),
                Positioned(
                  left: 8,
                  bottom: 25,
                  child: _box(
                    width: 55,
                    height: 55,
                    radius: 55,
                    gold: true,
                  ),
                ),
                Positioned(
                  left: 90,
                  bottom: 60,
                  child: _box(
                    width: 45,
                    height: 45,
                    radius: 45,
                    gold: true,
                  ),
                ),
                Positioned(
                  right: 55,
                  top: 25,
                  child: _box(
                    width: 50,
                    height: 50,
                    radius: 50,
                    gold: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaSkeleton() {
    return _SkeletonCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _box(
                width: 42,
                height: 42,
                radius: 13,
                gold: true,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(
                      width: 105,
                      height: 12,
                    ),
                    const SizedBox(height: 7),
                    _box(
                      width: 70,
                      height: 8,
                    ),
                  ],
                ),
              ),
              _box(
                width: 29,
                height: 29,
                radius: 30,
                gold: true,
              ),
            ],
          ),
          const SizedBox(height: 15),
          _box(
            width: double.infinity,
            height: 1,
          ),
          const SizedBox(height: 15),
          _box(
            width: 170,
            height: 20,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _box(
                  width: double.infinity,
                  height: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _box(
                  width: double.infinity,
                  height: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitleSkeleton({
    required double width,
  }) {
    return Row(
      children: [
        _box(
          width: 38,
          height: 38,
          radius: 12,
          gold: true,
        ),
        const SizedBox(width: 10),
        _box(
          width: width,
          height: 13,
        ),
      ],
    );
  }

  Widget _box({
    required double width,
    required double height,
    double radius = 7,
    bool gold = false,
  }) {
    final baseColor = gold ? _gold : Colors.white;

    return Opacity(
      opacity: _animation.value,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor.withValues(
            alpha: gold ? 0.12 : 0.085,
          ),
          borderRadius: BorderRadius.circular(
            radius,
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SkeletonCard({
    required this.child,
    required this.padding,
  });

  static const Color _cardColor = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.045,
          ),
        ),
      ),
      child: child,
    );
  }
}
