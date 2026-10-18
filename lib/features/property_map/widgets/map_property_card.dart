import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/map_property.dart';
import '../../../utils/property_default_images.dart';

class MapPropertyCard extends StatelessWidget {
  final MapProperty property;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const MapPropertyCard({
    super.key,
    required this.property,
    required this.onTap,
    this.onClose,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _card = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 132,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _gold.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.25,
                ),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(19),
                ),
                child: SizedBox(
                  width: 125,
                  height: double.infinity,
                  child: _PropertyImage(
                    imageUrl: property.imageUrl,
                    propertyType: property.propertyType,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    13,
                    12,
                    12,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (property.isFeatured) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: _gold,
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              property.title.isEmpty
                                  ? property.propertyType
                                  : property.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (onClose != null)
                            InkWell(
                              onTap: onClose,
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(3),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: _gold,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property.location.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatPrice(property.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _gold.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              property.adType,
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (property.propertyNumber > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '#${property.propertyNumber}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(double value) {
    final formatted = NumberFormat.decimalPattern().format(value.round());

    return '$formatted د.ع';
  }
}

class _PropertyImage extends StatelessWidget {
  final String imageUrl;
  final String propertyType;

  const _PropertyImage({
    required this.imageUrl,
    required this.propertyType,
  });

  @override
  Widget build(BuildContext context) {
    final rawImage = imageUrl.trim();

    final image = rawImage.isNotEmpty
        ? rawImage
        : PropertyDefaultImages.getImage(propertyType);

    if (image.startsWith('assets/')) {
      return Image.asset(
        image,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    if (image.startsWith('http://') || image.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: image,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: const Color(0xFF0F172A),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFD4AF37),
            ),
          ),
        ),
        errorWidget: (_, __, ___) {
          return Image.asset(
            PropertyDefaultImages.getImage(propertyType),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
        },
      );
    }

    return Image.asset(
      PropertyDefaultImages.getImage(propertyType),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: const Icon(
        Icons.home_work_rounded,
        color: Color(0xFFD4AF37),
        size: 38,
      ),
    );
  }
}
