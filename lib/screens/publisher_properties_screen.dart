import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/currency.dart';
import '../utils/property_default_images.dart';
import 'property_details.dart';

class PublisherPropertiesScreen extends StatefulWidget {
  final String publisherUid;
  final String publisherName;
  final String publisherPhotoUrl;
  final bool isVerified;

  const PublisherPropertiesScreen({
    super.key,
    required this.publisherUid,
    required this.publisherName,
    this.publisherPhotoUrl = '',
    this.isVerified = false,
  });

  @override
  State<PublisherPropertiesScreen> createState() =>
      _PublisherPropertiesScreenState();
}

class _PublisherPropertiesScreenState extends State<PublisherPropertiesScreen> {
  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);
  static const Color _card = Color(0xff1E293B);
  static const Color _muted = Color(0xff94A3B8);

  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _queryNotifier = ValueNotifier<String>('');

  @override
  void dispose() {
    _searchController.dispose();
    _queryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.white,
          title: const Text(
            'عقارات الناشر',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('properties')
              .where('userId', isEqualTo: widget.publisherUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _gold),
              );
            }

            if (snapshot.hasError) {
              return _emptyState(
                icon: Icons.cloud_off_rounded,
                title: 'تعذر تحميل العقارات',
                subtitle: 'حدث خطأ أثناء جلب عقارات الناشر. حاول مرة أخرى',
              );
            }

            final docs = (snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((doc) => doc.data()['status'] == 'approved')
                .toList();

            docs.sort((a, b) {
              final aTime = _timestamp(a.data()['createdAt']);
              final bTime = _timestamp(b.data()['createdAt']);

              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            final totalViews = docs.fold<int>(
              0,
              (sum, doc) => sum + _intValue(doc.data()['views']),
            );

            final featuredCount =
                docs.where((doc) => doc.data()['isFeatured'] == true).length;

            return ValueListenableBuilder<String>(
              valueListenable: _queryNotifier,
              builder: (context, query, _) {
                final normalizedQuery = query.trim().toLowerCase();

                final filteredDocs = docs.where((doc) {
                  final data = doc.data();
                  final searchable = [
                    data['title'],
                    data['adNumber'],
                    data['city'],
                    data['areaName'],
                    data['propertyType'],
                  ]
                      .map((value) => value?.toString() ?? '')
                      .join(' ')
                      .toLowerCase();

                  return searchable.contains(normalizedQuery);
                }).toList();

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildPublisherHeader(
                        totalProperties: docs.length,
                        totalViews: totalViews,
                        featuredCount: featuredCount,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildSearchBar(
                        total: docs.length,
                        query: query,
                      ),
                    ),
                    if (filteredDocs.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _emptyState(
                          icon: docs.isEmpty
                              ? Icons.home_work_outlined
                              : Icons.search_off_rounded,
                          title: docs.isEmpty
                              ? 'لا توجد عقارات منشورة'
                              : 'لا توجد نتائج مطابقة',
                          subtitle: docs.isEmpty
                              ? 'لا توجد عقارات منشورة لهذا الناشر حالياً.'
                              : 'جرّب البحث باسم العقار أو رقمه أو المنطقة',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        sliver: SliverList.builder(
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _PropertyCard(
                                data: doc.data(),
                                docId: doc.id,
                                onTap: () => _openProperty(
                                  context,
                                  doc.id,
                                  doc.data(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPublisherHeader({
    required int totalProperties,
    required int totalViews,
    required int featuredCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _gold.withValues(alpha: .20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_gold, Color(0xff8C6F18)],
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: _background,
                  backgroundImage: widget.publisherPhotoUrl.trim().isNotEmpty
                      ? NetworkImage(widget.publisherPhotoUrl.trim())
                      : null,
                  child: widget.publisherPhotoUrl.trim().isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          color: _gold,
                          size: 34,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.publisherName.trim().isNotEmpty
                                ? widget.publisherName.trim()
                                : 'ناشر العقار',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (widget.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: _gold,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'العقارات المنشورة للناشر',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.real_estate_agent_rounded,
                  color: _gold,
                  size: 23,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _StatBox(
                icon: Icons.home_work_outlined,
                value: '$totalProperties',
                label: 'عقار',
              ),
              const SizedBox(width: 8),
              _StatBox(
                icon: Icons.visibility_outlined,
                value: _compactNumber(totalViews),
                label: 'مشاهدة',
              ),
              const SizedBox(width: 8),
              _StatBox(
                icon: Icons.workspace_premium_outlined,
                value: '$featuredCount',
                label: 'مميز',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar({
    required int total,
    required String query,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          _queryNotifier.value = value;
        },
        style: const TextStyle(color: Colors.white),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'ابحث باسم العقار، الرقم أو المنطقة',
          hintStyle: const TextStyle(color: _muted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _gold),
          suffixIcon: query.isEmpty
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '$total',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: () {
                    _searchController.clear();
                    _queryNotifier.value = '';
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _muted,
                  ),
                ),
          filled: true,
          fillColor: _card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: .06),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: _gold,
              width: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  void _openProperty(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetails(
          property: null,
          imageUrl: (data['imageUrl'] ?? '').toString(),
          title: (data['title'] ?? '').toString(),
          location: (data['location'] ?? '').toString(),
          price: (data['price'] ?? '').toString(),
          negotiable: data['negotiable'] == true,
          rooms: _intValue(data['rooms']),
          bathrooms: _intValue(data['bathrooms']),
          area: _intValue(data['area']),
          frontage: (data['frontage'] as num?)?.toDouble(),
          depth: (data['depth'] as num?)?.toDouble(),
          floors: (data['floors'] as num?)?.toInt(),
          apartmentFloor: (data['apartmentFloor'] as num?)?.toInt(),
          unitsCount: (data['unitsCount'] as num?)?.toInt(),
          livingRooms: _intValue(data['livingRooms']),
          parking: _intValue(data['parking']),
          description: (data['description'] ?? '').toString(),
          ownerPhone: (data['ownerPhone'] ?? '').toString(),
          ownerWhatsapp: (data['ownerWhatsapp'] ?? '').toString(),
          publisherPhone: (data['publisherPhone'] ?? '').toString(),
          publisherWhatsapp: (data['publisherWhatsapp'] ?? '').toString(),
          publisherUid: (data['publisherUid'] ?? '').toString(),
          publisherName: (data['publisherName'] ?? '').toString(),
          publisherEmail: (data['publisherEmail'] ?? '').toString(),
          images: (data['images'] as List?) ?? [],
          features: (data['features'] as List?) ?? [],
          documentType: (data['documentType'] ?? '').toString(),
          furnitureStatus: (data['furnitureStatus'] ?? '').toString(),
          propertyType: (data['propertyType'] ?? '').toString(),
          adType: (data['adType'] ?? '').toString(),
          city: (data['city'] ?? '').toString(),
          areaName: (data['areaName'] ?? '').toString(),
          landmark: (data['landmark'] ?? '').toString(),
          latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
          isVerified: data['isVerified'] == true,
          isFeatured: data['isFeatured'] == true,
          availabilityStatus: (data['availabilityStatus'] ?? '').toString(),
          views: _intValue(data['views']),
          createdAt: data['createdAt'] as Timestamp?,
          buildYear: _intValue(data['buildYear']),
          propertyNumber: _intValue(data['adNumber']),
          docId: docId,
          isFavorite: false,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: .08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _gold.withValues(alpha: .14),
                ),
              ),
              child: Icon(icon, color: _gold.withValues(alpha: .65), size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Timestamp? _timestamp(dynamic value) {
    return value is Timestamp ? value : null;
  }

  static String _compactNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}م';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}ك';
    }
    return '$value';
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  static const Color _gold = Color(0xffD4AF37);
  static const Color _muted = Color(0xff94A3B8);

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: .05),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: _gold, size: 19),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.data,
    required this.docId,
    required this.onTap,
  });

  static const Color _gold = Color(0xffD4AF37);
  static const Color _card = Color(0xff1E293B);
  static const Color _muted = Color(0xff94A3B8);

  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = (data['imageUrl'] ?? '').toString().trim();
    final propertyType = (data['propertyType'] ?? '').toString();

    final fallback = PropertyDefaultImages.getImage(propertyType);
    final displayImage = image.isNotEmpty ? image : fallback;

    final isFeatured = data['isFeatured'] == true;
    final title = (data['title'] ?? 'عقار').toString().trim();
    final location = _location(data);
    final adNumber = (data['adNumber'] ?? '--').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isFeatured
                  ? _gold.withValues(alpha: .32)
                  : Colors.white.withValues(alpha: .06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: SizedBox(
                  height: 205,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _PropertyImage(
                        image: displayImage,
                        fallback: fallback,
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: .04),
                                Colors.black.withValues(alpha: .68),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _GlassTag(
                          icon: Icons.tag_rounded,
                          label: '#$adNumber',
                        ),
                      ),
                      if (isFeatured)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .22),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Colors.black,
                                  size: 15,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'مميز',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        right: 14,
                        left: 14,
                        bottom: 14,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.open_in_new_rounded,
                              color: Colors.white70,
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: _gold,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            iqd(data['price']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _InfoPill(
                          icon: Icons.visibility_outlined,
                          label: '${_intValue(data['views'])}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _location(Map<String, dynamic> data) {
    final parts = <String>[
      (data['city'] ?? '').toString().trim(),
      (data['district'] ?? '').toString().trim(),
      (data['areaName'] ?? '').toString().trim(),
    ];

    final unique = <String>[];
    for (final part in parts) {
      if (part.isNotEmpty && !unique.contains(part)) {
        unique.add(part);
      }
    }

    return unique.isEmpty ? 'الموقع غير محدد' : unique.join(' • ');
  }

  static int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _PropertyImage extends StatelessWidget {
  const _PropertyImage({
    required this.image,
    required this.fallback,
  });

  final String image;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    if (image.startsWith('assets/')) {
      return Image.asset(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          fallback,
          fit: BoxFit.cover,
        ),
      );
    }

    return Image.network(
      image,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        fallback,
        fit: BoxFit.cover,
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(fallback, fit: BoxFit.cover),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _PropertyCard._gold,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlassTag extends StatelessWidget {
  const _GlassTag({
    required this.icon,
    required this.label,
  });

  static const Color _gold = Color(0xffD4AF37);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .48),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: .12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _gold, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  static const Color _muted = Color(0xff94A3B8);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _muted, size: 15),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
