import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'status_chip.dart';
import 'admin_action_menu.dart';

import '../../../utils/property_default_images.dart';
import '../../property_details.dart';

class PropertyCard extends StatelessWidget {
  final DocumentSnapshot document;

  const PropertyCard({
    super.key,
    required this.document,
  });

  // ==================================================
  // أدوات تحويل آمنة
  // ==================================================

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  bool _toBool(dynamic value) {
    return value == true;
  }

  String _toStringValue(dynamic value) {
    if (value == null) return '';

    return value.toString();
  }

  List<dynamic> _toList(dynamic value) {
    if (value is List) {
      return List<dynamic>.from(value);
    }

    return <dynamic>[];
  }

  // ==================================================
  // فتح تفاصيل العقار
  // ==================================================

  void _openPropertyDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final propertyType = _toStringValue(data['propertyType']);

    final imageUrl = _toStringValue(data['imageUrl']).trim();

    final displayImage = imageUrl.isNotEmpty
        ? imageUrl
        : PropertyDefaultImages.getImage(
            propertyType,
          );

    final images = _toList(
      data['images'],
    );

    final features = _toList(
      data['features'],
    );

    final city = _toStringValue(data['city']);

    final areaName = _toStringValue(
      data['areaName'] ?? data['district'],
    );

    final landmark = _toStringValue(data['landmark']);

    final locationParts = <String>[
      city,
      areaName,
      landmark,
    ].where((item) => item.trim().isNotEmpty).toList();

    final location =
        locationParts.isEmpty ? 'الموقع غير محدد' : locationParts.join(' - ');

    final createdAtValue = data['createdAt'];

