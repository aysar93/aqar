import '../bookings/booking_page_indicator.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../banners/banner_model.dart';
import '../bookings/booking_media_image.dart';
import '../banners/banner_service.dart';
import '../office/screens/office_profile_screen.dart';
import '../services/property_service.dart';
import '../screens/property_details.dart';

class BannerSlider extends StatefulWidget {
  const BannerSlider(
      {super.key,
      this.stream,
      this.onBookingVenue,
      this.imageBuilder,
      this.accentColor});

  final Future<void> Function(String id, String category)? onBookingVenue;

  final Stream<List<BannerModel>>? stream;
  final Widget Function(BannerModel)? imageBuilder;
  final Color? accentColor;

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider>
    with SingleTickerProviderStateMixin {
  // مهم جدًا:
  // لا ننشئ Stream داخل build حتى لا يعود Carousel
  // إلى البنر الأول عند إعادة البناء.
  late final Stream<List<BannerModel>> _bannersStream;

  int _currentIndex = 0;
  final _pages = CarouselSliderController();
  bool _bookingFocused = false;

  @override
  void initState() {
    super.initState();

    _bannersStream = (widget.stream ?? BannerService.activeBanners())
        .asyncMap((banners) async {
      final valid = await Future.wait(banners.map((banner) async {
        if (widget.imageBuilder != null) return true;
        if (widget.onBookingVenue != null && banner.mediaId != null)
          return true;
        final uri = Uri.tryParse(banner.imageUrl.trim());
        if (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty ||
            !mounted) {
          return false;
        }
        var loaded = true;
        await precacheImage(NetworkImage(banner.imageUrl.trim()), context,
            onError: (_, __) {
          loaded = false;
        });
        return loaded;
      }));
      return [
        for (var i = 0; i < banners.length; i++)
          if (valid[i]) banners[i]
      ];
    });
  }

  Future<void> _openBanner(BannerModel banner) async {
    final target = banner.targetId.trim();
    if (target.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('الرابط غير متوفر حالياً'),
              duration: Duration(seconds: 2),
            ),
          );
      }
      return;
    }

    if (widget.onBookingVenue != null) {
      if (['chalet', 'hall', 'farm'].contains(banner.type)) {
        try {
          await widget.onBookingVenue!(target, banner.type);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('المكان غير متاح حالياً'),
                  duration: Duration(seconds: 2),
                ),
              );
          }
        }
        return;
      }
      if (banner.type != 'external') {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('الرابط غير متوفر حالياً'),
                duration: Duration(seconds: 2),
              ),
            );
        }
        return;
      }
      final uri = Uri.tryParse(target);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('الرابط غير متوفر حالياً'),
                duration: Duration(seconds: 2),
              ),
            );
        }
        return;
      }
    }

    switch (banner.type) {
      case 'external':
        final uri = Uri.tryParse(target);

        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        }

        return;

      case 'office':
        if (target.isEmpty || !mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OfficeProfileScreen(
              officeId: target,
            ),
          ),
        );

        return;

      case 'property':
      default:
        if (target.isEmpty) return;

        try {
          final property = await PropertyService.getPropertyById(target);

          if (!mounted || property == null) return;

          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PropertyDetails(
                property: property,
                imageUrl: property.imageUrl,
                title: property.title,
                location: property.location,
                price: property.price.toString(),
                rooms: property.rooms,
                bathrooms: property.bathrooms,
                area: property.area,
                livingRooms: property.livingRooms,
                parking: property.parking,
                description: property.description,
                ownerPhone: property.ownerPhone,
                ownerWhatsapp: property.ownerWhatsapp,
                publisherUid: property.publisherUid,
                publisherName: property.publisherName,
                publisherEmail: property.publisherEmail,
                publisherPhone: property.publisherPhone,
                publisherWhatsapp: property.publisherWhatsapp,
                images: property.images,
                features: property.features,
                documentType: property.documentType,
                furnitureStatus: property.furnitureStatus,
                propertyType: property.propertyType,
                adType: property.adType,
                city: property.city,
                areaName: property.areaName,
                landmark: property.landmark,
                latitude: property.latitude,
                longitude: property.longitude,
                isVerified: property.isVerified,
                isFeatured: property.isFeatured,
                availabilityStatus: property.availabilityStatus,
                views: property.views,
                createdAt: property.createdAt,
                buildYear: property.buildYear,
                propertyNumber: property.propertyNumber,
                docId: property.id,
                isFavorite: property.isFavorite,
              ),
            ),
          );
        } catch (_) {
          if (!mounted) return;

          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'تعذر فتح الإعلان حاليًا.',
                ),
              ),
            );
        }

        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    // الارتفاع الأصلي للبنر.
    final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
    final bannerHeight = widget.onBookingVenue != null
        ? 80.0 + textScale * 102.0
        : (width * 0.32).clamp(115.0, 155.0);

    // ارتفاع البنر + المؤشر.
    // The booking overlay is measured against its actual text column below.

    return StreamBuilder<List<BannerModel>>(
      stream: _bannersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final banners = snapshot.data!;
        double measuredHeight = bannerHeight;
        if (widget.onBookingVenue != null) {
          double textHeight(
              String value, double size, double lineHeight, double available) {
            final painter = TextPainter(
                text: TextSpan(
                    text: value,
                    style: DefaultTextStyle.of(context).style.merge(TextStyle(
                        fontSize: size,
                        height: lineHeight,
                        fontWeight: FontWeight.w700))),
                textDirection: TextDirection.rtl,
                textScaler: MediaQuery.textScalerOf(context))
              ..layout(maxWidth: available);
            final result = painter.height;
            painter.dispose();
            return result;
          }

          final textWidth =
              (width * (banners.length > 1 ? .91 : 1) - 58 - 80 * textScale)
                  .clamp(72.0, width);
          for (final banner in banners) {
            final needed = 64 +
                textHeight(banner.title.trim(), 15, 1.6, textWidth) +
                textHeight(banner.subtitle.trim(), 10.5, 1.25, textWidth) +
                4;
            if (needed > measuredHeight) measuredHeight = needed;
          }
        }
        final totalHeight = measuredHeight +
            (widget.onBookingVenue != null
                ? (banners.length > 1 ? 31.0 : 0.0)
                : 19.0);

        // حماية المؤشر من الخروج عن عدد البنرات.
        if (banners.length <= 1) {
          _currentIndex = 0;
        } else if (_currentIndex >= banners.length) {
          _currentIndex = 0;
        }

        return Focus(
            onFocusChange: (focus) {
              if (mounted && widget.onBookingVenue != null)
                setState(() => _bookingFocused = focus);
            },
            child: Padding(
                padding: widget.onBookingVenue != null
                    ? const EdgeInsets.only(top: 10, bottom: 4)
                    : const EdgeInsets.symmetric(vertical: 24),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: totalHeight,
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: measuredHeight,
                          width: double.infinity,
                          child: CarouselSlider.builder(
                            carouselController: _pages,
                            itemCount: banners.length,
                            itemBuilder: (
                              context,
                              index,
                              realIndex,
                            ) {
                              final banner = banners[index];

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: _ReferenceBannerCard(
                                  banner: banner,
                                  imageBuilder: widget.imageBuilder,
                                  accentColor: widget.accentColor,
                                  onTap: () => _openBanner(banner),
                                ),
                              );
                            },
                            options: CarouselOptions(
                              height: measuredHeight,
                              viewportFraction: banners.length > 1 ? 0.91 : 1.0,
                              enlargeCenterPage: false,
                              padEnds: true,
                              enableInfiniteScroll: banners.length > 1,
                              autoPlay: banners.length > 1 &&
                                  (widget.onBookingVenue == null ||
                                      (!MediaQuery.disableAnimationsOf(
                                              context) &&
                                          !_bookingFocused)),
                              autoPlayInterval: const Duration(seconds: 5),
                              autoPlayAnimationDuration:
                                  const Duration(milliseconds: 650),
                              autoPlayCurve: Curves.easeOutCubic,
                              onPageChanged: (
                                index,
                                reason,
                              ) {
                                if (!mounted) return;

                                if (_currentIndex != index) {
                                  setState(() {
                                    _currentIndex = index;
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        // ==================================================
                        // المؤشر
                        // ==================================================
                        if (banners.length > 1) const SizedBox(height: 7),

                        if (banners.length > 1 && widget.onBookingVenue != null)
                          BookingPageIndicator(
                              count: banners.length,
                              page: _currentIndex,
                              accent:
                                  widget.accentColor ?? const Color(0xFFC5A16B),
                              onPage: (i) => _pages.animateToPage(i,
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 250)))
                        else if (banners.length > 1)
                          _ReferenceIndicator(
                            count: banners.length,
                            currentIndex: _currentIndex,
                            accentColor: widget.accentColor,
                          ),
                      ],
                    ),
                  ),
                )));
      },
    );
  }
}

