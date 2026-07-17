import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/currency.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_view/photo_view.dart';
import '../models/property_model.dart';

class PropertyDetails extends StatefulWidget {
  final PropertyModel? property;
  final String imageUrl;
  final String title;
  final String location;
  final String price;
  final int rooms;
  final int bathrooms;

  final int area;
  final int livingRooms;
  final int parking;

  final String description;
  final String ownerPhone;
  final String ownerWhatsapp;
  final String publisherPhone;
  final String publisherWhatsapp;
  final String publisherUid;
final String publisherName;
final String publisherEmail;
  final List<dynamic> images;
  final List<dynamic> features;
  final String documentType;
final String furnitureStatus;
final String propertyType;
final String adType;

final String city;
final String areaName;
final String landmark;

final double latitude;
final double longitude;

final bool isVerified;
final bool isFeatured;

final String availabilityStatus;

final int views;

final Timestamp? createdAt;

final int buildYear;
final int propertyNumber;
  final String? docId;
  final bool isFavorite;

  const PropertyDetails({
    super.key,
    this.property,
    required this.imageUrl,
    required this.title,
    required this.location,
    required this.price,
    required this.rooms,
    required this.bathrooms,
    required this.area,
    required this.livingRooms,
    required this.parking,
    required this.description,
    required this.ownerPhone,
    required this.ownerWhatsapp,
    required this.publisherUid,
required this.publisherName,
required this.publisherEmail,
    required this.publisherPhone,
    required this.publisherWhatsapp,
   required this.images,
required this.features,

required this.documentType,
required this.furnitureStatus,

required this.propertyType,
required this.adType,

required this.city,
required this.areaName,
required this.landmark,

required this.latitude,
required this.longitude,

required this.isVerified,
required this.isFeatured,

required this.availabilityStatus,

required this.views,

required this.createdAt,

required this.buildYear,
required this.propertyNumber,
this.docId,
this.isFavorite = false,
  });

  @override
  State<PropertyDetails> createState() =>
      _PropertyDetailsState();
}

