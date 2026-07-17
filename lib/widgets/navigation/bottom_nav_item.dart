import 'package:flutter/material.dart';

class BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const BottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 70,
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [

              AnimatedContainer(
                duration:
                    const Duration(milliseconds: 250),

                padding:
                    const EdgeInsets.all(6),

                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xffD4AF37)
                          .withValues(alpha: 0.15)
                      : Colors.transparent,

                  borderRadius:
                      BorderRadius.circular(14),
                ),

                child: Icon(
                  icon,

                  size: 28,

                  color: selected
                      ? const Color(0xffD4AF37)
                      : Colors.white70,
                ),
              ),


              const SizedBox(height: 4),


              Text(
                label,

                style: TextStyle(
                  color: selected
                      ? const Color(0xffD4AF37)
                      : Colors.white70,

                  fontSize: 12,

                  fontWeight:
                      selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}