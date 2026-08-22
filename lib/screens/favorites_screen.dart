import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/property_card.dart';
import 'property_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/currency.dart';
import '../widgets/aqar_refresh_indicator.dart';
import '../services/favorites_service.dart';

class FavoritesScreen extends StatelessWidget {
  final VoidCallback? onExplore;

  const FavoritesScreen({
    super.key,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xff0F172A),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            "المفضلة",
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
                    color: const Color(0xffD4AF37).withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border_rounded,
                    size: 52,
                    color: Color(0xffD4AF37),
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  "المفضلة خاصة بالمستخدمين المسجلين",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "سجل الدخول لحفظ العقارات المفضلة والرجوع إليها في أي وقت",
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

    return Scaffold(
      backgroundColor: const Color(0xff0F172A),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "المفضلة",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: AqarRefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('favorites')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xffD4AF37),
                ),
              );
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  const SizedBox(height: 90),
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 90,
                    color: Colors.white.withValues(alpha: .15),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      "لا توجد عقارات مفضلة",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "اضغط على أيقونة القلب داخل أي عقار\nوسيظهر هنا تلقائياً",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: onExplore,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.rtl,
                          children: [
                            Icon(
                              Icons.explore_rounded,
                              color: Color(0xffD4AF37),
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "استكشف العقارات",
                              style: TextStyle(
                                color: Color(0xffD4AF37),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
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
                        propertySnapshot.data!.data() as Map<String, dynamic>;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: PropertyCard(
                        docId: docs[index].id,
                        imageUrl: data['imageUrl'] ?? '',
                        title: data['title'] ?? '',
                        location: data['location'] ?? '',
                        price: iqd(data['price']).toString(),
                        rooms: (data['rooms'] as num?)?.toInt() ?? 0,
                        bathrooms: (data['bathrooms'] as num?)?.toInt() ?? 0,
                        area: (data['area'] as num?)?.toInt() ?? 0,
                        livingRooms:
                            (data['livingRooms'] as num?)?.toInt() ?? 0,
                        parking: (data['parking'] as num?)?.toInt() ?? 0,
                        description: data['description'] ?? '',
                        ownerPhone: data['ownerPhone'] ?? '',
                        ownerWhatsapp: data['ownerWhatsapp'] ?? '',
                        images: List<dynamic>.from(data['images'] ?? []),
                        features: List<dynamic>.from(data['features'] ?? []),
                        propertyNumber:
                            (data['adNumber'] as num?)?.toInt() ?? 0,
                        availabilityStatus:
                            (data['availabilityStatus'] ?? 'available')
                                .toString(),
                        isFavorite: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PropertyDetails(
                                docId: docs[index].id,
                                propertyNumber:
                                    (data['adNumber'] as num?)?.toInt() ?? 0,
                                isFavorite: true,

                                availabilityStatus:
                                    (data['availabilityStatus'] ?? 'available')
                                        .toString(),
                                imageUrl: (data['imageUrl'] ?? '').toString(),
                                title: (data['title'] ?? '').toString(),
                                location: (data['location'] ?? '').toString(),

                                price: iqd(data['price']).toString(),
                                negotiable: data['negotiable'] == true,

                                rooms: (data['rooms'] as num?)?.toInt() ?? 0,
                                bathrooms:
                                    (data['bathrooms'] as num?)?.toInt() ?? 0,
                                area: (data['area'] as num?)?.toInt() ?? 0,
                                frontage:
                                    (data['frontage'] as num?)?.toDouble(),
                                depth: (data['depth'] as num?)?.toDouble(),
                                floors: (data['floors'] as num?)?.toInt(),
                                apartmentFloor:
                                    (data['apartmentFloor'] as num?)?.toInt(),
                                unitsCount:
                                    (data['unitsCount'] as num?)?.toInt(),
                                livingRooms:
                                    (data['livingRooms'] as num?)?.toInt() ?? 0,
                                parking:
                                    (data['parking'] as num?)?.toInt() ?? 0,

                                description:
                                    (data['description'] ?? '').toString(),

                                ownerPhone:
                                    (data['ownerPhone'] ?? '').toString(),
                                ownerWhatsapp:
                                    (data['ownerWhatsapp'] ?? '').toString(),

                                publisherPhone:
                                    (data['publisherPhone'] ?? '').toString(),
                                publisherWhatsapp:
                                    (data['publisherWhatsapp'] ?? '')
                                        .toString(),
                                publisherUid:
                                    (data['publisherUid'] ?? '').toString(),

                                publisherName:
                                    (data['publisherName'] ?? '').toString(),

                                publisherEmail:
                                    (data['publisherEmail'] ?? '').toString(),
                                // ===== الحقول الجديدة =====
                                propertyType:
                                    (data['propertyType'] ?? '').toString(),
                                adType: (data['adType'] ?? '').toString(),

                                city: (data['city'] ?? '').toString(),
                                areaName:
                                    (data['areaName'] ?? data['district'] ?? '')
                                        .toString(),
                                landmark: (data['landmark'] ?? '').toString(),

                                latitude:
                                    (data['latitude'] as num?)?.toDouble() ??
                                        0.0,
                                longitude:
                                    (data['longitude'] as num?)?.toDouble() ??
                                        0.0,

                                isVerified: data['isVerified'] ?? false,
                                isFeatured: data['isFeatured'] ?? false,

                                views: (data['views'] as num?)?.toInt() ?? 0,

                                createdAt: data['createdAt'],

                                buildYear:
                                    (data['buildYear'] as num?)?.toInt() ?? 0,
                                // ==========================

                                images: List<String>.from(data['images'] ?? []),
                                features:
                                    List<String>.from(data['features'] ?? []),
                                documentType:
                                    (data['documentType'] ?? '').toString(),

                                furnitureStatus:
                                    (data['furnitureStatus'] ?? '').toString(),
                              ),
                            ),
                          );
                        },
                        onFavorite: () async {
                          await FavoritesService.toggleFavorite(docs[index].id);
                        },
                      ),
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
