import 'dart:async';
import '../core/data/paged_query.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/aqar_refresh_indicator.dart';
import '../services/notification_navigation_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _pageKey = GlobalKey<PagedQueryBuilderState<Map<String, dynamic>>>();
  final Set<String> _locallyRead = {}, _locallyDeleted = {};
  StreamSubscription<User?>? _auth;
  String? _uid;
  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid == _uid || !mounted) return;
      setState(() {
        _uid = user?.uid;
        _locallyRead.clear();
        _locallyDeleted.clear();
      });
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final user = FirebaseAuth.instance.currentUser;

    // ==================================================
    // الضيف
    // ==================================================
    if (user == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(
            "التنبيهات",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
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
                    color: const Color(0xFFC5A16B).withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 52,
                    color: Color(0xFFC5A16B),
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  "التنبيهات خاصة بالمستخدمين المسجلين",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "سجل الدخول لاستلام تنبيهات العقارات والإشعارات الخاصة بحسابك",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondary,
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
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("التنبيهات"),
        centerTitle: true,
        backgroundColor: bgColor,
        foregroundColor: textPrimary,
        actions: [
          IconButton(
              tooltip: "حذف جميع التنبيهات",
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Row(
                        children: [
                          Icon(Icons.delete_sweep, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text(
                            "حذف كافة التنبيهات",
                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      content: const Text(
                        "هل أنت متأكد من رغبتك في حذف جميع التنبيهات نهائياً؟",
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo')),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("تأكيد الحذف", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );

                if (confirm != true || !context.mounted) return;

                try {
                  final snapshot = await FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', isEqualTo: uid)
                      .get();

                  if (snapshot.docs.isNotEmpty) {
                    final batch = FirebaseFirestore.instance.batch();
                    final deletedIds = <String>{};
                    for (final doc in snapshot.docs) {
                      batch.delete(doc.reference);
                      deletedIds.add(doc.id);
                    }
                    await batch.commit();
                    if (mounted) {
                      setState(() => _locallyDeleted.addAll(deletedIds));
                      _pageKey.currentState?.refresh();
                    }
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تم حذف جميع التنبيهات بنجاح"),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تعذر حذف التنبيهات، يرجى المحاولة لاحقاً"),
                        backgroundColor: Color(0xFFEF4444),
                      ),
                    );
                  }
                }
              }),
        ],
      ),
      body: AqarRefreshIndicator(
        onRefresh: () async {
          await _pageKey.currentState?.refresh();
        },
        child: PagedQueryBuilder<Map<String, dynamic>>(
          key: _pageKey,
          query: FirebaseFirestore.instance
              .collection('notifications')
              .where(
                'userId',
                isEqualTo: uid,
              )
              .orderBy(
                'createdAt',
                descending: true,
              ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        "لا توجد إشعارات جديدة حالياً",
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC5A16B),
                          side: const BorderSide(color: Color(0xFFC5A16B)),
                        ),
                        onPressed: () => _pageKey.currentState?.refresh(),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text("تحديث", style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final docs = snapshot.data!.docs
                .where((d) => !_locallyDeleted.contains(d.id))
                .toList();

            if (docs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 140),
                  Center(
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 50,
                        color: Color(0xFFC5A16B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Center(
                    child: Text(
                      "لا توجد تنبيهات",
                      style: TextStyle(
                        color: textPrimary,
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
                        color: textSecondary,
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
                final data = docs[index].data();

                final List readBy = data['readBy'] ?? [];

                final isRead = _locallyRead.contains(docs[index].id) ||
                    readBy.contains(uid);

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
                    setState(() => _locallyDeleted.add(docs[index].id));
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
                        if (mounted) {
                          setState(() => _locallyRead.add(docs[index].id));
                        }
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
                            ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(18),
                        border: isDark
                            ? null
                            : Border.all(color: Colors.black12),
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
                                color: const Color(0xFFC5A16B),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  data['title'] ?? '',
                                  style: TextStyle(
                                    color: textPrimary,
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
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateText,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                  fontSize: 12,
                                ),
                              ),
                              if (!isRead)
                                const Text(
                                  "جديد",
                                  style: TextStyle(
                                    color: Color(0xFFC5A16B),
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
