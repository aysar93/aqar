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
import '../services/favorites_service.dart';
import '../features/property_map/models/property_location.dart';
import '../features/property_map/screens/property_location_screen.dart';
import 'publisher_properties_screen.dart';
import '../core/design/aqar_sizes.dart';
import '../core/design/aqar_text.dart';
import '../office/screens/office_profile_screen.dart';

class PropertyDetails extends StatefulWidget {
  final PropertyModel? property;
  final String imageUrl;
  final String title;
  final String location;
  final String price;
  final bool negotiable;
  final int rooms;
  final int bathrooms;

  final int area;
  final double? frontage;
  final double? depth;
  final int? floors;
  final int? apartmentFloor;
  final int? unitsCount;
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
    this.negotiable = false,
    required this.rooms,
    required this.bathrooms,
    required this.area,
    this.frontage,
    this.depth,
    this.floors,
    this.apartmentFloor,
    this.unitsCount,
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
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  late bool favorite;

  // بيانات الناشر
  Map<String, dynamic>? publisherData;
  bool publisherLoading = true;

  // بيانات جهة التواصل مع الإعلان (مكتب أو ناشر شخصي)
  bool contactLoading = true;
  bool isOfficeProperty = false;
  String contactName = '';
  String contactPhone = '';
  String contactWhatsapp = '';
  String contactLogo = '';
  String? contactOfficeId;

  int activeImage = 0;
  bool expandedDescription = false;
  int currentViews = 0;

  bool showComments = false;

  final TextEditingController commentController = TextEditingController();

  String? replyingToCommentId;

  final TextEditingController replyController = TextEditingController();

  final CarouselSliderController carouselController =
      CarouselSliderController();

  final Map<String, bool> expandedReplies = {};
  bool isRepliesExpanded(String commentId) {
    return expandedReplies[commentId] ?? false;
  }

  @override
  void initState() {
    super.initState();

    favorite = false;
    currentViews = widget.views;

    loadFavorite();
    increaseViews();
    _loadPublisherData();
    _loadContactData();
  }

  @override
  void dispose() {
    commentController.dispose();
    replyController.dispose();
    super.dispose();
  }

