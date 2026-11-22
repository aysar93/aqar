import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/aqar_sizes.dart';
import '../../core/design/aqar_spacing.dart';
import '../../core/design/aqar_text.dart';
import '../../providers/app_settings_provider.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final String? photoUrl;
  final int notificationCount;
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationPressed;

  const HomeHeader({
    super.key,
    required this.userName,
    this.photoUrl,
    required this.notificationCount,
    required this.onMenuPressed,
    required this.onNotificationPressed,
  });

  static const Color _gold = Color(0xFFC5A16B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // On the golden header surface, dark navy provides high-contrast, premium readability in both themes
    const primaryTextColor = Color(0xFF0F172A);
    final secondaryTextColor = const Color(0xFF0F172A).withValues(alpha: .75);
    final badgeBorderColor = isDark ? const Color(0xff0F172A) : Colors.white;
    final buttonHeight = AqarSizes.headerButton(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // زر القائمة الجانبية المستقل بدون مفتاح الثيم
          _squareButton(
            context,
            icon: Icons.menu_rounded,
            color: const Color(0xFF0F172A),
            onTap: onMenuPressed,
          ),
          SizedBox(width: AqarSpacing.sm(context)),
          SizedBox(
            height: buttonHeight,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFD8BD95),
                      Color(0xFFC5A16B),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xffC5A16B),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: AqarSizes.avatarRadius(context),
                  backgroundColor: _gold,
                  backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(photoUrl!)
                      : null,
                  child: (photoUrl == null || photoUrl!.isEmpty)
                      ? Icon(
                          Icons.person,
                          color: Colors.black,
                          size: AqarSizes.avatarIcon(context),
                        )
                      : null,
                ),
              ),
            ),
          ),
          SizedBox(width: AqarSpacing.sm(context)),
          Expanded(
            child: SizedBox(
              height: buttonHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: userName == "مستخدم"
                    ? Text(
                        "مرحباً بك يا ضيف",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: AqarText.pageTitle(context),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "مرحباً بك",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: AqarText.small(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          SizedBox(width: AqarSpacing.sm(context)),
          // زر الإشعارات فقط (تمت إزالة زر الدردشة المكرر بالكامل)
          SizedBox(
            height: buttonHeight,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _squareButton(
                    context,
                    icon: Icons.notifications_none_rounded,
                    color: const Color(0xFF0F172A),
                    onTap: onNotificationPressed,
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: badgeBorderColor,
                            width: 2.5,
                          ),
                        ),
                        child: Text(
                          notificationCount > 9 ? "9+" : "$notificationCount",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _squareButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: const Color(0x33C5A16B),
        highlightColor: const Color(0x11C5A16B),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: AqarSizes.headerButton(context),
          height: AqarSizes.headerButton(context),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xff263548),
                      Color(0xff1E293B),
                    ]
                  : const [
                      Colors.white,
                      Color(0xFFF1F5F9),
                    ],
            ),
            border: Border.all(
              color: isDark ? const Color(0x35C5A16B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black26
                    : Colors.black.withValues(alpha: .04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: color,
              size: AqarSizes.headerIcon(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// مفتاح منزلق احترافي بشكل كبسولة (Pill Toggle) للتبديل بين الوضعين النهاري والليلي
class ThemePillToggle extends StatelessWidget {
  const ThemePillToggle({super.key});

  static const Color _gold = Color(0xFFC5A16B);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final isDark = settings.isDarkMode;

    return Semantics(
      label: isDark
          ? 'الوضع الداكن، اضغط للتبديل إلى الوضع النهاري'
          : 'الوضع النهاري، اضغط للتبديل إلى الوضع الداكن',
      button: true,
      child: GestureDetector(
        key: const ValueKey('home-header-theme-pill-toggle'),
        onTap: () => settings.toggleTheme(),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 44,
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            border: Border.all(
              color: isDark ? const Color(0x40C5A16B) : const Color(0xFFCBD5E1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black38
                    : Colors.black.withValues(alpha: .06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 1.5),
                    child: Icon(
                      Icons.wb_sunny_rounded,
                      size: 11,
                      color: isDark ? Colors.white30 : const Color(0xFFD97706),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 1.5),
                    child: Icon(
                      Icons.nightlight_round,
                      size: 11,
                      color: isDark ? _gold : Colors.black26,
                    ),
                  ),
                ],
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOut,
                alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFFD8BD95), Color(0xFFC5A16B)]
                          : const [Colors.white, Color(0xFFF8FAFC)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? const Color(0xFFC5A16B).withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      size: 10,
                      color: isDark ? Colors.black : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
