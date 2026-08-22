import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/aqar_refresh_indicator.dart';
import '../services/notification_navigation_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData getNotificationIcon(String type) {
    switch (type) {
      case 'property':
        return Icons.home;

      case 'account':
        return Icons.person;

      case 'general':
      default:
        return Icons.campaign;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ==================================================
    // الضيف
    // ==================================================
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            "التنبيهات",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 35),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 52,
                    color: Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  "التنبيهات خاصة بالمستخدمين المسجلين",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "سجل الدخول لاستلام تنبيهات العقارات والإشعارات الخاصة بحسابك",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final uid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("التنبيهات"),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
              tooltip: "حذف جميع التنبيهات",
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final snapshot = await FirebaseFirestore.instance
                    .collection('notifications')
                    .where(
                      'userId',
                      isEqualTo: uid,
                    )
                    .get();

                for (final doc in snapshot.docs) {
                  await doc.reference.delete();
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("تم حذف جميع التنبيهات"),
                    ),
                  );
                }
              }),
        ],
      ),
      body: AqarRefreshIndicator(
        onRefresh: () async {
          await Future.delayed(
            const Duration(milliseconds: 500),
          );
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where(
                'userId',
                isEqualTo: uid,
              )
              .orderBy(
                'createdAt',
                descending: true,
              )
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    snapshot.error.toString(),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 140),
                  const Center(
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Color(0xFF1E293B),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 50,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Center(
                    child: Text(
                      "لا توجد تنبيهات",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 35),
                    child: Text(
                      "ستظهر هنا جميع إشعارات العقارات والتنبيهات الجديدة عند توفرها",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;

                final List readBy = data['readBy'] ?? [];

                final isRead = readBy.contains(uid);

                final createdAt = data['createdAt'] as Timestamp?;

                final dateText = createdAt != null
                    ? "${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}"
                    : "";

                return Dismissible(
                  key: Key(docs[index].id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 25),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  onDismissed: (_) async {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(docs[index].id)
                        .delete();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("تم حذف الإشعار"),
                        ),
                      );
                    }
                  },
                  child: InkWell(
                    onTap: () async {
                      if (!isRead) {
                        await FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(docs[index].id)
                            .update({
                          'readBy': FieldValue.arrayUnion([uid]),
                        });
                      }

                      if (!context.mounted) return;

                      await NotificationNavigationService.handleNotification(
                        context,
                        Map<String, dynamic>.from(data),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRead
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                getNotificationIcon(
                                  data['type'] ?? 'general',
                                ),
                                color: const Color(0xFFD4AF37),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  data['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            data['message'] ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateText,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              if (!isRead)
                                const Text(
                                  "جديد",
                                  style: TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
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
            );
          },
        ),
      ),
    );
  }
}
