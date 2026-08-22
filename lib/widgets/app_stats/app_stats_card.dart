import 'package:flutter/material.dart';

import '../../models/app_stats/app_stats.dart';
import '../../services/app_stats_service.dart';
import 'app_stat_item.dart';

class AppStatsCard extends StatefulWidget {
  final AppStatsService? service;

  const AppStatsCard({
    super.key,
    this.service,
  });

  @override
  State<AppStatsCard> createState() => _AppStatsCardState();
}

class _AppStatsCardState extends State<AppStatsCard> {
  late final AppStatsService _service;

  AppStats? _stats;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? AppStatsService();

    _loadStats();
  }

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final stats = await _service.getAppStats();

      if (!mounted) return;

      setState(() {
        _stats = stats;
        _isLoading = false;
        _errorMessage = null;
      });
    } on AppStatsException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل الإحصائيات حاليًا.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        height: 70,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF111827),
              Color(0xFF0F172A),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(
              alpha: 0.24,
            ),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.14,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // توهج ذهبي خفيف
            Positioned(
              top: -45,
              right: -30,
              child: IgnorePointer(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFD4AF37).withValues(
                          alpha: 0.08,
                        ),
                        const Color(0xFFD4AF37).withValues(
                          alpha: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 250,
                ),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const _StatsLoading(
        key: ValueKey('stats-loading'),
      );
    }

    if (_errorMessage != null) {
      return _StatsError(
        key: const ValueKey('stats-error'),
        message: _errorMessage!,
        onRetry: _loadStats,
      );
    }

    final stats = _stats;

    if (stats == null) {
      return _StatsError(
        key: const ValueKey('stats-empty'),
        message: 'لا تتوفر الإحصائيات حاليًا',
        onRetry: _loadStats,
      );
    }

    return _StatsData(
      key: ValueKey(
        'stats-${stats.propertiesCount}-${stats.usersCount}',
      ),
      stats: stats,
    );
  }
}

// ============================================================================
// Stats
// ============================================================================

class _StatsData extends StatelessWidget {
  final AppStats stats;

  const _StatsData({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // العقارات
        Expanded(
          child: AppStatItem(
            icon: Icons.home_work_rounded,
            value: stats.propertiesCount,
            label: 'عقار',
            iconContainerSize: 27,
            iconSize: 14,
            valueFontSize: 16,
            labelFontSize: 9.5,
            iconValueSpacing: 3,
            valueLabelSpacing: 2,
          ),
        ),

        // الفاصل
        Container(
          width: 1,
          height: 43,
          margin: const EdgeInsets.symmetric(
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFD4AF37).withValues(
                  alpha: 0,
                ),
                const Color(0xFFD4AF37).withValues(
                  alpha: 0.30,
                ),
                const Color(0xFFD4AF37).withValues(
                  alpha: 0,
                ),
              ],
            ),
          ),
        ),

        // المستخدمون
        Expanded(
          child: AppStatItem(
            icon: Icons.people_alt_rounded,
            value: stats.usersCount,
            label: 'مستخدم',
            iconContainerSize: 27,
            iconSize: 14,
            valueFontSize: 16,
            labelFontSize: 9.5,
            iconValueSpacing: 3,
            valueLabelSpacing: 2,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Loading
// ============================================================================

class _StatsLoading extends StatelessWidget {
  const _StatsLoading({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 19,
        height: 19,
        child: CircularProgressIndicator(
          strokeWidth: 1.8,
          color: Color(0xFFD4AF37),
        ),
      ),
    );
  }
}

// ============================================================================
// Error
// ============================================================================

class _StatsError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _StatsError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD4AF37).withValues(
              alpha: 0.08,
            ),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(
                alpha: 0.18,
              ),
              width: 0.8,
            ),
          ),
          child: const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFD4AF37),
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.70,
              ),
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          height: 30,
          child: IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            tooltip: 'إعادة المحاولة',
            onPressed: () {
              onRetry();
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFD4AF37),
              size: 17,
            ),
          ),
        ),
      ],
    );
  }
}
