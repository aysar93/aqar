import 'package:flutter/material.dart';

import '../../theme/statistics_text_styles.dart';

enum StatisticsEmptyStateType {
  noData,
  error,
  insufficientData,
}

class StatisticsEmptyState extends StatelessWidget {
  final StatisticsEmptyStateType type;

  /// عنوان مخصص اختياري.
  final String? title;

  /// وصف مخصص اختياري.
  final String? message;

  /// إعادة محاولة التحميل.
  final VoidCallback? onRetry;

  /// إعادة تعيين الفلاتر.
  final VoidCallback? onResetFilters;

  const StatisticsEmptyState({
    super.key,
    this.type = StatisticsEmptyStateType.noData,
    this.title,
    this.message,
    this.onRetry,
    this.onResetFilters,
  });

  /// حالة عدم وجود عقارات مطابقة.
  const StatisticsEmptyState.noData({
    super.key,
    this.title,
    this.message,
    this.onResetFilters,
  })  : type = StatisticsEmptyStateType.noData,
        onRetry = null;

  /// حالة حدوث خطأ.
  const StatisticsEmptyState.error({
    super.key,
    this.title,
    this.message,
    this.onRetry,
  })  : type = StatisticsEmptyStateType.error,
        onResetFilters = null;

  /// حالة وجود بيانات، لكن حجمها غير كافٍ.
  const StatisticsEmptyState.insufficientData({
    super.key,
    this.title,
    this.message,
    this.onResetFilters,
  })  : type = StatisticsEmptyStateType.insufficientData,
        onRetry = null;

  static const Color _background = Color(0xFF1E293B);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.08,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(accent),
          const SizedBox(height: 17),
          Text(
            title ?? _defaultTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: StatisticsTextStyles.sectionTitleSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? _defaultMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.52,
              ),
              fontSize: StatisticsTextStyles.secondarySize,
              fontWeight: FontWeight.w500,
              height: 1.65,
            ),
          ),
          if (_hasAction) ...[
            const SizedBox(height: 20),
            _buildActionButton(accent),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon(Color accent) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: accent.withValues(alpha: 0.15),
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.09),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _icon,
          color: accent,
          size: 25,
        ),
      ),
    );
  }

  Widget _buildActionButton(Color accent) {
    final callback = _actionCallback;

    if (callback == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: callback,
        icon: Icon(
          _actionIcon,
          size: 18,
        ),
        label: Text(
          _actionLabel,
          style: const TextStyle(
            fontSize: StatisticsTextStyles.sectionSubtitleSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: type == StatisticsEmptyStateType.error
              ? Colors.white
              : const Color(0xFF0F172A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  bool get _hasAction {
    switch (type) {
      case StatisticsEmptyStateType.error:
        return onRetry != null;

      case StatisticsEmptyStateType.noData:
      case StatisticsEmptyStateType.insufficientData:
        return onResetFilters != null;
    }
  }

  VoidCallback? get _actionCallback {
    switch (type) {
      case StatisticsEmptyStateType.error:
        return onRetry;

      case StatisticsEmptyStateType.noData:
      case StatisticsEmptyStateType.insufficientData:
        return onResetFilters;
    }
  }

  String get _actionLabel {
    switch (type) {
      case StatisticsEmptyStateType.error:
        return 'إعادة المحاولة';

      case StatisticsEmptyStateType.noData:
      case StatisticsEmptyStateType.insufficientData:
        return 'إعادة تعيين الفلاتر';
    }
  }

  IconData get _actionIcon {
    switch (type) {
      case StatisticsEmptyStateType.error:
        return Icons.refresh_rounded;

      case StatisticsEmptyStateType.noData:
      case StatisticsEmptyStateType.insufficientData:
        return Icons.filter_alt_off_outlined;
    }
  }

  String get _defaultTitle {
    switch (type) {
      case StatisticsEmptyStateType.noData:
        return 'لا توجد بيانات مطابقة';

      case StatisticsEmptyStateType.error:
        return 'تعذر تحميل الإحصائيات';

      case StatisticsEmptyStateType.insufficientData:
        return 'البيانات غير كافية';
    }
  }

  String get _defaultMessage {
    switch (type) {
      case StatisticsEmptyStateType.noData:
        return 'لم نجد عقارات مطابقة للفلاتر المحددة. جرّب تغيير المدينة أو المنطقة أو نوع العقار أو الفترة الزمنية.';

      case StatisticsEmptyStateType.error:
        return 'حدث خطأ أثناء قراءة بيانات السوق. تحقق من الاتصال بالإنترنت ثم حاول مرة أخرى.';

      case StatisticsEmptyStateType.insufficientData:
        return 'توجد بعض العقارات ضمن النتائج، لكن حجم البيانات الحالي لا يكفي لتقديم قراءة مفيدة للسوق. جرّب توسيع الفلاتر أو الفترة الزمنية.';
    }
  }

  IconData get _icon {
    switch (type) {
      case StatisticsEmptyStateType.noData:
        return Icons.search_off_rounded;

      case StatisticsEmptyStateType.error:
        return Icons.cloud_off_outlined;

      case StatisticsEmptyStateType.insufficientData:
        return Icons.analytics_outlined;
    }
  }

  Color get _accentColor {
    switch (type) {
      case StatisticsEmptyStateType.noData:
        return _gold;

      case StatisticsEmptyStateType.error:
        return _red;

      case StatisticsEmptyStateType.insufficientData:
        return _orange;
    }
  }
}
