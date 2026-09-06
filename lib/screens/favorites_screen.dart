import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/property_card.dart';
import 'property_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/currency.dart';
import '../widgets/aqar_refresh_indicator.dart';
import '../services/favorites_service.dart';

class FavoritesScreen extends StatefulWidget {
  final VoidCallback? onExplore;

  const FavoritesScreen({
    super.key,
    this.onExplore,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _favoritesSub;

  final List<String> _favoriteIds = [];
  final Map<String, Map<String, dynamic>> _properties = {};

  bool _loading = true;
  bool _loadingMore = false;
  int _visibleCount = _pageSize;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _listenToFavorites();
  }

  @override
  void dispose() {
    _favoritesSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenToFavorites() {
    final user = _user;

    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    _favoritesSub?.cancel();

    _favoritesSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .snapshots()
        .listen(
      (snapshot) async {
        final ids = snapshot.docs.map((doc) => doc.id).toList();

        // نحذف فقط العقارات التي لم تعد في المفضلة.
        _properties.removeWhere((id, _) => !ids.contains(id));

        _favoriteIds
          ..clear()
          ..addAll(ids);

        if (_visibleCount < _pageSize) {
          _visibleCount = _pageSize;
        }

        if (_visibleCount > _favoriteIds.length && _favoriteIds.isNotEmpty) {
          // لا نعيد العدد إلى 10 عند حذف عنصر، نحافظ على العدد المعروض قدر الإمكان.
          _visibleCount = _visibleCount.clamp(1, _favoriteIds.length);
        }

        await _loadVisibleProperties();

        if (!mounted) return;

        setState(() {
          _loading = false;
        });
      },
      onError: (error) {
        debugPrint('FAVORITES LISTEN ERROR: $error');

        if (!mounted) return;

        setState(() {
          _loading = false;
        });
      },
    );
  }

  Future<void> _loadVisibleProperties() async {
    if (_favoriteIds.isEmpty) return;

    final targetCount = _visibleCount.clamp(0, _favoriteIds.length);
    final idsToLoad = _favoriteIds
        .take(targetCount)
        .where((id) => !_properties.containsKey(id))
        .toList();

    if (idsToLoad.isEmpty) return;

    // نحمل الدفعة المطلوبة مرة واحدة فقط.
    final results = await Future.wait(
      idsToLoad.map(
        (id) =>
            FirebaseFirestore.instance.collection('properties').doc(id).get(),
      ),
    );

    for (final doc in results) {
      if (doc.exists && doc.data() != null) {
        _properties[doc.id] = doc.data()!;
      }
    }
  }

  Future<void> _refresh() async {
    _properties.clear();

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    await _loadVisibleProperties();

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _visibleCount >= _favoriteIds.length) return;

    final oldOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    setState(() {
      _loadingMore = true;
      _visibleCount = (_visibleCount + _pageSize).clamp(0, _favoriteIds.length);
    });

    await _loadVisibleProperties();

    if (!mounted) return;

    setState(() {
      _loadingMore = false;
    });

    // نحافظ على موضع المستخدم بعد إضافة الدفعة الجديدة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final max = _scrollController.position.maxScrollExtent;
      final target = oldOffset.clamp(0.0, max);

      if ((_scrollController.offset - target).abs() > 1) {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

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
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(
            child: CircularProgressIndicator(
              color: Color(0xffD4AF37),
            ),
          ),
        ],
      );
    }

    if (_favoriteIds.isEmpty) {
      return ListView(
        controller: _scrollController,
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
              onTap: widget.onExplore,
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

    final visibleIds = _favoriteIds
        .take(_visibleCount.clamp(0, _favoriteIds.length))
        .where(_properties.containsKey)
        .toList();

    final hasMore = _visibleCount < _favoriteIds.length;

    return ListView.builder(
      key: const PageStorageKey<String>('favorites_stable_list'),
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
      itemCount: visibleIds.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == visibleIds.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : _loadMore,
                icon: _loadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xffD4AF37),
                        ),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  _loadingMore
                      ? "جاري التحميل..."
                      : "عرض المزيد (${(_favoriteIds.length - _visibleCount).clamp(0, _pageSize)})",
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xffD4AF37),
                  side: BorderSide(
                    color: const Color(0xffD4AF37).withValues(alpha: .45),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          );
        }

        final propertyId = visibleIds[index];
        final data = _properties[propertyId]!;

        return Padding(
          key: ValueKey<String>('favorite_card_$propertyId'),
          padding: const EdgeInsets.only(bottom: 18),
          child: PropertyCard(
            docId: propertyId,
            imageUrl: data['imageUrl'] ?? '',
            title: data['title'] ?? '',
            location: data['location'] ?? '',
            price: iqd(data['price']).toString(),
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
            isFavorite: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PropertyDetails(
                    docId: propertyId,
                    propertyNumber: (data['adNumber'] as num?)?.toInt() ?? 0,
                    isFavorite: true,
                    availabilityStatus:
                        (data['availabilityStatus'] ?? 'available').toString(),
                    imageUrl: (data['imageUrl'] ?? '').toString(),
                    title: (data['title'] ?? '').toString(),
                    location: (data['location'] ?? '').toString(),
                    price: iqd(data['price']).toString(),
                    negotiable: data['negotiable'] == true,
                    rooms: (data['rooms'] as num?)?.toInt() ?? 0,
                    bathrooms: (data['bathrooms'] as num?)?.toInt() ?? 0,
                    area: (data['area'] as num?)?.toInt() ?? 0,
                    frontage: (data['frontage'] as num?)?.toDouble(),
                    depth: (data['depth'] as num?)?.toDouble(),
                    floors: (data['floors'] as num?)?.toInt(),
                    apartmentFloor: (data['apartmentFloor'] as num?)?.toInt(),
                    unitsCount: (data['unitsCount'] as num?)?.toInt(),
                    livingRooms: (data['livingRooms'] as num?)?.toInt() ?? 0,
                    parking: (data['parking'] as num?)?.toInt() ?? 0,
                    description: (data['description'] ?? '').toString(),
                    ownerPhone: (data['ownerPhone'] ?? '').toString(),
                    ownerWhatsapp: (data['ownerWhatsapp'] ?? '').toString(),
                    publisherPhone: (data['publisherPhone'] ?? '').toString(),
                    publisherWhatsapp:
                        (data['publisherWhatsapp'] ?? '').toString(),
                    publisherUid: (data['publisherUid'] ?? '').toString(),
                    publisherName: (data['publisherName'] ?? '').toString(),
                    publisherEmail: (data['publisherEmail'] ?? '').toString(),
                    propertyType: (data['propertyType'] ?? '').toString(),
                    adType: (data['adType'] ?? '').toString(),
                    city: (data['city'] ?? '').toString(),
                    areaName:
                        (data['areaName'] ?? data['district'] ?? '').toString(),
                    landmark: (data['landmark'] ?? '').toString(),
                    latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
                    longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
                    isVerified: data['isVerified'] ?? false,
                    isFeatured: data['isFeatured'] ?? false,
                    views: (data['views'] as num?)?.toInt() ?? 0,
                    createdAt: data['createdAt'],
                    buildYear: (data['buildYear'] as num?)?.toInt() ?? 0,
                    images: List<String>.from(data['images'] ?? []),
                    features: List<String>.from(data['features'] ?? []),
                    documentType: (data['documentType'] ?? '').toString(),
                    furnitureStatus: (data['furnitureStatus'] ?? '').toString(),
                  ),
                ),
              );
            },
            onFavorite: () async {
              await FavoritesService.toggleFavorite(propertyId);
            },
          ),
        );
      },
    );
  }
}
