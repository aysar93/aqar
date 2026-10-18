import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../property_details.dart';
import 'widgets/search_bar_widget.dart';

class CommentsManagementScreen extends StatefulWidget {
  const CommentsManagementScreen({super.key});

  @override
  State<CommentsManagementScreen> createState() =>
      _CommentsManagementScreenState();
}

class _CommentsManagementScreenState extends State<CommentsManagementScreen> {
  static const Color _background = Color(0xff0F172A);
  static const Color _card = Color(0xff1E293B);
  static const Color _cardSoft = Color(0xff243247);
  static const Color _gold = Color(0xffD4AF37);
  static const Color _text = Color(0xffF8FAFC);
  static const Color _muted = Color(0xff94A3B8);
  static const Color _danger = Color(0xffEF4444);
  static const Color _success = Color(0xff22C55E);

  static const int _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  String _filter = 'all';
  int _visibleCount = _pageSize;

  final Map<String, Map<String, dynamic>> _userCache = {};
  final Set<String> _loadingUsers = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _textValue(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  DateTime? _timestampValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDate(dynamic value) {
    final date = _timestampValue(value);
    if (date == null) return 'بدون تاريخ';

    final now = DateTime.now();
    final sameDay =
        now.year == date.year && now.month == date.month && now.day == date.day;

    if (sameDay) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'اليوم، $hour:$minute';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _normalizeSearch(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  String _userName(
    Map<String, dynamic> comment,
    Map<String, dynamic>? user,
  ) {
    final candidates = [
      comment['userName'],
      comment['name'],
      user?['name'],
      user?['displayName'],
      user?['username'],
      user?['fullName'],
    ];

    for (final candidate in candidates) {
      final value = _textValue(candidate);
      if (value.isNotEmpty && value != 'مستخدم') return value;
    }

    return 'مستخدم';
  }

  String _userPhoto(
    Map<String, dynamic> comment,
    Map<String, dynamic>? user,
  ) {
    final candidates = [
      comment['userPhoto'],
      comment['photoUrl'],
      comment['imageUrl'],
      user?['photoUrl'],
      user?['imageUrl'],
      user?['profileImage'],
      user?['avatarUrl'],
    ];

    for (final candidate in candidates) {
      final value = _textValue(candidate);
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  Future<Map<String, dynamic>?> _loadUser(String uid) async {
    if (uid.isEmpty) return null;

    if (_userCache.containsKey(uid)) {
      return _userCache[uid];
    }

    if (_loadingUsers.contains(uid)) return null;
    _loadingUsers.add(uid);

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final data = snapshot.data();

      if (data != null) {
        _userCache[uid] = data;
      }

      return data;
    } finally {
      _loadingUsers.remove(uid);
    }
  }

  List<DocumentSnapshot<Object?>> _filterAndSort(
    List<DocumentSnapshot<Object?>> source,
  ) {
    final query = _normalizeSearch(_search);

    final List<DocumentSnapshot> result = source.where((doc) {
      final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

      final isHidden = data['isHidden'] == true;
      final isPinned = data['isPinned'] == true;

      if (_filter == 'visible' && isHidden) return false;
      if (_filter == 'hidden' && !isHidden) return false;
      if (_filter == 'pinned' && !isPinned) return false;

      if (query.isEmpty) return true;

      final comment = _normalizeSearch(
        _textValue(data['text'] ?? data['comment']),
      );

      final name = _normalizeSearch(
        _textValue(data['userName'] ?? data['name']),
      );

      final email = _normalizeSearch(
        _textValue(data['userEmail']),
      );

      final phone = _normalizeSearch(
        _textValue(data['userPhone']),
      );

      final propertyNumber = _normalizeSearch(
        _textValue(
          data['propertyNumber'] ?? data['adNumber'] ?? data['propertyNo'],
        ),
      );

      return comment.contains(query) ||
          name.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          propertyNumber.contains(query);
    }).toList();

    result.sort((a, b) {
      final dataA = (a.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

      final dataB = (b.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

      final dateA = _timestampValue(dataA['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final dateB = _timestampValue(dataB['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return dateB.compareTo(dateA);
    });

    return result;
  }

  Future<void> _openProperty(DocumentSnapshot commentDoc) async {
    final propertyId = commentDoc.reference.parent.parent?.id;

    if (propertyId == null || propertyId.isEmpty) {
      _showMessage('تعذر تحديد العقار المرتبط بهذا التعليق');
      return;
    }

    try {
      final propertySnapshot = await FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .get();

      if (!propertySnapshot.exists || !mounted) {
        _showMessage('العقار المرتبط بالتعليق غير موجود');
        return;
      }

      final data = propertySnapshot.data() ?? {};
      final propertyNumber = (data['propertyNumber'] ??
              data['adNumber'] ??
              data['propertyNo'] ??
              0) is num
          ? ((data['propertyNumber'] ??
                  data['adNumber'] ??
                  data['propertyNo'] ??
                  0) as num)
              .toInt()
          : int.tryParse(
                _textValue(
                  data['propertyNumber'] ??
                      data['adNumber'] ??
                      data['propertyNo'],
                ),
              ) ??
              0;

      final imageUrl = _textValue(
        data['imageUrl'] ??
            ((data['images'] is List && (data['images'] as List).isNotEmpty)
                ? (data['images'] as List).first
                : ''),
      );

      final priceValue = data['price'];
      final price = priceValue is num
          ? priceValue.toString()
          : _textValue(priceValue, '0');

      final images = data['images'] is List
          ? List<dynamic>.from(data['images'] as List)
          : <dynamic>[];

      final features = data['features'] is List
          ? List<dynamic>.from(data['features'] as List)
          : <dynamic>[];

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PropertyDetails(
            docId: propertySnapshot.id,
            property: null,
            imageUrl: imageUrl,
            title: _textValue(data['title'], 'عقار'),
            location: _textValue(data['location']),
            price: price,
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
            description: _textValue(data['description']),
            ownerPhone: _textValue(data['ownerPhone']),
            ownerWhatsapp: _textValue(data['ownerWhatsapp']),
            publisherUid: _textValue(data['publisherUid'] ?? data['userId']),
            publisherName: _textValue(
              data['publisherName'] ?? data['userName'],
              'مستخدم',
            ),
            publisherEmail: _textValue(data['publisherEmail']),
            publisherPhone: _textValue(data['publisherPhone']),
            publisherWhatsapp: _textValue(data['publisherWhatsapp']),
            images: images,
            features: features,
            documentType: _textValue(data['documentType']),
            furnitureStatus: _textValue(data['furnitureStatus']),
            propertyType: _textValue(data['propertyType']),
            adType: _textValue(data['adType']),
            city: _textValue(data['city']),
            areaName: _textValue(data['areaName']),
            landmark: _textValue(data['landmark']),
            latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
            isVerified: data['isVerified'] == true,
            isFeatured: data['isFeatured'] == true,
            availabilityStatus: _textValue(data['availabilityStatus']),
            views: (data['views'] as num?)?.toInt() ?? 0,
            createdAt: data['createdAt'] is Timestamp
                ? data['createdAt'] as Timestamp
                : null,
            buildYear: (data['buildYear'] as num?)?.toInt() ?? 0,
            propertyNumber: propertyNumber,
          ),
        ),
      );
    } catch (e) {
      _showMessage('تعذر فتح العقار');
    }
  }

  Future<void> _toggleHidden(DocumentSnapshot doc, bool hidden) async {
    try {
      await doc.reference.update({
        'isHidden': hidden,
        'moderatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showMessage(hidden ? 'تم إخفاء التعليق' : 'تم إظهار التعليق');
      }
    } catch (_) {
      _showMessage('تعذر تحديث حالة التعليق');
    }
  }

  Future<void> _togglePinned(DocumentSnapshot doc, bool pinned) async {
    try {
      await doc.reference.update({
        'isPinned': pinned,
        'pinnedAt': pinned ? FieldValue.serverTimestamp() : null,
      });

      if (mounted) {
        _showMessage(pinned ? 'تم تثبيت التعليق' : 'تم إلغاء تثبيت التعليق');
      }
    } catch (_) {
      _showMessage('تعذر تحديث تثبيت التعليق');
    }
  }

  Future<void> _deleteComment(DocumentSnapshot doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _card,
            title: const Text(
              'حذف التعليق',
              style: TextStyle(color: _text, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'هل أنت متأكد من حذف هذا التعليق؟ لا يمكن التراجع عن العملية',
              style: TextStyle(color: _muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      await doc.reference.delete();
      if (mounted) _showMessage('تم حذف التعليق بنجاح');
    } catch (_) {
      _showMessage('تعذر حذف التعليق');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.right),
          backgroundColor: _cardSoft,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    Color accent = _gold,
  }) {
    return Expanded(
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                color: accent,
                size: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 9.5,
                height: 1.05,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _text,
                fontSize: 15,
                height: 1.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required int count,
  }) {
    final selected = _filter == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _filter = value;
          _visibleCount = _pageSize;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? _gold : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _gold : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          '$label  $count',
          style: TextStyle(
            color: selected ? Colors.black : _text,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(
    Map<String, dynamic> comment,
    Map<String, dynamic>? user,
  ) {
    final photo = _userPhoto(comment, user);
    final name = _userName(comment, user);

    if (photo.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: _cardSoft,
        backgroundImage: NetworkImage(photo),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: _gold.withValues(alpha: 0.16),
      child: Text(
        name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: _gold,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildCommentCard(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final uid = _textValue(data['userId']);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadUser(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = _userName(data, user);
        final photo = _userPhoto(data, user);
        final comment = _textValue(
          data['text'] ?? data['comment'],
          'تعليق بدون نص',
        );
        final hidden = data['isHidden'] == true;
        final pinned = data['isPinned'] == true;
        final propertyId = doc.reference.parent.parent?.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: pinned
                  ? _gold.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openProperty(doc),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildUserAvatar(data, user),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (pinned) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.push_pin_rounded,
                                    color: _gold,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(data['createdAt']),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        color: _cardSoft,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: _muted,
                        ),
                        onSelected: (value) {
                          if (value == 'pin') {
                            _togglePinned(doc, !pinned);
                          } else if (value == 'hide') {
                            _toggleHidden(doc, !hidden);
                          } else if (value == 'delete') {
                            _deleteComment(doc);
                          } else if (value == 'property') {
                            _openProperty(doc);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'property',
                            child: Text(
                              propertyId == null
                                  ? 'العقار غير متوفر'
                                  : 'فتح العقار',
                              style: const TextStyle(color: _text),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(
                              pinned ? 'إلغاء تثبيت التعليق' : 'تثبيت التعليق',
                              style: const TextStyle(color: _text),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'hide',
                            child: Text(
                              hidden ? 'إظهار التعليق' : 'إخفاء التعليق',
                              style: const TextStyle(color: _text),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'حذف التعليق',
                              style: TextStyle(color: _danger),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.035),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      comment,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: hidden ? _muted : _text,
                        fontSize: 14,
                        height: 1.55,
                        decoration: hidden ? TextDecoration.lineThrough : null,
                        decorationColor: _danger,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Icon(
                        hidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 15,
                        color: hidden ? _danger : _success,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        hidden ? 'مخفي' : 'ظاهر',
                        style: TextStyle(
                          color: hidden ? _danger : _success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (propertyId != null)
                        Text(
                          'اضغط لفتح العقار',
                          style: TextStyle(
                            color: _gold.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _text,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'إدارة التعليقات',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collectionGroup('comments')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _gold),
              );
            }

            final allDocs = <DocumentSnapshot<Object?>>[
              ...(snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
            ];
            final visibleDocs = _filterAndSort(allDocs);

            final total = allDocs.length;
            final hidden = allDocs.where((doc) {
              final data =
                  (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
              return data['isHidden'] == true;
            }).length;

            final pinned = allDocs.where((doc) {
              final data =
                  (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
              return data['isPinned'] == true;
            }).length;
            final active = total - hidden;

            final shownCount = visibleDocs.length < _visibleCount
                ? visibleDocs.length
                : _visibleCount;

            final shownDocs = visibleDocs.take(shownCount).toList();
            final canLoadMore = shownCount < visibleDocs.length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Column(
                    children: [
                      SearchBarWidget(
                        controller: _searchController,
                        hintText:
                            'ابحث بالاسم أو الهاتف أو البريد أو نص التعليق',
                        onChanged: (value) {
                          setState(() {
                            _search = value;
                            _visibleCount = _pageSize;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatCard(
                            title: 'إجمالي التعليقات',
                            value: total,
                            icon: Icons.forum_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            title: 'الظاهرة',
                            value: active,
                            icon: Icons.visibility_rounded,
                            accent: _success,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            title: 'المخفية',
                            value: hidden,
                            icon: Icons.visibility_off_rounded,
                            accent: _danger,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                label: 'الكل',
                                value: 'all',
                                count: total,
                              ),
                              const SizedBox(width: 7),
                              _buildFilterChip(
                                label: 'الظاهرة',
                                value: 'visible',
                                count: active,
                              ),
                              const SizedBox(width: 7),
                              _buildFilterChip(
                                label: 'المخفية',
                                value: 'hidden',
                                count: hidden,
                              ),
                              const SizedBox(width: 7),
                              _buildFilterChip(
                                label: 'المثبتة',
                                value: 'pinned',
                                count: pinned,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visibleDocs.isEmpty
                      ? _buildEmptyState(
                          _search.isEmpty
                              ? 'لا توجد تعليقات حتى الآن'
                              : 'لا توجد نتائج مطابقة للبحث',
                        )
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: shownDocs.length + (canLoadMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == shownDocs.length) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: 2,
                                  bottom: 8,
                                ),
                                child: SizedBox(
                                  height: 48,
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _gold,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _visibleCount += _pageSize;
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.expand_more_rounded,
                                    ),
                                    label: Text(
                                      'عرض المزيد (${visibleDocs.length - shownCount})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return _buildCommentCard(shownDocs[index]);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 260;

        return ListView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            compact ? 12 : 24,
            20,
            24,
          ),
          children: [
            SizedBox(
              height: compact ? 120 : 170,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: compact ? 54 : 64,
                      height: compact ? 54 : 64,
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        color: _gold,
                        size: compact ? 27 : 32,
                      ),
                    ),
                    SizedBox(height: compact ? 9 : 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text,
                        fontSize: compact ? 14 : 16,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 5),
                      const Text(
                        'ستظهر التعليقات الجديدة هنا تلقائيًا',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _danger.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _danger.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: _danger,
                size: 38,
              ),
              const SizedBox(height: 10),
              const Text(
                'تعذر تحميل التعليقات',
                style: TextStyle(
                  color: _text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
