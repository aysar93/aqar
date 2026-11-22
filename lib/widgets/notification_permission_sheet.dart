import 'package:flutter/material.dart';

class NotificationPermissionSheet extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onLater;

  const NotificationPermissionSheet({
    super.key,
    required this.onEnable,
    required this.onLater,
  });

  static const Color gold = Color(0xFFC5A16B);
  static const Color dark = Color(0xFF0F172A);
  static const Color card = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? card : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(32),
          ),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // المقبض العلوي
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(20),
              ),
            ),

            const SizedBox(height: 28),

            // أيقونة الإشعارات
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: gold.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: gold,
                    size: 38,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'ابقَ على اطلاع',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'فعّل الإشعارات لتصلك تحديثات إعلاناتك، '
              'والرسائل، وأهم التنبيهات فور وصولها',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                fontSize: 15.5,
                height: 1.8,
              ),
            ),

            const SizedBox(height: 28),

            // زر التفعيل
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: onEnable,
                icon: const Icon(
                  Icons.notifications_rounded,
                  size: 22,
                ),
                label: const Text(
                  'تفعيل الإشعارات',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: dark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ليس الآن
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: onLater,
                child: Text(
                  'ليس الآن',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'يمكنك تغيير إعدادات الإشعارات لاحقًا',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
