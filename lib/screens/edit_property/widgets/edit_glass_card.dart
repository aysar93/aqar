import 'package:flutter/material.dart';

class EditGlassCard extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  const EditGlassCard({
    super.key,
    required this.child,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 220,
          ),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xffC5A16B).withValues(alpha: .12)
                : (isDark ? const Color(0xff1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? const Color(0xffC5A16B)
                  : onSurface.withValues(alpha: 0.10),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xffC5A16B).withValues(alpha: .18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? .15 : .06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
              if (selected)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xffC5A16B),
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