class _PropertyDetailsState
    extends State<PropertyDetails> {
  late bool favorite;

int activeImage = 0;
bool expandedDescription = false;
final TextEditingController commentController =
    TextEditingController();

    String? replyingToCommentId;

    final TextEditingController replyController =
    TextEditingController();

final CarouselSliderController carouselController =
    CarouselSliderController();

  @override
void initState() {
  super.initState();
  favorite = false;
  loadFavorite();
  increaseViews();
}

@override
void dispose() {
  commentController.dispose();
  replyController.dispose();
  super.dispose();
}
Future<void> loadFavorite() async {

  if (widget.docId == null) return;

  final user =
      FirebaseAuth.instance.currentUser;

  if (user == null) return;

  final doc =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.docId)
          .get();

  if (mounted) {
    setState(() {
      favorite = doc.exists;
    });
  }
}
  Future<void> toggleFavorite() async {

  if (widget.docId == null) return;

  final uid = FirebaseAuth.instance.currentUser!.uid;

  final ref = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('favorites')
      .doc(widget.docId);

  if (favorite) {
    await ref.delete();
  } else {
    await ref.set({
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  setState(() {
    favorite = !favorite;
  });
}

void openGallery(int initialIndex) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PhotoViewGallery.builder(
              itemCount: widget.images.isEmpty
                  ? 1
                  : widget.images.length,
              pageController: PageController(
                initialPage: initialIndex,
              ),
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(
                    widget.images.isEmpty
                        ? widget.imageUrl
                        : widget.images[index],
                  ),
                  minScale:
                      PhotoViewComputedScale.contained,
                  maxScale:
                      PhotoViewComputedScale.covered * 3,
                );
              },
              backgroundDecoration:
                  const BoxDecoration(
                color: Colors.black,
              ),
            ),

            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> increaseViews() async {
  if (widget.docId == null) return;

  await FirebaseFirestore.instance
      .collection('properties')
      .doc(widget.docId)
      .update({
    'views': FieldValue.increment(1),
  });
}

  Future<void> openWhatsApp() async {

  const phone = "9647838081677";

  final message = Uri.encodeComponent(
    "مرحباً، أريد الاستفسار عن العقار: ${widget.title}\n"
    "رقم الإعلان: #${widget.propertyNumber}",
  );

  final url = Uri.parse(
    "https://wa.me/$phone?text=$message",
  );

  await launchUrl(
    url,
    mode: LaunchMode.externalApplication,
  );
}

Future<void> callOffice() async {

  const phone = "07838081677";

  await launchUrl(
    Uri.parse("tel:$phone"),
    mode: LaunchMode.externalApplication,
  );
}

  
Future<void> shareProperty() async {
  await Share.share(
    '''
🏡 ${widget.title}

📍 الموقع: ${widget.location}

💰 💰 السعر: ${iqd(widget.price)}

🛏 عدد الغرف: ${widget.rooms}
🚿 عدد الحمامات: ${widget.bathrooms}

📞 للاستفسار:
${widget.ownerPhone}

🏢 مكتب الاندلس للعقارات
''',
  );
}

  Widget infoCard(
  IconData icon,
  String title,
  String value,
) {
  return SizedBox(
    width: 110,
    child: Container(
      height: 110,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffD4AF37).withOpacity(0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xffD4AF37),
            child: Icon(
              icon,
              color: Colors.black,
              size: 20,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget infoChip(
  IconData icon,
  String text,
) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: const Color(0xff1E293B),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: const Color(0xffD4AF37).withOpacity(0.35),
      ),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xffD4AF37),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> sendComment() async {

  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return;

  if (commentController.text.trim().isEmpty) return;

  await FirebaseFirestore.instance
      .collection("properties")
      .doc(widget.docId)
      .collection("comments")
      .add({

    "text": commentController.text.trim(),

    "userId": user.uid,

    "userName": user.displayName ?? "مستخدم",

    "createdAt": FieldValue.serverTimestamp(),

    "isHidden": false,

    "isPinned": false,

  });

  // إرسال إشعار لصاحب العقار

await FirebaseFirestore.instance
    .collection("notifications")
    .add({

  "userId": widget.publisherUid,

  "title": "تعليق جديد على عقارك",

  "body":
      "${user.displayName ?? "مستخدم"} أضاف تعليقاً على عقارك",

  "propertyId": widget.docId,

  "type": "comment",

  "createdAt": FieldValue.serverTimestamp(),

  "isRead": false,

});

  commentController.clear();
}

Future<void> sendReply(String commentId) async {

  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return;

  if (replyController.text.trim().isEmpty) {
    return;
  }

final commentSnapshot = await FirebaseFirestore.instance
    .collection("properties")
    .doc(widget.docId)
    .collection("comments")
    .doc(commentId)
    .get();

final commentData =
    commentSnapshot.data();

  await FirebaseFirestore.instance
      .collection("properties")
      .doc(widget.docId)
      .collection("comments")
      .doc(commentId)
      .collection("replies")
      .add({

    "text": replyController.text.trim(),

    "userId": user.uid,

    "userName": user.displayName ?? "مستخدم",

    "createdAt": FieldValue.serverTimestamp(),

  });

if (commentData != null &&
    commentData["userId"] != user.uid) {

  await FirebaseFirestore.instance
      .collection("notifications")
      .add({

    "userId": commentData["userId"],

    "title": "تم الرد على تعليقك",

    "body":
        "${user.displayName ?? "مستخدم"} رد على تعليقك",

    "propertyId": widget.docId,

    "type": "reply",

    "createdAt": FieldValue.serverTimestamp(),

    "isRead": false,

  });

}

  replyController.clear();

  setState(() {
    replyingToCommentId = null;
  });

}

Widget commentItem(
  Map<String, dynamic> data,
  String commentId,
) {

  return AnimatedContainer(
  duration: const Duration(milliseconds: 250),
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xff1E293B),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: data["isPinned"] == true
          ? const Color(0xffD4AF37)
          : Colors.white.withOpacity(.05),
      width: data["isPinned"] == true ? 1.5 : 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.18),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const CircleAvatar(
  radius: 24,
          backgroundColor: Color(0xffD4AF37),
          child: Icon(
            Icons.person,
            color: Colors.black,
          ),
        ),

        const SizedBox(width: 14),

if (FirebaseAuth.instance.currentUser?.email ==
    "aysar.aliraqe@gmail.com")
  PopupMenuButton(
    icon: const Icon(
      Icons.more_vert,
      color: Colors.white,
    ),
    itemBuilder: (context) => [

      const PopupMenuItem(
        value: "hide",
        child: Text("إخفاء التعليق"),
      ),

      PopupMenuItem(
  value: "pin",
  child: Text(
    data["isPinned"] == true
        ? "إلغاء تثبيت التعليق"
        : "تثبيت التعليق",
  ),
),

      const PopupMenuItem(
        value: "delete",
        child: Text("حذف التعليق"),
      ),

    ],
    onSelected: (value) async {

      final ref = FirebaseFirestore.instance
          .collection("properties")
          .doc(widget.docId)
          .collection("comments")
          .doc(commentId);

          if (value == "pin") {

  await ref.update({

    "isPinned":
        !(data["isPinned"] ?? false),

  });

}


      if (value == "hide") {

        await ref.update({
          "isHidden": true,
        });

      }


      if (value == "delete") {

        await ref.delete();

      }

    },
  ),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                data["userName"] ?? "مستخدم",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              if (data["isPinned"] == true)
  const Text(
    "📌 تعليق مثبت",
    style: TextStyle(
      color: Color(0xffD4AF37),
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
  ),

              const SizedBox(height: 6),

              Text(
  data["text"] ?? "",
  style: const TextStyle(
    color: Colors.white70,
    fontSize: 15,
  ),
),

const SizedBox(height: 6),

Text(
  timeAgo(data["createdAt"]),
  style: const TextStyle(
    color: Colors.grey,
    fontSize: 12,
  ),
),

const SizedBox(height: 8),

TextButton.icon(
  onPressed: () {

  setState(() {
    replyingToCommentId = commentId;
  });

},
  icon: const Icon(
    Icons.reply,
    size: 18,
    color: Color(0xffD4AF37),
  ),
  label: const Text(
    "رد",
    style: TextStyle(
      color: Color(0xffD4AF37),
    ),
  ),
),

if (replyingToCommentId == commentId)
  Container(
  margin: const EdgeInsets.only(top: 12),
  padding: const EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 4,
  ),
  decoration: BoxDecoration(
    color: const Color(0xff0F172A),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xffD4AF37).withOpacity(.20),
    ),
  ),
    child: Row(
      children: [

        Expanded(
          child: TextField(
  controller: replyController,
  style: const TextStyle(
    color: Colors.white,
  ),
            decoration: const InputDecoration(
  hintText: "اكتب ردك...",
  hintStyle: TextStyle(
    color: Colors.white54,
  ),
  border: InputBorder.none,
),
          ),
        ),

        Container(
  margin: const EdgeInsets.all(4),
  decoration: const BoxDecoration(
    color: Color(0xffD4AF37),
    shape: BoxShape.circle,
  ),
  child: IconButton(
    onPressed: () {
      sendReply(commentId);
    },
    icon: const Icon(
      Icons.send_rounded,
      color: Colors.black,
    ),
  ),
),

      ],
    ),
  ),

  StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection("properties")
      .doc(widget.docId)
      .collection("comments")
      .doc(commentId)
      .collection("replies")
      .orderBy("createdAt", descending: true)
      .snapshots(),

  builder: (context, snapshot) {

    if (!snapshot.hasData ||
        snapshot.data!.docs.isEmpty) {
      return const SizedBox();
    }

    return Column(
      children: snapshot.data!.docs.map((doc) {

        final reply =
            doc.data() as Map<String, dynamic>;

        return Container(
  margin: const EdgeInsets.only(
    top: 10,
    right: 28,
    left: 6,
  ),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: const Color(0xff0F172A),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xffD4AF37).withOpacity(.15),
    ),
  ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              Row(
  children: [
    const CircleAvatar(
      radius: 12,
      backgroundColor: Color(0xffD4AF37),
      child: Icon(
        Icons.person,
        size: 14,
        color: Colors.black,
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        reply["userName"] ?? "مستخدم",
        style: const TextStyle(
          color: Color(0xffD4AF37),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    ),
  ],
),

              const SizedBox(height: 4),

              Text(
                reply["text"] ?? "",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),

            ],
          ),
        );

      }).toList(),
    );

  },
),

            ],
          ),
        ),

      ],
    ),
  );
}

