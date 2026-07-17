import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final titleController = TextEditingController();
  final messageController = TextEditingController();
  final searchController = TextEditingController();

  String notificationType = "general";

  bool sendToAll = true;

  String search = '';
  String? selectedUserId;
  String? selectedUserName;

  Future<void> sendNotification() async {
    if (titleController.text.trim().isEmpty ||
        messageController.text.trim().isEmpty) {
      return;
    }

    await NotificationService.sendNotification(
  title: titleController.text.trim(),
  message: messageController.text.trim(),
  type: notificationType,
  target: sendToAll ? "all" : "user",
  userId: selectedUserId ?? "",
);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم إرسال التنبيه"),
        ),
      );

      titleController.clear();
      messageController.clear();

      setState(() {
        selectedUserId = null;
        selectedUserName = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("إرسال تنبيه"),
          backgroundColor: const Color(0xff0F172A),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text("الجميع"),
                    icon: Icon(Icons.groups),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text("مستخدم"),
                    icon: Icon(Icons.person),
                  ),
                ],
                selected: {
                  sendToAll,
                },
                onSelectionChanged: (value) {
                  setState(() {
                    sendToAll = value.first;
                  });
                },
              ),
              const SizedBox(height: 20),
              if (!sendToAll) ...[
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: "بحث عن مستخدم",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      search = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final users = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      final name =
                          (data['name'] ?? '').toString().toLowerCase();

                      final phone = (data['phone'] ?? '').toString();

                      final email =
                          (data['email'] ?? '').toString().toLowerCase();

                      return name.contains(search) ||
                          phone.contains(search) ||
                          email.contains(search);
                    }).toList();

                    return SizedBox(
                      height: 220,
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final doc = users[index];

                          final data = doc.data() as Map<String, dynamic>;

                          return ListTile(
                            selected: selectedUserId == doc.id,
                            title: Text(
                              data['name'] ?? '',
                            ),
                            subtitle: Text(
                              data['phone'] ?? '',
                            ),
                            leading: const Icon(
                              Icons.person,
                            ),
                            onTap: () {
                              setState(() {
                                selectedUserId = doc.id;

                                selectedUserName = data['name'];
                              });
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
                if (selectedUserName != null)
                  Text(
                    "المحدد: $selectedUserName",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 20),
              ],
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "عنوان التنبيه",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "نص التنبيه",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 25),
              DropdownButtonFormField<String>(
                value: notificationType,
                decoration: const InputDecoration(
                  labelText: "نوع التنبيه",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "general",
                    child: Text("📢 عام"),
                  ),
                  DropdownMenuItem(
                    value: "property",
                    child: Text("🏠 عقار"),
                  ),
                  DropdownMenuItem(
                    value: "account",
                    child: Text("👤 حساب"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    notificationType = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.send,
                  ),
                  label: const Text(
                    "إرسال",
                  ),
                  onPressed: sendNotification,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    searchController.dispose();
    super.dispose();
  }
}
