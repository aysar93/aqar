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
  final searchController = TextEditingController();
  String search = '';

  String selectedCategory = "الكل";
  late Stream<List<PropertyModel>> featuredStream;
  late Stream<List<PropertyModel>> latestStream;
  late Stream<List<PropertyModel>> mostViewedStream;

  @override
  void initState() {
    super.initState();

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
      endDrawer: const AppDrawer(),
      backgroundColor: const Color(0xFF0F172A),
      body: AqarRefreshIndicator(
        onRefresh: _refreshHome,
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              AqarSpacing.screen(context),
              AqarSpacing.sm(context),
              AqarSpacing.screen(context),
              AqarSpacing.lg(context),
            ),
            children: [
              // Header
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("users")
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
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
                      stream: FirebaseFirestore.instance
                          .collection("notifications")
                          .where(
                            "userId",
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                          )
                          .snapshots(),
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
                            Scaffold.maybeOf(context)?.openEndDrawer();
                          },
                          onNotificationPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                        );
                      },
                    );
                  }

                  if (accountMode == 'office' && activeOfficeId.isNotEmpty) {
                    return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('offices')
                          .doc(activeOfficeId)
                          .snapshots(),
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

              const SizedBox(height: 20),

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

              const SizedBox(height: 15),

              CategoriesSection(
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

              const SizedBox(height: 30),
              const BannerSlider(),

              const SizedBox(height: 24),

              HorizontalPropertiesSection(
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
              ),

              const SizedBox(height: 24),

              HorizontalPropertiesSection(
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
              ),

              const SizedBox(height: 24),

              HorizontalPropertiesSection(
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
              ),
              const SizedBox(height: 24),
              const PropertyRequestsSection(),

              const SizedBox(height: 20),

              const FeaturedOfficesSection(),

              const SizedBox(height: 32),

              const WhyAqarSection(),

              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
