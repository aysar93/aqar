import 'package:flutter/material.dart';

import '../../../models/property_request_data.dart';

class Step2PropertyType extends StatelessWidget {
  final PropertyRequestData request;
  final VoidCallback onChanged;

  const Step2PropertyType({
    super.key,
    required this.request,
    required this.onChanged,
  });

  static const Color _gold = Color(0xffD4AF37);

  static const List<_PropertyTypeItem> _propertyTypes = [
    _PropertyTypeItem(
      title: "بيت",
      icon: Icons.home_rounded,
    ),
    _PropertyTypeItem(
      title: "شقة",
      icon: Icons.apartment_rounded,
    ),
    _PropertyTypeItem(
      title: "أرض",
      icon: Icons.landscape_rounded,
    ),
    _PropertyTypeItem(
      title: "محل",
      icon: Icons.storefront_rounded,
    ),
    _PropertyTypeItem(
      title: "عمارة",
      icon: Icons.location_city_rounded,
    ),
    _PropertyTypeItem(
      title: "مزرعة",
      icon: Icons.agriculture_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        const Text(
          "ما نوع العقار المطلوب؟",
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "اختر نوع العقار الذي تبحث عنه",
          style: TextStyle(
            color: Colors.white60,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            const crossAxisSpacing = 14.0;
            // تشمل الحشوة والأيقونة والنص والإطار الأعرض عند الاختيار.
            const minimumTileHeight = 120.0;
            final tileWidth = (constraints.maxWidth - crossAxisSpacing) / 2;
            final idealTileHeight = tileWidth / 1.35;
            final tileHeight = idealTileHeight < minimumTileHeight
                ? minimumTileHeight
                : idealTileHeight;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _propertyTypes.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisSpacing: 14,
                mainAxisExtent: tileHeight,
              ),
              itemBuilder: (context, index) {
                final item = _propertyTypes[index];
                final selected = request.propertyType == item.title;

                return _PropertyTypeCard(
                  item: item,
                  selected: selected,
                  onTap: () {
                    if (request.propertyType != item.title) {
                      request.propertyType = item.title;

                      // حذف أي مواصفات متبقية من نوع عقار
                      // تم اختياره سابقًا ولا يستخدمها النوع الجديد.
                      request.clearFieldsNotUsedByPropertyType();
                    }

                    onChanged();
                  },
                );
              },
            );
          },
        ),
        if (request.propertyType != null) ...[
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _gold.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: _gold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "العقار المطلوب: ${request.propertyType}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PropertyTypeCard extends StatelessWidget {
  final _PropertyTypeItem item;
  final bool selected;
  final VoidCallback onTap;

  const _PropertyTypeCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);
  static const Color _card = Color(0xff1E293B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _gold.withValues(alpha: 0.10) : _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _gold : Colors.white.withValues(alpha: 0.06),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected ? _gold : _gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        item.icon,
                        color: selected ? _background : _gold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      style: TextStyle(
                        color: selected ? _gold : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: _gold,
                    size: 21,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyTypeItem {
  final String title;
  final IconData icon;

  const _PropertyTypeItem({
    required this.title,
    required this.icon,
  });
}
