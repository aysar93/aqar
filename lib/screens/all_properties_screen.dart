import 'package:aqar/moderation/user_blocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/property_model.dart';
import '../utils/currency.dart';
import '../utils/property_mapper.dart';

import '../widgets/property_card.dart';
import '../widgets/aqar_refresh_indicator.dart';
import '../widgets/home/search_section.dart';
import '../widgets/home/categories_section.dart';

import 'property_details.dart';
import 'edit_property/edit_property_screen.dart';
import '../services/favorites_service.dart';
import '../core/data/paged_query.dart';
import '../core/data/property_catalog_query.dart';
import '../core/data/property_text_search.dart';
import '../office/screens/offices_screen.dart';

const String adminEmail = "aysar.aliraqe@gmail.com";

class AllPropertiesScreen extends StatefulWidget {
  final String mode;
  final String initialCategory;
  final String initialSearch;

  // معرف المكتب عند فتح عقارات مكتب محدد
  final String? officeId;

  const AllPropertiesScreen({
    super.key,
    this.mode = "all",
    this.initialCategory = "الكل",
    this.initialSearch = "",
    this.officeId,
  });

  @override
  State<AllPropertiesScreen> createState() => _AllPropertiesScreenState();
}

class _AllPropertiesScreenState extends State<AllPropertiesScreen> {
  final TextEditingController searchController = TextEditingController();

  String search = '';
  String selectedCategory = "الكل";
  String sortBy = "الأحدث";
  String selectedAdType = "الكل";
  bool showFilters = false;
  bool featuredOnly = false;
  int _visibleCount = 20;
  PagedQueryController<Map<String, dynamic>>? _catalog;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _completeSearchStream;
  late Query<Map<String, dynamic>> _completeQuery;

  void _catalogChanged() {
    if (mounted) setState(() {});
  }

  void _configureCatalog() {
    final plan = PropertyCatalogQuery(
        officeId: widget.officeId,
        category: selectedCategory,
        adType: selectedAdType,
        featured: featuredOnly,
        search: search,
        sort: sortBy,
        mode: widget.mode);
    final complete = plan.candidates(FirebaseFirestore.instance);
    // Retain a stable complete candidate stream while text is typed.
    // Structured predicates never restrict search to the loaded cursor pages.
    if (_completeQuery != complete) {
      _completeQuery = complete;
      _completeSearchStream = complete.safeSnapshots();
    }
    if (!plan.bounded) {
      _catalog?.dispose();
      _catalog = null;
      return;
    }
    final query = plan.pageQuery(FirebaseFirestore.instance);
    if (_catalog?.query == query) return;
    _catalog?.dispose();
    _visibleCount = 20;
    _catalog = PagedQueryController(query,
        pageSize: 20,
        safe: true,
        matches: (data) => data['status'] == 'approved');
    _catalog!.addListener(_catalogChanged);
    _catalog!.start();
  }

  Widget _catalogBuilder(
      Widget Function(
              BuildContext, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>)
          builder) {
    final catalog = _catalog;
    if (catalog != null) return builder(context, catalog.snapshot);
    return StreamBuilder(stream: _completeSearchStream, builder: builder);
  }

  @override
  void dispose() {
    _catalog?.dispose();
    searchController.dispose();
    super.dispose();
  }

  bool _matchesPropertySearch(String id, Map<String, dynamic> data) =>
      PropertyTextSearch.matches(search, id, data);

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory;
    search = widget.initialSearch.toLowerCase();
    searchController.text = widget.initialSearch;

