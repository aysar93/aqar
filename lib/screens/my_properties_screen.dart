import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_property_screen.dart';
import '../utils/currency.dart';
class MyPropertiesScreen extends StatelessWidget {
  const MyPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'يجب تسجيل الدخول أولاً',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('عقاراتي'),
        backgroundColor:
            const Color(0xff0D47A1),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('properties')
            .where(
              'userId',
              isEqualTo: uid,
            )
            .snapshots(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد عقارات',
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,

            itemBuilder:
                (context, index) {

              final data =
                  docs[index].data()
                      as Map<String, dynamic>;

              return Card(
  margin: const EdgeInsets.all(10),
  elevation: 3,

  child: Padding(
    padding: const EdgeInsets.all(15),

    child: Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

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
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          data['location'] ?? '',
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

            Icon(
              Icons.remove_red_eye,
              size: 18,
              color: Colors.grey,
            ),

            const SizedBox(width: 5),

            Text(
              '${data['views'] ?? 0}',
            ),

            const SizedBox(width: 20),

            Icon(
              Icons.favorite,
              size: 18,
              color: Colors.red,
            ),

            const SizedBox(width: 5),

            Text(
              '${data['favorites'] ?? 0}',
            ),
          ],
        ),

        const SizedBox(height: 10),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),

          decoration: BoxDecoration(
            color:
                data['status'] ==
                        'approved'
                    ? Colors.green
                    : Colors.orange,
            borderRadius:
                BorderRadius.circular(
                    20),
          ),

          child: Text(
            data['status'] ==
                    'approved'
                ? 'تمت الموافقة'
                : 'قيد المراجعة',

            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 15),

        Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    IconButton(
      icon: const Icon(
        Icons.edit,
        color: Colors.blue,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditPropertyScreen(
              docId: docs[index].id,
              data: data,
            ),
          ),
        );
      },
    ),
    IconButton(
      icon: const Icon(
        Icons.delete,
        color: Colors.red,
      ),
      onPressed: () async {
        await FirebaseFirestore.instance
            .collection('properties')
            .doc(docs[index].id)
            .delete();
      },
    ),
  ],
),

                    ], // إغلاق children الخاصة بـ Column
                  ), // إغلاق Column
                ), // إغلاق Padding
              ); // إغلاق Card
            },
          );
        },
      ),
    );
  }
}