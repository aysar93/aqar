import 'package:flutter/material.dart';

class NotificationPermissionSheet extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onLater;

  const NotificationPermissionSheet({
    super.key,
    required this.onEnable,
    required this.onLater,
  });

  static const Color gold = Color(0xFFD4AF37);
  static const Color dark = Color(0xFF0F172A);
  static const Color card = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Container(
        decoration: const BoxDecoration(
          color: card,
          borderRadius: BorderRadius.vertical(
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
                color: Colors.white24,
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

            const Text(
              'ابقَ على اطلاع',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'فعّل الإشعارات لتصلك تحديثات إعلاناتك، '
              'والرسائل، وأهم التنبيهات فور وصولها',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
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
                child: const Text(
                  'ليس الآن',
                  style: TextStyle(
                    color: Colors.white60,
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
                const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white38,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'يمكنك تغيير إعدادات الإشعارات لاحقًا',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
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
