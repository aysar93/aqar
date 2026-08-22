import 'package:flutter/material.dart';
import '../../core/design/aqar_sizes.dart';
import '../../core/design/aqar_spacing.dart';
import '../../core/design/aqar_radius.dart';
import '../../core/design/aqar_text.dart';

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
      "title": "مزرعة",
      "icon": Icons.agriculture_rounded,
    },
    {
      "title": "المكاتب",
      "icon": Icons.business_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: AqarSizes.categorySectionHeight(context),
        child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => SizedBox(width: AqarSpacing.xs(context)),
          itemBuilder: (context, index) {
            final item = _categories[index];
            final title = item["title"] as String;
            final icon = item["icon"] as IconData;

            final selected = selectedCategory == title;

            return AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: Offset.zero,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AqarRadius.category(context),
                    splashColor: const Color(0xffD4AF37).withValues(alpha: .12),
                    highlightColor: Colors.transparent,
                    onTap: () => onCategorySelected(title),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: AqarSizes.categoryWidth(context),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xff263548),
                            Color(0xff1E293B),
                          ],
                        ),
                        borderRadius: AqarRadius.category(context),
                        border: Border.all(
                          color: const Color(0xffD4AF37).withValues(alpha: .18),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .22),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSlide(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                offset: selected
                                    ? const Offset(0, -0.08)
                                    : Offset.zero,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 220),
                                  scale: selected ? 1.04 : 1.0,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    padding: EdgeInsets.all(
                                      AqarSizes.categoryCirclePadding(context),
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: selected
                                          ? const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xffF8D86B),
                                                Color(0xffD4AF37),
                                              ],
                                            )
                                          : LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white
                                                    .withValues(alpha: .08),
                                                Colors.white
                                                    .withValues(alpha: .02),
                                              ],
                                            ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                            alpha: selected ? .35 : .08),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: .18),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      icon,
                                      size: AqarSizes.categoryIcon(context),
                                      color: selected
                                          ? Colors.black
                                          : const Color(0xffD4AF37),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: AqarSpacing.xs(context)),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: AqarText.category(context),
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            bottom: AqarSpacing.xs(context),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              width: selected
                                  ? AqarSizes.categoryIndicatorWidth(context)
                                  : 0,
                              height:
                                  AqarSizes.categoryIndicatorHeight(context),
                              decoration: BoxDecoration(
                                color: const Color(0xffD4AF37),
                                borderRadius:
                                    AqarRadius.categoryIndicator(context),
                              ),
                            ),
                          ),
                        ],
                      ),
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
