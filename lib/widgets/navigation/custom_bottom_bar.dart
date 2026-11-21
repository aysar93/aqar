import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'bottom_nav_item.dart';
import 'add_property_button.dart';

class CustomBottomBar extends StatelessWidget {
  static const double height = 82;
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onAddTap;

  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? MediaQuery.paddingOf(context).bottom
            : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final barHeight = isLandscape ? 58.0 : height;
    return Container(
      height: barHeight + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLandscape ? 18 : 28),
          topRight: Radius.circular(isLandscape ? 18 : 28),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: BottomNavItem(
              icon: currentIndex == 4
                  ? Icons.calendar_month_rounded
                  : Icons.calendar_month_outlined,
              label: "الحجوزات",
              selected: currentIndex == 4,
              onTap: () => onTap(4),
            ),
          ),
          Expanded(
            child: BottomNavItem(
              icon: currentIndex == 3
                  ? Icons.video_collection_rounded
                  : Icons.video_collection_outlined,
              label: "الريلز",
              selected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ),
          Expanded(
            child: AddPropertyButton(
              onTap: onAddTap,
            ),
          ),
          Expanded(
            child: BottomNavItem(
              icon: currentIndex == 1
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              label: "المفضلة",
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          Expanded(
            child: BottomNavItem(
              icon: currentIndex == 0
                  ? Icons.home_rounded
                  : Icons.home_outlined,
              label: "الرئيسية",
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
        ],
      ),
    );
  }
}
