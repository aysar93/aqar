import 'package:flutter/material.dart';
import '../../models/add_property_data.dart';
import 'widgets/glass_card.dart';

class Step2PropertyType extends StatelessWidget {
  final AddPropertyData property;
  final VoidCallback onChanged;

  const Step2PropertyType({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final types = [
      {
        "name": "بيت",
        "icon": Icons.home_rounded,
      },
      {
        "name": "شقة",
        "icon": Icons.apartment_rounded,
      },
      {
        "name": "أرض",
        "icon": Icons.landscape_rounded,
      },
      {
        "name": "محل",
        "icon": Icons.storefront_rounded,
      },
      {
        "name": "عمارة",
        "icon": Icons.business_rounded,
      },
      {
        "name": "مزرعة",
        "icon": Icons.agriculture_rounded,
      },
    ];

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // بطاقة GlassCard تحتوي على حشوة رأسية 44px. مع الأيقونة والنص
                // تحتاج البطاقة إلى ارتفاع أدنى حتى لا يفيض الـ Column على
                // الشاشات الضيقة، مع الحفاظ على النسبة الحالية في الشاشات الأوسع.
                const crossAxisSpacing = 15.0;
                // نضيف هامشاً للإطار الذي يصبح عرضه 2px عند اختيار البطاقة.
                const minimumTileHeight = 136.0;
                final tileWidth = (constraints.maxWidth - crossAxisSpacing) / 2;
                final idealTileHeight = tileWidth / 1.2;
                final tileHeight = idealTileHeight < minimumTileHeight
                    ? minimumTileHeight
                    : idealTileHeight;

                return GridView.builder(
                  itemCount: types.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: crossAxisSpacing,
                    mainAxisSpacing: 15,
                    mainAxisExtent: tileHeight,
                  ),
                  itemBuilder: (context, index) {
                    final item = types[index];
                    final name = item["name"] as String;

                    return GlassCard(
                      selected: property.propertyType == name,
                      onTap: () {
                        // إذا اختار المستخدم نفس النوع مرة أخرى
                        // فلا حاجة لإعادة تنظيف البيانات.
                        if (property.propertyType == name) {
                          return;
                        }

                        // تعيين النوع الجديد.
                        property.propertyType = name;

                        // حذف أي بيانات متبقية من نوع العقار السابق
                        // ولا تتناسب مع النوع الجديد.
                        property.clearFieldsNotUsedByPropertyType();

                        onChanged();
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item["icon"] as IconData,
                            size: 45,
                            color: const Color(0xffD4AF37),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
