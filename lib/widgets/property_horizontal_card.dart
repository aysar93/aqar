import 'package:flutter/material.dart';

import '../models/property_model.dart';
import '../utils/currency.dart';

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

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: 290,
        margin: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          color: const Color(0xff1E293B),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
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
                  child: Image.network(
                    image,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        height: 190,
                        color: const Color(0xff263248),
                        child: const Center(
                          child: Icon(
                            Icons.home_work_rounded,
                            color: Colors.white54,
                            size: 55,
                          ),
                        ),
                      );
                    },
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
                        Colors.black.withOpacity(.70),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "#${property.propertyNumber}",
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
                      borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(20),
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
              ],
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
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
                        const Icon(
                          Icons.location_on,
                          color: Color(0xffD4AF37),
                          size: 17,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    Text(
                      iqd(property.price),
                      style: const TextStyle(
                        color: Color(0xffD4AF37),
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        _InfoItem(
                          Icons.bed,
                          property.rooms.toString(),
                        ),
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
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xffD4AF37),
          size: 18,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}