String timeAgo(dynamic timestamp) {
  if (timestamp == null) {
    return "الآن";
  }

  final date = timestamp.toDate();
  final now = DateTime.now();

  final difference = now.difference(date);

  if (difference.inMinutes < 1) {
    return "الآن";
  } else if (difference.inMinutes < 60) {
    return "قبل ${difference.inMinutes} دقيقة";
  } else if (difference.inHours < 24) {
    return "قبل ${difference.inHours} ساعة";
  } else if (difference.inDays < 7) {
    return "قبل ${difference.inDays} يوم";
  } else {
    return "${date.day}/${date.month}/${date.year}";
  }
}

  @override
  Widget build(BuildContext context) {
    print("PROPERTY DETAILS SCREEN OPENED");

    debugPrint("IMAGES = ${widget.images}");
  debugPrint("COUNT = ${widget.images.length}");
  debugPrint("TYPE = ${widget.images.runtimeType}");
  
  
    final isAdmin =
    FirebaseAuth.instance.currentUser?.email ==
    "aysar.aliraqe@gmail.com";

final bool showRooms =
    widget.propertyType == "بيت" ||
    widget.propertyType == "شقة";

final bool showArea =
    widget.propertyType != "محل";

final bool showLiving =
    widget.propertyType == "بيت" ||
    widget.propertyType == "شقة";

final bool showParking =
    widget.propertyType == "بيت" ||
    widget.propertyType == "شقة" ||
    widget.propertyType == "عمارة";

    return Scaffold(
  backgroundColor:
      Theme.of(context).scaffoldBackgroundColor,

  body: SingleChildScrollView(
        child: Column(
          children: [

            Stack(
              children: [

                CarouselSlider.builder(
  carouselController: carouselController,
  itemCount: widget.images.isEmpty
      ? 1
      : widget.images.length,

  options: CarouselOptions(
  height: 360,
  viewportFraction: 1.0,
  enableInfiniteScroll: true,
  enlargeCenterPage: false,

  autoPlay: true,
  autoPlayInterval: const Duration(seconds: 3),
  autoPlayAnimationDuration: const Duration(milliseconds: 800),
  autoPlayCurve: Curves.fastOutSlowIn,
  pauseAutoPlayOnTouch: false,
  pauseAutoPlayOnManualNavigate: false,

  onPageChanged: (index, reason) {
    setState(() {
      activeImage = index;
    });
  },
),
  itemBuilder: (_, index, __) {
    return GestureDetector(
  onTap: () => openGallery(index),
  child: Image.network(
    widget.images.isEmpty
        ? widget.imageUrl
        : widget.images[index],
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Container(
      color: Colors.grey,
      child: const Icon(
        Icons.home,
        size: 80,
      ),
    ),
  ),
);
  },
),

Positioned(
  top: 20,
  right: 70,
  child: Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 6,
    ),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      "${activeImage + 1}/${widget.images.isEmpty ? 1 : widget.images.length}"
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),

                IgnorePointer(
  child: Container(
    height: 360,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.black54,
          Colors.transparent,
        ],
      ),
    ),
  ),
),

Positioned(
  bottom: 12,
  left: 0,
  right: 0,
  child: Center(
    child: AnimatedSmoothIndicator(
      activeIndex: activeImage,
      count: widget.images.isEmpty ? 1 : widget.images.length,
      effect: const ExpandingDotsEffect(
        dotHeight: 8,
        dotWidth: 8,
        expansionFactor: 3,
      ),
    ),
  ),
),
                SafeArea(
  child: Padding(
    padding: const EdgeInsets.all(15),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        // زر الرجوع
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),

        Row(
          children: [

            // زر المشاركة
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.share_rounded,
                  color: Colors.white,
                ),
                onPressed: shareProperty,
              ),
            ),

            const SizedBox(width: 12),

            // زر المفضلة
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              child: IconButton(
                icon: Icon(
                  favorite
                      ? Icons.favorite
                      : Icons.favorite_border_rounded,
                  color: favorite
                      ? Colors.redAccent
                      : Colors.white,
                ),
                onPressed: toggleFavorite,
              ),
            ),

          ],
        ),
      ],
    ),
  ),
),

                          Positioned(
  bottom: 28,
  left: 20,
  child: Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 8,
    ),

    decoration: BoxDecoration(
      color: const Color(0xffD4AF37),

      borderRadius:
          BorderRadius.circular(18),

      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),

    child: Text(
      "#${widget.propertyNumber}",

      style: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),

