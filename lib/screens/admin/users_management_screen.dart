import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'widgets/search_bar_widget.dart';
class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() =>
      _UsersManagementScreenState();
}

class _UsersManagementScreenState
    extends State<UsersManagementScreen> {

  final TextEditingController searchController =
      TextEditingController();

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
          "إدارة المستخدمين",
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

    hintText: "بحث عن مستخدم",

    onChanged: (value) {

      setState(() {

        search = value.trim();

      });

    },

  ),
),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .orderBy(
                    "createdAt",
                    descending: true,
                  )
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

                List<DocumentSnapshot> docs =
                    snapshot.data!.docs;

                if (search.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;

                    final name =
                        (data["name"] ?? "")
                            .toString()
                            .toLowerCase();

                    final email =
                        (data["email"] ?? "")
                            .toString()
                            .toLowerCase();

                    final phone =
                        (data["phone"] ?? "")
                            .toString()
                            .toLowerCase();

                    final text =
                        search.toLowerCase();

                    return name.contains(text) ||
                        email.contains(text) ||
                        phone.contains(text);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "لا يوجد مستخدمون",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder:
                      (context, index) {

                    final user =
                        docs[index];

                    final data =
                        user.data()
                            as Map<String, dynamic>;

                    final isAdmin =
                        data["isAdmin"] ?? false;

                    return Card(
                      color: const Color(0xff1E293B),
                      margin:
                          const EdgeInsets.only(
                        bottom: 14,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),

                      child: ListTile(

                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(
                                  0xffD4AF37),
                          child: Text(
                            (data["name"] ?? "?")
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style:
                                const TextStyle(
                              color: Colors.black,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),

                        title: Text(
                          data["name"] ??
                              "بدون اسم",
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [

                            const SizedBox(
                                height: 6),

                            Text(
                              data["email"] ?? "",
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white70,
                              ),
                            ),

                            Text(
                              data["phone"] ?? "",
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white54,
                              ),
                            ),

                            const SizedBox(
                                height: 8),

                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: isAdmin
                                    ? Colors.green
                                        .withOpacity(
                                            .2)
                                    : Colors.blue
                                        .withOpacity(
                                            .2),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                            20),
                              ),
                              child: Text(
                                isAdmin
                                    ? "مدير"
                                    : "مستخدم",
                                style: TextStyle(
                                  color: isAdmin
                                      ? Colors
                                          .green
                                      : Colors
                                          .blue,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),

                          ],
                        ),

                        trailing: PopupMenuButton(
                          color:
                              const Color(
                                  0xff1E293B),

                          itemBuilder:
                              (context) => [

                            const PopupMenuItem(
                              value: "admin",
                              child: Text(
                                "تعيين كمدير",
                              ),
                            ),

                            const PopupMenuItem(
                              value: "user",
                              child: Text(
                                "إزالة صلاحية المدير",
                              ),
                            ),

                            const PopupMenuItem(
                              value: "delete",
                              child: Text(
                                "حذف المستخدم",
                              ),
                            ),

                          ],

                          onSelected:
                              (value) async {

                            if (value ==
                                "admin") {
                              await user
                                  .reference
                                  .update({
                                "isAdmin":
                                    true,
                              });
                            }

                            if (value ==
                                "user") {
                              await user
                                  .reference
                                  .update({
                                "isAdmin":
                                    false,
                              });
                            }

                            if (value ==
                                "delete") {
                              await user
                                  .reference
                                  .delete();
                            }
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
  );
}


  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

}