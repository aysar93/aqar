import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'favorites_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'my_properties_screen.dart';
import 'admin/admin_dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'settings_screen.dart';
import '../bottom_sheets/terms_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isAdmin = false;
  bool loading = true;
  String phone = "";

  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  Future<void> checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        isAdmin = doc.data()?['isAdmin'] == true;
        phone = doc.data()?['phone'] ?? "";
      }
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  // دالة مساعدة لفتح الروابط بشكل آمن
  Future<void> _openUrl(String urlString,
      {LaunchMode mode = LaunchMode.platformDefault}) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: mode);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذراً، لم نتمكن من فتح الرابط')),
        );
      }
    }
  }

  Widget menuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xff1E293B),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
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
          size: 16,
          color: Colors.white54,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("حسابي"),
        centerTitle: true,
        backgroundColor: const Color(0xff0F172A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 45,
              backgroundColor: Color(0xffD4AF37),
              child: Icon(
                Icons.person,
                size: 50,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              user?.email ?? "ضيف",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                phone,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 30),

            if (user == null)
              menuItem(
                context,
                Icons.login,
                "تسجيل الدخول",
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
              ),

            if (isAdmin)
              menuItem(
                context,
                Icons.admin_panel_settings,
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

            menuItem(
              context,
              Icons.favorite,
              "المفضلة",
              () {
                if (FirebaseAuth.instance.currentUser == null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FavoritesScreen(),
                  ),
                );
              },
            ),

            menuItem(
              context,
              Icons.home_work,
              "عقاراتي",
              () {
                if (FirebaseAuth.instance.currentUser == null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyPropertiesScreen(),
                  ),
                );
              },
            ),

            Card(
  color: const Color(0xff1E293B),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  ),
  child: Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          children: const [

            Icon(
              Icons.business,
              color: Color(0xffD4AF37),
              size: 32,
            ),

            SizedBox(width: 12),

            Expanded(
              child: Text(
                "هل تمتلك مكتبًا عقاريًا؟",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          ],
        ),

        SizedBox(height: 12),

        const Text(
          "انضم إلى منصة عقارات الأنبار، وأنشئ صفحة خاصة بمكتبك، واعرض جميع عقاراتك في مكان واحد.",
          style: TextStyle(
            color: Colors.white70,
            height: 1.5,
          ),
        ),

        SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text("انضم الآن"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffD4AF37),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {

              // سنربطه بالشاشة القادمة

            },
          ),
        ),

      ],
    ),
  ),
),

const SizedBox(height: 15),

            const SizedBox(height: 10),

            // زر شروط الاستخدام المنسق والمنظم بالكامل
            menuItem(
  context,
  Icons.description,
  "شروط الاستخدام",
  () => showTermsSheet(context),
),

            // زر تواصل معنا الاحترافي والمحاذي بشكل صحيح
            menuItem(
              context,
              Icons.phone,
              "تواصل معنا",
              () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xff1E293B),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "يسعدنا تواصلك معنا",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xffD4AF37)),
                          ),
                          const SizedBox(height: 25),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.chat),
                                  label: const Text("واتساب",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  onPressed: () =>
                                      _openUrl('https://wa.me/9647838081677'),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xffD4AF37),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.call),
                                  label: const Text("اتصال هاتفي",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  onPressed: () => _openUrl('tel:07838081677'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // زر موقع المكتب المعدل والمحدث لخرائط جوجل على الرمادي
            menuItem(
              context,
              Icons.location_on,
              "موقع المكتب",
              () async {
                await _openUrl(
                  'https://maps.google.com/?q=الرمادي+حي+الجمهورية',
                  mode: LaunchMode.externalApplication,
                );
              },
            ),

            menuItem(
              context,
              Icons.settings,
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

            // زر عن التطبيق المنسق والمحاذي لليمين بالكامل
            menuItem(
              context,
              Icons.info,
              "عن التطبيق",
              () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xff1E293B),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      height: MediaQuery.of(context).size.height * 0.75,
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 50,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const CircleAvatar(
                            radius: 35,
                            backgroundColor: Color(0xffD4AF37),
                            child: Icon(Icons.home_work,
                                color: Colors.white, size: 35),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "عقارات الانبار",
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xffD4AF37)),
                          ),
                          const Text(
                            "الإصدار 1.0.0",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const Divider(height: 30),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "من نحن؟",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xffD4AF37)),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "تطبيق عقارات الأنبار هو المنصة الرقمية المتكاملة والمتخصصة في سوق العقارات داخل محافظة الأنبار. انطلق التطبيق ليكون صلة الوصل الأسرع والأكثر أماناً بين الباحثين عن عقارات (شراء أو إيجار) وبين الملاك وأصحاب المكاتب العقارية، مستفيدين من أحدث التقنيات لتسهيل عملية البحث والتسويق.",
                                    textAlign: TextAlign.justify,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  const Text(
                                    "رؤيتنا:",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xffD4AF37)),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "أن نكون الدليل العقاري الأول والأنشط في الأنبار، ونساهم في تطوير وتسهيل حركة الاستثمار العقاري والتوسع العمراني الذي تشهده المحافظة، من خلال توفير بيئة رقمية شفافة وموثوقة لكل مستخدم.",
                                    textAlign: TextAlign.justify,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  const Text(
                                    "أبرز مميزات التطبيق:",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xffD4AF37)),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildFeaturePoint(
                                      "تغطية شاملة لجميع أقضية ونواحي محافظة الأنبار."),
                                  _buildFeaturePoint(
                                      "تنوع كبير في العقارات (بيوت، شقق، أراضي، مجمعات)."),
                                  _buildFeaturePoint(
                                      "فلاتر بحث ذكية ومتقدمة لتسهيل العثور على العقار المناسب."),
                                  _buildFeaturePoint(
                                      "تواصل مباشر وفوري بين المعلن والباحث عن العقار."),
                                  const SizedBox(height: 25),
                                  const Center(
                                    child: Text(
                                      "جميع الحقوق محفوظة © عقارات الأنبار 2026",
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            if (user != null)
              menuItem(
                context,
                Icons.logout,
                "تسجيل الخروج",
                () {
                  FirebaseAuth.instance.signOut().then((_) {
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لبناء فقرات شروط الاستخدام بشكل منسق ومحاذي
  Widget _buildTermSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xffD4AF37)),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            textAlign: TextAlign.justify,
            style: const TextStyle(
                fontSize: 14, color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ودجت فرعية مساعدة لبناء نقاط المميزات في "عن التطبيق" بشكل منسق
  Widget _buildFeaturePoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