Positioned(
  bottom: 28,
  right: 20,
  child: Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: const Color(0xffD4AF37),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Text(
      widget.price,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
),

Positioned(
  bottom: 70,
  left: 0,
  right: 0,
  child: Center(
    child: Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 10,
  ),
  decoration: BoxDecoration(
    color: widget.availabilityStatus == 'available'
        ? const Color(0xff1F8A4C)
        : widget.availabilityStatus == 'reserved'
            ? const Color(0xffD9822B)
            : const Color(0xffC0392B),

    borderRadius: BorderRadius.circular(30),

    border: Border.all(
      color: const Color(0xffD4AF37),
      width: 1.3,
    ),

    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.35),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
    ],
  ),

  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [

      Icon(
        widget.availabilityStatus == 'available'
            ? Icons.check_circle_rounded
            : widget.availabilityStatus == 'reserved'
                ? Icons.access_time_filled_rounded
                : Icons.cancel_rounded,
        color: Colors.white,
        size: 20,
      ),

      const SizedBox(width: 8),

      Text(
        widget.availabilityStatus == 'available'
            ? "متوفر"
            : widget.availabilityStatus == 'reserved'
                ? "محجوز"
                : "تم البيع",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),

    ],
  ),
)

],
),
Container(
  width: double.infinity,
  margin: const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 15,
  ),
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0xff1E293B),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: const Color(0xffD4AF37).withOpacity(.20),
    ),
  ),
  child: Wrap(
    spacing: 14,
    runSpacing: 14,
    children: [

      if (widget.isVerified)
        infoChip(
          Icons.verified,
          "عقار موثق",
        ),

      if (widget.isFeatured)
        infoChip(
          Icons.star,
          "عقار مميز",
        ),

      infoChip(
        Icons.remove_red_eye,
        "${widget.views} مشاهدة",
      ),

      infoChip(
        Icons.calendar_month,
        widget.createdAt == null
            ? "بدون تاريخ"
            : "${widget.createdAt!.toDate().day}/${widget.createdAt!.toDate().month}/${widget.createdAt!.toDate().year}",
      ),

    ],
  ),
),

            Padding(
              padding:
                  const EdgeInsets
                      .all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [

                  Text(
  widget.title,
  style: const TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.3,
    letterSpacing: .2,
  ),
),

const SizedBox(height: 10),

Row(
  children: [
    const Icon(
      Icons.location_on_rounded,
      color: Color(0xffD4AF37),
      size: 18,
    ),
    const SizedBox(width: 6),

    Expanded(
      child: Text(
        widget.location,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.white70,
        ),
      ),
    ),
  ],
),

