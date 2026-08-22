import 'package:flutter/material.dart';

class RequestDefaultImage extends StatelessWidget {
  final String? propertyType;
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final bool showRequestedBadge;

  const RequestDefaultImage({
    super.key,
    required this.propertyType,
    this.width,
    this.height = 190,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(20),
    ),
    this.fit = BoxFit.cover,
    this.showRequestedBadge = true,
  });

  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);
  static const Color _card = Color(0xff1E293B);

  // ==================================================
  // مسار الصورة حسب نوع العقار
  // ==================================================

  static String imagePathFor(String? propertyType) {
    switch (propertyType?.trim()) {
      case "بيت":
        return "assets/images/requests/house.png";

      case "شقة":
        return "assets/images/requests/apartment.png";

      case "أرض":
        return "assets/images/requests/land.png";

      case "محل":
        return "assets/images/requests/shop.png";

      case "عمارة":
        return "assets/images/requests/building.png";

      case "مزرعة":
        return "assets/images/requests/farm.png";

      default:
        return "assets/images/requests/property.png";
    }
  }

  // ==================================================
  // الأيقونة حسب نوع العقار
  // ==================================================

  static IconData iconFor(String? propertyType) {
    switch (propertyType?.trim()) {
      case "بيت":
        return Icons.home_rounded;

      case "شقة":
        return Icons.apartment_rounded;

      case "أرض":
        return Icons.landscape_rounded;

      case "محل":
        return Icons.storefront_rounded;

      case "عمارة":
        return Icons.location_city_rounded;

      case "مزرعة":
        return Icons.agriculture_rounded;

      default:
        return Icons.real_estate_agent_rounded;
    }
  }

  // ==================================================
  // اسم النوع
  // ==================================================

  static String titleFor(String? propertyType) {
    final value = propertyType?.trim();

    if (value == null || value.isEmpty) {
      return "عقار";
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = imagePathFor(propertyType);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ==========================================
            // الصورة
            // ==========================================

            Image.asset(
              imagePath,
              fit: fit,

              // إلى أن نضيف الصور الفعلية،
              // سيظهر التصميم الاحتياطي بدل الخطأ.
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return _buildFallback();
              },
            ),

            // ==========================================
            // تدرج لزيادة وضوح الشارة
            // ==========================================

            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(
                        alpha: 0.34,
                      ),
                    ],
                    stops: const [
                      0.45,
                      1.0,
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // شارة مطلوب
            // ==========================================

            if (showRequestedBadge)
              PositionedDirectional(
                top: 12,
                start: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.22,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: _background,
                        size: 16,
                      ),
                      SizedBox(width: 5),
                      Text(
                        "مطلوب",
                        style: TextStyle(
                          color: _background,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // التصميم الاحتياطي
  // ==================================================

  Widget _buildFallback() {
    final icon = iconFor(propertyType);
    final title = titleFor(propertyType);

    return Container(
      decoration: const BoxDecoration(
        color: _card,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -45,
            right: -35,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(
                  alpha: 0.07,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -55,
            left: -35,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(
                  alpha: 0.045,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _gold.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _gold.withValues(
                        alpha: 0.22,
                      ),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: _gold,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "مطلوب $title",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "طلب عقاري",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
