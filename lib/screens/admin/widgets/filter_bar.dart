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
                          0xffD4AF37,
                        )
                      : const Color(
                          0xff1E293B,
                        ),
                  borderRadius: BorderRadius.circular(
                    20,
                  ),
                ),
                child: Center(
                  child: Text(
                    filterName(filter),
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
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
