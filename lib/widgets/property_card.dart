import 'package:flutter/material.dart';

class PropertyCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String location;
  final String price;

  final int rooms;
  final int bathrooms;
  final int area;
  final int livingRooms;
  final int parking;

  final int propertyNumber;

  final String availabilityStatus;

  final bool isFavorite;

  final VoidCallback onTap;
  final VoidCallback onFavorite;

  final String description;
  final String ownerPhone;
  final String ownerWhatsapp;

  final List<dynamic> images;
  final List<dynamic> features;

  const PropertyCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.location,
    required this.price,
    required this.rooms,
    required this.bathrooms,
    required this.area,
    required this.livingRooms,
    required this.parking,
    required this.propertyNumber,
    required this.availabilityStatus,
    required this.description,
    required this.ownerPhone,
    required this.ownerWhatsapp,
    required this.images,
    required this.features,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  Color _statusColor() {
    switch (availabilityStatus) {
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
    switch (availabilityStatus) {
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

  Widget infoItem(
    IconData icon,
    String value,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xff0F172A),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xffD4AF37),
              size: 20,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayImage =
        images.isNotEmpty
            ? images.first.toString()
            : imageUrl;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        margin:
            const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(
          color: const Color(0xff1E293B),
          borderRadius:
              BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            /// صورة العقار
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  child: Image.network(
                    displayImage,
                    width: double.infinity,
                    height: 240,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                            Container(
                      height: 240,
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: Icon(
                          Icons.home_work,
                          color: Colors.white,
                          size: 70,
                        ),
                      ),
                    ),
                  ),
                ),

                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                    gradient: LinearGradient(
                      begin:
                          Alignment.bottomCenter,
                      end:
                          Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(
                            .75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                                /// زر المفضلة
                Positioned(
                  top: 16,
                  right: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onFavorite,
                      borderRadius:
                          BorderRadius.circular(30),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color:
                              Colors.black.withOpacity(.55),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.redAccent,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                /// رقم الإعلان
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffD4AF37),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Text(
                      "#$propertyNumber",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),

                /// حالة العقار
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(),
                      borderRadius:
                          BorderRadius.circular(14),
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
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                22,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  /// اسم العقار
                  Text(
                    title,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// الموقع
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color:
                            Color(0xffD4AF37),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  /// السعر
                  Text(
                    price,
                    style: const TextStyle(
                      color:
                          Color(0xffD4AF37),
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xff0F172A),
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [

                        infoItem(
                          Icons.bed,
                          "$rooms",
                        ),

                        infoItem(
                          Icons.bathtub,
                          "$bathrooms",
                        ),

                        infoItem(
                          Icons.square_foot,
                          "$area م²",
                        ),

                        infoItem(
                          Icons.directions_car,
                          "$parking",
                        ),
                      ],
                    ),
                  ),
                                  ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}