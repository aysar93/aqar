import 'package:flutter/material.dart';

class CategoriesSection extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const CategoriesSection({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  static const List<Map<String, dynamic>> _categories = [
    {
      "title": "الكل",
      "icon": Icons.apps_rounded,
    },
    {
      "title": "بيت",
      "icon": Icons.home_rounded,
    },
    {
      "title": "شقة",
      "icon": Icons.apartment_rounded,
    },
    {
      "title": "أرض",
      "icon": Icons.landscape_rounded,
    },
    {
      "title": "محل",
      "icon": Icons.storefront_rounded,
    },
    {
      "title": "عمارة",
      "icon": Icons.location_city_rounded,
    },
    {
      "title": "المكاتب",
      "icon": Icons.business_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 105,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _categories[index];
          final title = item["title"] as String;
          final icon = item["icon"] as IconData;

          final selected = selectedCategory == title;

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onCategorySelected(title),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 88,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xffD4AF37)
                    : const Color(0xff1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? const Color(0xffD4AF37)
                      : Colors.white10,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xffD4AF37)
                              .withOpacity(.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: selected
                        ? Colors.black
                        : const Color(0xffD4AF37),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}