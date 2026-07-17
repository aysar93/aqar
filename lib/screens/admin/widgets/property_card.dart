import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'status_chip.dart';
import 'admin_action_menu.dart';

class PropertyCard extends StatelessWidget {
  final DocumentSnapshot document;

  const PropertyCard({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    final data = document.data() as Map<String, dynamic>;

    final title = data["title"] ?? "";
    final city = data["city"] ?? "";
    final district = data["district"] ?? "";
    final price = data["price"] ?? 0;

    final propertyType =
        data["propertyType"] ?? "";

    final adType =
        data["adType"] ?? "";

    final status =
        data["status"] ?? "pending";

    final availability =
        data["availabilityStatus"] ??
            "متوفر";

    final image =
        data["imageUrl"] ?? "";

    final views =
        data["views"] ?? 0;

    final favorites =
        data["favorites"] ?? 0;

    final comments =
        data["commentsCount"] ?? 0;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          /// صورة العقار
          ClipRRect(
            borderRadius:
                const BorderRadius.only(
              topLeft:
                  Radius.circular(18),
              topRight:
                  Radius.circular(18),
            ),
            child: image.isNotEmpty
                ? Image.network(
                    image,
                    height: 210,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 210,
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(
                        Icons.home,
                        color: Colors.white54,
                        size: 70,
                      ),
                    ),
                  ),
          ),

          Padding(
            padding:
                const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                                Row(
                  children: [

                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    AdminActionMenu(
                      document: document,
                    ),

                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [

                    const Icon(
                      Icons.location_on,
                      color: Color(0xffD4AF37),
                      size: 18,
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        "$city - $district",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  "$price د.ع",
                  style: const TextStyle(
                    color: Color(0xffD4AF37),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [

                    StatusChip(
                      status: status,
                    ),

                    const SizedBox(width: 10),

                    StatusChip(
                      status: availability,
                      availability: true,
                    ),

                  ],
                ),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [

                    Chip(
                      backgroundColor: const Color(0xff334155),
                      label: Text(
                        propertyType,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),

                    Chip(
                      backgroundColor: const Color(0xff334155),
                      label: Text(
                        adType,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),

                  ],
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceAround,
                  children: [

                    _counter(
                      Icons.remove_red_eye,
                      views.toString(),
                    ),

                    _counter(
                      Icons.favorite,
                      favorites.toString(),
                    ),

                    _counter(
                      Icons.comment,
                      comments.toString(),
                    ),

                  ],
                ),
                              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _counter(
    IconData icon,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: const Color(0xffD4AF37),
          size: 18,
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}