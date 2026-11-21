import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  final String selectedFilter;

  final Function(String) onChanged;

  const FilterBar({
    super.key,
    required this.selectedFilter,
    required this.onChanged,
  });

  final List<String> filters = const [
    "الكل",
    "pending",
    "approved",
    "rejected",
  ];

  String filterName(String value) {
    switch (value) {
      case "pending":
        return "قيد الانتظار";

      case "approved":
        return "مقبول";

      case "rejected":
        return "مرفوض";

      default:
        return "الكل";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: 45,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          itemBuilder: (context, index) {
            final filter = filters[index];

            final selected = selectedFilter == filter;

            return GestureDetector(
              onTap: () {
                onChanged(filter);
              },
              child: Container(
                margin: const EdgeInsets.only(
                  left: 10,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(
                          0xffC5A16B,
                        )
                      : (isDark
                          ? const Color(0xff1E293B)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(
                    20,
                  ),
                ),
                child: Center(
                  child: Text(
                    filterName(filter),
                    style: TextStyle(
                      color: selected ? Colors.black : onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