const SizedBox(height: 18),

Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  ),
  decoration: BoxDecoration(
    color: const Color(0xff162033),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: const Color(0xffD4AF37).withOpacity(.25),
    ),
  ),
  child: Row(
    children: [
      const Icon(
        Icons.payments_rounded,
        color: Color(0xffD4AF37),
      ),

      const SizedBox(width: 12),

      Expanded(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "السعر",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              iqd(widget.price),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xffD4AF37),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),

const SizedBox(height: 20),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: const Color(0xff1E293B),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: const Color(0xffD4AF37).withOpacity(.20),
    ),
  ),
  child: Column(
    children: [

      Row(
        children: [

          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xffD4AF37),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [

                  const Icon(
                    Icons.sell_rounded,
                    color: Colors.black,
                    size: 28,
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "نوع الإعلان",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),

                  Text(
                    widget.adType,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xff162033),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xffD4AF37).withOpacity(.25),
                ),
              ),
              child: Column(
                children: [

                  const Icon(
                    Icons.home_work_rounded,
                    color: Color(0xffD4AF37),
                    size: 28,
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "نوع العقار",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),

                  Text(
                    widget.propertyType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                ],
              ),
            ),
          ),

        ],
      ),

      const SizedBox(height: 20),

      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [

          if (widget.city.isNotEmpty)
            infoChip(
              Icons.location_city_rounded,
              "المدينة • ${widget.city}",
            ),

          if (widget.areaName.isNotEmpty)
            infoChip(
              Icons.map_rounded,
              "المنطقة • ${widget.areaName}",
            ),

          if (widget.landmark.isNotEmpty)
            infoChip(
              Icons.place_rounded,
              "أقرب نقطة • ${widget.landmark}",
            ),

        ],
      ),

    ],
  ),
),

