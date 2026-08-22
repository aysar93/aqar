import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'property_request_home_card.dart';
import '../../../screens/property_requests/all_property_requests_screen.dart';
import '../../../screens/property_requests/property_request_details_screen.dart';

class PropertyRequestsSection extends StatefulWidget {
  const PropertyRequestsSection({super.key});

  @override
  State<PropertyRequestsSection> createState() =>
      _PropertyRequestsSectionState();
}

class _PropertyRequestsSectionState extends State<PropertyRequestsSection> {
  static const Color _gold = Color(0xffD4AF37);

  late PageController _pageController;
  bool _controllerInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controllerInitialized) return;

    final width = MediaQuery.of(context).size.width;

    final viewportFraction = width < 360
        ? 0.85
        : width < 600
            ? 0.65
            : width < 900
                ? 0.48
                : 0.34;

    _pageController = PageController(
      viewportFraction: viewportFraction,
      keepPage: true,
    );

    _controllerInitialized = true;
  }

  int _currentPage = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _isAdmin = false;
          });
        }
        return;
      }

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _isAdmin = document.data()?['isAdmin'] == true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isAdmin = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('property_requests')
          .where(
            'status',
            isEqualTo: 'approved',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 330,
            child: Center(
              child: CircularProgressIndicator(
                color: _gold,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint(
            "PropertyRequestsSection ERROR: "
            "${snapshot.error}",
          );

          return const SizedBox.shrink();
        }

        final requests = snapshot.data?.docs.toList() ?? [];

        requests.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;

          final bData = b.data() as Map<String, dynamic>;

          final aTime = aData['createdAt'] as Timestamp?;

          final bTime = bData['createdAt'] as Timestamp?;

          if (aTime == null && bTime == null) {
            return 0;
          }

          if (aTime == null) {
            return 1;
          }

          if (bTime == null) {
            return -1;
          }

          return bTime.compareTo(aTime);
        });

        if (requests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(
            bottom: 20,
          ),
          padding: const EdgeInsets.only(
            top: 6,
            bottom: 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xffD4AF37).withValues(alpha: 0.10),
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
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(context),
                const SizedBox(height: 12),
                ClipRect(
                  child: SizedBox(
                    height: 250,
                    child: PageView.builder(
                      controller: _pageController,
                      reverse: true,
                      padEnds: false,
                      physics: const BouncingScrollPhysics(),
                      itemCount: requests.length,
                      onPageChanged: (index) {
                        if (!mounted) return;

                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final doc = requests[index];

                        final data = doc.data() as Map<String, dynamic>;

                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double scale = 1.0;

                            if (_pageController.hasClients &&
                                _pageController.position.haveDimensions) {
                              final page = _pageController.page ??
                                  _currentPage.toDouble();

                              scale = (1 - ((page - index).abs() * 0.08)).clamp(
                                0.90,
                                1.0,
                              );
                            }

                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                            ),
                            child: PropertyRequestHomeCard(
                              requestId: doc.id,
                              data: data,
                              isAdmin: _isAdmin,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PropertyRequestDetailsScreen(
                                      requestId: doc.id,
                                      data: data,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: AnimatedSmoothIndicator(
                    activeIndex: _safeCurrentPage(
                      requests.length,
                    ),
                    count: requests.length,
                    effect: const ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                      spacing: 6,
                      dotColor: Colors.white24,
                      activeDotColor: _gold,
                    ),
                    onDotClicked: (index) {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(
                          milliseconds: 350,
                        ),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(
    BuildContext context,
  ) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 27,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xffF8D66D),
                      Color(0xffD4AF37),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "طلبات العقارات",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: .3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "العقارات التي يبحث عنها المستخدمون",
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
              Transform.translate(
                offset: const Offset(12, 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllPropertyRequestsScreen(),
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
                          color: _gold.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        "عرض الكل",
                        style: TextStyle(
                          color: _gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )),
    );
  }

  int _safeCurrentPage(int count) {
    if (count <= 0) {
      return 0;
    }

    if (_currentPage >= count) {
      return count - 1;
    }

    return _currentPage;
  }
}
