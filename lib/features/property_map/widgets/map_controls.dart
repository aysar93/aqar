import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final VoidCallback? onMyLocation;
  final VoidCallback? onResetMap;
  final VoidCallback? onRefresh;

  final bool isRefreshing;
  final bool myLocationEnabled;

  const MapControls({
    super.key,
    this.onMyLocation,
    this.onResetMap,
    this.onRefresh,
    this.isRefreshing = false,
    this.myLocationEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onMyLocation != null)
          _MapControlButton(
            icon: Icons.my_location_rounded,
            tooltip: 'موقعي',
            enabled: myLocationEnabled,
            onTap: onMyLocation!,
          ),
        if (onMyLocation != null) const SizedBox(height: 10),
        if (onResetMap != null)
          _MapControlButton(
            icon: Icons.map_rounded,
            tooltip: 'عرض الأنبار',
            onTap: onResetMap!,
          ),
        if (onResetMap != null && onRefresh != null) const SizedBox(height: 10),
        if (onRefresh != null)
          _MapControlButton(
            icon: Icons.refresh_rounded,
            tooltip: 'تحديث العقارات',
            isLoading: isRefreshing,
            onTap: onRefresh!,
          ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  final bool enabled;
  final bool isLoading;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && !isLoading ? onTap : null,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: onSurface.withValues(
                  alpha: 0.07,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.18,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFFC5A16B),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 23,
                      color: enabled
                          ? const Color(0xFFC5A16B)
                          : const Color(0xFF64748B),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