    switch (widget.mode) {
      case "featured":
        featuredOnly = true;
        break;

      case "latest":
        sortBy = "الأحدث";
        break;

      case "views":
        sortBy = "الأكثر مشاهدة";
        break;
    }
    Query<Map<String, dynamic>> complete = FirebaseFirestore.instance
        .collection('properties')
        .where('status', isEqualTo: 'approved');
    if (widget.officeId?.trim().isNotEmpty ?? false) {
      complete = complete.where('officeId', isEqualTo: widget.officeId!.trim());
    }
    _completeSearchStream = complete.safeSnapshots();
    _completeQuery = complete;
    _configureCatalog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.mode == "featured"
              ? "⭐ العقارات المميزة"
              : widget.mode == "views"
                  ? "🔥 الأكثر مشاهدة"
                  : widget.mode == "latest"
                      ? "🆕 أحدث العقارات"
                      : "جميع العقارات",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: AqarRefreshIndicator(
        onRefresh: () async {
          if (_catalog != null) {
            await _catalog!.refresh();
          } else {
            setState(
                () => _completeSearchStream = _completeQuery.safeSnapshots());
          }
        },
        child: _catalogBuilder(
          (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  "حدث خطأ أثناء تحميل العقارات",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFD4AF37),
                ),
              );
            }

            final docs = snapshot.data!.docs;

            final filteredDocs = docs.where((doc) {
              final data = doc.data();

              final propertyType = (data["propertyType"] ?? "").toString();

              final matchesSearch = _matchesPropertySearch(doc.id, data);

              final matchesCategory = selectedCategory == "الكل" ||
                  propertyType == selectedCategory;

              final adType = (data["adType"] ?? "").toString();

              final matchesAdType =
                  selectedAdType == "الكل" || adType == selectedAdType;

              final isFeatured = data["isFeatured"] == true;

              final matchesFeatured = !featuredOnly || isFeatured;

              return matchesSearch &&
                  matchesCategory &&
                  matchesAdType &&
                  matchesFeatured;
            }).toList();

            // Cursor pages already have the complete server order, including
            // document-name ties. Local sorting is only for substring search.
            if (_catalog == null) {
              filteredDocs.sort((a, b) {
                final dataA = a.data();
                final dataB = b.data();

                // إجبار الترتيب حسب الصفحة المفتوحة
                if (widget.mode == "views") {
                  return ((dataB["views"] ?? 0) as num)
                      .compareTo((dataA["views"] ?? 0) as num);
                }

                if (widget.mode == "latest") {
                  final aTime = dataA["createdAt"] as Timestamp?;
                  final bTime = dataB["createdAt"] as Timestamp?;

                  if (aTime == null || bTime == null) return 0;

                  return bTime.compareTo(aTime);
                }

                // الترتيب العادي داخل صفحة جميع العقارات
                switch (sortBy) {
                  case "الأعلى سعراً":
                    return ((dataB["price"] ?? 0) as num)
                        .compareTo((dataA["price"] ?? 0) as num);

                  case "الأقل سعراً":
                    return ((dataA["price"] ?? 0) as num)
                        .compareTo((dataB["price"] ?? 0) as num);

                  case "الأكثر مشاهدة":
                    return ((dataB["views"] ?? 0) as num)
                        .compareTo((dataA["views"] ?? 0) as num);

                  default:
                    final aTime = dataA["createdAt"] as Timestamp?;
                    final bTime = dataB["createdAt"] as Timestamp?;

                    if (aTime == null || bTime == null) return 0;

                    return bTime.compareTo(aTime);
                }
              });
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                SearchSection(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {
                      search = value.toLowerCase();
                      _configureCatalog();
                      _visibleCount = 20;
                    });
                  },
                  onFilterTap: () {
                    setState(() {
                      showFilters = !showFilters;
                    });
                  },
                ),
                const SizedBox(
                  height: 16,
                ),
                CategoriesSection(
                  selectedCategory: selectedCategory,
                  onCategorySelected: (category) {
                    setState(() {
                      if (category == "المكاتب") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OfficesScreen(),
                          ),
                        );
                        return;
                      }

                      selectedCategory = category;
                      _configureCatalog();
                    });
                  },
                ),
                const SizedBox(
                  height: 20,
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      showFilters = !showFilters;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff162033),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xffD4AF37).withValues(alpha: .45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .20),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          color: Color(0xffD4AF37),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            showFilters ? "إخفاء الفلاتر" : "الفلاتر",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: .2,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: showFilters ? .5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xffD4AF37),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.mode == "all")
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: showFilters
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            "ترتيب النتائج",
                            style: TextStyle(
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              "الأحدث",
                              "الأعلى سعراً",
                              "الأقل سعراً",
                              "الأكثر مشاهدة",
                            ].map((item) {
                              final selected = sortBy == item;

                              return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      item,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.black
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    selected: selected,
                                    selectedColor: const Color(0xffD4AF37),
                                    backgroundColor: const Color(0xff162033),
                                    side: BorderSide(
                                      color: selected
                                          ? const Color(0xffD4AF37)
                                          : const Color(0xff2D3A55),
                                      width: selected ? 1.8 : 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    onSelected: (_) {
                                      setState(() {
                                        sortBy = item;
                                        _configureCatalog();
                                      });
                                    },
                                  ));
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                if (widget.mode == "all" && showFilters)
                  const SizedBox(height: 18),
                if (showFilters)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          "نوع الإعلان",
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            "الكل",
                            "للبيع",
                            "للإيجار",
                          ].map((item) {
                            final selected = selectedAdType == item;

                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ChoiceChip(
                                label: Text(
                                  item,
                                  style: TextStyle(
                                    color:
                                        selected ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: selected,
                                selectedColor: const Color(0xffD4AF37),
                                backgroundColor: const Color(0xff162033),
                                side: BorderSide(
                                  color: selected
                                      ? const Color(0xffD4AF37)
                                      : const Color(0xff2D3A55),
                                  width: selected ? 1.8 : 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    selectedAdType = item;
                                    _configureCatalog();
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff162033),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xffD4AF37).withValues(alpha: .45),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.home_work_rounded,
                        color: Color(0xffD4AF37),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _catalog == null
                              ? "تم العثور على ${filteredDocs.length} عقار"
                              : "تم تحميل ${filteredDocs.length} عقار",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        sortBy,
                        style: const TextStyle(
                          color: Color(0xffD4AF37),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (widget.mode == "all")
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        if (_catalog?.loadingMore ?? false) return;
                        searchController.clear();

                        setState(() {
                          search = "";
                          selectedCategory = "الكل";
                          selectedAdType = "الكل";
                          sortBy = "الأحدث";
                          _configureCatalog();
                        });
                      },
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xffD4AF37),
                      ),
                      label: const Text(
                        "إعادة تعيين الفلاتر",
                        style: TextStyle(
                          color: Color(0xffD4AF37),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (filteredDocs.isEmpty)
                  SizedBox(
                    height: 350,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            search.isNotEmpty
                                ? Icons.search_off_rounded
                                : Icons.home_work_outlined,
                            size: 70,
                            color: const Color(0xFFD4AF37),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            search.isNotEmpty
                                ? "لم يتم العثور على نتائج"
                                : "لا توجد عقارات حالياً",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            search.isNotEmpty
                                ? "جرّب كلمة بحث أخرى أو غيّر التصنيف."
                                : "ستظهر العقارات هنا فور إضافتها",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredDocs.length > _visibleCount
                        ? _visibleCount
                        : filteredDocs.length,
                    itemBuilder: (context, index) {
                      final isAdmin =
                          FirebaseAuth.instance.currentUser?.email ==
                              adminEmail;

                      final doc = filteredDocs[index];

                      final data = doc.data();

                      final PropertyModel property = propertyFromMap(
                        data,
                        doc.id,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: RepaintBoundary(
                          child: Stack(
                            children: [
                              StreamBuilder<bool>(
                                stream: FavoritesService.favoriteStream(doc.id),
                                builder: (context, favSnapshot) {
                                  return PropertyCard(
                                    imageUrl: property.imageUrl,
                                    title: property.title,
                                    location: property.location,
                                    price: iqd(property.price),
                                    publisherName: property.publisherName,
                                    publisherPhotoUrl:
                                        property.publisherPhotoUrl,
                                    officeName: property.officeName,
                                    officeLogoUrl: property.officeLogoUrl,
                                    isOfficeProperty: property.isOfficeProperty,
                                    rooms: property.rooms,
                                    bathrooms: property.bathrooms,
                                    area: property.area,
                                    livingRooms: property.livingRooms,
                                    parking: property.parking,
                                    description: property.description,
                                    ownerPhone: property.ownerPhone,
                                    ownerWhatsapp: property.ownerWhatsapp,
                                    images: property.images,
                                    features: property.features,
                                    propertyNumber: property.propertyNumber,
                                    docId: doc.id,
                                    availabilityStatus:
                                        property.availabilityStatus,
                                    isFavorite: favSnapshot.data ?? false,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PropertyDetails(
                                            docId: doc.id,
                                            propertyNumber:
                                                (data["propertyNumber"] ??
                                                            data["adNumber"] ??
                                                            data["propertyNo"]
                                                                as num?)
                                                        ?.toInt() ??
                                                    0,
                                            isFavorite:
                                                favSnapshot.data ?? false,
                                            imageUrl: data["imageUrl"] ?? "",
                                            title: data["title"] ?? "",
                                            location: data["location"] ?? "",
                                            price: iqd(data["price"]),
                                            negotiable:
                                                data["negotiable"] == true,
                                            rooms: (data["rooms"] as num?)
                                                    ?.toInt() ??
                                                0,
                                            bathrooms:
                                                (data["bathrooms"] as num?)
                                                        ?.toInt() ??
                                                    0,
                                            area: (data["area"] as num?)
                                                    ?.toInt() ??
                                                0,
                                            frontage: (data["frontage"] as num?)
                                                ?.toDouble(),
                                            depth: (data["depth"] as num?)
                                                ?.toDouble(),
                                            floors: (data["floors"] as num?)
                                                ?.toInt(),
                                            apartmentFloor:
                                                (data["apartmentFloor"] as num?)
                                                    ?.toInt(),
                                            unitsCount:
                                                (data["unitsCount"] as num?)
                                                    ?.toInt(),
                                            livingRooms:
                                                (data["livingRooms"] as num?)
                                                        ?.toInt() ??
                                                    0,
                                            parking: (data["parking"] as num?)
                                                    ?.toInt() ??
                                                0,
                                            description:
                                                data["description"] ?? "",
                                            ownerPhone:
                                                data["ownerPhone"] ?? "",
                                            ownerWhatsapp:
                                                data["ownerWhatsapp"] ?? "",
                                            publisherPhone:
                                                data["publisherPhone"] ?? "",
                                            publisherWhatsapp:
                                                data["publisherWhatsapp"] ?? "",
                                            publisherUid:
                                                (data["publisherUid"] ??
                                                        data["userId"] ??
                                                        "")
                                                    .toString(),
                                            publisherName:
                                                (data["publisherName"] ?? "")
                                                    .toString(),
                                            publisherEmail:
                                                (data["publisherEmail"] ?? "")
                                                    .toString(),
                                            propertyType:
                                                (data["propertyType"] ?? "")
                                                    .toString(),
                                            adType: (data["adType"] ?? "")
                                                .toString(),
                                            city:
                                                (data["city"] ?? "").toString(),
                                            areaName: (data["areaName"] ?? "")
                                                .toString(),
                                            landmark: (data["landmark"] ?? "")
                                                .toString(),
                                            latitude: (data["latitude"] as num?)
                                                    ?.toDouble() ??
                                                0,
                                            longitude:
                                                (data["longitude"] as num?)
                                                        ?.toDouble() ??
                                                    0,
                                            availabilityStatus:
                                                (data["availabilityStatus"] ??
                                                        "available")
                                                    .toString(),
                                            isVerified:
                                                data["isVerified"] ?? false,
                                            isFeatured:
                                                data["isFeatured"] ?? false,
                                            views: (data["views"] as num?)
                                                    ?.toInt() ??
                                                0,
                                            createdAt: data["createdAt"],
                                            buildYear:
                                                (data["buildYear"] as num?)
                                                        ?.toInt() ??
                                                    0,
                                            images: List<dynamic>.from(
                                                data["images"] ?? []),
                                            features: List<dynamic>.from(
                                                data["features"] ?? []),
                                            documentType:
                                                (data["documentType"] ?? "")
                                                    .toString(),
                                            furnitureStatus:
                                                (data["furnitureStatus"] ?? "")
                                                    .toString(),
                                          ),
                                        ),
                                      );
                                    },
                                    onFavorite: () async {
                                      await FavoritesService.toggleFavorite(
                                          doc.id);
                                    },
                                  );
                                },
                              ),
                              if (isAdmin)
                                Positioned(
                                  right: 30,
                                  bottom: 110,
                                  child: PopupMenuButton<String>(
                                    tooltip: 'إدارة العقار',
                                    offset: const Offset(0, -6),
                                    color: const Color(0xff1E293B),
                                    elevation: 10,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: const Color(0xffD4AF37)
                                            .withValues(alpha: .16),
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    icon: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xff0F172A)
                                            .withValues(alpha: .90),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xffD4AF37)
                                              .withValues(alpha: .25),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.more_horiz_rounded,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                                    ),
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        if (!context.mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditPropertyScreen(
                                              docId: doc.id,
                                              data: data,
                                            ),
                                          ),
                                        );
                                      } else if (value == 'delete') {
                                        final confirmed =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) =>
                                              Directionality(
                                            textDirection: TextDirection.rtl,
                                            child: AlertDialog(
                                              backgroundColor:
                                                  const Color(0xff1E293B),
                                              title: const Text(
                                                'حذف العقار',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              content: const Text(
                                                'هل أنت متأكد من حذف هذا العقار؟ لا يمكن التراجع عن هذه العملية',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  height: 1.5,
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                    dialogContext,
                                                    false,
                                                  ),
                                                  child: const Text(
                                                    'إلغاء',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ),
                                                FilledButton.icon(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                    dialogContext,
                                                    true,
                                                  ),
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 17,
                                                  ),
                                                  label: const Text('حذف'),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.redAccent,
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        10,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );

                                        if (confirmed == true) {
                                          await FirebaseFirestore.instance
                                              .collection("properties")
                                              .doc(doc.id)
                                              .delete();
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: Color(0xff60A5FA),
                                            ),
                                            SizedBox(width: 9),
                                            Text(
                                              'تعديل العقار',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: Colors.redAccent,
                                            ),
                                            SizedBox(width: 9),
                                            Text(
                                              'حذف العقار',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                if ((_catalog?.hasMore ?? false) ||
                    filteredDocs.length > _visibleCount) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_catalog?.loadingMore ?? false) return;
                          _visibleCount += 20;
                          _catalog?.loadMore();
                        });
                      },
                      icon: const Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'عرض المزيد',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xffD4AF37),
                        side: BorderSide(
                          color: const Color(0xffD4AF37).withValues(alpha: .35),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
