import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pending_properties.dart';
import 'property_details.dart';
import '../widgets/property_card.dart';
import '../utils/currency.dart';
import 'edit_property_screen.dart';
import '../widgets/aqar_refresh_indicator.dart';
import 'package:provider/provider.dart';
import '../providers/app_settings_provider.dart';
import 'package:aqar/chat/chat_screen.dart';
import '../widgets/app_drawer.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/search_section.dart';
import '../widgets/home/categories_section.dart';
import '../widgets/home/featured_properties_section.dart';
import '../widgets/home/featured_offices_section.dart';
import '../widgets/home/latest_properties_section.dart';
import '../widgets/home/most_viewed_section.dart';
import '../widgets/home/advertisement_banner.dart';

const String adminEmail = "aysar.aliraqe@gmail.com";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final searchController = TextEditingController();
  String search = '';

String selectedCategory = "الكل";

  @override
  Widget build(BuildContext context) {

        return Scaffold(
  drawer: const AppDrawer(),
      backgroundColor: const Color(0xFF0F172A),

      appBar: AppBar(
  backgroundColor: const Color(0xFF0F172A),
  elevation: 0,
  title: StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
    .collection("settings")
    .doc("app_settings")
    .snapshots(),
  builder: (context, snapshot) {
    String appName = "عقارات الأنبار";

    if (snapshot.hasData && snapshot.data!.exists) {
      final data =
          snapshot.data!.data() as Map<String, dynamic>;

      appName = data["appName"] ?? appName;
    }

    return Text(
      appName,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  },
),
  centerTitle: false,
  actions: [
    StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection("settings")
      .doc("app_settings")
      .snapshots(),
  builder: (context, settingsSnapshot) {
    bool allowChat = true;

    if (settingsSnapshot.hasData &&
        settingsSnapshot.data!.exists) {
      final data =
          settingsSnapshot.data!.data()
              as Map<String, dynamic>;

      allowChat = data["allowChat"] ?? true;
    }

    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const SizedBox();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("chats")
          .doc(uid)
          .snapshots(),
      builder: (context, chatSnapshot) {
        int unread = 0;

        if (chatSnapshot.hasData &&
            chatSnapshot.data!.exists) {
          final data =
              chatSnapshot.data!.data()
                  as Map<String, dynamic>;

          unread = data["unreadUser"] ?? 0;
        }

        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (!allowChat) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      "الدردشة مع الإدارة غير متاحة حالياً",
                    ),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ChatScreen(),
                ),
              );
            },
            child: SizedBox(
  width: 46,
  height: 46,
              child: Stack(
                clipBehavior: Clip.none,
                children: [

                  Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [

                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFD4AF37),
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.forum_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                   
                    ],
                  ),

                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: 2,
                      child: Container(
                        padding:
                            const EdgeInsets.all(5),
                        constraints:
                            const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        decoration:
                            const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            unread > 99
                                ? "99+"
                                : unread.toString(),
                            style:
                                const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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
    PopupMenuButton<String>(
  icon: const Icon(
    Icons.menu_rounded,
    color: Colors.white,
  ),
  color: const Color(0xFF1E293B),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  onSelected: (value) {
    switch (value) {
      case "pending":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PendingProperties(),
          ),
        );
        break;

      case "refresh":
        setState(() {});
        break;
    }
  },
  itemBuilder: (context) => [
    const PopupMenuItem(
      value: "refresh",
      child: Row(
        children: [
          Icon(
            Icons.refresh_rounded,
            color: Color(0xFFD4AF37),
          ),
          SizedBox(width: 12),
          Text("تحديث"),
        ],
      ),
    ),

    if (FirebaseAuth.instance.currentUser?.email == adminEmail)
      const PopupMenuItem(
        value: "pending",
        child: Row(
          children: [
            Icon(
              Icons.pending_actions,
              color: Color(0xFFD4AF37),
            ),
            SizedBox(width: 12),
            Text("مراجعة العقارات"),
          ],
        ),
      ),
  ],
),
const SizedBox(width: 6),
  ],
),

      body: AqarRefreshIndicator(
  onRefresh: () async {
    await Future.delayed(const Duration(milliseconds: 500));
  },
  child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('properties')
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          final filteredDocs = docs.where((doc) {
  final data = doc.data() as Map<String, dynamic>;

  final title =
      (data['title'] ?? '').toString().toLowerCase();

  final location =
      (data['location'] ?? '').toString().toLowerCase();

  final adNumber =
      (data['adNumber'] ?? 0).toString();

  final propertyType =
      (data['propertyType'] ?? '').toString();

  final searchText =
      search.replaceAll("#", "").trim();

  final matchesSearch =
      title.contains(search) ||
      location.contains(search) ||
      adNumber.contains(searchText);

  final matchesCategory =
      selectedCategory == "الكل" ||
      propertyType == selectedCategory;

  return matchesSearch && matchesCategory;
}).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              const HomeHeader(),

              const SizedBox(height: 20),

              // Search
SearchSection(
  controller: searchController,
  onChanged: (value) {
    setState(() {
      search = value.toLowerCase();
    });
  },
),

              const SizedBox(height: 15),

CategoriesSection(
  selectedCategory: selectedCategory,
  onCategorySelected: (category) {
    setState(() {
      if (category == "المكاتب") {

        // سنربطه لاحقاً بصفحة المكاتب

        return;
      }

      selectedCategory = category;
    });
  },
),

const FeaturedPropertiesSection(),

const SizedBox(height: 24),

const FeaturedOfficesSection(),

const AdvertisementBanner(),

const SizedBox(height: 24),

const LatestPropertiesSection(),

const MostViewedSection(),

const Text(
  "العقارات",
  style: TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  ),
),

              const SizedBox(height: 10),

              if (filteredDocs.isEmpty)
  const SizedBox(
    height: 300,
    child: Center(
      child: Text(
        "لا توجد عقارات متاحة حالياً",
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    ),
  )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final isAdmin =
                        FirebaseAuth.instance.currentUser?.email ==
                            adminEmail;

                    final doc = filteredDocs[index];
                    final data =
                        doc.data() as Map<String, dynamic>;

                    return Stack(
                      children: [
                        PropertyCard(
  imageUrl: data['imageUrl'] ?? '',
  title: data['title'] ?? '',
  location: data['location'] ?? '',
  price: iqd(data['price']),

  rooms: (data['rooms'] as num?)?.toInt() ?? 0,
  bathrooms: (data['bathrooms'] as num?)?.toInt() ?? 0,
  area: (data['area'] as num?)?.toInt() ?? 0,
  livingRooms: (data['livingRooms'] as num?)?.toInt() ?? 0,
  parking: (data['parking'] as num?)?.toInt() ?? 0,

  description: data['description'] ?? '',
  ownerPhone: data['ownerPhone'] ?? '',
  ownerWhatsapp: data['ownerWhatsapp'] ?? '',
  images: List<dynamic>.from(data['images'] ?? []),
  features: List<dynamic>.from(data['features'] ?? []),

  propertyNumber: (data['adNumber'] as num?)?.toInt() ?? 0,

  availabilityStatus:
      (data['availabilityStatus'] ?? 'available').toString(),

  isFavorite: data['isFavorite'] == true,

  onTap: () {
    debugPrint("HOME IMAGES = ${data['images']}");
    debugPrint("HOME COUNT = ${(data['images'] ?? []).length}");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetails(
          docId: doc.id,

          propertyNumber:
              (data['adNumber'] as num?)?.toInt() ?? 0,

          isFavorite: data['isFavorite'] == true,

          imageUrl: data['imageUrl'] ?? '',
          title: data['title'] ?? '',
          location: data['location'] ?? '',
          price: iqd(data['price']),

          rooms: (data['rooms'] as num?)?.toInt() ?? 0,
          bathrooms: (data['bathrooms'] as num?)?.toInt() ?? 0,
          area: (data['area'] as num?)?.toInt() ?? 0,
          livingRooms:
              (data['livingRooms'] as num?)?.toInt() ?? 0,
          parking: (data['parking'] as num?)?.toInt() ?? 0,

          description: data['description'] ?? '',

          ownerPhone: data['ownerPhone'] ?? '',
          ownerWhatsapp: data['ownerWhatsapp'] ?? '',

          publisherPhone: data['publisherPhone'] ?? '',
          publisherWhatsapp: data['publisherWhatsapp'] ?? '',

          publisherUid:
              (data['publisherUid'] ?? '').toString(),

          publisherName:
              (data['publisherName'] ?? '').toString(),

          publisherEmail:
              (data['publisherEmail'] ?? '').toString(),

          propertyType:
              (data['propertyType'] ?? '').toString(),

          adType:
              (data['adType'] ?? '').toString(),

          city:
              (data['city'] ?? '').toString(),

          areaName:
              (data['areaName'] ?? '').toString(),

          landmark:
              (data['landmark'] ?? '').toString(),

          latitude:
              (data['latitude'] as num?)?.toDouble() ?? 0.0,

          longitude:
              (data['longitude'] as num?)?.toDouble() ?? 0.0,

          availabilityStatus:
              (data['availabilityStatus'] ?? 'available')
                  .toString(),

          isVerified: data['isVerified'] ?? false,
          isFeatured: data['isFeatured'] ?? false,

          views:
              (data['views'] as num?)?.toInt() ?? 0,

          createdAt: data['createdAt'],

          buildYear:
              (data['buildYear'] as num?)?.toInt() ?? 0,

          images: List<dynamic>.from(data['images'] ?? []),
          features: List<dynamic>.from(data['features'] ?? []),

          documentType:
              (data['documentType'] ?? '').toString(),

          furnitureStatus:
              (data['furnitureStatus'] ?? '').toString(),
        ),
      ),
    );
  },

  onFavorite: () async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(doc.id);

    final favDoc = await favRef.get();

    if (favDoc.exists) {
      await favRef.delete();
    } else {
      await favRef.set({
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  },
),

                        // Share button
                        Positioned(
                          top: 10,
                          left: 10,
                          child: IconButton(
                            icon:
                                const Icon(Icons.share, size: 22),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: const CircleBorder(),
                            ),
                            onPressed: () {},
                          ),
                        ),

                        // Admin controls
if (isAdmin)
  Positioned(
    bottom: 15,
    right: 15,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            icon: const Icon(
              Icons.edit,
              color: Colors.blue,
              size: 22,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditPropertyScreen(
                    docId: doc.id,
                    data: data,
                  ),
                ),
              );
            },
          ),
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            icon: const Icon(
              Icons.delete,
              color: Colors.red,
              size: 22,
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('properties')
                  .doc(doc.id)
                  .delete();
            },
          ),
        ],
      ),
    ),
  ),
                      ],
                    );
                  },
                ),
            ],
          );
              },
      ),
    ),
  );
  }
}