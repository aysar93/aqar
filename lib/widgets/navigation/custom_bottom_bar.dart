import 'package:flutter/material.dart';

import 'bottom_nav_item.dart';
import 'add_property_button.dart';

class CustomBottomBar extends StatelessWidget {
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
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        color: Color(0xff1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: BottomNavItem(
              icon: Icons.home_rounded,
              label: "الرئيسية",
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: BottomNavItem(
              icon: Icons.favorite_rounded,
              label: "المفضلة",
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          Expanded(
            child: AddPropertyButton(
              onTap: onAddTap,
            ),
          ),
          Expanded(
            child: BottomNavItem(
              icon: Icons.notifications_rounded,
              label: "التنبيهات",
              selected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ),
          Expanded(
            child: BottomNavItem(
              icon: Icons.forum_rounded,
              label: "الدردشة",
              selected: currentIndex == 4,
              onTap: () => onTap(4),
            ),
          ),
        ],
      ),
    );
  }
}
