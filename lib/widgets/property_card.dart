import 'package:flutter/material.dart';
import 'property_image.dart';

class PropertyCard extends StatefulWidget {
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
  final String docId;

  final String availabilityStatus;

  final bool isFavorite;

  final VoidCallback onTap;
  final VoidCallback onFavorite;

  final String description;
  final String ownerPhone;
  final String ownerWhatsapp;

  final List<dynamic> images;
  final List<dynamic> features;

  final String publisherName;
  final String publisherPhotoUrl;

  final String officeName;
  final String officeLogoUrl;
  final bool isOfficeProperty;

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
    required this.docId,
    required this.availabilityStatus,
    required this.description,
    required this.ownerPhone,
    required this.ownerWhatsapp,
    required this.images,
    required this.features,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    this.publisherName = '',
    this.publisherPhotoUrl = '',
    this.officeName = '',
    this.officeLogoUrl = '',
    this.isOfficeProperty = false,
  });
  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  bool _pressed = false;
  bool _visible = false;

  Color _statusColor() {
    switch (widget.availabilityStatus) {
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
    switch (widget.availabilityStatus) {
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
              borderRadius: BorderRadius.circular(12),
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
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });
  }

  Widget _buildPublisher() {
    final bool showOffice =
        widget.isOfficeProperty && widget.officeName.trim().isNotEmpty;

    final String name = showOffice
        ? widget.officeName
        : widget.publisherName.trim().isNotEmpty
            ? widget.publisherName
            : 'صاحب العقار';

    final String photoUrl =
        showOffice ? widget.officeLogoUrl : widget.publisherPhotoUrl;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xffD4AF37),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: photoUrl.trim().isNotEmpty
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Icon(
                        showOffice
                            ? Icons.business_rounded
                            : Icons.person_rounded,
                        color: const Color(0xffD4AF37),
                      );
                    },
                  )
                : Icon(
                    showOffice ? Icons.business_rounded : Icons.person_rounded,
                    color: const Color(0xffD4AF37),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showOffice ? 'المكتب العقاري' : 'صاحب العقار',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (showOffice)
          const Icon(
            Icons.verified_rounded,
            color: Color(0xffD4AF37),
            size: 18,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayImage = widget.images.isNotEmpty
        ? widget.images.first.toString()
        : widget.imageUrl;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 350),
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 120),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;

              final isSmall = width < 360;
              final cardHeight = isSmall
                  ? 144.0
                  : width < 600
                      ? 154.0
                      : 166.0;

              final imageWidth = isSmall
                  ? 112.0
                  : width < 600
                      ? 128.0
                      : 172.0;

              return Container(
                width: double.infinity,
                height: cardHeight,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xff1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xffD4AF37).withValues(alpha: .10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTapCancel: () => setState(() => _pressed = false),
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(16),
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
                              child: PropertyImage(
                                imagePath: displayImage,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(9, 5, 5, 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.title.trim().isEmpty
                                            ? 'عقار بدون عنوان'
                                            : widget.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          height: 1.02,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 30,
                                          minHeight: 30,
                                        ),
                                        onPressed: widget.onFavorite,
                                        icon: Icon(
                                          widget.isFavorite
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          size: 18,
                                          color: widget.isFavorite
                                              ? Colors.redAccent
                                              : Colors.white54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                _goldDivider(),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      color: Color(0xffD4AF37),
                                      size: 13,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        widget.location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: .58),
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                _goldDivider(),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.confirmation_number_outlined,
                                      color: Color(0xffD4AF37),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        'رقم الإعلان: ${widget.propertyNumber}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: .60,
                                          ),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                _goldDivider(),
                                Row(
                                  children: [
                                    _publisherAvatar(),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _publisherDisplayName(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (widget.isOfficeProperty &&
                                        widget.officeName.trim().isNotEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 3),
                                        child: Icon(
                                          Icons.verified_rounded,
                                          color: Color(0xffD4AF37),
                                          size: 14,
                                        ),
                                      ),
                                  ],
                                ),
                                const Spacer(),
                                _goldDivider(),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.price,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xffD4AF37),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor()
                                            .withValues(alpha: .11),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Text(
                                        _statusText(),
                                        style: TextStyle(
                                          color: _statusColor(),
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
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
          ),
        ),
      ),
    );
  }

  Widget _goldDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        height: 0.6,
        width: double.infinity,
        color: const Color(0xffD4AF37).withValues(alpha: .18),
      ),
    );
  }

  String _publisherDisplayName() {
    if (widget.isOfficeProperty && widget.officeName.trim().isNotEmpty) {
      return widget.officeName.trim();
    }

    if (widget.publisherName.trim().isNotEmpty) {
      return widget.publisherName.trim();
    }

    return 'صاحب العقار';
  }

  Widget _publisherAvatar() {
    final showOffice =
        widget.isOfficeProperty && widget.officeName.trim().isNotEmpty;
    final photo = showOffice
        ? widget.officeLogoUrl.trim()
        : widget.publisherPhotoUrl.trim();

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xffD4AF37).withValues(alpha: .65),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: photo.isNotEmpty
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  showOffice ? Icons.business_rounded : Icons.person_rounded,
                  color: const Color(0xffD4AF37),
                  size: 12,
                ),
              )
            : Icon(
                showOffice ? Icons.business_rounded : Icons.person_rounded,
                color: const Color(0xffD4AF37),
                size: 13,
              ),
      ),
    );
  }
}