const SizedBox(height: 25),

                  // تفاصيل العقار بشكل عمودي

Wrap(
  spacing: 14,
  runSpacing: 14,
  children: [

    if (showRooms)
      infoCard(
        Icons.bed,
        "غرف",
        widget.rooms.toString(),
      ),

    if (showRooms)
      infoCard(
        Icons.bathtub,
        "حمامات",
        widget.bathrooms.toString(),
      ),

    if (showArea)
      infoCard(
        Icons.square_foot,
        "المساحة",
        "${widget.area} م²",
      ),

    if (showLiving)
      infoCard(
        Icons.weekend,
        "مجالس",
        widget.livingRooms.toString(),
      ),

    if (showParking)
      infoCard(
        Icons.directions_car,
        "مواقف",
        widget.parking.toString(),
      ),

  ],
),

const SizedBox(height: 30),

Row(
  children: [
    const Icon(
      Icons.info_outline_rounded,
      color: Color(0xffD4AF37),
      size: 24,
    ),
    const SizedBox(width: 10),
    const Text(
      "معلومات إضافية",
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
),

const SizedBox(height: 18),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0xff1E293B),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: const Color(0xffD4AF37).withOpacity(.20),
    ),
  ),
  child: Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [

      infoChip(
        Icons.calendar_month_rounded,
        widget.buildYear == 0
            ? "سنة البناء: غير محدد"
            : "سنة البناء: ${widget.buildYear}",
      ),

      infoChip(
        Icons.description_rounded,
        widget.documentType.isEmpty
            ? "نوع السند: غير محدد"
            : "نوع السند: ${widget.documentType}",
      ),

      infoChip(
        Icons.chair_rounded,
        widget.furnitureStatus.isEmpty
            ? "التأثيث: غير محدد"
            : "التأثيث: ${widget.furnitureStatus}",
      ),

    ],
  ),
),

