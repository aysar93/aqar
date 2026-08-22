import 'package:flutter/material.dart';

import '../models/edit_property_data.dart';
import '../widgets/edit_glass_card.dart';

class EditStep2PropertyType extends StatelessWidget {
  final EditPropertyData property;
  final VoidCallback onChanged;

  const EditStep2PropertyType({
    super.key,
    required this.property,
    required this.onChanged,
  });

  static const List<Map<String, dynamic>> propertyTypes = [
    {
      'name': 'بيت',
      'icon': Icons.home_rounded,
    },
    {
      'name': 'أرض',
      'icon': Icons.landscape_rounded,
    },
    {
      'name': 'شقة',
      'icon': Icons.apartment_rounded,
    },
    {
      'name': 'محل',
      'icon': Icons.store_rounded,
    },
    {
      'name': 'عمارة',
      'icon': Icons.business_rounded,
    },
    {
      'name': 'مزرعة',
      'icon': Icons.agriculture_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "نوع العقار",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "اختر نوع العقار",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              itemCount: propertyTypes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, index) {
                final item = propertyTypes[index];

                final String name = item['name'] as String;

                final IconData icon = item['icon'] as IconData;

                final bool selected = property.propertyType == name;

                return EditGlassCard(
                  selected: selected,
                  onTap: () {
                    property.propertyType = name;

                    // إذا تحول العقار إلى أرض أو محل،
                    // لا نحتفظ بتفاصيل الغرف القديمة.
                    if (name == 'أرض' || name == 'محل') {
                      property.rooms = 0;
                      property.bathrooms = 0;
                      property.livingRooms = 0;
                    }

                    onChanged();
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 45,
                        color: const Color(0xffD4AF37),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
