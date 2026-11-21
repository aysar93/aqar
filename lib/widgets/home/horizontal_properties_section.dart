import 'package:flutter/material.dart';
import '../property_horizontal_home_card.dart';
import '../../models/property_model.dart';
import '../../utils/property_navigator.dart';
import '../../services/favorites_service.dart';

import '../../core/design/aqar_sizes.dart';
import '../../core/design/aqar_spacing.dart';

class HorizontalPropertiesSection extends StatefulWidget {
  final String title;
  final Stream<List<PropertyModel>> stream;

  final VoidCallback? onViewAll;

  const HorizontalPropertiesSection({
    super.key,
    required this.title,
    required this.stream,
    this.onViewAll,
  });

  @override
  State<HorizontalPropertiesSection> createState() =>
      _HorizontalPropertiesSectionState();
}

class _HorizontalPropertiesSectionState
    extends State<HorizontalPropertiesSection> {
  late PageController _pageController;
  bool _controllerInitialized = false;
  double _lastWidth = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final width = MediaQuery.sizeOf(context).width;
    if (_controllerInitialized && (width - _lastWidth).abs() < 2) return;
    _lastWidth = width;

    final viewportFraction = width < 360
        ? 0.82
        : width < 600
            ? 0.65
            : width < 900
                ? 0.48
                : 0.34;

    final initialPage = _controllerInitialized && _pageController.hasClients
        ? (_pageController.page?.round() ?? _currentPage)
        : _currentPage;

    if (_controllerInitialized) {
      final old = _pageController;
      _pageController = PageController(
        viewportFraction: viewportFraction,
        initialPage: initialPage,
        keepPage: true,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    } else {
      _pageController = PageController(
        viewportFraction: viewportFraction,
        initialPage: initialPage,
        keepPage: true,
      );
      _controllerInitialized = true;
    }
  }

  int _currentPage = 0;

  String get _sectionTitle {
    final title = widget.title.trim();

    if (title.contains("المميزة")) {
      return "العقارات المميزة";
    }
    if (title.contains("أحدث")) {
      return "أحدث العقارات";
    }
    if (title.contains("الأكثر مشاهدة")) {
      return "الأكثر مشاهدة";
    }

    return title.replaceFirst(RegExp(r"^[⭐🆕🔥]"), "").trim();
  }

  String get _sectionDescription {
    if (_sectionTitle == "العقارات المميزة") {
      return "أفضل العقارات المميزة المختارة لك";
    }
    if (_sectionTitle == "أحدث العقارات") {
      return "أحدث العقارات المضافة";
    }
    if (_sectionTitle == "الأكثر مشاهدة") {
      return "العقارات الأكثر مشاهدة";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PropertyModel>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        final debugItemCount = snapshot.data?.length ?? 0;
        debugPrint(
          '[DEBUG_HORIZONTAL_SECTION] '
          'title="$widget.title" '
          'connectionState=${snapshot.connectionState} '
          'hasData=${snapshot.hasData} '
          'itemCount=$debugItemCount '
          'renderState=${snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData ? "Waiting" : snapshot.hasError ? "Error" : debugItemCount == 0 ? "Empty" : "Loaded"}',
        );

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final properties = snapshot.data!;

        return Container(
          margin: EdgeInsets.only(
            bottom: AqarSpacing.lg(context),
          ),
          padding: EdgeInsets.only(
            top: AqarSpacing.sm(context),
            bottom: AqarSpacing.xs(context),
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFC5A16B).withValues(alpha: 0.10)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.black.withValues(alpha: .04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: AqarSizes.horizontalSectionHeight(context) + 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 27,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xffD8BD95),
                                Color(0xffC5A16B),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _sectionTitle,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: .3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _sectionDescription,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(12, 0),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: widget.onViewAll,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xffC5A16B)
                                        .withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'عرض الكل',
                                  style: TextStyle(
                                    color: Color(0xffC5A16B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: AqarSpacing.xs(context)),

                // سنضع هنا القائمة الأفقية في الخطوة القادمة

                if (properties.isNotEmpty)
                  SizedBox(
                    height: AqarSizes.horizontalCardsHeight(context),
                    child: PageView.builder(
                      controller: _pageController,
                      // التقليب من اليمين إلى اليسار مثل قسم المكاتب المميزة.
                      reverse: true,
                      allowImplicitScrolling: true,
                      physics: const BouncingScrollPhysics(),
                      pageSnapping: true,
                      padEnds: false,
                      itemCount: properties.length,
                      findChildIndexCallback: (key) {
                        if (key is! ValueKey<String>) return null;
                        final index = properties
                            .indexWhere((item) => item.id == key.value);
                        return index < 0 ? null : index;
                      },
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        final property = properties[index];

                        return Padding(
                          key: ValueKey(property.id),
                          padding: const EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: StreamBuilder(
                              stream:
                                  FavoritesService.favoriteStream(property.id),
                              builder: (context, snapshot) {
                                return PropertyHorizontalHomeCard(
                                  property: property,
                                  isFavorite: snapshot.data ?? false,
                                  onFavorite: () async {
                                    await FavoritesService.toggleFavorite(
                                        property.id);
                                  },
                                  onTap: () => PropertyNavigator.open(
                                    context,
                                    property,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                if (properties.length > 1) ...[
                  SizedBox(height: AqarSpacing.sm(context)),
                  Center(
                    child: SizedBox(
                      width: 46,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _pageController,
                              builder: (context, child) {
                                final page = _pageController.hasClients
                                    ? (_pageController.page ??
                                        _currentPage.toDouble())
                                    : _currentPage.toDouble();

                                final maxOffset = 46 - 16;

                                final offset = properties.length <= 1
                                    ? 0.0
                                    : (page / (properties.length - 1)) *
                                        maxOffset;

                                return Transform.translate(
                                  offset: Offset(offset, 0),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 16,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: const Color(0xffC5A16B),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                SizedBox(height: AqarSpacing.sm(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
