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
import '../screens/favorites_screen.dart';
import '../screens/my_properties_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/statistics/property_statistics_screen.dart';

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
    return ListTile(
      leading: const Icon(
        Icons.arrow_back_ios_new,
        color: Colors.white54,
        size: 15,
      ),
      title: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      trailing: Icon(icon, color: const Color(0xffD4AF37)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget section(List<Widget> children, {double spacingScale = 1}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14, vertical: 8 * spacingScale),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(children: children),
      ),
    );
  }

  Widget guestHeader({double spacingScale = 1}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16 * spacingScale),
      padding:
          EdgeInsets.symmetric(horizontal: 22, vertical: 22 * spacingScale),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xffD4AF37),
            backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.black, size: 34)
                : null,
          ),
          SizedBox(height: 18 * spacingScale),
          const Text(
            "مرحباً بك 👋",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10 * spacingScale),
          const Text(
            "يمكنك تصفح جميع العقارات بدون تسجيل، وللاستفادة من جميع خدمات التطبيق قم بتسجيل الدخول",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
          SizedBox(height: 18 * spacingScale),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text(
                "تسجيل الدخول",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffD4AF37),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(52),
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

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 12 * spacingScale),
      padding:
          EdgeInsets.symmetric(horizontal: 14, vertical: 14 * spacingScale),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isOfficeMode
              ? const Color(0xffD4AF37).withValues(alpha: .35)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xffD4AF37),
                backgroundImage:
                    displayPhoto.isNotEmpty ? NetworkImage(displayPhoto) : null,
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
                      color: const Color(0xffD4AF37),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6 * spacingScale),
          if ((showOfficeIdentity ? myOffice!.email : email).isNotEmpty)
            Text(
              showOfficeIdentity ? myOffice!.email : email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          if (!showOfficeIdentity && userProvider.phone.isNotEmpty) ...[
            SizedBox(height: 6 * spacingScale),
            Text(
              "📞 ${userProvider.phone}",
              style: const TextStyle(color: Colors.white60),
            ),
          ],
          SizedBox(height: 8 * spacingScale),
          if (!officeLoading && myOffice == null) ...[
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xffD4AF37), Color(0xffB8860B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffD4AF37).withValues(alpha: 0.20),
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
                    backgroundColor: const Color(0xffD4AF37),
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

    if (loading) {
      return const Drawer(
        backgroundColor: Color(0xff0F172A),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xffD4AF37)),
        ),
      );
    }

    return Drawer(
      backgroundColor: const Color(0xff0F172A),
      child: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          // Reduce only spare vertical space on shorter Android viewports.
          final spacingScale =
              !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                  ? (1 - (720 - constraints.maxHeight) / 360).clamp(0.6, 1.0)
                  : 1.0;
          Widget compactSection(List<Widget> children) =>
              section(children, spacingScale: spacingScale);
          return Column(
            children: [
              user == null
                  ? guestHeader(spacingScale: spacingScale)
                  : userHeader(user, userProvider, spacingScale: spacingScale),
              Expanded(
                child: ListView(
                  primary: isAndroid ? false : null,
                  padding: isAndroid
                      ? EdgeInsets.only(bottom: scrollBottomReserve)
                      : null,
                  children: [
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
                      drawerItem(Icons.phone, "تواصل معنا", () {
                        showContactSheet(context);
                      }),
                      const Divider(height: 1),
                      drawerItem(Icons.location_on, "موقع المكتب", () async {
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
                      const Divider(height: 1),
                      drawerItem(Icons.description, "شروط الاستخدام", () {
                        showTermsSheet(context);
                      }),
                      const Divider(height: 1),
                      drawerItem(Icons.verified_user, "سياسة الخصوصية", () {
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
                          final url = AppStoreLinks.ratingUri(defaultTargetPlatform);

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
                            await FirebaseAuth.instance.signOut();

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
            ],
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
