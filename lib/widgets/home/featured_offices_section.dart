import 'package:flutter/material.dart';

import '../../office/models/office_model.dart';
import '../../office/screens/office_profile_screen.dart';
import '../../office/services/office_service.dart';
import '../../office/widgets/office_card.dart';
import '../../office/screens/offices_screen.dart';

class FeaturedOfficesSection extends StatefulWidget {
  const FeaturedOfficesSection({super.key});

  @override
  State<FeaturedOfficesSection> createState() => _FeaturedOfficesSectionState();
}

class _FeaturedOfficesSectionState extends State<FeaturedOfficesSection> {
  static const Color gold = Color(0xFFD4AF37);
  static const Color sectionBackground = Color(0xFF0F172A);

  final PageController _pageController = PageController();

  late final Stream<List<OfficeModel>> _featuredOfficesStream;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _featuredOfficesStream = OfficeService.featuredOffices();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OfficeModel>>(
      stream: _featuredOfficesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 260,
            child: Center(
              child: CircularProgressIndicator(color: gold),
            ),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final offices = snapshot.data ?? [];

        if (offices.isEmpty) {
          return const SizedBox.shrink();
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            margin: const EdgeInsets.symmetric(
              vertical: 8,
            ),
            padding: const EdgeInsets.only(
              top: 14,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              color: sectionBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: gold.withValues(alpha: 0.10),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: offices.length,
                    onPageChanged: (index) {
                      if (mounted) {
                        setState(() => _currentPage = index);
                      }
                    },
                    itemBuilder: (context, index) {
                      final office = offices[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: OfficeCard(
                          office: office,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OfficeProfileScreen(
                                  officeId: office.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (offices.length > 1) ...[
                  const SizedBox(height: 8),
                  _buildPageIndicator(offices.length),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 4,
            height: 27,
            decoration: BoxDecoration(
              color: gold,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'المكاتب المميزة',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'أفضل المكاتب العقارية المختارة لك',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (!context.mounted) return;

                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (routeContext) => const OfficesScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: gold.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(
                    color: gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int count) {
    final visibleDots = count > 5 ? 5 : count;
    final activeIndex = _currentPage.clamp(0, visibleDots - 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: TextDirection.ltr,
      children: List.generate(
        visibleDots,
        (index) {
          final active = index == activeIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? gold : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
          );
        },
      ),
    );
  }
}