const SizedBox(
  height: 30),

                  const Text(
  "وصف العقار",
  style: TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 15),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(22),
  decoration: BoxDecoration(
    color: const Color(0xff1A2434),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: const Color(0xffD4AF37).withOpacity(.20),
    ),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      Container(
        width: 5,
        height: expandedDescription ? 180 : 120,
        decoration: BoxDecoration(
          color: const Color(0xffD4AF37),
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      const SizedBox(width: 18),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: const [

                Icon(
                  Icons.description_rounded,
                  color: Color(0xffD4AF37),
                  size: 22,
                ),

                SizedBox(width: 8),

                Text(
                  "تفاصيل العقار",
                  style: TextStyle(
                    color: Color(0xffD4AF37),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              ],
            ),

            const SizedBox(height: 18),

            Text(
              widget.description.isEmpty
                  ? "لا يوجد وصف لهذا العقار."
                  : widget.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                height: 1.9,
              ),
              maxLines: expandedDescription ? null : 5,
              overflow: expandedDescription
                  ? null
                  : TextOverflow.ellipsis,
            ),

            if (widget.description.length > 150)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      expandedDescription =
                          !expandedDescription;
                    });
                  },
                  icon: Icon(
                    expandedDescription
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xffD4AF37),
                  ),
                  label: Text(
                    expandedDescription
                        ? "إخفاء"
                        : "عرض المزيد",
                    style: const TextStyle(
                      color: Color(0xffD4AF37),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

          ],
        ),
      ),

    ],
  ),
),

                  const SizedBox(
                      height: 20),

                  Row(
  children: const [

    Icon(
      Icons.workspace_premium_rounded,
      color: Color(0xffD4AF37),
      size: 24,
    ),

    SizedBox(width: 10),

    Text(
      "المميزات",
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),

  ],
),

                  const SizedBox(height: 18),

                  Wrap(
  spacing: 14,
  runSpacing: 14,
  children: widget.features.map((e) {

    IconData icon = Icons.check_circle_outline;

    final text = e.toString();

    if (text.contains("مسبح")) {
      icon = Icons.pool_rounded;
    } else if (text.contains("حديقة")) {
      icon = Icons.park_rounded;
    } else if (text.contains("مصعد")) {
      icon = Icons.elevator_rounded;
    } else if (text.contains("كراج")) {
      icon = Icons.garage_rounded;
    } else if (text.contains("مطبخ")) {
      icon = Icons.kitchen_rounded;
    } else if (text.contains("كاميرا")) {
      icon = Icons.videocam_rounded;
    } else if (text.contains("مكيف")) {
      icon = Icons.ac_unit_rounded;
    } else if (text.contains("شرفة")) {
      icon = Icons.balcony_rounded;
    } else if (text.contains("أمن")) {
      icon = Icons.security_rounded;
    }

    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff182233),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffD4AF37).withOpacity(.25),
        ),
      ),
      child: Row(
        children: [

          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xffD4AF37).withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xffD4AF37),
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),

        ],
      ),
    );

  }).toList(),
),
if (isAdmin)
  Column(
    children: [

      const Text(
        "بيانات صاحب العقار",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 10),

      Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: const Color(0xff1E293B),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: const Color(0xffD4AF37).withOpacity(.25),
    ),
  ),
  child: Column(
    children: [

      ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xffD4AF37),
          child: Icon(
            Icons.person,
            color: Colors.black,
          ),
        ),
        title: const Text(
          "اسم الناشر",
          style: TextStyle(color: Colors.white60),
        ),
        subtitle: Text(
          widget.publisherName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      const Divider(),

      ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xffD4AF37),
          child: Icon(
            Icons.phone,
            color: Colors.black,
          ),
        ),
        title: const Text(
          "رقم الهاتف",
          style: TextStyle(color: Colors.white60),
        ),
        subtitle: Text(
          widget.ownerPhone,
          style: const TextStyle(color: Colors.white),
        ),
      ),

      const Divider(),

      ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xffD4AF37),
          child: Icon(
            Icons.email,
            color: Colors.black,
          ),
        ),
        title: const Text(
          "البريد الإلكتروني",
          style: TextStyle(color: Colors.white60),
        ),
        subtitle: Text(
          widget.publisherEmail,
          style: const TextStyle(color: Colors.white),
        ),
      ),

      const Divider(),

      ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xffD4AF37),
          child: Icon(
            Icons.badge,
            color: Colors.black,
          ),
        ),
        title: const Text(
          "UID",
          style: TextStyle(color: Colors.white60),
        ),
        subtitle: SelectableText(
          widget.publisherUid,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
            ),
    ],
  ),
),

const SizedBox(height: 40),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0xff1E293B),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: const Color(0xffD4AF37).withOpacity(.25),
    ),
  ),
  child: const Row(
    children: [

      CircleAvatar(
        backgroundColor: Color(0xffD4AF37),
        child: Icon(
          Icons.support_agent_rounded,
          color: Colors.black,
        ),
      ),

      SizedBox(width: 14),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              "التواصل مع مكتب الاندلس",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            SizedBox(height: 4),

            Text(
              "جميع الاستفسارات تتم عن طريق المكتب",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
              ),
            ),

          ],
        ),
      ),

    ],
  ),
),

