import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),

        color: const Color(0xFF1E293B),

        border: Border.all(
          color: selected
              ? const Color(0xFFD4AF37)
              : Colors.white12,
          width: selected ? 2 : 1,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),

          if (selected)
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: .25),
              blurRadius: 35,
              spreadRadius: 2,
            ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,

          child: Padding(
            padding: const EdgeInsets.all(22),
            child: child,
          ),
        ),
      ),
    );
  }
}