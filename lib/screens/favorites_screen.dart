import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/property_card.dart';
import 'property_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/currency.dart';
import '../widgets/aqar_refresh_indicator.dart';
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("المفضلة"),
        backgroundColor: const Color(0xff0D47A1),
      ),
       body: AqarRefreshIndicator(
  onRefresh: () async {
    await Future.delayed(const Duration(milliseconds: 500));
  },
  child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
    .collection('users')
    .doc(FirebaseAuth.instance.currentUser!.uid)
    .collection('favorites')
    .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: const [
      SizedBox(height: 250),
      Center(
        child: Text("لا توجد لديك عقارات مفضلة"),
      ),
    ],
  );
}

          return ListView.builder(
  padding: const EdgeInsets.all(16),
  itemCount: docs.length,
  itemBuilder: (context, index) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('properties')
          .doc(docs[index].id)
          .get(),
      builder: (context, propertySnapshot) {
        if (!propertySnapshot.hasData) {
          return const SizedBox();
        }

        if (!propertySnapshot.data!.exists) {
          return const SizedBox();
        }

        final data =
            propertySnapshot.data!.data()
                as Map<String, dynamic>;

        return PropertyCard(
          imageUrl: data['imageUrl'] ?? '',
          title: data['title'] ?? '',
          location: data['location'] ?? '',
          price: iqd(data['price']).toString(),
          rooms: data['rooms'] ?? 0,
          bathrooms: data['bathrooms'] ?? 0,
          area: data['area'] ?? 0,
          livingRooms: data['livingRooms'] ?? 0,
          parking: data['parking'] ?? 0,
          description: data['description'] ?? '',
          ownerPhone: data['ownerPhone'] ?? '',
          ownerWhatsapp: data['ownerWhatsapp'] ?? '',
          images: List<dynamic>.from(data['images'] ?? []),
          features: List<dynamic>.from(data['features'] ?? []),
          propertyNumber: data['propertyNumber'] ?? 0,
availabilityStatus:
    (data['availabilityStatus'] ?? 'available').toString(),
          isFavorite: true,

          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PropertyDetails(
  docId: docs[index].id,
  propertyNumber: data['propertyNumber'] ?? 0,
  isFavorite: true,
  

availabilityStatus:
    (data['availabilityStatus'] ?? 'available').toString(),
  imageUrl: (data['imageUrl'] ?? '').toString(),
  title: (data['title'] ?? '').toString(),
  location: (data['location'] ?? '').toString(),

  price: iqd(data['price']).toString(),

  rooms: (data['rooms'] ?? 0) as int,
  bathrooms: (data['bathrooms'] ?? 0) as int,
  area: (data['area'] ?? 0) as int,
  livingRooms: (data['livingRooms'] ?? 0) as int,
  parking: (data['parking'] ?? 0) as int,

  description: (data['description'] ?? '').toString(),

  ownerPhone: (data['ownerPhone'] ?? '').toString(),
  ownerWhatsapp: (data['ownerWhatsapp'] ?? '').toString(),

  publisherPhone: (data['publisherPhone'] ?? '').toString(),
  publisherWhatsapp: (data['publisherWhatsapp'] ?? '').toString(),
publisherUid:
    (data['publisherUid'] ?? '').toString(),

publisherName:
    (data['publisherName'] ?? '').toString(),

publisherEmail:
    (data['publisherEmail'] ?? '').toString(),
  // ===== الحقول الجديدة =====
  propertyType: (data['propertyType'] ?? '').toString(),
  adType: (data['adType'] ?? '').toString(),

  city: (data['city'] ?? '').toString(),
  areaName: (data['areaName'] ?? '').toString(),
  landmark: (data['landmark'] ?? '').toString(),

  latitude: (data['latitude'] ?? 0).toDouble(),
  longitude: (data['longitude'] ?? 0).toDouble(),

  isVerified: data['isVerified'] ?? false,
  isFeatured: data['isFeatured'] ?? false,


  views: data['views'] ?? 0,

  createdAt: data['createdAt'],

  buildYear: data['buildYear'] ?? 0,
  // ==========================

  images: List<String>.from(data['images'] ?? []),
  features: List<String>.from(data['features'] ?? []),
  documentType: (data['documentType'] ?? '').toString(),

furnitureStatus:
    (data['furnitureStatus'] ?? '').toString(),
),
              ),
            );
          },

                    onFavorite: () async {
            final uid =
                FirebaseAuth.instance.currentUser!.uid;

            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('favorites')
                .doc(docs[index].id)
                .delete();
          },
        );
      },
    );
  },
);
        },
      ),
    ),
  );
  }
}