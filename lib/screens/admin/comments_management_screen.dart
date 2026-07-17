import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'widgets/search_bar_widget.dart';

class CommentsManagementScreen extends StatefulWidget {
  const CommentsManagementScreen({super.key});

  @override
  State<CommentsManagementScreen> createState() =>
      _CommentsManagementScreenState();
}

class _CommentsManagementScreenState extends State<CommentsManagementScreen> {
  final TextEditingController searchController = TextEditingController();

  String search = "";

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
            "إدارة التعليقات",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBarWidget(
                controller: searchController,
                hintText: "بحث عن تعليق أو مستخدم",
                onChanged: (value) {
                  setState(() {
                    search = value.trim().toLowerCase();
                  });
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collectionGroup("comments")
                  
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        snapshot.error.toString(),
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  List<DocumentSnapshot> docs = snapshot.data!.docs;
                  docs.sort((a, b) {
  final ta =
      (a["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;

  final tb =
      (b["createdAt"] as Timestamp?)?.millisecondsSinceEpoch ?? 0;

  return tb.compareTo(ta);
});

                  if (search.isNotEmpty) {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      final comment = (data["text"] ?? data["comment"] ?? "")
                          .toString()
                          .toLowerCase();

                      final userName =
                          (data["userName"] ?? "").toString().toLowerCase();

                      return comment.contains(search) ||
                          userName.contains(search);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "لا توجد تعليقات",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final comment = data["text"] ?? data["comment"] ?? "";

                      final userName = data["userName"] ?? "مستخدم";

                      final createdAt = data["createdAt"] as Timestamp?;

                      final date = createdAt != null
                          ? "${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}"
                          : "";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xff1E293B),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0xffD4AF37),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await doc.reference.delete();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              comment,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              date,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
    );
  }

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
  }
}
