import 'package:flutter/material.dart';

class MapEmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback? onClearFilters;
  final VoidCallback? onRefresh;

  const MapEmptyState({
    super.key,
    this.hasFilters = false,
    this.onClearFilters,
    this.onRefresh,
  });

  static const Color _gold = Color(0xFFC5A16B);
  static const Color _card = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 320,
        ),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: (isDark ? _card : Colors.white).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: onSurface.withValues(
              alpha: 0.06,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.18,
              ),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? Icons.filter_alt_off_rounded
                    : Icons.location_off_rounded,
                color: _gold,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'لا توجد عقارات مطابقة'
                  : 'لا توجد عقارات على الخريطة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              hasFilters
                  ? 'جرّب تغيير الفلاتر أو توسيع نطاق البحث.'
                  : 'لا توجد عقارات بمواقع جغرافية متاحة حاليًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            if (hasFilters && onClearFilters != null)
              _ActionButton(
                icon: Icons.restart_alt_rounded,
                label: 'مسح الفلاتر',
                onPressed: onClearFilters!,
              )
            else if (onRefresh != null)
              _ActionButton(
                icon: Icons.refresh_rounded,
                label: 'تحديث',
                onPressed: onRefresh!,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFC5A16B),
          foregroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        icon: Icon(
          icon,
          size: 19,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
