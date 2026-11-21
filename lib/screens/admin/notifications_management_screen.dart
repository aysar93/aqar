import '../../services/trusted_inbox.dart';
import '../../core/data/paged_query.dart';
import 'package:flutter/material.dart';
import '../send_notification_screen.dart';

class NotificationsManagementScreen extends StatefulWidget {
  const NotificationsManagementScreen({super.key});

  @override
  State<NotificationsManagementScreen> createState() =>
      _NotificationsManagementScreenState();
}

class _NotificationsManagementScreenState
    extends State<NotificationsManagementScreen> {
  final Set<String> _deleted = {};
  Future<void> deleteNotification(String id) async {
    await TrustedInbox.dismiss(TrustedInbox.collection().doc(id));
    if (mounted) setState(() => _deleted.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final bgColor = isDark ? const Color(0xff0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xff1E293B) : Colors.white;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text(
            "إدارة الإشعارات",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: cardColor,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.add_alert,
                color: Color(0xffC5A16B),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SendNotificationScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: PagedQueryBuilder<Map<String, dynamic>>(
                  query: TrustedInbox.managementQuery(),
                  pageSize: 30,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = snapshot.data!.docs
                        .where((d) => !_deleted.contains(d.id))
                        .toList();

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          "لا توجد إشعارات",
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.70),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();

                        return Card(
                          color: cardColor,
                          child: ListTile(
                            title: Text(
                              data["title"] ?? "",
                              style: TextStyle(
                                color: onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data["message"] ?? "",
                                  style: TextStyle(
                                    color: onSurface.withValues(alpha: 0.70),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  data["type"] == "property"
                                      ? "🏠 عقار"
                                      : data["type"] == "account"
                                          ? "👤 حساب"
                                          : "📢 عام",
                                  style: const TextStyle(
                                    color: Color(0xffC5A16B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                deleteNotification(
                                  docs[index].id,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
