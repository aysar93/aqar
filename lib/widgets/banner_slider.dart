import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../banners/banner_model.dart';
import '../banners/banner_service.dart';
import '../office/screens/office_profile_screen.dart';
import '../services/property_service.dart';
import '../screens/property_details.dart';

class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key});

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

  // آخر ارتفاع مستخدم للبنر.
  // نحتفظ به مؤقتًا عند اختفاء البنرات حتى لا يتحرك
  // محتوى الـ ListView فجأة.
  double _reservedHeight = 0.0;

  // هل كانت هناك بنرات ظاهرة قبل وصول القائمة الفارغة؟
  bool _hadBanners = false;

  // يمنع جدولة أكثر من عملية إخفاء في نفس الوقت.
  bool _hideScheduled = false;

  @override
  void initState() {
    super.initState();

    _bannersStream = BannerService.activeBanners();
  }

  Future<void> _openBanner(BannerModel banner) async {
    final target = banner.targetId.trim();

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

  void _scheduleHide() {
    if (_hideScheduled) return;

    _hideScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _hideScheduled = false;

      if (!_hadBanners) return;

      setState(() {
        _hadBanners = false;
        _reservedHeight = 0.0;
        _currentIndex = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    // الارتفاع الأصلي للبنر.
    final bannerHeight = (width * 0.32).clamp(115.0, 155.0);

    // ارتفاع البنر + المؤشر.
    final totalHeight = bannerHeight + 19.0;

    return StreamBuilder<List<BannerModel>>(
      stream: _bannersStream,
      builder: (context, snapshot) {
        // ==========================================================
        // انتظار أول نتيجة من Firestore.
        //
        // إذا لم تظهر البنرات بعد، لا نحجز مساحة ضخمة مثل 175.
        // ==========================================================
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        // ==========================================================
        // خطأ أو لا توجد بنرات.
        //
        // إذا كانت البنرات موجودة قبل قليل، نحافظ مؤقتًا على
        // آخر ارتفاع حتى يكتمل الـFrame، ثم نصفر الارتفاع.
        //
        // بهذه الطريقة لا يحدث تغيير مفاجئ في موضع الأقسام.
        // ==========================================================
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          if (_hadBanners) {
            _scheduleHide();

            return SizedBox(
              height: _reservedHeight,
            );
          }

          return const SizedBox.shrink();
        }

        final banners = snapshot.data!;

        // ==========================================================
        // لدينا بنرات.
        // ==========================================================
        _hadBanners = true;
        _reservedHeight = totalHeight;

        // حماية المؤشر من الخروج عن عدد البنرات.
        if (banners.length <= 1) {
          _currentIndex = 0;
        } else if (_currentIndex >= banners.length) {
          _currentIndex = 0;
        }

        return AnimatedSize(
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
                  height: bannerHeight,
                  width: double.infinity,
                  child: CarouselSlider.builder(
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
                          onTap: () => _openBanner(banner),
                        ),
                      );
                    },
                    options: CarouselOptions(
                      height: bannerHeight,
                      viewportFraction: banners.length > 1 ? 0.91 : 1.0,
                      enlargeCenterPage: false,
                      padEnds: true,
                      enableInfiniteScroll: banners.length > 1,
                      autoPlay: banners.length > 1,
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

                if (banners.length > 1)
                  _ReferenceIndicator(
                    count: banners.length,
                    currentIndex: _currentIndex,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReferenceBannerCard extends StatelessWidget {
  const _ReferenceBannerCard({
    required this.banner,
    required this.onTap,
  });

  final BannerModel banner;
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
                _BannerImage(
                  imageUrl: banner.imageUrl,
                ),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontSize: 17,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            if (banner.subtitle.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                banner.subtitle.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
  });

  final int count;
  final int currentIndex;

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
                  ? const Color(0xFFD4AF37)
                  : Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}
