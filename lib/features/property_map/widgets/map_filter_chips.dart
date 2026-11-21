import 'package:flutter/material.dart';

class MapFilterChips extends StatelessWidget {
  final String? selectedPropertyType;
  final ValueChanged<String?> onChanged;

  final List<String> propertyTypes;

  const MapFilterChips({
    super.key,
    required this.selectedPropertyType,
    required this.onChanged,
    this.propertyTypes = const [
      'بيت',
      'أرض',
      'شقة',
      'محل',
      'عمارة',
      'مزرعة',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: propertyTypes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _TypeChip(
              label: 'الكل',
              selected: selectedPropertyType == null,
              onTap: () => onChanged(null),
            );
          }

          final type = propertyTypes[index - 1];

          return _TypeChip(
            label: type,
            selected: selectedPropertyType == type,
            onTap: () => onChanged(type),
          );
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
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
        borderRadius: BorderRadius.circular(50),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFC5A16B)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC5A16B)
                  : onSurface.withValues(
                      alpha: 0.08,
                    ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF0F172A) : onSurface,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
