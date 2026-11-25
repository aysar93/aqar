import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/property_model.dart';
import '../utils/currency.dart';
import '../core/design/aqar_sizes.dart';
import '../core/design/aqar_breakpoints.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double imageHeight =
        AqarBreakpoints.isTablet(context) ? 145.0 : 126.0;

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
            color: isDark ? const Color(0xff1E293B) : Colors.white,
            elevation: 8,
            shadowColor: isDark
                ? Colors.black.withValues(alpha: .35)
                : Colors.black.withValues(alpha: .06),
            shape: RoundedRectangleBorder(
              borderRadius: AqarRadius.dialog(context),
              side: BorderSide(
                color:
                    isDark ? const Color(0x22C5A16B) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          color: const Color(0x30C5A16B),
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
                                height: imageHeight,
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: image.toString(),
                                width: double.infinity,
                                height: imageHeight,
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
                                        color: Color(0xffC5A16B),
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
                    Positioned(
                      top: AqarSpacing.md(context),
                      right: AqarSpacing.md(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
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
                    if (property.videoUrl != null &&
                        property.videoUrl!.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white24,
                              width: 0.5,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.videocam_rounded,
                                color: Color(0xffC5A16B),
                                size: 12,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'فيديو',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        property.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: AqarText.propertyTitle(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xffC5A16B),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF64748B),
                                fontSize: AqarText.bodySmall(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              iqd(property.price),
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xffC5A16B),
                                fontWeight: FontWeight.bold,
                                fontSize: AqarText.price(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffC5A16B)
                                  .withValues(alpha: .15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xffC5A16B)
                                    .withValues(alpha: .45),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              "رقم: #${property.propertyNumber}",
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xffD8BD95)
                                    : const Color(0xff8C6D3B),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
