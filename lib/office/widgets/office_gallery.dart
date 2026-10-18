import 'package:flutter/material.dart';

/// معرض صور المكتب.
///
/// يعرض صور المكتب بشكل أفقي، مع:
/// - صورة رئيسية كبيرة.
/// - صور مصغرة.
/// - مؤشر عدد الصور.
/// - إمكانية فتح الصورة بالحجم الكامل.
///
/// لا يرتبط مباشرة بـ Firebase؛
/// يستقبل روابط الصور فقط.
class OfficeGallery extends StatefulWidget {
  final List<String> images;

  /// عند الضغط على صورة.
  final ValueChanged<int>? onImageTap;

  /// ارتفاع المعرض.
  final double height;

  const OfficeGallery({
    super.key,
    required this.images,
    this.onImageTap,
    this.height = 250,
  });

  @override
  State<OfficeGallery> createState() => _OfficeGalleryState();
}

class _OfficeGalleryState extends State<OfficeGallery> {
  late final PageController _pageController;

  int _currentIndex = 0;

  List<String> get _images {
    return widget.images
        .map(
          (image) => image.trim(),
        )
        .where(
          (image) => image.isNotEmpty,
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;

    if (images.isEmpty) {
      return _buildEmptyGallery(
        context,
      );
    }

    return Column(
      children: [
        _buildMainGallery(
          context,
          images,
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          _buildThumbnails(
            context,
            images,
          ),
        ],
      ],
    );
  }

  // ═════════════════════════════════════════════
  // المعرض الرئيسي
  // ═════════════════════════════════════════════

  Widget _buildMainGallery(
    BuildContext context,
    List<String> images,
  ) {
    return Container(
      width: double.infinity,
      height: widget.height,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (
              context,
              index,
            ) {
              return GestureDetector(
                onTap: () {
                  if (widget.onImageTap != null) {
                    widget.onImageTap!(index);
                    return;
                  }

                  _openFullScreenGallery(
                    context,
                    index,
                  );
                },
                child: _buildImage(
                  context,
                  images[index],
                ),
              );
            },
          ),

          // مؤشر عدد الصور
          if (images.length > 1)
            Positioned(
              top: 14,
              right: 14,
              child: _buildImageCounter(
                context,
                images.length,
              ),
            ),

          // زر الصورة السابقة
          if (images.length > 1)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildNavigationButton(
                  context,
                  icon: Icons.chevron_left_rounded,
                  onPressed: _previousImage,
                ),
              ),
            ),

          // زر الصورة التالية
          if (images.length > 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildNavigationButton(
                  context,
                  icon: Icons.chevron_right_rounded,
                  onPressed: _nextImage,
                ),
              ),
            ),

          // النقاط
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: _buildPageIndicator(
                context,
                images.length,
              ),
            ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // صورة
  // ═════════════════════════════════════════════

  Widget _buildImage(
    BuildContext context,
    String imageUrl,
  ) {
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return _buildImageError(
          context,
        );
      },
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return _buildImageLoading(
          context,
        );
      },
    );
  }

  // ═════════════════════════════════════════════
  // تحميل الصورة
  // ═════════════════════════════════════════════

  Widget _buildImageLoading(
    BuildContext context,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFFD4AF37),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // خطأ الصورة
  // ═════════════════════════════════════════════

  Widget _buildImageError(
    BuildContext context,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'تعذر تحميل الصورة',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // عداد الصور
  // ═════════════════════════════════════════════

  Widget _buildImageCounter(
    BuildContext context,
    int total,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 15,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            '${_currentIndex + 1} / $total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // أزرار التنقل
  // ═════════════════════════════════════════════

  Widget _buildNavigationButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black.withValues(
        alpha: 0.45,
      ),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.chevron_left_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // مؤشر الصفحات
  // ═════════════════════════════════════════════

  Widget _buildPageIndicator(
    BuildContext context,
    int count,
  ) {
    final visibleCount = count > 8 ? 8 : count;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        visibleCount,
        (index) {
          final actualIndex = count <= 8
              ? index
              : _indicatorIndex(
                  index,
                  count,
                );

          final isSelected = actualIndex == _currentIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(
              horizontal: 3,
            ),
            width: isSelected ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD4AF37)
                  : Colors.white.withValues(
                      alpha: 0.7,
                    ),
              borderRadius: BorderRadius.circular(10),
            ),
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════
  // الصور المصغرة
  // ═════════════════════════════════════════════

  Widget _buildThumbnails(
    BuildContext context,
    List<String> images,
  ) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        itemCount: images.length,
        separatorBuilder: (
          context,
          index,
        ) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (
          context,
          index,
        ) {
          final selected = index == _currentIndex;

          return GestureDetector(
            onTap: () {
              _goToImage(index);
            },
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 180,
              ),
              width: 64,
              height: 64,
              padding: EdgeInsets.all(
                selected ? 2 : 0,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(
                          0xFFD4AF37,
                        )
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(
                        Icons.image_outlined,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════
  // معرض فارغ
  // ═════════════════════════════════════════════

  Widget _buildEmptyGallery(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      height: widget.height,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_outlined,
            size: 54,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد صور للمكتب',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // الصورة السابقة
  // ═════════════════════════════════════════════

  void _previousImage() {
    if (_currentIndex <= 0) {
      return;
    }

    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ═════════════════════════════════════════════
  // الصورة التالية
  // ═════════════════════════════════════════════

  void _nextImage() {
    if (_currentIndex >= _images.length - 1) {
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ═════════════════════════════════════════════
  // الانتقال إلى صورة
  // ═════════════════════════════════════════════

  void _goToImage(int index) {
    if (index < 0 || index >= _images.length) {
      return;
    }

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ═════════════════════════════════════════════
  // فتح المعرض بالحجم الكامل
  // ═════════════════════════════════════════════

  void _openFullScreenGallery(
    BuildContext context,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return _FullScreenOfficeGallery(
            images: _images,
            initialIndex: initialIndex,
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════
  // حساب مؤشر الصور عند كثرة الصور
  // ═════════════════════════════════════════════

  int _indicatorIndex(
    int index,
    int count,
  ) {
    if (count <= 8) {
      return index;
    }

    if (index == 0) {
      return 0;
    }

    if (index == 7) {
      return count - 1;
    }

    final available = count - 2;

    final position = ((_currentIndex - 1) / (available - 1)).clamp(0.0, 1.0);

    return 1 + ((available - 1) * position).round();
  }
}

// ═══════════════════════════════════════════════
// شاشة المعرض بالحجم الكامل
// ═══════════════════════════════════════════════

class _FullScreenOfficeGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenOfficeGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenOfficeGallery> createState() =>
      _FullScreenOfficeGalleryState();
}

class _FullScreenOfficeGalleryState extends State<_FullScreenOfficeGallery> {
  late final PageController _controller;

  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;

    _controller = PageController(
      initialPage: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (
          context,
          index,
        ) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white54,
                    size: 60,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
