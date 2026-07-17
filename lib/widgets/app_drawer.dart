import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/login_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/my_properties_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/admin/admin_dashboard.dart';

import '../bottom_sheets/about_sheet.dart';
import '../bottom_sheets/contact_sheet.dart';
import '../bottom_sheets/privacy_sheet.dart';
import '../bottom_sheets/terms_sheet.dart';
import 'dart:async';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool loading = true;
  bool isAdmin = false;

  String name = "";
  String phone = "";

  StreamSubscription<User?>? _authSubscription;

  @override
void initState() {
  super.initState();

  loadUser();

  _authSubscription = FirebaseAuth.instance
      .authStateChanges()
      .listen((_) {
    loadUser();
  });
}

  Future<void> loadUser() async {
  name = "";
  phone = "";
  isAdmin = false;

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
      isAdmin = data["isAdmin"] == true;
    }
  }

  if (mounted) {
    setState(() {
      loading = false;
    });
  }
}

  Widget drawerItem(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: const Color(0xffD4AF37),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white54,
        size: 15,
      ),
      onTap: () {
  Navigator.pop(context);
  onTap();
},
    );
  }

  Widget section(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }

  Widget guestHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xffD4AF37),
            child: Icon(
              Icons.person_outline,
              color: Colors.black,
              size: 46,
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            "مرحباً بك 👋",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            "يمكنك تصفح جميع العقارات بدون تسجيل، وللاستفادة من جميع خدمات التطبيق قم بتسجيل الدخول.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text(
                "تسجيل الدخول",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
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
    MaterialPageRoute(
      builder: (_) => const LoginScreen(),
    ),
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
    Widget userHeader(User user) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xffD4AF37),
            child: Icon(
              Icons.person,
              color: Colors.black,
              size: 46,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            name.isEmpty ? "مستخدم" : name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            user.email ?? "",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),

          if (phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "📞 $phone",
              style: const TextStyle(
                color: Colors.white60,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (loading) {
      return const Drawer(
  backgroundColor: Color(0xff0F172A),
  child: Center(
    child: CircularProgressIndicator(
      color: Color(0xffD4AF37),
    ),
  ),
);
    }

    return Drawer(
      backgroundColor: const Color(0xff0F172A),
      child: SafeArea(
        child: Column(
          children: [

            user == null
                ? guestHeader()
                : userHeader(user),

            Expanded(
              child: ListView(
                children: [

                  if (user != null)
  section([
    drawerItem(
      Icons.home_work_rounded,
      "عقاراتي",
      () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyPropertiesScreen(),
          ),
        );
      },
    ),

    const Divider(height: 1),

    drawerItem(
      Icons.favorite_rounded,
      "المفضلة",
      () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FavoritesScreen(),
          ),
        );
      },
    ),

    const Divider(height: 1),

    drawerItem(
      Icons.settings_rounded,
      "الإعدادات",
      () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(),
          ),
        );
      },
    ),
  ]),

                  section([

                    drawerItem(
                      Icons.phone,
                      "تواصل معنا",
                      () {
                        showContactSheet(context);
                      },
                    ),

                    const Divider(height: 1),

                    drawerItem(
                      Icons.location_on,
                      "موقع المكتب",
                      () async {

                        final url = Uri.parse(
                          "https://maps.google.com/?q=الرمادي+حي+الجمهورية",
                        );

                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),

                    const Divider(height: 1),

                    drawerItem(
                      Icons.description,
                      "شروط الاستخدام",
                      () {
                        showTermsSheet(context);
                      },
                    ),

                    const Divider(height: 1),

                    drawerItem(
                      Icons.verified_user,
                      "سياسة الخصوصية",
                      () {
                        showPrivacySheet(context);
                      },
                    ),
                                        const Divider(height: 1),

                    drawerItem(
  Icons.share_rounded,
  "مشاركة التطبيق",
  () {
    Share.share(
      "حمّل تطبيق عقارات الأنبار واستعرض أفضل العقارات بسهولة.\n\nhttps://play.google.com/store/apps/details?id=com.example.aqar",
    );
  },
),

                    const Divider(height: 1),

                    drawerItem(
  Icons.star_rate_rounded,
  "تقييم التطبيق",
  () async {
    final url = Uri.parse(
      "https://play.google.com/store/apps/details?id=com.example.aqar",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    }
  },
),

                    const Divider(height: 1),

                    drawerItem(
                      Icons.info_outline_rounded,
                      "عن التطبيق",
                      () {
                        showAboutSheet(context);
                      },
                    ),
                  ]),

                  if (isAdmin)
                    section([
                      drawerItem(
                        Icons.admin_panel_settings_rounded,
                        "لوحة الإدارة",
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AdminDashboard(),
                            ),
                          );
                        },
                      ),
                    ]),

                  if (user != null)
                    section([
                      drawerItem(
                        Icons.logout_rounded,
                        "تسجيل الخروج",
                        () async {
                          await FirebaseAuth.instance.signOut();

                          if (!context.mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ]),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
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