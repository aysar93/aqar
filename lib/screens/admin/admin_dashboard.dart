import 'package:flutter/material.dart';
import 'admin_chat_list_screen.dart';
import 'property_management_screen.dart';
import 'users_management_screen.dart';
import 'comments_management_screen.dart';
import 'notifications_management_screen.dart';
import 'settings_screen.dart';
import '../send_notification_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'banner_management_screen.dart';
import 'property_requests/admin_property_requests_screen.dart';
import 'office_management_screen.dart';
import '../../app_updates/app_updates_management_screen.dart';
import '../../analytics/screens/analytics_dashboard_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xff0F172A),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "لوحة إدارة عقارات الانبار",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              "مرحباً بك",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "لوحة التحكم",
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 25),
            adminButton(
              context,
              icon: Icons.analytics_rounded,
              title: "إحصائيات النشاط",
              subtitle: "المتصلون الآن والزيارات والجلسات",
              color: Colors.green,
              page: const AnalyticsDashboardScreen(),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("properties")
                  .where(
                    "status",
                    isEqualTo: "pending",
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                final int pendingProperties =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;

                return adminButton(
                  context,
                  icon: Icons.home_work_rounded,
                  title: "إدارة العقارات",
                  subtitle: pendingProperties > 0
                      ? "$pendingProperties عقار بانتظار المراجعة"
                      : "إدارة جميع العقارات",
                  color: Colors.orange,
                  page: const PropertyManagementScreen(),
                  badgeCount: pendingProperties,
                );
              },
            ),
            adminButton(
              context,
              icon: Icons.business_rounded,
              title: "إدارة المكاتب",
              subtitle: "إدارة واعتماد المكاتب العقارية",
              color: const Color(0xffD4AF37),
              page: const OfficeManagementScreen(),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("property_requests")
                  .where(
                    "status",
                    isEqualTo: "pending",
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                final int pendingRequests =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;

                return adminButton(
                  context,
                  icon: Icons.manage_search_rounded,
                  title: "طلبات العقارات",
                  subtitle: pendingRequests > 0
                      ? "$pendingRequests طلب بانتظار المراجعة"
                      : "لا توجد طلبات بانتظار المراجعة",
                  color: const Color(0xffD4AF37),
                  page: const AdminPropertyRequestsScreen(),
                  badgeCount: pendingRequests,
                );
              },
            ),
            adminButton(
              context,
              icon: Icons.people_alt_rounded,
              title: "إدارة المستخدمين",
              subtitle: "المستخدمون والأدمن",
              color: Colors.blue,
              page: const UsersManagementScreen(),
            ),
            adminButton(
              context,
              icon: Icons.comment_rounded,
              title: "إدارة التعليقات",
              subtitle: "التعليقات والردود",
              color: Colors.green,
              page: const CommentsManagementScreen(),
            ),
            adminButton(
              context,
              icon: Icons.notifications_active_rounded,
              title: "إدارة التنبيهات",
              subtitle: "عرض وإدارة التنبيهات",
              color: Colors.red,
              page: const NotificationsManagementScreen(),
            ),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection("chats").snapshots(),
              builder: (context, snapshot) {
                int unreadCount = 0;

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    unreadCount += (data["unreadAdmin"] ?? 0) as int;
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: const Color(0xff1E293B),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminChatListScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  Colors.teal.withValues(alpha: .15),
                              child: const Icon(
                                Icons.chat_rounded,
                                color: Colors.teal,
                                size: 30,
                              ),
                            ),
                            const SizedBox(
                              width: 18,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        "المحادثات",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      if (unreadCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  const Text(
                                    "محادثات المستخدمين",
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white38,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            adminButton(
              context,
              icon: Icons.send_rounded,
              title: "إرسال إشعار جديد",
              subtitle: "إرسال تنبيه للمستخدمين",
              color: Colors.amber,
              page: const SendNotificationScreen(),
            ),
            adminButton(
              context,
              icon: Icons.campaign_rounded,
              title: "إدارة البنرات",
              subtitle: "إضافة وتعديل البنرات الإعلانية",
              color: Colors.deepOrange,
              page: const BannerManagementScreen(),
            ),
            adminButton(
              context,
              icon: Icons.settings_rounded,
              title: "الإعدادات",
              subtitle: "إعدادات التطبيق",
              color: Colors.purple,
              page: const SettingsScreen(),
            ),
            adminButton(
              context,
              icon: Icons.system_update_rounded,
              title: "تحديثات التطبيق",
              subtitle: "إدارة الإصدارات وتنبيه المستخدمين بالتحديث",
              color: const Color(0xffD4AF37),
              page: const AppUpdatesManagementScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget adminButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget page,
    int badgeCount = 0,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => page,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withValues(alpha: .15),
                  child: Icon(
                    icon,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badgeCount > 0) ...[
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeCount > 99 ? "99+" : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
