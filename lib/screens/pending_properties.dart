import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/currency.dart';
import '../services/notification_service.dart';
class PendingProperties extends StatefulWidget {
  const PendingProperties({super.key});

  @override
  State<PendingProperties> createState() =>
      _PendingPropertiesState();
}

class _PendingPropertiesState
    extends State<PendingProperties> {

  bool isAdmin = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  Future<void> checkAdmin() async {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user != null) {

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (doc.exists) {
        isAdmin =
            doc.data()?['isAdmin'] == true;
      }
    }

    setState(() {
      loading = false;
    });
  }

  @override
Widget build(BuildContext context) {

  if (loading) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  if (!isAdmin) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('غير مصرح'),
      ),
      body: const Center(
        child: Text(
          'هذه الصفحة مخصصة للإدارة فقط',
        ),
      ),
    );
  }

  return Scaffold(
    appBar: AppBar(
      title: const Text('العقارات بانتظار الموافقة'),
      backgroundColor: const Color(0xFF0D47A1),
      centerTitle: true,
    ),

    body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('properties')
            .where('status', isEqualTo: 'pending')
            .snapshots(),

        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد عقارات بانتظار الموافقة',
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,

            itemBuilder: (context, index) {

              final doc = docs[index];
              final data =
                  doc.data() as Map<String, dynamic>;

              return Card(
  margin: const EdgeInsets.all(10),
  elevation: 4,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            data['imageUrl'] ?? '',
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                height: 180,
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(
                    Icons.home,
                    size: 60,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 15),

        Text(
          data['title'] ?? '',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(
              Icons.location_on,
              color: Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                data['location'] ?? '',
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          iqd(data['price']),
          style: const TextStyle(
            color: Color(0xff0D47A1),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Icon(Icons.bed, color: Colors.grey.shade700),
            const SizedBox(width: 5),
            Text('${data['rooms'] ?? 0}'),

            const SizedBox(width: 20),

            Icon(Icons.bathtub,
                color: Colors.grey.shade700),
            const SizedBox(width: 5),
            Text('${data['bathrooms'] ?? 0}'),
          ],
        ),

        const SizedBox(height: 20),

        Row(
          children: [

            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {

  await FirebaseFirestore
      .instance
      .collection('properties')
      .doc(doc.id)
      .update({
    'status': 'approved',
  });


  await NotificationService.sendNotification(
  title: "تم قبول إعلانك",
  message: "تمت الموافقة على عقارك بنجاح",
  type: "property",
  target: "user",
  userId: data["userId"],
);

},
                icon: const Icon(Icons.check),
                label: const Text('قبول'),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {

  await FirebaseFirestore
      .instance
      .collection('properties')
      .doc(doc.id)
      .update({
    'status': 'rejected',
  });


  await NotificationService.sendNotification(
  title: "تم رفض إعلانك",
  message: "تم رفض العقار من قبل الإدارة، يرجى مراجعة البيانات.",
  type: "property",
  target: "user",
  userId: data["userId"],
);

},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                icon: const Icon(Icons.close),
                label: const Text('رفض'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [

            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseFirestore
                      .instance
                      .collection('properties')
                      .doc(doc.id)
                      .update({
                    'isFeatured': true,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xffD4AF37),
                ),
                icon: const Icon(Icons.star),
                label: const Text('تمييز'),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseFirestore
                      .instance
                      .collection('properties')
                      .doc(doc.id)
                      .delete();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                icon: const Icon(Icons.delete),
                label: const Text('حذف'),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
);
            },
          );
        },
      ),
    );
  }
}