class _ReferenceBannerCard extends StatelessWidget {
  const _ReferenceBannerCard({
    required this.banner,
    required this.onTap,
    this.imageBuilder,
    this.accentColor,
  });

  final BannerModel banner;
  final Widget Function(BannerModel)? imageBuilder;
  final Color? accentColor;
  final VoidCallback onTap;

  String get _label {
    switch (banner.type) {
      case 'office':
        return 'مكتب عقاري';

      case 'external':
        return 'إعلان';

      default:
        return 'مميز';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageBuilder != null)
                  imageBuilder!(banner)
                else if (banner.mediaId != null)
                  BookingMediaImage(url: banner.imageUrl)
                else
                  _BannerImage(imageUrl: banner.imageUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [
                        0.0,
                        0.48,
                        1.0,
                      ],
                      colors: [
                        Color(0x08000000),
                        Color(0x18000000),
                        Color(0xE8000000),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 11,
                  child: _BannerTag(
                    label: _label,
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (banner.title.trim().isNotEmpty)
                              Text(
                                banner.title.trim(),
                                maxLines: accentColor != null ? null : 2,
                                overflow: accentColor != null
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accentColor != null
                                      ? Colors.white
                                      : const Color(0xFFD4AF37),
                                  fontSize: accentColor != null ? 15 : 17,
                                  height: accentColor != null ? 1.6 : 1.1,
                                  fontWeight: accentColor != null
                                      ? FontWeight.w700
                                      : FontWeight.w900,
                                ),
                              ),
                            if (banner.subtitle.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                banner.subtitle.trim(),
                                maxLines: accentColor != null ? null : 1,
                                overflow: accentColor != null
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _BannerCta(
                        color: primary,
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

class _BannerImage extends StatelessWidget {
  const _BannerImage({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          size: 34,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 34,
          ),
        );
      },
      loadingBuilder: (
        context,
        child,
        progress,
      ) {
        if (progress == null) return child;

        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }
}

class _BannerTag extends StatelessWidget {
  const _BannerTag({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BannerCta extends StatelessWidget {
  const _BannerCta({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 76,
        minHeight: 34,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'اكتشف الآن',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.88),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.arrow_back_rounded,
            size: 14,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _ReferenceIndicator extends StatelessWidget {
  const _ReferenceIndicator({
    required this.count,
    required this.currentIndex,
    this.accentColor,
  });

  final int count;
  final int currentIndex;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) {
          final selected = index == currentIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            width: selected ? 19 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: selected
                  ? accentColor ?? const Color(0xFFD4AF37)
                  : Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}
