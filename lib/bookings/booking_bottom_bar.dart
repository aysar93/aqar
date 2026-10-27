import 'package:flutter/material.dart';
import 'booking_widgets.dart';

/// Independent bottom navigation bar for the Bookings ecosystem.
/// Strictly presents the 5 required tabs in exact order:
/// 0: استكشف (Explore)
/// 1: بحث (Search)
/// 2: ريلز (Reels)
/// 3: حجوزاتي (My Bookings)
/// 4: حسابي (My Account)
class BookingBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? pendingBookingsCount;
  final bool hasReelsBadge;

  const BookingBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.pendingBookingsCount,
    this.hasReelsBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navBackground = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final selectedColor = bookingGold;
    final unselectedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final items = <_BookingNavItem>[
      const _BookingNavItem(
        label: 'استكشف',
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
      ),
      const _BookingNavItem(
        label: 'بحث',
        icon: Icons.search_outlined,
        activeIcon: Icons.saved_search,
      ),
      _BookingNavItem(
        label: 'ريلز',
        icon: Icons.play_circle_outline_rounded,
        activeIcon: Icons.play_circle_fill_rounded,
        badge: hasReelsBadge,
      ),
      _BookingNavItem(
        label: 'حجوزاتي',
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_month,
        badgeCount: pendingBookingsCount,
      ),
      const _BookingNavItem(
        label: 'حسابي',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: navBackground,
        border: Border(
          top: BorderSide(color: borderColor, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;
              return Expanded(
                child: Semantics(
                  selected: isSelected,
                  button: true,
                  label: item.label,
                  child: InkWell(
                    onTap: () => onTap(index),
                    splashColor: bookingGold.withValues(alpha: 0.15),
                    highlightColor: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? bookingGold.withValues(alpha: isDark ? 0.22 : 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: 24,
                                color: isSelected ? selectedColor : unselectedColor,
                              ),
                            ),
                            if (item.badgeCount != null && item.badgeCount! > 0)
                              Positioned(
                                top: -2,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    item.badgeCount! > 9 ? '+9' : '${item.badgeCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      height: 1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else if (item.badge)
                              Positioned(
                                top: 2,
                                right: 10,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: bookingGold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Cairo',
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? selectedColor : unselectedColor,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BookingNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool badge;
  final int? badgeCount;

  const _BookingNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge = false,
    this.badgeCount,
  });
}
