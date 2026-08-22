import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_property/edit_property_screen.dart';
import '../utils/currency.dart';
import '../utils/property_default_images.dart';
import 'package:intl/intl.dart' as intl;
import 'property_details.dart';

class MyPropertiesScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;
  final bool readOnly;

  const MyPropertiesScreen({
    super.key,
    this.targetUserId,
    this.targetUserName,
    this.readOnly = false,
  });

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen> {
  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);
  static const Color _card = Color(0xff1E293B);

  String filter = 'all';
  String requestFilter = 'all';
  int selectedTab = 0;
  int _visiblePropertyCount = 10;

  bool get _isViewingOtherUser =>
      widget.readOnly || (widget.targetUserId?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final uid = (widget.targetUserId?.trim().isNotEmpty ?? false)
        ? widget.targetUserId!.trim()
        : currentUid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(
          child: Text(
            'يجب تسجيل الدخول أولاً',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(
            _isViewingOtherUser
                ? ((widget.targetUserName?.trim().isNotEmpty ?? false)
                    ? 'عقارات ${widget.targetUserName!.trim()}'
                    : 'عقارات المستخدم')
                : 'إعلاناتي',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            if (!_isViewingOtherUser)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _tabButton(
                          title: "عقاراتي",
                          icon: Icons.home_work_rounded,
                          selected: selectedTab == 0,
                          onTap: () => setState(() => selectedTab = 0),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _tabButton(
                          title: "طلباتي",
                          icon: Icons.manage_search_rounded,
                          selected: selectedTab == 1,
                          onTap: () => setState(() => selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _buildPropertiesTab(uid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _gold : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xffD4AF37),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final docs = snapshot.data!.docs;
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          if (filter == 'approved') {
            return data['status'] == 'approved';
          }

          if (filter == 'pending') {
            return data['status'] == 'pending';
          }

          return true;
        }).toList();
        final approved = docs.where((e) {
          final map = e.data() as Map<String, dynamic>;
          return map['status'] == 'approved';
        }).length;

        final pending = docs.where((e) {
          final map = e.data() as Map<String, dynamic>;
          return map['status'] == 'pending';
        }).length;

        if (docs.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 90),
              Icon(
                Icons.home_work_outlined,
                size: 95,
                color: Colors.white.withValues(alpha: .12),
              ),
              const SizedBox(height: 25),
              const Center(
                child: Text(
                  "ليس لديك أي عقار",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "ابدأ بإضافة أول عقار لك\nوسيظهر هنا تلقائياً",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _filterButton(
                      title: "الكل",
                      count: docs.length,
                      selected: filter == "all",
                      onTap: () {
                        setState(() {
                          filter = "all";
                          _visiblePropertyCount = 10;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _filterButton(
                      title: "تمت الموافقة",
                      count: approved,
                      selected: filter == "approved",
                      onTap: () {
                        setState(() {
                          filter = "approved";
                          _visiblePropertyCount = 10;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _filterButton(
                      title: "قيد المراجعة",
                      count: pending,
                      selected: filter == "pending",
                      onTap: () {
                        setState(() {
                          filter = "pending";
                          _visiblePropertyCount = 10;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        18,
                        18,
                        12,
                      ),
                      itemCount: filteredDocs.length > _visiblePropertyCount
                          ? _visiblePropertyCount
                          : filteredDocs.length,
                      itemBuilder: (context, index) {
                        final data =
                            filteredDocs[index].data() as Map<String, dynamic>;

                        return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PropertyDetails(
                                    property: null,
                                    imageUrl:
                                        (data['imageUrl'] ?? '').toString(),
                                    title: (data['title'] ?? '').toString(),
                                    location:
                                        (data['location'] ?? '').toString(),
                                    price: (data['price'] ?? '').toString(),
                                    negotiable: data['negotiable'] == true,
                                    rooms:
                                        (data['rooms'] as num?)?.toInt() ?? 0,
                                    bathrooms:
                                        (data['bathrooms'] as num?)?.toInt() ??
                                            0,
                                    area: (data['area'] as num?)?.toInt() ?? 0,
                                    frontage:
                                        (data['frontage'] as num?)?.toDouble(),
                                    depth: (data['depth'] as num?)?.toDouble(),
                                    floors: (data['floors'] as num?)?.toInt(),
                                    apartmentFloor:
                                        (data['apartmentFloor'] as num?)
                                            ?.toInt(),
                                    unitsCount:
                                        (data['unitsCount'] as num?)?.toInt(),
                                    livingRooms: (data['livingRooms'] as num?)
                                            ?.toInt() ??
                                        0,
                                    parking:
                                        (data['parking'] as num?)?.toInt() ?? 0,
                                    description:
                                        (data['description'] ?? '').toString(),
                                    ownerPhone:
                                        (data['ownerPhone'] ?? '').toString(),
                                    ownerWhatsapp: (data['ownerWhatsapp'] ?? '')
                                        .toString(),
                                    publisherPhone:
                                        (data['publisherPhone'] ?? '')
                                            .toString(),
                                    publisherWhatsapp:
                                        (data['publisherWhatsapp'] ?? '')
                                            .toString(),
                                    publisherUid:
                                        (data['publisherUid'] ?? '').toString(),
                                    publisherName: (data['publisherName'] ?? '')
                                        .toString(),
                                    publisherEmail:
                                        (data['publisherEmail'] ?? '')
                                            .toString(),
                                    images: (data['images'] as List?) ?? [],
                                    features: (data['features'] as List?) ?? [],
                                    documentType:
                                        (data['documentType'] ?? '').toString(),
                                    furnitureStatus:
                                        (data['furnitureStatus'] ?? '')
                                            .toString(),
                                    propertyType:
                                        (data['propertyType'] ?? '').toString(),
                                    adType: (data['adType'] ?? '').toString(),
                                    city: (data['city'] ?? '').toString(),
                                    areaName:
                                        (data['areaName'] ?? '').toString(),
                                    landmark:
                                        (data['landmark'] ?? '').toString(),
                                    latitude: (data['latitude'] as num?)
                                            ?.toDouble() ??
                                        0.0,
                                    longitude: (data['longitude'] as num?)
                                            ?.toDouble() ??
                                        0.0,
                                    isVerified: data['isVerified'] ?? false,
                                    isFeatured: data['isFeatured'] ?? false,
                                    availabilityStatus:
                                        (data['availabilityStatus'] ?? '')
                                            .toString(),
                                    views:
                                        (data['views'] as num?)?.toInt() ?? 0,
                                    createdAt: data['createdAt'] as Timestamp?,
                                    buildYear:
                                        (data['buildYear'] as num?)?.toInt() ??
                                            0,
                                    propertyNumber:
                                        (data['adNumber'] as num?)?.toInt() ??
                                            0,
                                    docId: filteredDocs[index].id,
                                    isFavorite: false,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 154,
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xff1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xffD4AF37)
                                      .withValues(alpha: .10),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    SizedBox(
                                      width: 128,
                                      height: double.infinity,
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Builder(
                                            builder: (context) {
                                              final image =
                                                  (data['imageUrl'] ?? '')
                                                      .toString()
                                                      .trim();
                                              final displayImage =
                                                  image.isNotEmpty
                                                      ? image
                                                      : PropertyDefaultImages
                                                          .getImage(
                                                          (data['propertyType'] ??
                                                                  '')
                                                              .toString(),
                                                        );

                                              if (displayImage
                                                  .startsWith('assets/')) {
                                                return Image.asset(
                                                  displayImage,
                                                  fit: BoxFit.cover,
                                                );
                                              }

                                              return Image.network(
                                                displayImage,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) {
                                                  return Image.asset(
                                                    PropertyDefaultImages
                                                        .getImage(
                                                      (data['propertyType'] ??
                                                              '')
                                                          .toString(),
                                                    ),
                                                    fit: BoxFit.cover,
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            9, 7, 4, 7),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    (data['title'] ?? '')
                                                            .toString()
                                                            .trim()
                                                            .isEmpty
                                                        ? 'عقار بدون عنوان'
                                                        : (data['title'] ?? '')
                                                            .toString(),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      height: 1.06,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                if (!_isViewingOtherUser)
                                                  PopupMenuButton<String>(
                                                    tooltip: 'إدارة العقار',
                                                    offset: const Offset(0, 6),
                                                    color:
                                                        const Color(0xff1E293B),
                                                    elevation: 10,
                                                    padding: EdgeInsets.zero,
                                                    iconSize: 19,
                                                    icon: const Icon(
                                                      Icons.more_horiz_rounded,
                                                      color: Color(0xffD4AF37),
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      side: BorderSide(
                                                        color: const Color(
                                                                0xffD4AF37)
                                                            .withValues(
                                                                alpha: .16),
                                                      ),
                                                    ),
                                                    onSelected: (value) {
                                                      if (value == 'edit') {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                EditPropertyScreen(
                                                              docId:
                                                                  filteredDocs[
                                                                          index]
                                                                      .id,
                                                              data: data,
                                                            ),
                                                          ),
                                                        );
                                                      } else if (value ==
                                                          'delete') {
                                                        _deleteProperty(
                                                          context,
                                                          filteredDocs[index]
                                                              .id,
                                                        );
                                                      }
                                                    },
                                                    itemBuilder: (_) => const [
                                                      PopupMenuItem<String>(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                              size: 18,
                                                              color: Color(
                                                                  0xffD4AF37),
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text('تعديل'),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem<String>(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .delete_outline_rounded,
                                                              size: 18,
                                                              color: Colors
                                                                  .redAccent,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text('حذف'),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 3,
                                              ),
                                              child: Container(
                                                height: .6,
                                                color: const Color(0xffD4AF37)
                                                    .withValues(alpha: .18),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,
                                                  color: Color(0xffD4AF37),
                                                  size: 13,
                                                ),
                                                const SizedBox(width: 3),
                                                Expanded(
                                                  child: Text(
                                                    '${data['city'] ?? ''}'
                                                    '${(data['district'] ?? '').toString().isNotEmpty ? ' - ${data['district']}' : ''}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: .58),
                                                      fontSize: 9.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons
                                                      .confirmation_number_outlined,
                                                  color: Color(0xffD4AF37),
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 3),
                                                Expanded(
                                                  child: Text(
                                                    'رقم الإعلان: ${data['propertyNumber'] ?? data['adNumber'] ?? '--'}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: .52),
                                                      fontSize: 8.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.remove_red_eye_outlined,
                                                  color: Color(0xffD4AF37),
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${data['views'] ?? 0} مشاهدة',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: .48),
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Spacer(),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    iqd(data['price']),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Color(0xffD4AF37),
                                                      fontSize: 11.0,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Flexible(
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: data['status'] ==
                                                                  'approved' ||
                                                              data['status'] ==
                                                                  'active'
                                                          ? const Color(
                                                                  0xff1DB954)
                                                              .withValues(
                                                                  alpha: .12)
                                                          : const Color(
                                                                  0xffF39C12)
                                                              .withValues(
                                                                  alpha: .12),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              7),
                                                    ),
                                                    child: Text(
                                                      data['status'] ==
                                                                  'approved' ||
                                                              data['status'] ==
                                                                  'active'
                                                          ? 'منشور'
                                                          : data['status'] ==
                                                                  'rejected'
                                                              ? 'مرفوض'
                                                              : 'قيد المراجعة',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: data['status'] ==
                                                                    'approved' ||
                                                                data['status'] ==
                                                                    'active'
                                                            ? const Color(
                                                                0xff55E88A)
                                                            : data['status'] ==
                                                                    'rejected'
                                                                ? Colors
                                                                    .redAccent
                                                                : const Color(
                                                                    0xffF5B94C),
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ));
                      },
                    ),
                  ),
                  if (filteredDocs.length > _visiblePropertyCount)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _visiblePropertyCount += 10;
                            });
                          },
                          icon: const Icon(
                            Icons.expand_more_rounded,
                            size: 19,
                          ),
                          label: Text(
                            'عرض المزيد (${filteredDocs.length - _visiblePropertyCount})',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _gold,
                            side: BorderSide(
                              color: _gold.withValues(alpha: .35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequestsTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('property_requests')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _gold),
          );
        }

        if (snapshot.hasError) {
          return _emptyRequests(
            icon: Icons.error_outline_rounded,
            title: "تعذر تحميل الطلبات",
            subtitle: "حدث خطأ أثناء تحميل طلباتك",
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final docs = snapshot.data!.docs.toList();

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        final approved = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'approved';
        }).length;

        final pending = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'pending';
        }).length;

        final rejected = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'rejected';
        }).length;

        final filteredDocs = docs.where((doc) {
          if (requestFilter == 'all') return true;
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == requestFilter;
        }).toList();

        if (docs.isEmpty) {
          return _emptyRequests(
            icon: Icons.manage_search_rounded,
            title: "ليس لديك أي طلب عقار",
            subtitle: "عندما ترسل طلب شراء أو إيجار عقار سيظهر هنا تلقائياً",
          );
        }

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  _requestFilterButton(
                    title: "الكل",
                    count: docs.length,
                    selected: requestFilter == 'all',
                    onTap: () => setState(() => requestFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _requestFilterButton(
                    title: "منشور",
                    count: approved,
                    selected: requestFilter == 'approved',
                    onTap: () => setState(() => requestFilter = 'approved'),
                  ),
                  const SizedBox(width: 8),
                  _requestFilterButton(
                    title: "قيد المراجعة",
                    count: pending,
                    selected: requestFilter == 'pending',
                    onTap: () => setState(() => requestFilter = 'pending'),
                  ),
                  const SizedBox(width: 8),
                  _requestFilterButton(
                    title: "مرفوض",
                    count: rejected,
                    selected: requestFilter == 'rejected',
                    onTap: () => setState(() => requestFilter = 'rejected'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredDocs.isEmpty
                  ? _emptyRequests(
                      icon: Icons.inbox_outlined,
                      title: "لا توجد طلبات",
                      subtitle: "لا توجد طلبات ضمن هذه الحالة",
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _requestCard(doc.id, data);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _requestFilterButton({
    required String title,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        constraints: const BoxConstraints(minWidth: 92),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _gold : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _gold : Colors.white10,
          ),
        ),
        child: Column(
          children: [
            Text(
              "$count",
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(String requestId, Map<String, dynamic> data) {
    final requestType = (data['requestType'] ?? '').toString();
    final propertyType = (data['propertyType'] ?? 'عقار').toString();
    final city = (data['city'] ?? '').toString();
    final district = (data['district'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString();
    final createdAt = data['createdAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _gold.withValues(alpha: .15)),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(requestId, data),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _requestPropertyIcon(propertyType),
                      color: _gold,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _requestTitle(requestType, propertyType),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          [city, district]
                              .where((e) => e.trim().isNotEmpty)
                              .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _requestStatusBadge(status),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: _gold),
                    color: _card,
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteRequest(requestId);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text("حذف"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 14),
              _requestInfoRow(
                Icons.square_foot_rounded,
                "المساحة",
                _requestRange(
                  data['minArea'],
                  data['maxArea'],
                  suffix: "م²",
                ),
              ),
              const SizedBox(height: 10),
              _requestInfoRow(
                Icons.account_balance_wallet_outlined,
                "الميزانية",
                _requestRange(
                  data['minPrice'],
                  data['maxPrice'],
                  suffix: "د.ع",
                ),
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 10),
                _requestInfoRow(
                  Icons.calendar_today_rounded,
                  "التاريخ",
                  intl.DateFormat('yyyy/MM/dd').format(createdAt.toDate()),
                ),
              ],
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "عرض التفاصيل",
                    style: TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _gold,
                    size: 13,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requestStatusBadge(String status) {
    late String text;
    late Color color;
    switch (status) {
      case 'approved':
        text = 'منشور';
        color = const Color(0xff22C55E);
        break;
      case 'rejected':
        text = 'مرفوض';
        color = const Color(0xffEF4444);
        break;
      default:
        text = 'قيد المراجعة';
        color = const Color(0xffF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _requestInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 18),
        const SizedBox(width: 7),
        Text(
          "$title:",
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyRequests({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      children: [
        const SizedBox(height: 90),
        Icon(icon, size: 90, color: Colors.white.withValues(alpha: .12)),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  void _showRequestDetails(String requestId, Map<String, dynamic> data) {
    final rows = <MapEntry<String, String>>[
      MapEntry("نوع الطلب", (data['requestType'] ?? 'غير محدد').toString()),
      MapEntry("نوع العقار", (data['propertyType'] ?? 'غير محدد').toString()),
      MapEntry("المدينة", (data['city'] ?? 'غير محدد').toString()),
      MapEntry("المنطقة", (data['district'] ?? 'غير محدد').toString()),
      MapEntry("أقرب نقطة دالة", _requestDisplay(data['landmark'])),
      MapEntry(
        "المساحة",
        _requestRange(data['minArea'], data['maxArea'], suffix: "م²"),
      ),
      MapEntry(
        "الميزانية",
        _requestRange(data['minPrice'], data['maxPrice'], suffix: "د.ع"),
      ),
      MapEntry("الغرف", _requestDisplay(data['rooms'])),
      MapEntry("الحمامات", _requestDisplay(data['bathrooms'])),
      MapEntry("المجالس", _requestDisplay(data['livingRooms'])),
      MapEntry("مواقف السيارات", _requestDisplay(data['parking'])),
      MapEntry("أقل عدد طوابق", _requestDisplay(data['minFloors'])),
      MapEntry("أعلى عدد طوابق", _requestDisplay(data['maxFloors'])),
      MapEntry("الطابق المطلوب", _requestDisplay(data['apartmentFloor'])),
      MapEntry("الهاتف", _requestDisplay(data['phone'])),
      MapEntry("واتساب", _requestDisplay(data['whatsapp'])),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * .88,
            ),
            decoration: const BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _requestTitle(
                              (data['requestType'] ?? '').toString(),
                              (data['propertyType'] ?? 'عقار').toString(),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _requestStatusBadge(
                          (data['status'] ?? 'pending').toString(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        ...rows.map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 125,
                                  child: Text(
                                    row.key,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    row.value,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if ((data['description'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 8),
                          const Text(
                            "تفاصيل إضافية",
                            style: TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['description'].toString(),
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.7,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          "معرّف الطلب: $requestId",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          title: const Text(
            "حذف الطلب",
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "هل أنت متأكد من حذف طلب العقار؟ لا يمكن التراجع بعد الحذف",
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                "حذف",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('property_requests')
          .doc(requestId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم حذف الطلب بنجاح")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تعذر حذف الطلب: $e")),
      );
    }
  }

  String _requestTitle(String requestType, String propertyType) {
    if (requestType == 'شراء') return "مطلوب $propertyType للشراء";
    if (requestType == 'إيجار') return "مطلوب $propertyType للإيجار";
    return "مطلوب $propertyType";
  }

  String _requestDisplay(dynamic value) {
    if (value == null) return "غير محدد";
    final text = value.toString().trim();
    if (text.isEmpty || text == '0') return "غير محدد";
    return text;
  }

  String _requestRange(dynamic minValue, dynamic maxValue,
      {required String suffix}) {
    final min = _requestDouble(minValue);
    final max = _requestDouble(maxValue);

    if (min == null && max == null) return "غير محدد";
    if (min != null && max != null) {
      if (min == max) return "${_requestNumber(min)} $suffix";
      return "${_requestNumber(min)} - ${_requestNumber(max)} $suffix";
    }
    if (min != null) return "من ${_requestNumber(min)} $suffix";
    return "حتى ${_requestNumber(max!)} $suffix";
  }

  double? _requestDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _requestNumber(double value) {
    return intl.NumberFormat('#,##0').format(value.round());
  }

  IconData _requestPropertyIcon(String propertyType) {
    switch (propertyType) {
      case 'بيت':
        return Icons.home_rounded;
      case 'شقة':
        return Icons.apartment_rounded;
      case 'أرض':
        return Icons.landscape_rounded;
      case 'محل':
        return Icons.storefront_rounded;
      case 'عمارة':
        return Icons.location_city_rounded;
      case 'مزرعة':
        return Icons.agriculture_rounded;
      default:
        return Icons.real_estate_agent_rounded;
    }
  }

  Widget _filterButton({
    required String title,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffD4AF37) : const Color(0xff1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xffD4AF37) : Colors.white10,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xffD4AF37).withValues(alpha: .35),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Text(
              "$count",
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(
    IconData icon,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff334155),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: const Color(0xffD4AF37),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProperty(
    BuildContext context,
    String propertyId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xff1E293B),
          title: const Text(
            "حذف العقار",
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "هل أنت متأكد من حذف هذا العقار؟ لا يمكن التراجع بعد الحذف",
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                "حذف",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('properties')
        .doc(propertyId)
        .delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم حذف العقار بنجاح"),
        ),
      );
    }
  }
}