  // جلب بيانات ناشر الإعلان من مجموعة users
  Future<void> _loadPublisherData() async {
    final String uid = widget.publisherUid.trim();

    // في حال لم يكن للإعلان ناشر مسجل
    if (uid.isEmpty) {
      if (!mounted) return;

      setState(() {
        publisherData = null;
        publisherLoading = false;
      });

      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!mounted) return;

      setState(() {
        publisherData = doc.exists ? doc.data() : null;
        publisherLoading = false;
      });
    } catch (e) {
      debugPrint("LOAD PUBLISHER ERROR: $e");

      if (!mounted) return;

      setState(() {
        publisherData = null;
        publisherLoading = false;
      });
    }
  }

  Future<void> _loadContactData() async {
    try {
      Map<String, dynamic> propertyData = {};

      if (widget.docId != null && widget.docId!.trim().isNotEmpty) {
        final propertyDoc = await FirebaseFirestore.instance
            .collection('properties')
            .doc(widget.docId)
            .get();
        propertyData = propertyDoc.data() ?? {};
      }

      final officeId = (propertyData['officeId'] ?? '').toString().trim();
      final officeFlag = propertyData['isOfficeProperty'] == true;
      final officeName = (propertyData['officeName'] ?? '').toString().trim();
      final officePhone = (propertyData['officePhone'] ?? '').toString().trim();
      final officeWhatsapp =
          (propertyData['officeWhatsapp'] ?? '').toString().trim();
      final officeLogo =
          (propertyData['officeLogo'] ?? propertyData['officeLogoUrl'] ?? '')
              .toString()
              .trim();

      Map<String, dynamic> officeData = {};
      if (officeId.isNotEmpty) {
        final officeDoc = await FirebaseFirestore.instance
            .collection('offices')
            .doc(officeId)
            .get();
        officeData = officeDoc.data() ?? {};
      }

      final resolvedIsOffice =
          officeFlag || officeId.isNotEmpty || officeName.isNotEmpty;

      final resolvedName = resolvedIsOffice
          ? ((officeData['name'] ?? officeData['officeName'] ?? officeName)
              .toString()
              .trim())
          : widget.publisherName.trim().isNotEmpty
              ? widget.publisherName.trim()
              : (publisherData?['name'] ?? 'صاحب العقار').toString().trim();

      final resolvedPhone = resolvedIsOffice
          ? ((officeData['phone'] ?? officeData['phoneNumber'] ?? officePhone)
              .toString()
              .trim())
          : (widget.ownerPhone.trim().isNotEmpty
              ? widget.ownerPhone.trim()
              : widget.publisherPhone.trim());

      final resolvedWhatsapp = resolvedIsOffice
          ? ((officeData['whatsapp'] ??
                  officeData['whatsappNumber'] ??
                  officeWhatsapp)
              .toString()
              .trim())
          : (widget.ownerWhatsapp.trim().isNotEmpty
              ? widget.ownerWhatsapp.trim()
              : widget.publisherWhatsapp.trim());

      final resolvedLogo = resolvedIsOffice
          ? ((officeData['logoUrl'] ?? officeData['logo'] ?? officeLogo)
              .toString()
              .trim())
          : (publisherData?['photoUrl'] ?? '').toString().trim();

      if (!mounted) return;

      setState(() {
        isOfficeProperty = resolvedIsOffice;
        contactOfficeId = officeId.isEmpty ? null : officeId;
        contactName = resolvedName.isEmpty
            ? (resolvedIsOffice ? 'المكتب العقاري' : 'صاحب العقار')
            : resolvedName;
        contactPhone = resolvedPhone;
        contactWhatsapp = resolvedWhatsapp;
        contactLogo = resolvedLogo;
        contactLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD CONTACT ERROR: $e');

      if (!mounted) return;

      setState(() {
        isOfficeProperty = false;
        contactName = widget.publisherName.trim().isNotEmpty
            ? widget.publisherName.trim()
            : 'صاحب العقار';
        contactPhone = widget.ownerPhone.trim().isNotEmpty
            ? widget.ownerPhone.trim()
            : widget.publisherPhone.trim();
        contactWhatsapp = widget.ownerWhatsapp.trim().isNotEmpty
            ? widget.ownerWhatsapp.trim()
            : widget.publisherWhatsapp.trim();
        contactLogo = (publisherData?['photoUrl'] ?? '').toString().trim();
        contactLoading = false;
      });
    }
  }

  String _contactPhoneForCall() {
    return contactPhone.trim();
  }

  Future<void> callContact() async {
    final phone = _contactPhoneForCall();
    if (phone.isEmpty) return;
    await callNumber(phone);
  }

  Future<void> whatsappContact() async {
    final phone = contactWhatsapp.trim().isNotEmpty
        ? contactWhatsapp.trim()
        : contactPhone.trim();
    if (phone.isEmpty) return;
    await openWhatsapp(phone);
  }

  String _publisherJoinDate() {
    final value = publisherData?['createdAt'];

    if (value is! Timestamp) {
      return '';
    }

    final date = value.toDate();

    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    return 'عضو منذ ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildPublisherCard() {
    const gold = Color(0xffD4AF37);
    const cardColor = Color(0xff1E293B);

    // أثناء تحميل بيانات الناشر
    if (publisherLoading) {
      return Container(
        width: double.infinity,
        height: 96,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withValues(alpha: .25)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: gold, strokeWidth: 2.5),
        ),
      );
    }

    final data = publisherData;

    // =====================================================
    // تحديد بيانات الناشر حسب نوع العقار
    // =====================================================

    final bool isOffice = isOfficeProperty;

    // إذا كان العقار تابعًا لمكتب:
    // نستخدم اسم المكتب وصورته التي تم تحميلها في contactName/contactLogo.
    //
    // إذا كان العقار تابعًا لمستخدم عادي:
    // نستخدم بيانات حساب المستخدم publisherData،
    // ثم نرجع إلى البيانات المحفوظة داخل الإعلان عند الحاجة.

    final String name = isOffice
        ? (contactName.trim().isNotEmpty ? contactName.trim() : 'مكتب عقاري')
        : ((data?['name'] ?? '').toString().trim().isNotEmpty
            ? (data?['name'] ?? '').toString().trim()
            : (widget.publisherName.trim().isNotEmpty
                ? widget.publisherName.trim()
                : 'ناشر العقار'));

    final String photoUrl = isOffice
        ? contactLogo.trim()
        : ((data?['photoUrl'] ?? '').toString().trim().isNotEmpty
            ? (data?['photoUrl'] ?? '').toString().trim()
            : (data?['photo'] ?? '').toString().trim());

    final bool verified = data?['isVerified'] == true;

    final String accountLabel = isOffice ? 'مكتب عقاري' : 'ناشر العقار';

    final String joinDate = _publisherJoinDate();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: gold.withValues(alpha: .28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // صورة الناشر
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: gold, width: 1.5),
                  ),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xff0F172A),
                    backgroundImage:
                        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Icon(
                            isOffice
                                ? Icons.business_rounded
                                : Icons.person_rounded,
                            color: gold,
                            size: 32,
                          )
                        : null,
                  ),
                ),

                const SizedBox(width: 14),

                // الاسم ونوع الحساب
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                    MediaQuery.of(context).size.width < 380
                                        ? 14
                                        : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: gold,
                              size: 19,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            isOffice
                                ? Icons.business_center_rounded
                                : Icons.campaign_rounded,
                            size: 15,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              joinDate.isNotEmpty
                                  ? '$accountLabel  •  $joinDate'
                                  : accountLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize:
                                    MediaQuery.of(context).size.width < 380
                                        ? 9
                                        : 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // زر مستقل حتى يبقى اسم الناشر ظاهرًا بعرض البطاقة الكامل
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: gold,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: gold.withValues(alpha: .28)),
                  ),
                  backgroundColor: gold.withValues(alpha: .10),
                ),
                onPressed: () {
                  // إذا كان العقار تابعًا لمكتب
                  if (isOfficeProperty &&
                      contactOfficeId != null &&
                      contactOfficeId!.trim().isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OfficeProfileScreen(
                          officeId: contactOfficeId!.trim(),
                        ),
                      ),
                    );

                    return;
                  }

                  // إذا كان العقار تابعًا لمستخدم عادي
                  if (widget.publisherUid.trim().isEmpty) {
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublisherPropertiesScreen(
                        publisherUid: widget.publisherUid.trim(),
                        publisherName: name,
                        publisherPhotoUrl: photoUrl,
                        isVerified: verified,
                      ),
                    ),
                  );
                },
                child: Text(
                  isOffice ? 'عرض عقارات المكتب' : 'عرض عقارات الناشر',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            Container(height: 1, color: Colors.white.withValues(alpha: .07)),

            const SizedBox(height: 14),

            // =================================================
            // أزرار التواصل - تظهر لجميع المستخدمين
            // =================================================
            Row(
              children: [
                // زر الاتصال
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: contactPhone.trim().isEmpty
                          ? null
                          : () {
                              callContact();
                            },
                      icon: const Icon(Icons.phone_rounded, size: 19),
                      label: const Text(
                        'اتصال',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: gold,
                        disabledForegroundColor: Colors.white24,
                        side: BorderSide(
                          color: contactPhone.trim().isNotEmpty
                              ? gold.withValues(alpha: .45)
                              : Colors.white12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // زر واتساب
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: contactWhatsapp.trim().isEmpty
                          ? null
                          : () {
                              openWhatsapp(contactWhatsapp);
                            },
                      icon: const Icon(Icons.chat_rounded, size: 19),
                      label: const Text(
                        'واتساب',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white10,
                        disabledForegroundColor: Colors.white24,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> loadFavorite() async {
    final user = FirebaseAuth.instance.currentUser;

    // الضيف لا يملك مفضلة
    if (user == null) {
      if (mounted) {
        setState(() {
          favorite = false;
        });
      }
      return;
    }

    if (widget.docId == null || widget.docId!.isEmpty) return;

    try {
      final isFav = await FavoritesService.isFavorite(widget.docId!);

      if (mounted) {
        setState(() {
          favorite = isFav;
        });
      }
    } catch (e) {
      debugPrint("LOAD FAVORITE ERROR: $e");

      if (mounted) {
        setState(() {
          favorite = false;
        });
      }
    }
  }

  Future<void> toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;

    // الضيف
    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "يجب تسجيل الدخول لإضافة العقار إلى المفضلة",
            textAlign: TextAlign.right,
          ),
          backgroundColor: Color(0xff1E293B),
        ),
      );

      return;
    }

    if (widget.docId == null || widget.docId!.isEmpty) return;

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(widget.docId);

      if (favorite) {
        await ref.delete();
      } else {
        await ref.set({'createdAt': FieldValue.serverTimestamp()});
      }

      if (!mounted) return;

      setState(() {
        favorite = !favorite;
      });
    } catch (e) {
      debugPrint("TOGGLE FAVORITE ERROR: $e");
    }
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
                itemCount: widget.images.isEmpty ? 1 : widget.images.length,
                pageController: PageController(initialPage: initialIndex),
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: (widget.images.isEmpty
                                ? widget.imageUrl
                                : widget.images[index])
                            .toString()
                            .startsWith('assets/')
                        ? AssetImage(
                            widget.images.isEmpty
                                ? widget.imageUrl
                                : widget.images[index],
                          )
                        : NetworkImage(
                            widget.images.isEmpty
                                ? widget.imageUrl
                                : widget.images[index],
                          ) as ImageProvider,
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                  );
                },
                backgroundDecoration: const BoxDecoration(color: Colors.black),
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
    final docId = widget.docId?.trim();

    if (docId == null || docId.isEmpty) {
      debugPrint('INCREASE VIEWS: docId is empty');
      return;
    }

    try {
      final propertyRef =
          FirebaseFirestore.instance.collection('properties').doc(docId);

      await propertyRef.update({'views': FieldValue.increment(1)});

      if (mounted) {
        setState(() {
          currentViews++;
        });
      }

      debugPrint('INCREASE VIEWS: success for $docId');
    } catch (e) {
      debugPrint('INCREASE VIEWS ERROR: $e');
    }
  }

  Future<void> callNumber(String phone) async {
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleanedPhone.isEmpty) return;

    await launchUrl(
      Uri.parse('tel:$cleanedPhone'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> openWhatsapp(String phone) async {
    String cleanedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedPhone.isEmpty) return;

    // 078xxxxxxxx -> 96478xxxxxxxx
    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = '964${cleanedPhone.substring(1)}';
    }

    final message = Uri.encodeComponent(
      'مرحباً، أريد الاستفسار عن العقار: ${widget.title}\n'
      'رقم الإعلان: ${widget.propertyNumber}',
    );

    final url = Uri.parse('https://wa.me/$cleanedPhone?text=$message');

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> shareProperty() async {
    final name = contactName.trim().isNotEmpty
        ? contactName.trim()
        : (widget.publisherName.trim().isNotEmpty
            ? widget.publisherName.trim()
            : 'صاحب العقار');
    final phone = contactPhone.trim().isNotEmpty
        ? contactPhone.trim()
        : (widget.ownerPhone.trim().isNotEmpty
            ? widget.ownerPhone.trim()
            : widget.publisherPhone.trim());

    await Share.share('''
🏡 ${widget.title}

📍 الموقع: ${widget.location}

💰 السعر: ${iqd(widget.price)}

🛏 عدد الغرف: ${widget.rooms}
🚿 عدد الحمامات: ${widget.bathrooms}

📞 للاستفسار:
$phone

${isOfficeProperty ? '🏢 المكتب: ' : '👤 الناشر: '}$name
''');
  }

  Widget infoTile(IconData icon, String title, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xffD4AF37), size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: AqarText.detailsLabel(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AqarText.detailsValue(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: 14,
          endIndent: 14,
          color: Colors.white.withValues(alpha: .08),
        ),
      ],
    );
  }

  Widget infoChip(IconData icon, String text) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xff1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xffD4AF37).withValues(alpha: 0.35),
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
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon, size: 16, color: const Color(0xffD4AF37)),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  text,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget locationChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffD4AF37).withValues(alpha: 0.35),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, size: 16, color: const Color(0xffD4AF37)),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> sendComment() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "يجب تسجيل الدخول لإضافة تعليق",
            textAlign: TextAlign.right,
          ),
          backgroundColor: Color(0xff1E293B),
        ),
      );

      return;
    }

    if (commentController.text.trim().isEmpty) return;
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final userData = userDoc.data() ?? {};

    await FirebaseFirestore.instance
        .collection("properties")
        .doc(widget.docId)
        .collection("comments")
        .add({
      "text": commentController.text.trim(),
      "userId": user.uid,
      "userName": userData["name"] ?? "مستخدم",
      "userPhoto": userData["photoUrl"] ?? "",
      "userEmail": user.email ?? "",
      "createdAt": FieldValue.serverTimestamp(),
      "isHidden": false,
      "isPinned": false,
    });

    // إرسال إشعار لصاحب العقار فقط إذا كان المعلّق شخصًا آخر

    if (widget.publisherUid.isNotEmpty && widget.publisherUid != user.uid) {
      await FirebaseFirestore.instance.collection("notifications").add({
        "userId": widget.publisherUid,
        "title": "تعليق جديد على عقارك",
        "message": "${userData["name"] ?? "مستخدم"} أضاف تعليقاً على عقارك",
        "propertyId": widget.docId,
        "type": "comment",
        "createdAt": FieldValue.serverTimestamp(),
        "isRead": false,
      });
    }

    commentController.clear();
  }

  Future<void> sendReply(String commentId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "يجب تسجيل الدخول للرد على التعليقات",
            textAlign: TextAlign.right,
          ),
          backgroundColor: Color(0xff1E293B),
        ),
      );

      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final userData = userDoc.data() ?? {};

    if (replyController.text.trim().isEmpty) {
      return;
    }

    final commentSnapshot = await FirebaseFirestore.instance
        .collection("properties")
        .doc(widget.docId)
        .collection("comments")
        .doc(commentId)
        .get();

    final commentData = commentSnapshot.data();

    await FirebaseFirestore.instance
        .collection("properties")
        .doc(widget.docId)
        .collection("comments")
        .doc(commentId)
        .collection("replies")
        .add({
      "text": replyController.text.trim(),
      "userId": user.uid,
      "userName": userData["name"] ?? "مستخدم",
      "userPhoto": userData["photoUrl"] ?? "",
      "userEmail": user.email ?? "",
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (commentData != null && commentData["userId"] != user.uid) {
      await FirebaseFirestore.instance.collection("notifications").add({
        "userId": commentData["userId"],
        "title": "تم الرد على تعليقك",
        "message": "${userData["name"] ?? "مستخدم"} رد على تعليقك",
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

  Widget commentItem(Map<String, dynamic> data, String commentId) {
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
              : Colors.white.withValues(alpha: .05),
          width: data["isPinned"] == true ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xffD4AF37),
            backgroundImage: (data["userPhoto"] ?? "").toString().isNotEmpty
                ? NetworkImage(data["userPhoto"])
                : null,
            child: (data["userPhoto"] ?? "").toString().isEmpty
                ? const Icon(Icons.person, color: Colors.black)
                : null,
          ),
          const SizedBox(width: 14),
          if (FirebaseAuth.instance.currentUser?.email ==
              "aysar.aliraqe@gmail.com")
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
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
                  await ref.update({"isPinned": !(data["isPinned"] ?? false)});
                }

                if (value == "hide") {
                  await ref.update({"isHidden": true});
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data["userName"] ?? "مستخدم",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if ((data["userId"] ?? "") == widget.publisherUid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "مالك العقار",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if ((data["userEmail"] ?? "") ==
                            "aysar.aliraqe@gmail.com")
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffD4AF37),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified,
                                  size: 12,
                                  color: Colors.black,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "مشرف",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
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
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  timeAgo(data["createdAt"]),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                    style: TextStyle(color: Color(0xffD4AF37)),
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
                        color: const Color(0xffD4AF37).withValues(alpha: .20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: replyController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "اكتب ردك...",
                              hintStyle: TextStyle(color: Colors.white54),
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
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox();
                    }

                    final replies = snapshot.data!.docs;
                    final expanded = expandedReplies[commentId] ?? false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              expandedReplies[commentId] = !expanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  expanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: const Color(0xffD4AF37),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  expanded
                                      ? "إخفاء الردود"
                                      : "عرض الردود (${replies.length})",
                                  style: const TextStyle(
                                    color: Color(0xffD4AF37),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: expanded
                              ? Column(
                                  children: replies.map((doc) {
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
                                          color: const Color(
                                            0xffD4AF37,
                                          ).withValues(alpha: .15),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor: const Color(
                                                  0xffD4AF37,
                                                ),
                                                backgroundImage:
                                                    (reply["userPhoto"] ?? "")
                                                            .toString()
                                                            .isNotEmpty
                                                        ? NetworkImage(
                                                            reply["userPhoto"],
                                                          )
                                                        : null,
                                                child:
                                                    (reply["userPhoto"] ?? "")
                                                            .toString()
                                                            .isEmpty
                                                        ? const Icon(
                                                            Icons.person,
                                                            size: 14,
                                                            color: Colors.black,
                                                          )
                                                        : null,
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
                                )
                              : const SizedBox(),
                        ),
                      ],
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
    debugPrint("PROPERTY DETAILS SCREEN OPENED");

    debugPrint("IMAGES = ${widget.images}");
    debugPrint("COUNT = ${widget.images.length}");
    debugPrint("TYPE = ${widget.images.runtimeType}");

    final isAdmin =
        FirebaseAuth.instance.currentUser?.email == "aysar.aliraqe@gmail.com";

    final bool showRooms = widget.propertyType == "بيت" ||
        widget.propertyType == "شقة" ||
        widget.propertyType == "مزرعة";

    final bool showArea = widget.area > 0;

    final bool showLiving = widget.propertyType == "بيت" ||
        widget.propertyType == "شقة" ||
        widget.propertyType == "مزرعة";

    final bool showParking = widget.propertyType != "أرض" && widget.parking > 0;

    final bool showFrontage = widget.propertyType != "شقة" &&
        widget.frontage != null &&
        widget.frontage! > 0;

    final bool showDepth = widget.propertyType != "شقة" &&
        widget.depth != null &&
        widget.depth! > 0;

    final bool showFloors = (widget.propertyType == "بيت" ||
            widget.propertyType == "محل" ||
            widget.propertyType == "عمارة" ||
            widget.propertyType == "مزرعة") &&
        widget.floors != null &&
        widget.floors! > 0;

    final bool showApartmentFloor = widget.propertyType == "شقة" &&
        widget.apartmentFloor != null &&
        widget.apartmentFloor! > 0;

    final bool showUnitsCount = widget.propertyType == "عمارة" &&
        widget.unitsCount != null &&
        widget.unitsCount! > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(34),
                    bottomRight: Radius.circular(34),
                  ),
                  child: CarouselSlider.builder(
                    carouselController: carouselController,
                    itemCount: widget.images.isEmpty ? 1 : widget.images.length,
                    options: CarouselOptions(
                      height: AqarSizes.detailsImageHeight(context),
                      viewportFraction: 1.0,
                      enableInfiniteScroll: true,
                      enlargeCenterPage: false,
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 3),
                      autoPlayAnimationDuration: const Duration(
                        milliseconds: 800,
                      ),
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
                        child: index == 0
                            ? Hero(
                                tag: 'property_${widget.docId}',
                                child: (widget.images.isEmpty
                                            ? widget.imageUrl
                                            : widget.images[index])
                                        .toString()
                                        .startsWith('assets/')
                                    ? Image.asset(
                                        widget.images.isEmpty
                                            ? widget.imageUrl
                                            : widget.images[index],
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
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
                              )
                            : (widget.images.isEmpty
                                        ? widget.imageUrl
                                        : widget.images[index])
                                    .toString()
                                    .startsWith('assets/')
                                ? Image.asset(
                                    widget.images.isEmpty
                                        ? widget.imageUrl
                                        : widget.images[index],
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Image.network(
                                    widget.images.isEmpty
                                        ? widget.imageUrl
                                        : widget.images[index],
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey,
                                      child: const Icon(Icons.home, size: 80),
                                    ),
                                  ),
                      );
                    },
                  ),
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
                      "${activeImage + 1}/${widget.images.isEmpty ? 1 : widget.images.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(34),
                      bottomRight: Radius.circular(34),
                    ),
                    child: Container(
                      height: AqarSizes.detailsImageHeight(context),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
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
                      effect: ExpandingDotsEffect(
                        dotHeight: AqarSizes.detailsDot(context),
                        dotWidth: AqarSizes.detailsDot(context),
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
                          width: AqarSizes.detailsTopButton(context),
                          height: AqarSizes.detailsTopButton(context),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: AqarSizes.detailsTopIcon(context),
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
                              width: AqarSizes.detailsTopButton(context),
                              height: AqarSizes.detailsTopButton(context),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.share_rounded,
                                  color: Colors.white,
                                  size: AqarSizes.detailsTopIcon(context),
                                ),
                                onPressed: shareProperty,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // زر المفضلة
                            Container(
                              width: AqarSizes.detailsTopButton(context),
                              height: AqarSizes.detailsTopButton(context),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
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
                                  size: AqarSizes.detailsTopIcon(context),
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
                  bottom: 16,
                  right: 2,
                  child: Container(
                    width: AqarSizes.detailsPriceCardWidth(context),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // =========================
                        // السعر
                        // =========================
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              const Icon(
                                Icons.payments_rounded,
                                color: Color(0xffD4AF37),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.price,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (widget.negotiable) ...[
                                      const SizedBox(height: 2),
                                      const Text(
                                        "قابل للتفاوض",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: Color(0xffD4AF37),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1, color: Colors.white24),

                        // =========================
                        // حالة التوفر
                        // =========================
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: widget.docId == null || widget.docId!.isEmpty
                              ? null
                              : FirebaseFirestore.instance
                                  .collection('properties')
                                  .doc(widget.docId)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data();

                            final status =
                                (data?['status'] ?? 'approved').toString();

                            final availabilityStatus =
                                (data?['availabilityStatus'] ??
                                        widget.availabilityStatus)
                                    .toString();

                            late final IconData statusIcon;
                            late final Color statusColor;
                            late final String statusText;

                            if (status == 'rejected') {
                              statusIcon = Icons.cancel_rounded;
                              statusColor = const Color(0xFFE35D5D);
                              statusText = 'مرفوض';
                            } else if (status == 'pending') {
                              statusIcon = Icons.hourglass_top_rounded;
                              statusColor = const Color(0xFFF4B042);
                              statusText = 'قيد المراجعة';
                            } else {
                              switch (availabilityStatus) {
                                case 'reserved':
                                  statusIcon = Icons.schedule_rounded;
                                  statusColor = const Color(0xFFF4B042);
                                  statusText = 'محجوز';
                                  break;

                                case 'sold':
                                  statusIcon = Icons.gpp_bad_rounded;
                                  statusColor = const Color(0xFFE35D5D);
                                  statusText = 'تم البيع';
                                  break;

                                case 'rented':
                                  statusIcon = Icons.key_rounded;
                                  statusColor = const Color(0xFF64B5F6);
                                  statusText = 'تم التأجير';
                                  break;

                                case 'available':
                                default:
                                  statusIcon = Icons.verified_rounded;
                                  statusColor = const Color(0xFF35C76F);
                                  statusText = 'متوفر';
                                  break;
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Icon(
                                    statusIcon,
                                    color: statusColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      statusText,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xff1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xffD4AF37).withValues(alpha: .20),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    if (widget.isVerified) ...[
                      infoChip(Icons.verified, "موثق"),
                      const SizedBox(width: 8),
                    ],
                    if (widget.isFeatured) ...[
                      infoChip(Icons.star, "مميز"),
                      const SizedBox(width: 8),
                    ],
                    infoChip(Icons.remove_red_eye, "$currentViews مشاهدة"),
                    const SizedBox(width: 8),
                    infoChip(
                      Icons.calendar_month,
                      widget.createdAt == null
                          ? "بدون تاريخ"
                          : "${widget.createdAt!.toDate().day}/${widget.createdAt!.toDate().month}/${widget.createdAt!.toDate().year}",
                    ),
                    const SizedBox(width: 8),
                    infoChip(Icons.tag_rounded, "رقم ${widget.propertyNumber}"),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      letterSpacing: .2,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xffD4AF37),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.city,
                          textAlign: TextAlign.right,
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
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff162033),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xffD4AF37).withValues(alpha: .25),
                      ),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        const Icon(
                          Icons.payments_rounded,
                          color: Color(0xffD4AF37),
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "السعر",
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                iqd(widget.price),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: AqarText.detailsPrice(context),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xffD4AF37),
                                ),
                              ),
                              if (widget.negotiable) ...[
                                const SizedBox(height: 2),
                                Text(
                                  "قابل للتفاوض",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: AqarText.detailsStatus(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
                        color: const Color(0xffD4AF37).withValues(alpha: .20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xff162033),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(
                                      0xffD4AF37,
                                    ).withValues(alpha: .25),
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
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            if (widget.city.isNotEmpty)
                              Expanded(
                                child: locationChip(
                                  Icons.location_city_rounded,
                                  "المدينة | ${widget.city}",
                                ),
                              ),
                            if (widget.city.isNotEmpty &&
                                widget.areaName.isNotEmpty)
                              const SizedBox(width: 8),
                            if (widget.areaName.isNotEmpty)
                              Expanded(
                                child: locationChip(
                                  Icons.map_rounded,
                                  "المنطقة | ${widget.areaName}",
                                ),
                              ),
                            if (widget.areaName.isNotEmpty &&
                                widget.landmark.isNotEmpty)
                              const SizedBox(width: 8),
                            if (widget.landmark.isNotEmpty)
                              Expanded(
                                child: locationChip(
                                  Icons.place_rounded,
                                  "أقرب نقطة | ${widget.landmark}",
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // تفاصيل العقار بشكل عمودي
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: [
                        Icon(
                          Icons.home_work_rounded,
                          color: Color(0xffD4AF37),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "تفاصيل العقار",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xff1E293B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xffD4AF37).withValues(alpha: .20),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (showRooms)
                          infoTile(
                            Icons.bed_rounded,
                            "عدد الغرف",
                            widget.rooms.toString(),
                          ),
                        if (showRooms)
                          infoTile(
                            Icons.bathtub_rounded,
                            "عدد الحمامات",
                            widget.bathrooms.toString(),
                          ),
                        if (showArea)
                          infoTile(
                            Icons.square_foot_rounded,
                            "المساحة",
                            "${widget.area} م²",
                          ),
                        if (showFrontage)
                          infoTile(
                            Icons.swap_horiz_rounded,
                            "الواجهة",
                            "${widget.frontage} م",
                          ),
                        if (showDepth)
                          infoTile(
                            Icons.straighten_rounded,
                            "النزال / العمق",
                            "${widget.depth} م",
                          ),
                        if (showFloors)
                          infoTile(
                            Icons.layers_rounded,
                            widget.propertyType == "عمارة"
                                ? "عدد طوابق العمارة"
                                : widget.propertyType == "مزرعة"
                                    ? "عدد طوابق البناء"
                                    : "عدد الطوابق",
                            widget.floors.toString(),
                          ),
                        if (showApartmentFloor)
                          infoTile(
                            Icons.stairs_rounded,
                            "الطابق الذي تقع فيه الشقة",
                            widget.apartmentFloor.toString(),
                          ),
                        if (showUnitsCount)
                          infoTile(
                            Icons.apartment_rounded,
                            "عدد الشقق / الوحدات",
                            widget.unitsCount.toString(),
                          ),
                        if (showLiving)
                          infoTile(
                            Icons.weekend_rounded,
                            "عدد المجالس",
                            widget.livingRooms.toString(),
                          ),
                        if (showParking)
                          infoTile(
                            Icons.directions_car_rounded,
                            "مواقف السيارات",
                            widget.parking.toString(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  const Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xffD4AF37),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "معلومات إضافية",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xff1E293B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xffD4AF37).withValues(alpha: .20),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (widget.buildYear > 0)
                          infoTile(
                            Icons.calendar_month_rounded,
                            "سنة البناء",
                            widget.buildYear.toString(),
                          ),
                        if (widget.documentType.isNotEmpty)
                          infoTile(
                            Icons.description_rounded,
                            "نوع السند",
                            widget.documentType,
                          ),
                        if (widget.furnitureStatus.isNotEmpty)
                          infoTile(
                            Icons.chair_rounded,
                            "حالة التأثيث",
                            widget.furnitureStatus,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "وصف العقار",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: AqarText.detailsSectionTitle(context),
                        fontWeight: FontWeight.bold,
                      ),
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
                        color: const Color(0xffD4AF37).withValues(alpha: .20),
                      ),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
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
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Icon(
                                    Icons.description_rounded,
                                    color: Color(0xffD4AF37),
                                    size: AqarSizes.detailsTopIcon(context),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "تفاصيل العقار",
                                    style: TextStyle(
                                      color: Color(0xffD4AF37),
                                      fontSize: AqarText.detailsSubTitle(
                                        context,
                                      ),
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
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AqarText.detailsBody(context),
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

                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xffD4AF37),
                          size: AqarSizes.detailsTopIcon(context),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "المميزات",
                          style: TextStyle(
                            fontSize: AqarText.detailsSectionTitle(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xff1E293B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xffD4AF37).withValues(alpha: .20),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.features.asMap().entries.map((entry) {
                        IconData icon = Icons.check_circle_outline;
                        final text = entry.value.toString();

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

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Icon(
                                    icon,
                                    color: const Color(0xffD4AF37),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      text,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: AqarText.featureText(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white38,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                            if (entry.key < widget.features.length - 1)
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 14,
                                endIndent: 14,
                                color: Colors.white.withValues(alpha: .08),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ===============================
                  // 📍 موقع العقار
                  // ===============================
                  if (widget.latitude >= -90 &&
                      widget.latitude <= 90 &&
                      widget.longitude >= -180 &&
                      widget.longitude <= 180 &&
                      !(widget.latitude == 0 && widget.longitude == 0)) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: Color(0xffD4AF37),
                            size: AqarSizes.detailsTopIcon(context),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "موقع العقار على الخريطة",
                            style: TextStyle(
                              fontSize: AqarText.detailsSectionTitle(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xffD4AF37).withValues(alpha: .20),
                        ),
                      ),
                      child: Column(
                        children: [
                          // المدينة
                          _PropertyLocationRow(
                            icon: Icons.location_city_rounded,
                            label: "المدينة",
                            value: widget.city.trim().isNotEmpty
                                ? widget.city
                                : "غير محدد",
                          ),

                          if (widget.areaName.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),

                            Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: .06),
                            ),

                            const SizedBox(height: 12),

                            // المنطقة
                            _PropertyLocationRow(
                              icon: Icons.holiday_village_rounded,
                              label: "المنطقة",
                              value: widget.areaName,
                            ),
                          ],

                          if (widget.landmark.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),

                            Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: .06),
                            ),

                            const SizedBox(height: 12),

                            // أقرب نقطة دالة
                            _PropertyLocationRow(
                              icon: Icons.near_me_rounded,
                              label: "أقرب نقطة دالة",
                              value: widget.landmark,
                            ),
                          ],

                          const SizedBox(height: 16),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final location = PropertyLocation(
                                  city: widget.city,
                                  district: widget.areaName,
                                  landmark: widget.landmark,
                                  latitude: widget.latitude,
                                  longitude: widget.longitude,
                                );

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PropertyLocationScreen(
                                      location: location,
                                      propertyTitle: widget.title,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.map_rounded,
                                size: AqarSizes.propertyPriceIcon(context),
                              ),
                              label: Text(
                                "عرض الموقع على الخريطة",
                                style: TextStyle(
                                  fontSize: AqarText.mapButton(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xffD4AF37),
                                side: BorderSide(
                                  color: const Color(
                                    0xffD4AF37,
                                  ).withValues(alpha: .45),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AqarSizes.featureRadius(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // =====================================================
                  // معلومات الناشر - تظهر لجميع المستخدمين
                  // =====================================================
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: [
                        Icon(
                          Icons.account_circle_rounded,
                          color: Color(0xffD4AF37),
                          size: AqarSizes.detailsTopIcon(context),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "معلومات الناشر",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AqarText.detailsSectionTitle(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _buildPublisherCard(),

                  // =====================================================
                  // معلومات إضافية خاصة بالأدمن فقط
                  // =====================================================
                  if (isAdmin) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff1E293B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xffD4AF37).withValues(alpha: .18),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Color(0xffD4AF37),
                                size: 18,
                              ),
                              SizedBox(width: 7),
                              Text(
                                "معلومات الإدارة",
                                style: TextStyle(
                                  color: Color(0xffD4AF37),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          infoTile(
                            Icons.email_rounded,
                            "البريد الإلكتروني",
                            widget.publisherEmail,
                          ),
                          infoTile(
                            Icons.badge_rounded,
                            "UID",
                            widget.publisherUid,
                          ),
                        ],
                      ),
                    ),
                  ],

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
                        count = snapshot.data!.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;

                          return data["isHidden"] != true;
                        }).length;
                      }

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            showComments = !showComments;
                          });
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                const Icon(
                                  Icons.forum_rounded,
                                  color: Color(0xffD4AF37),
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "التعليقات",
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: AqarText.detailsSectionTitle(
                                        context,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: showComments ? .5 : 0,
                                  duration: const Duration(milliseconds: 250),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Color(0xffD4AF37),
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xff1E293B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "$count ${count == 1 ? "تعليق" : "تعليقات"}",
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: AqarText.body(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    showComments
                                        ? "إخفاء التعليقات"
                                        : "عرض التعليقات",
                                    style: const TextStyle(
                                      color: Color(0xffD4AF37),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              height: 1,
                              color: Colors.white12,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 15),

                  Container(
                    padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width < 360 ? 8 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff1E293B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xffD4AF37).withValues(alpha: .25),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // صورة المستخدم
                        Builder(
                          builder: (context) {
                            final user = FirebaseAuth.instance.currentUser;

                            // المستخدم ضيف
                            if (user == null) {
                              return CircleAvatar(
                                radius: MediaQuery.of(context).size.width < 360
                                    ? 18
                                    : 22,
                                backgroundColor: Color(0xffD4AF37),
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: Colors.black,
                                ),
                              );
                            }

                            // المستخدم مسجل الدخول
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection("users")
                                  .doc(user.uid)
                                  .get(),
                              builder: (context, snapshot) {
                                String photo = "";

                                if (snapshot.hasData && snapshot.data!.exists) {
                                  final data = snapshot.data!.data()
                                      as Map<String, dynamic>?;

                                  photo = (data?["photoUrl"] ?? "").toString();
                                }

                                return CircleAvatar(
                                  radius:
                                      MediaQuery.of(context).size.width < 360
                                          ? 18
                                          : 22,
                                  backgroundColor: const Color(0xffD4AF37),
                                  backgroundImage: photo.isNotEmpty
                                      ? NetworkImage(photo)
                                      : null,
                                  child: photo.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.black,
                                        )
                                      : null,
                                );
                              },
                            );
                          },
                        ),

                        SizedBox(
                          width:
                              MediaQuery.of(context).size.width < 360 ? 8 : 12,
                        ),

                        // حقل الكتابة
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xff0F172A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: TextField(
                              controller: commentController,
                              minLines: 1,
                              maxLines: 4,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              textInputAction: TextInputAction.newline,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: "شارك رأيك حول هذا العقار",
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: .45),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                prefixIcon:
                                    MediaQuery.of(context).size.width < 380
                                        ? null
                                        : const Icon(
                                            Icons.mode_comment_outlined,
                                            color: Color(0xffD4AF37),
                                          ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          width:
                              MediaQuery.of(context).size.width < 360 ? 8 : 12,
                        ),

                        // زر الإرسال
                        Container(
                          width: AqarSizes.detailsTopButton(context),
                          height: AqarSizes.detailsTopButton(context),
                          decoration: const BoxDecoration(
                            color: Color(0xffD4AF37),
                            shape: BoxShape.circle,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: sendComment,
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.black,
                                size: AqarSizes.detailsTopIcon(context),
                              ),
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
                        return const Center(child: CircularProgressIndicator());
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

                      if (!showComments) {
                        return const SizedBox();
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

                          return commentItem(data, docs[index].id);
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

  Widget detailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xffD4AF37),
          size: AqarSizes.detailsTopIcon(context),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white70,
              fontSize: AqarText.body(context),
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
      child: Divider(color: Colors.white24, height: 1),
    );
  }
}

class _PropertyLocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PropertyLocationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xff0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xffD4AF37).withValues(alpha: .15),
            ),
          ),
          child: Icon(icon, color: const Color(0xffD4AF37), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