    final Timestamp? createdAt =
        createdAtValue is Timestamp ? createdAtValue : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetails(
          imageUrl: displayImage,
          title: _toStringValue(
            data['title'],
          ),
          location: location,
          price: _toStringValue(
            data['price'],
          ),
          negotiable: _toBool(
            data['negotiable'],
          ),
          rooms: _toInt(
            data['rooms'],
          ),
          bathrooms: _toInt(
            data['bathrooms'],
          ),
          area: _toInt(
            data['area'],
          ),
          frontage: _toNullableDouble(
            data['frontage'],
          ),
          depth: _toNullableDouble(
            data['depth'],
          ),
          floors: _toNullableDouble(
            data['floors'],
          )?.toInt(),
          apartmentFloor: _toNullableDouble(
            data['apartmentFloor'],
          )?.toInt(),
          unitsCount: _toNullableDouble(
            data['unitsCount'],
          )?.toInt(),
          livingRooms: _toInt(
            data['livingRooms'],
          ),
          parking: _toInt(
            data['parking'],
          ),
          description: _toStringValue(
            data['description'],
          ),
          ownerPhone: _toStringValue(
            data['ownerPhone'],
          ),
          ownerWhatsapp: _toStringValue(
            data['ownerWhatsapp'],
          ),
          publisherUid: _toStringValue(
            data['publisherUid'] ?? data['userId'],
          ),
          publisherName: _toStringValue(
            data['publisherName'],
          ),
          publisherEmail: _toStringValue(
            data['publisherEmail'],
          ),
          publisherPhone: _toStringValue(
            data['publisherPhone'],
          ),
          publisherWhatsapp: _toStringValue(
            data['publisherWhatsapp'],
          ),
          images: images,
          features: features,
          documentType: _toStringValue(
            data['documentType'],
          ),
          furnitureStatus: _toStringValue(
            data['furnitureStatus'],
          ),
          propertyType: propertyType,
          adType: _toStringValue(
            data['adType'],
          ),
          city: city,
          areaName: areaName,
          landmark: landmark,
          latitude: _toNullableDouble(
                data['latitude'],
              ) ??
              0,
          longitude: _toNullableDouble(
                data['longitude'],
              ) ??
              0,
          isVerified: _toBool(
            data['isVerified'],
          ),
          isFeatured: _toBool(
            data['isFeatured'],
          ),
          availabilityStatus: _toStringValue(
            data['availabilityStatus'],
          ).isNotEmpty
              ? _toStringValue(
                  data['availabilityStatus'],
                )
              : 'available',
          views: _toInt(
            data['views'],
          ),
          createdAt: createdAt,
          buildYear: _toInt(
            data['buildYear'],
          ),
          propertyNumber: _toInt(
            data['propertyNumber'] ?? data['adNumber'] ?? data['propertyNo'],
          ),
          docId: document.id,
          isFavorite: false,
        ),
      ),
    );
  }

  // ==================================================
  // الواجهة
  // ==================================================

  @override
  Widget build(BuildContext context) {
    final data = document.data() as Map<String, dynamic>;

    final title = data["title"] ?? "";

    final city = data["city"] ?? "";

    final district = data["district"] ?? data["areaName"] ?? "";

    final price = data["price"] ?? 0;

    final propertyType = data["propertyType"] ?? "";

    final adType = data["adType"] ?? "";

    final status = data["status"] ?? "pending";

    final availability = data["availabilityStatus"] ?? "available";

    final isFeatured = data["isFeatured"] ?? false;

    final image = (data["imageUrl"] ?? "").toString().trim();

    final displayImage = image.isNotEmpty
        ? image
        : PropertyDefaultImages.getImage(
            propertyType,
          );

    final views = data["views"] ?? 0;

    final favorites = data["favorites"] ?? 0;

    final comments = data["commentsCount"] ?? 0;

    final propertyNumber =
        data["propertyNumber"] ?? data["adNumber"] ?? data["propertyNo"] ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final isVerySmall = width < 360;
        final imageWidth = isVerySmall
            ? 108.0
            : width < 600
                ? 122.0
                : 168.0;

        // Keep the card compact, but give the internal content enough room
        // for title/location/number/price/actions without vertical overflow.
        final cardHeight = isVerySmall
            ? 154.0
            : width < 600
                ? 166.0
                : 178.0;

        final titleSize = width < 600 ? 12.5 : 13.5;
        final priceSize = width < 600 ? 12.5 : 14.0;

        return Container(
          width: double.infinity,
          height: cardHeight,
          margin: const EdgeInsets.only(bottom: 7),
          decoration: BoxDecoration(
            color: const Color(0xff1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: .055),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openPropertyDetails(context, data),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  SizedBox(
                    width: imageWidth,
                    height: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: displayImage.startsWith('assets/')
                            ? Image.asset(
                                displayImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _imageFallback(propertyType),
                              )
                            : Image.network(
                                displayImage,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                                errorBuilder: (_, __, ___) =>
                                    _imageFallback(propertyType),
                              ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 7, 4, 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title.toString().trim().isEmpty
                                      ? 'عقار بدون عنوان'
                                      : title.toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w800,
                                    height: 1.08,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 1),
                              SizedBox(
                                width: 29,
                                height: 29,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 29,
                                    minHeight: 29,
                                  ),
                                  tooltip: isFeatured
                                      ? 'إلغاء التمييز'
                                      : 'تمييز العقار',
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('properties')
                                        .doc(document.id)
                                        .update({
                                      'isFeatured': !isFeatured,
                                    });
                                  },
                                  icon: Icon(
                                    isFeatured
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 17,
                                    color: isFeatured
                                        ? const Color(0xffD4AF37)
                                        : Colors.white54,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 29,
                                height: 29,
                                child: AdminActionMenu(
                                  document: document,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xffD4AF37),
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '$city - $district',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .55),
                                    fontSize: 9,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (propertyNumber.toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 11,
                                  color: Colors.white.withValues(alpha: .40),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    'رقم الإعلان: ${propertyNumber.toString()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: .45),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            '$price د.ع',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xffD4AF37),
                              fontSize: priceSize,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Flexible(
                                child: StatusChip(
                                  status: status,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: StatusChip(
                                  status: availability,
                                  availability: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  propertyType.toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .44),
                                    fontSize: 8,
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _compactCounter(
                                Icons.remove_red_eye_outlined,
                                views.toString(),
                              ),
                              const SizedBox(width: 5),
                              _compactCounter(
                                Icons.favorite_border_rounded,
                                favorites.toString(),
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
        );
      },
    );
  }

  Widget _imageFallback(String propertyType) {
    return Image.asset(
      PropertyDefaultImages.getImage(propertyType),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xff172238),
        child: const Center(
          child: Icon(
            Icons.home_work_outlined,
            color: Colors.white38,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _compactCounter(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 11,
          color: const Color(0xffD4AF37),
        ),
        const SizedBox(width: 1),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ==================================================
  // عداد
  // ==================================================
}
