import '../bookings/booking_discovery_design.dart';
import '../widgets/home/keep_alive_section.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../office/screens/offices_screen.dart';
import '../widgets/aqar_refresh_indicator.dart';
import '../widgets/app_drawer.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/search_section.dart';
import '../widgets/home/categories_section.dart';

import '../widgets/home/featured_offices_section.dart';

import '../widgets/home/horizontal_properties_section.dart';
import 'notifications_screen.dart';

import '../services/property_service.dart';
import '../widgets/home/why_aqar_section.dart';
import '../widgets/banner_slider.dart';
import '../models/property_model.dart';
import 'all_properties_screen.dart';
import '../features/property_map/screens/property_map_screen.dart';
import '../widgets/home/property_requests/property_requests_section.dart';
import '../core/design/aqar_spacing.dart';

const String adminEmail = "aysar.aliraqe@gmail.com";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<User?>? _auth;
  String? _actor;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _headerUser;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _notifications;
  final Map<String, Stream<DocumentSnapshot<Map<String, dynamic>>>>
      _headerOffices = {};
  void _setHeaderActor(String? uid) {
    _actor = uid;
    _headerOffices.clear();
    _headerUser = uid == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    _notifications = uid == null
        ? null
        : FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .snapshots();
  }

  @override
  void dispose() {
    _auth?.cancel();
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  final searchController = TextEditingController();
  final _scrollController = ScrollController();
  String search = '';

  String selectedCategory = "الكل";
  late Stream<List<PropertyModel>> featuredStream;
  late Stream<List<PropertyModel>> latestStream;
  late Stream<List<PropertyModel>> mostViewedStream;

  @override
  void initState() {
    super.initState();
    _setHeaderActor(FirebaseAuth.instance.currentUser?.uid);
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted && user?.uid != _actor) {
        setState(() => _setHeaderActor(user?.uid));
      }
    });

    featuredStream = PropertyService.featuredProperties();
    latestStream = PropertyService.latestProperties();
    mostViewedStream = PropertyService.mostViewedProperties();
  }

  Future<void> _refreshHome() async {
    if (!mounted) return;

    setState(() {
      featuredStream = PropertyService.featuredProperties();
      latestStream = PropertyService.latestProperties();
      mostViewedStream = PropertyService.mostViewedProperties();
    });

    // مهلة قصيرة حتى تبقى حركة التحديث طبيعية للمستخدم
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("HOME_SCREEN BUILD");

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AqarRefreshIndicator(
        onRefresh: _refreshHome,
        child: ListView(
          key: const PageStorageKey<String>('home-scroll'),
          controller: _scrollController,
          primary: false,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.only(bottom: AqarSpacing.lg(context)),
          children: [
            // Top Golden Header Surface (Reused directly from Bookings system)
            BookingGoldenHeaderContainer(
              padding: EdgeInsetsDirectional.fromSTEB(
                20,
                MediaQuery.sizeOf(context).width >
                        MediaQuery.sizeOf(context).height
                    ? MediaQuery.viewPaddingOf(context).top + 6
                    : MediaQuery.viewPaddingOf(context).top + 16,
                20,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  StreamBuilder<DocumentSnapshot>(
                key: ValueKey(_actor),
                stream: _headerUser,
                builder: (context, userSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                  final firebaseUser = FirebaseAuth.instance.currentUser;
                  final accountMode =
                      (userData["accountMode"] ?? "user").toString();
                  final activeOfficeId =
                      (userData["activeOfficeId"] ?? "").toString();
                  final personalName =
                      (userData["name"]?.toString().trim().isNotEmpty ?? false)
                          ? userData["name"].toString()
                          : (firebaseUser?.email?.split("@").first ?? "مستخدم");
                  final personalPhotoUrl =
                      (userData["photoUrl"] ?? "").toString();

                  Widget buildHeader({
                    required String userName,
                    required String photoUrl,
                  }) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: _notifications,
                      builder: (context, notificationSnapshot) {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        final notificationCount =
                            notificationSnapshot.data?.docs.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final List readBy = data['readBy'] ?? [];
                                  return !readBy.contains(uid);
                                }).length ??
                                0;

                        return HomeHeader(
                          userName: userName,
                          photoUrl: photoUrl,
                          notificationCount: notificationCount,
                          onMenuPressed: () {
                            Scaffold.maybeOf(context)?.openDrawer();
                          },
                          onNotificationPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }

                  if (accountMode == 'office' && activeOfficeId.isNotEmpty) {
                    return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _headerOffices.putIfAbsent(
                          activeOfficeId,
                          () => FirebaseFirestore.instance
                              .collection('offices')
                              .doc(activeOfficeId)
                              .snapshots()),
                      builder: (context, officeSnapshot) {
                        final officeData = officeSnapshot.data?.data() ?? {};
                        final officeName =
                            (officeData['name'] ?? '').toString().trim();
                        final officeLogo =
                            (officeData['logoUrl'] ?? '').toString().trim();
                        return buildHeader(
                          userName:
                              officeName.isNotEmpty ? officeName : personalName,
                          photoUrl: officeLogo.isNotEmpty
                              ? officeLogo
                              : personalPhotoUrl,
                        );
                      },
                    );
                  }

                  return buildHeader(
                    userName: personalName,
                    photoUrl: personalPhotoUrl,
                  );
                },
              ),

              const SizedBox(height: 16),

              // Search
              SearchSection(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        search = value.toLowerCase();
                      });
                    },
                    onSubmitted: (value) {
                      final text = value.trim();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllPropertiesScreen(
                            initialSearch: text,
                          ),
                        ),
                      );
                    },
                    onFilterTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PropertyMapScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AqarSpacing.screen(context),
              ),
              child: CategoriesSection(
                responsiveAndroidHome: true,
                selectedCategory: selectedCategory,
                onCategorySelected: (category) {
                  if (category == "المكاتب") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OfficesScreen(),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    selectedCategory = category;
                  });

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllPropertiesScreen(
                        mode: "all",
                        initialCategory: category,
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AqarSpacing.screen(context),
              ),
              child: const KeepAliveSection(child: BannerSlider()),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AqarSpacing.screen(context),
              ),
              child: KeepAliveSection(
                  child: HorizontalPropertiesSection(
                title: "⭐ العقارات المميزة",
                stream: featuredStream,
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllPropertiesScreen(
                        mode: "featured",
                      ),
                    ),
                  );
                },
              )),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AqarSpacing.screen(context),
              ),
              child: KeepAliveSection(
                  child: HorizontalPropertiesSection(
                title: "🆕 أحدث العقارات",
                stream: latestStream,
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllPropertiesScreen(
                        mode: "latest",
                      ),
                    ),
                  );
                },
              )),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AqarSpacing.screen(context),
              ),
              child: KeepAliveSection(
                  child: HorizontalPropertiesSection(
                title: "🔥 الأكثر مشاهدة",
                stream: mostViewedStream,
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllPropertiesScreen(
                        mode: "views",
                      ),
                    ),
                  );
                },
              )),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AqarSpacing.screen(context),
              ),
              child: const KeepAliveSection(child: PropertyRequestsSection()),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AqarSpacing.screen(context),
              ),
              child: const KeepAliveSection(child: FeaturedOfficesSection()),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AqarSpacing.screen(context),
              ),
              child: const WhyAqarSection(),
            ),

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
