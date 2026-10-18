import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/property_model.dart';
import '../utils/currency.dart';
import '../core/design/aqar_sizes.dart';
import '../core/design/aqar_spacing.dart';
import '../core/design/aqar_radius.dart';
import '../core/design/aqar_text.dart';

class PropertyHorizontalHomeCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavorite;

  const PropertyHorizontalHomeCard({
    super.key,
    required this.property,
    required this.onTap,
    required this.isFavorite,
    required this.onFavorite,
  });

  Color get _statusColor {
    switch (property.availabilityStatus) {
      case "sold":
        return Colors.red;
      case "rented":
        return Colors.deepPurple;
      case "reserved":
        return Colors.orange;
      default:
        return const Color(0xff1DB954);
    }
  }

  String get _statusText {
    switch (property.availabilityStatus) {
      case "sold":
        return "مباع";
      case "rented":
        return "مؤجر";
      case "reserved":
        return "محجوز";
      default:
        return "متاح";
    }
  }

  @override
  Widget build(BuildContext context) {
    final image =
        property.images.isNotEmpty ? property.images.first : property.imageUrl;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: .96, end: 1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: double.infinity,
        child: InkWell(
          borderRadius: AqarRadius.dialog(context),
          onTap: onTap,
          child: Card(
            color: const Color(0xff1E293B),
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: .35),
            shape: RoundedRectangleBorder(
              borderRadius: AqarRadius.dialog(context),
              side: const BorderSide(
                color: Color(0x22D4AF37),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                              AqarRadius.dialog(context).topLeft.x),
                        ),
                        border: Border.all(
                          color: const Color(0x30D4AF37),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                              AqarRadius.dialog(context).topLeft.x),
                        ),
                        child: image.toString().startsWith('assets/')
                            ? Image.asset(
                                image.toString(),
                                width: double.infinity,
                                height:
                                    AqarSizes.propertyImageHeight(context) + 15,
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: image.toString(),
                                width: double.infinity,
                                height:
                                    AqarSizes.propertyImageHeight(context) + 15,
                                fit: BoxFit.cover,
                                fadeInDuration: Duration.zero,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xff243244),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xffD4AF37),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xff243244),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.white54,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                            AqarRadius.dialog(context).topLeft.x,
                          ),
                        ),
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black12,
                                  Colors.black26,
                                  Colors.black45,
                                  const Color(0xff1E293B)
                                      .withValues(alpha: .55),
                                  const Color(0xff1E293B)
                                      .withValues(alpha: .82),
                                  const Color(0xff1E293B),
                                ],
                                stops: const [
                                  0.00,
                                  0.20,
                                  0.38,
                                  0.55,
                                  0.72,
                                  0.88,
                                  1.00,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: AqarSpacing.md(context),
                      right: AqarSpacing.md(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: .90),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white24,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _statusText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AqarText.tiny(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onFavorite,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: AqarSizes.avatar(context),
                            height: AqarSizes.avatar(context),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .35),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                              ),
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.white,
                              size: AqarSizes.icon(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Transform.translate(
                        offset: const Offset(0, 40), // جرّب 10 أو 12 أو 15
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // رقم الإعلان
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffD4AF37),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .30),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                "\u200E#${property.propertyNumber}",
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: AqarText.tiny(context),
                                ),
                              ),
                            ),

                            const SizedBox(width: 2),

                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    property.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: AqarText.propertyTitle(context),
                                      fontWeight: FontWeight.w900,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: Color(0xffD4AF37),
                                        size: 15,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          property.location,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize:
                                                AqarText.bodySmall(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    iqd(property.price),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: const Color(0xffF8D86B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: AqarText.price(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
