import 'package:cached_network_image/cached_network_image.dart';
import '../analytics/services/app_activity_service.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'navigation/custom_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aqar/services/share_origin.dart';
import 'package:aqar/services/app_store_links.dart';
import '../screens/login_screen.dart';
import '../chat/chat_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/my_properties_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/statistics/property_statistics_screen.dart';
import 'home/home_header.dart';

import '../bottom_sheets/about_sheet.dart';
import '../bottom_sheets/contact_sheet.dart';
import '../bottom_sheets/privacy_sheet.dart';
import '../bottom_sheets/terms_sheet.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../bottom_sheets/faq_sheet.dart';
import '../office/join_office/join_office_screen.dart';
import '../office/screens/office_dashboard.dart';
import '../office/services/office_service.dart';
import '../office/models/office_model.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool loading = true;
  bool isAdmin = false;
  bool isOfficeMode = false;

  String name = "";
  String phone = "";
  String email = "";
  String photoUrl = "";
  OfficeModel? myOffice;
  bool officeLoading = true;

  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();

    loadUser();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      loadUser();
    });
  }

  Future<void> loadUser() async {
    name = "";
    phone = "";
    email = "";
    photoUrl = "";
    isAdmin = false;
    isOfficeMode = false;
    myOffice = null;
    officeLoading = true;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        name = data["name"] ?? "";
        phone = data["phone"] ?? "";
        email = data["email"] ?? "";
        photoUrl = data["photoUrl"] ?? data["photo"] ?? "";
        isAdmin = data["isAdmin"] == true;
        isOfficeMode = data["accountMode"] == "office";
      }

      // جلب المكتب المرتبط بصاحب الحساب
      myOffice = await OfficeService.getMyOffice(user.uid);
    }

    if (mounted) {
      setState(() {
        loading = false;
        officeLoading = false;
      });
    }
  }

  Widget drawerItem(IconData icon, String title, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(
        icon,
        color: const Color(0xffC5A16B),
        size: 22,
      ),
      title: Text(
        title,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget section(List<Widget> children, {double spacingScale = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14, vertical: 8 * spacingScale),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isDark ? null : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildThemeFooter(BuildContext context, bool isDark, {double spacingScale = 1}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: (12 * spacingScale).clamp(8.0, 16.0),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x33C5A16B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                size: 20,
                color: const Color(0xffC5A16B),
              ),
              const SizedBox(width: 10),
              Text(
                isDark ? "الوضع الليلي" : "الوضع النهاري",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const ThemePillToggle(),
        ],
      ),
    );
  }

  Widget guestHeader({double spacingScale = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: (isLandscape ? 8.0 : 16.0) * spacingScale,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 22,
        vertical: (isLandscape ? 12.0 : 22.0) * spacingScale,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isDark ? null : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: isLandscape ? 24 : 32,
            backgroundColor: const Color(0xffC5A16B),
            backgroundImage:
                photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Icon(
                    Icons.person,
                    color: Colors.black,
                    size: isLandscape ? 26 : 34,
                  )
                : null,
          ),
          SizedBox(height: (isLandscape ? 10.0 : 18.0) * spacingScale),
          Text(
            "مرحباً بك 👋",
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: isLandscape ? 18 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: (isLandscape ? 6.0 : 10.0) * spacingScale),
          Text(
            "يمكنك تصفح جميع العقارات بدون تسجيل، وللاستفادة من جميع خدمات التطبيق قم بتسجيل الدخول",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              fontSize: isLandscape ? 12.5 : 14,
              height: isLandscape ? 1.4 : 1.6,
            ),
          ),
          SizedBox(height: (isLandscape ? 10.0 : 18.0) * spacingScale),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.login, size: isLandscape ? 18 : 22),
              label: Text(
                "تسجيل الدخول",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isLandscape ? 13 : 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffC5A16B),
                foregroundColor: Colors.black,
                minimumSize: Size.fromHeight(isLandscape ? 42 : 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );

                if (mounted) {
                  loadUser();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget userHeader(User user, UserProvider userProvider,
      {double spacingScale = 1}) {
    final bool showOfficeIdentity = isOfficeMode && myOffice != null;
    final String displayName = showOfficeIdentity
        ? myOffice!.name
        : (userProvider.name.isEmpty ? "مستخدم" : userProvider.name);
    final String displayPhoto =
        showOfficeIdentity ? myOffice!.logoUrl : userProvider.photoUrl;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 12 * spacingScale),
      padding:
          EdgeInsets.symmetric(horizontal: 14, vertical: 14 * spacingScale),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isOfficeMode
              ? const Color(0xffC5A16B).withValues(alpha: .35)
              : (isDark ? Colors.transparent : const Color(0xFFE2E8F0)),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xffC5A16B),
                backgroundImage:
                    displayPhoto.isNotEmpty ? CachedNetworkImageProvider(displayPhoto) : null,
                child: displayPhoto.isEmpty
                    ? Icon(
                        showOfficeIdentity
                            ? Icons.business_rounded
                            : Icons.person,
                        color: Colors.black,
                        size: 46,
                      )
                    : null,
              ),
              if (showOfficeIdentity)
                Positioned(
                  right: -4,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffC5A16B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'وضع المكتب',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 10 * spacingScale),
          Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6 * spacingScale),
          if ((showOfficeIdentity ? myOffice!.email : email).isNotEmpty)
            Text(
              showOfficeIdentity ? myOffice!.email : email,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          if (!showOfficeIdentity && userProvider.phone.isNotEmpty) ...[
            SizedBox(height: 6 * spacingScale),
            Text(
              "📞 ${userProvider.phone}",
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
          SizedBox(height: 8 * spacingScale),
          if (!officeLoading && myOffice == null) ...[
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xffC5A16B), Color(0xffC5A16B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffC5A16B).withValues(alpha: 0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const JoinOfficeScreen(),
                        ),
                      );
                      if (mounted) await loadUser();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_rounded,
                            color: Colors.black,
                            size: 23,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'الانضمام كمكتب عقاري',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else if (!officeLoading && myOffice != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;
                  final newOfficeMode = !isOfficeMode;
                  try {
                    final updateData = <String, dynamic>{
                      'accountMode': newOfficeMode ? 'office' : 'user',
                    };
                    if (newOfficeMode) {
                      updateData['activeOfficeId'] = myOffice!.id;
                    } else {
                      updateData['activeOfficeId'] = FieldValue.delete();
                    }
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .update(updateData);
                    if (!mounted) return;
                    setState(() => isOfficeMode = newOfficeMode);
                    Navigator.pop(context);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          newOfficeMode
                              ? 'تعذر تفعيل وضع المكتب'
                              : 'تعذر العودة إلى الحساب الشخصي',
                        ),
                      ),
                    );
                  }
                },
                icon: Icon(
                  isOfficeMode
                      ? Icons.person_outline_rounded
                      : Icons.business_center_outlined,
                ),
                label: Text(
                  isOfficeMode ? 'العودة للحساب الشخصي' : 'الدخول كمكتب',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (isOfficeMode) ...[
              SizedBox(height: 10 * spacingScale),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OfficeDashboard(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffC5A16B),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.dashboard_rounded),
                  label: const Text(
                    'لوحة إدارة المكتب',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userProvider = context.watch<UserProvider>();
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final mediaQuery = MediaQuery.of(context);
    // SafeArea consumes padding.bottom, but an enclosing Scaffold can remove
    // that padding while retaining the system's viewPadding.
    final scrollBottomReserve = isAndroid
        ? CustomBottomBar.height +
            math.max(
                0.0, mediaQuery.viewPadding.bottom - mediaQuery.padding.bottom)
        : 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (loading) {
      return Drawer(
        backgroundColor: isDark
            ? const Color(0xff0F172A)
            : Theme.of(context).scaffoldBackgroundColor,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xffC5A16B)),
        ),
      );
    }

    return Drawer(
      backgroundColor: isDark
          ? const Color(0xff0F172A)
          : Theme.of(context).scaffoldBackgroundColor,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            // Reduce only spare vertical space on shorter Android viewports.
            final spacingScale =
                !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                    ? (1 - (720 - constraints.maxHeight) / 360)
                        .clamp(constraints.maxHeight < 500 ? 0.45 : 0.6, 1.0)
                    : 1.0;
            Widget compactSection(List<Widget> children) =>
                section(children, spacingScale: spacingScale);
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    primary: isAndroid ? false : null,
                    padding: isAndroid
                        ? EdgeInsets.only(bottom: scrollBottomReserve)
                        : null,
                    children: [
                      user == null
                          ? guestHeader(spacingScale: spacingScale)
                          : userHeader(user, userProvider, spacingScale: spacingScale),
                      // قسم الحساب والإعدادات يظهر فقط للمستخدم المسجل ويختفي تماماً عن الضيف
                      if (user != null)
                        compactSection([
                          drawerItem(Icons.home_work_rounded, "اعلاناتي", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyPropertiesScreen(),
                              ),
                            );
                          }),
                          const Divider(height: 1),
                          drawerItem(Icons.favorite_rounded, "المفضلة", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FavoritesScreen(),
                              ),
                            );
                          }),
                          const Divider(height: 1),
                          drawerItem(Icons.settings_rounded, "الإعدادات",
                              () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );

                            if (!mounted) return;

                            await loadUser();
                          }),
                        ]),
                      compactSection([
                      drawerItem(
                        Icons.query_stats_rounded,
                        " اسعار العقارات",
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PropertyStatisticsScreen(),
                            ),
                          );
                        },
                      ),
                    ]),
                      compactSection([
                        drawerItem(Icons.phone_in_talk_rounded, "اتصل بنا", () {
                          showContactSheet(context);
                        }),
                        const Divider(height: 1),
                        drawerItem(Icons.chat_bubble_outline_rounded, "الدردشة", () {
                          final user = FirebaseAuth.instance.currentUser;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => user == null
                                  ? const LoginScreen()
                                  : const ChatScreen(),
                            ),
                          );
                        }),
                        const Divider(height: 1),
                        drawerItem(Icons.location_on_rounded, "موقع المكتب", () async {
                          final url = Uri.parse(
                            "https://maps.google.com/?q=الرمادي+حي+الجمهوري",
                          );

                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        }),
                      ]),
                      compactSection([
                        drawerItem(Icons.description_rounded, "شروط الاستخدام", () {
                          showTermsSheet(context);
                        }),
                        const Divider(height: 1),
                        drawerItem(Icons.verified_user_rounded, "سياسة الخصوصية", () {
                          showPrivacySheet(context);
                        }),
                        const Divider(height: 1),
                        drawerItem(Icons.quiz_rounded, "الأسئلة الشائعة", () {
                          showFaqSheet(context);
                        }),
                        const Divider(height: 1),
                        drawerItem(Icons.share_rounded, "مشاركة التطبيق", () {
                          Share.share(
                            AppStoreLinks.shareMessage,
                            sharePositionOrigin: shareOrigin(context),
                          );
                        }),
                        const Divider(height: 1),
                        drawerItem(
                          Icons.star_rate_rounded,
                          "تقييم التطبيق",
                          () async {
                            final url =
                                AppStoreLinks.ratingUri(defaultTargetPlatform);

                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                        const Divider(height: 1),
                        drawerItem(Icons.info_outline_rounded, "عن التطبيق", () {
                          showAboutSheet(context);
                        }),
                      ]),
                      if (isAdmin)
                        compactSection([
                          drawerItem(
                            Icons.admin_panel_settings_rounded,
                            "لوحة الإدارة",
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminDashboard(),
                                ),
                              );
                            },
                          ),
                        ]),
                      if (user != null)
                        compactSection([
                          drawerItem(
                            Icons.logout_rounded,
                            "تسجيل الخروج",
                            () async {
                              await AppActivityService.instance.signOut();

                              if (!context.mounted) return;

                              context.read<UserProvider>().clear();

                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
                          ),
                        ]),
                      SizedBox(height: 20 * spacingScale),
                    ],
                  ),
                ),
                // مفتاح الوضع الليلي والنهاري في أسفل القائمة الجانبية يظهر للضيف والمسجل معاً
                _buildThemeFooter(context, isDark, spacingScale: spacingScale),
              ],
            );
        }),
      ),
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