const SizedBox(height: 20),

    ],
  ),
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0xff1E293B),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: const Color(0xffD4AF37).withOpacity(0.4),
    ),
  ),

  child: Column(
    children: [

      Row(
  children: [

    Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xffD4AF37),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.business_rounded,
        color: Colors.black,
        size: 30,
      ),
    ),

    const SizedBox(width: 16),

    const Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            "التواصل مع",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
            ),
          ),

          SizedBox(height: 4),

          Text(
            "مكتب الأندلس للعقارات",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

        ],
      ),
    ),

  ],
),


      const SizedBox(height: 18),

      Container(
  margin: const EdgeInsets.symmetric(vertical: 20),
  height: 1,
  color: Colors.white10,
),


      const SizedBox(height: 15),


     Row(
  children: [

    Expanded(
      child: SizedBox(
        height: 58,
        child: ElevatedButton.icon(
          onPressed: openWhatsApp,
          icon: const Icon(
            Icons.chat_bubble_rounded,
            color: Colors.white,
            size: 22,
          ),
          label: const Text(
            "واتساب",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 8,
            shadowColor: Colors.black45,
            backgroundColor: const Color(0xff25D366),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    ),

    const SizedBox(width: 14),

    Expanded(
      child: SizedBox(
        height: 58,
        child: ElevatedButton.icon(
          onPressed: callOffice,
          icon: const Icon(
            Icons.call_rounded,
            color: Colors.black,
            size: 22,
          ),
          label: const Text(
            "اتصال",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 8,
            shadowColor: Colors.black45,
            backgroundColor: const Color(0xffD4AF37),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    ),

  ],
),


      const SizedBox(height: 18),


      const Divider(
        color: Colors.white24,
      ),


      const SizedBox(height: 10),


      const Text(
        "أوقات العمل: يومياً\n9:00 صباحاً - 9:00 مساءً",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.6,
        ),
      ),

    ],
  ),
),

const SizedBox(height: 30),

StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection("properties")
      .doc(widget.docId)
      .collection("comments")
      .snapshots(),

  builder: (context, snapshot) {

    int count = 0;

    if (snapshot.hasData) {
      count = snapshot.data!.docs
          .where((doc) {
            final data =
                doc.data() as Map<String, dynamic>;

            return data["isHidden"] != true;
          })
          .length;
    }

    return Row(
  children: [

    Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xffD4AF37),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.forum_rounded,
        color: Colors.black,
      ),
    ),

    const SizedBox(width: 14),

    Expanded(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          const Text(
            "التعليقات",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          Text(
            "$count تعليق",
            style: const TextStyle(
              color: Colors.white60,
             ),
),

        ],
      ),
    ),

  ],
);
  },
),

const SizedBox(height: 15),

Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  ),
  decoration: BoxDecoration(
    color: const Color(0xff1E293B),
    borderRadius: BorderRadius.circular(18),
  ),
  child: Row(
    children: [

      const CircleAvatar(
  radius: 24,
  backgroundColor: Color(0xffD4AF37),
  child: Icon(
    Icons.person,
    color: Colors.black,
  ),
),

      const SizedBox(width: 12),

      Expanded(
        child: TextField(
          controller: commentController,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "اكتب تعليقك...",
            border: InputBorder.none,
          ),
        ),
      ),

      Container(
  decoration: const BoxDecoration(
    color: Color(0xffD4AF37),
    shape: BoxShape.circle,
  ),
  child: IconButton(
    onPressed: sendComment,
    icon: const Icon(
      Icons.send_rounded,
      color: Colors.black,
    ),
  ),
),
            ],
  ),
),

const SizedBox(height: 20),

StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection("properties")
      .doc(widget.docId)
      .collection("comments")
      
      .orderBy("createdAt", descending: true)
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
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "لا توجد تعليقات حتى الآن",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (context, index) {

        final data =
            docs[index].data() as Map<String, dynamic>;
            if (data["isHidden"] == true) {
  return const SizedBox();
}

        return commentItem(
  data,
  docs[index].id,
);

      },
    );
  },
),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget detailRow(
  IconData icon,
  String title,
  String value,
) {
  return Row(
    children: [

      Icon(
        icon,
        color: const Color(0xffD4AF37),
        size: 25,
      ),

      const SizedBox(width: 15),

      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ),

      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),

    ],
  );
}


Widget detailDivider() {
  return const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(
      color: Colors.white24,
      height: 1,
    ),
  );
}
}