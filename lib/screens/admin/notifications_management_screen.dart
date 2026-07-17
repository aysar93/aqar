import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../send_notification_screen.dart';

class NotificationsManagementScreen extends StatefulWidget {
  const NotificationsManagementScreen({super.key});

  @override
  State<NotificationsManagementScreen> createState() =>
      _NotificationsManagementScreenState();
}

class _NotificationsManagementScreenState
    extends State<NotificationsManagementScreen> {


  Future<void> deleteNotification(String id) async {
    await FirebaseFirestore.instance
        .collection("notifications")
        .doc(id)
        .delete();
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
  textDirection: TextDirection.rtl,

  child: Scaffold(
      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
  title: const Text(
    "إدارة الإشعارات",
    style: TextStyle(
      fontWeight: FontWeight.bold,
    ),
  ),

  backgroundColor: const Color(0xff1E293B),

  actions: [

    IconButton(

      icon: const Icon(
        Icons.add_alert,
        color: Color(0xffD4AF37),
      ),

      onPressed: () {

        Navigator.push(
          context,

          MaterialPageRoute(
            builder: (_) =>
                const SendNotificationScreen(),
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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("notifications")
                    .orderBy(
                      "createdAt",
                      descending: true,
                    )
                    .snapshots(),

                builder: (context, snapshot) {

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }


                  final docs = snapshot.data!.docs;


                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "لا توجد إشعارات",
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    );
                  }


                  return ListView.builder(
                    itemCount: docs.length,

                    itemBuilder: (context, index) {

                      final data =
                          docs[index].data()
                              as Map<String, dynamic>;


                      return Card(
                        color: const Color(0xff1E293B),

                        child: ListTile(

                          title: Text(
                            data["title"] ?? "",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),


                          subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Text(
      data["message"] ?? "",
      style: const TextStyle(
        color: Colors.white70,
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
        color: Color(0xffD4AF37),
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