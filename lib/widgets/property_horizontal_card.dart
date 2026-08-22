import 'package:flutter/material.dart';

import '../models/property_model.dart';
import '../utils/currency.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PropertyHorizontalCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback onTap;

  const PropertyHorizontalCard({
    super.key,
    required this.property,
    required this.onTap,
  });

  Color _statusColor() {
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

  String _statusText() {
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
    final image = property.images.isNotEmpty
        ? property.images.first.toString()
        : property.imageUrl;

    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: const Color(0xffD4AF37).withValues(alpha: .12),
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Container(
            width: 290,
            margin: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              color: const Color(0xff1E293B),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .32),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Hero(
                        tag: 'property_${property.id}',
                        child: image.toString().startsWith('assets/')
                            ? Image.asset(
                                image.toString(),
                                height: 190,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: image.toString(),
                                height: 190,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 190,
                                  color: const Color(0xff263248),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Color(0xffD4AF37),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  height: 190,
                                  color: const Color(0xff263248),
                                  child: const Center(
                                    child: Icon(
                                      Icons.home_work_rounded,
                                      color: Colors.white54,
                                      size: 55,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Container(
                      height: 190,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: .70),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffD4AF37),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xffD4AF37)
                                  .withValues(alpha: .35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          "\u200E#${property.propertyNumber}",
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _statusColor().withValues(alpha: .35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _statusText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (property.isFeatured)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffD4AF37),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffD4AF37)
                                    .withValues(alpha: .35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.workspace_premium,
                                size: 16,
                                color: Colors.black,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "مميز",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: property.adType == "للبيع"
                              ? const Color(0xff2563EB)
                              : const Color(0xff7C3AED),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (property.adType == "للبيع"
                                      ? const Color(0xff2563EB)
                                      : const Color(0xff7C3AED))
                                  .withValues(alpha: .35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              property.adType == "للبيع"
                                  ? Icons.sell_rounded
                                  : Icons.key_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              property.adType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 60,
                      right: 14,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            // سنربطه بخدمة المفضلة في الخطوة القادمة
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .35),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .15),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .20),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_border_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffD4AF37)
                                    .withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xffD4AF37)
                                      .withValues(alpha: .30),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.home_work_rounded,
                                    size: 15,
                                    color: Color(0xffD4AF37),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    property.propertyType,
                                    style: const TextStyle(
                                      color: Color(0xffD4AF37),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xffD4AF37)
                                    .withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xffD4AF37),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                property.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xffD4AF37),
                                Color(0xffB8922F),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffD4AF37)
                                    .withValues(alpha: .30),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.payments_rounded,
                                color: Colors.black,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  iqd(property.price),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              const Text(
                                "د.ع",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (property.propertyType != "أرض")
                              _InfoItem(
                                Icons.bed,
                                property.rooms.toString(),
                              ),
                            if (property.propertyType != "أرض")
                              _InfoItem(
                                Icons.bathtub,
                                property.bathrooms.toString(),
                              ),
                            _InfoItem(
                              Icons.square_foot,
                              property.area.toString(),
                            ),
                            _InfoItem(
                              Icons.remove_red_eye,
                              property.views.toString(),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String value;

  const _InfoItem(
    this.icon,
    this.value,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: .06),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: const Color(0xffD4AF37),
            size: 18,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
