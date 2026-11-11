import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../booking_admin_theme.dart';
import '../../booking_widgets.dart' show bookingMoney;
import '../../booking_screen.dart' show bookingCall;

class BookingAdminVenuesTab extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? venuesStream;

  const BookingAdminVenuesTab({super.key, this.venuesStream});

  @override
  State<BookingAdminVenuesTab> createState() => _BookingAdminVenuesTabState();
}

class _BookingAdminVenuesTabState extends State<BookingAdminVenuesTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _filterMode = 'all'; // all, published, pending, needs_revision, inactive
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dark = BookingAdminTheme.isDark(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.venuesStream ?? FirebaseFirestore.instance.collection('booking_venues').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'حدث خطأ في تحميل الأماكن: ${snapshot.error}',
                style: TextStyle(color: dark ? BookingAdminTheme.textMuted : const Color(0xFF64748B), fontFamily: 'Cairo'),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: BookingAdminTheme.gold));
        }

        final rawDocs = snapshot.data!.docs.map((d) {
          final map = Map<String, dynamic>.from(d.data());
          map['_id'] = d.id;
          return map;
        }).toList();

        final cleanDocs = BookingAdminDataSanitizer.prepareCleanVenuesList(rawDocs);

        final filteredDocs = cleanDocs.where((data) {
          final name = (data['name'] ?? '').toString().toLowerCase();
          final location = (data['location'] ?? '').toString().toLowerCase();
          final ownerName = (data['ownerName'] ?? '').toString().toLowerCase();
          final active = data['active'] == true;
          final verification = (data['verificationStatus'] ?? 'pending').toString().toLowerCase();

          // البحث
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matches = name.contains(q) || location.contains(q) || ownerName.contains(q);
            if (!matches) return false;
          }

          // التصفية
          if (_filterMode == 'published') {
            return active && (verification == 'verified' || verification == 'approved');
          } else if (_filterMode == 'pending') {
            return verification == 'pending' || (verification != 'verified' && verification != 'approved' && !active);
          } else if (_filterMode == 'needs_revision') {
            return verification == 'needs_revision';
          } else if (_filterMode == 'inactive') {
            return !active;
          }

          return true;
        }).toList();

        final pendingCount = cleanDocs.where((data) {
          final v = (data['verificationStatus'] ?? 'pending').toString().toLowerCase();
          final active = data['active'] == true;
          return v == 'pending' || (v != 'verified' && v != 'approved' && !active);
        }).length;

        final publishedCount = cleanDocs.where((data) => data['active'] == true).length;

        return Column(
          children: [
            // شريط البحث والتصفية المتطور
            _buildSearchAndFilters(
              docsCount: cleanDocs.length,
              pendingCount: pendingCount,
              publishedCount: publishedCount,
            ),

            // شريط إحصائي بسيط للنتائج
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Text(
                    'المعروض: ${filteredDocs.length} مكان من إجمالي ${cleanDocs.length}',
                    style: TextStyle(
                      color: BookingAdminTheme.textMute(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const Spacer(),
                  if (_searchQuery.isNotEmpty || _filterMode != 'all')
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.clear_all, size: 16, color: BookingAdminTheme.gold),
                      label: const Text(
                        'مسح الفلاتر',
                        style: TextStyle(color: BookingAdminTheme.gold, fontSize: 11, fontFamily: 'Cairo'),
                      ),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _filterMode = 'all';
                        });
                      },
                    ),
                ],
              ),
            ),

            // قائمة الأماكن
            Expanded(
              child: filteredDocs.isEmpty
                  ? BookingAdminEmptyState(
                      icon: Icons.villa_outlined,
                      title: 'لا توجد أماكن مطابقة',
                      description: 'لم يتم العثور على أي منشأة أو شاليه يطابق معايير البحث الحالية.',
                      actionLabel: (_searchQuery.isNotEmpty || _filterMode != 'all') ? 'إعادة ضبط الفلاتر' : null,
                      onAction: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _filterMode = 'all';
                        });
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final data = filteredDocs[index];
                        final id = (data['_id'] ?? 'venue_$index').toString();
                        return _buildVenueRowCard(id, data);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilters({
    required int docsCount,
    required int pendingCount,
    required int publishedCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: TextStyle(color: BookingAdminTheme.text(context), fontSize: 13, fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: 'ابحث باسم المكان، المدينة، الحي، أو اسم المالك...',
              hintStyle: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
              prefixIcon: Icon(Icons.search, size: 20, color: BookingAdminTheme.icon(context)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: BookingAdminTheme.icon(context)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: BookingAdminTheme.surfaceSecondary(context),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: BookingAdminTheme.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: BookingAdminTheme.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BookingAdminTheme.gold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('كل الأماكن ($docsCount)', 'all'),
                _chip('الأماكن المنشورة ($publishedCount)', 'published'),
                _chip(
                  pendingCount > 0 ? 'بانتظار الاعتماد ($pendingCount)' : 'بانتظار الاعتماد',
                  'pending',
                  highlight: pendingCount > 0,
                ),
                _chip('بحاجة لتعديل المالك', 'needs_revision'),
                _chip('معطلة / متوقفة', 'inactive'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, {bool highlight = false}) {
    final selected = _filterMode == value;
    final color = highlight ? const Color(0xFF38BDF8) : BookingAdminTheme.gold;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (s) {
          if (s) setState(() => _filterMode = value);
        },
        selectedColor: color.withValues(alpha: 0.18),
        backgroundColor: BookingAdminTheme.surfaceSecondary(context),
        labelStyle: TextStyle(
          color: selected ? color : BookingAdminTheme.textMute(context),
          fontSize: 11,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Cairo',
        ),
        side: BorderSide(
          color: selected ? color : BookingAdminTheme.border(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildVenueRowCard(String id, Map<String, dynamic> v) {
    final name = v['name'] ?? 'بدون اسم';
    final location = v['location'] ?? 'الأنبار';
    final category = v['category'] ?? 'chalet';
    final ownerName = v['ownerName'] ?? 'مالك غير محدد';
    final active = v['active'] == true;
    final verification = (v['verificationStatus'] ?? 'pending').toString();
    final price = v['price'] ?? 0;
    final deposit = v['deposit'] ?? 50000;
    final mediaPaths = (v['mediaPaths'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openVenueInspectionSheet(context, id, v),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // صورة المكان المصغرة
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: BookingAdminTheme.surfaceSecondary(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: BookingAdminTheme.border(context)),
                      ),
                      child: mediaPaths.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                mediaPaths.first.toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.villa_outlined,
                                  color: BookingAdminTheme.icon(context),
                                  size: 28,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.villa_outlined,
                              color: BookingAdminTheme.icon(context),
                              size: 28,
                            ),
                    ),
                    const SizedBox(width: 12),

                    // بيانات المكان والموقع والمالك
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: BookingAdminTheme.text(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              BookingAdminStatusBadge(
                                status: active
                                    ? 'approved'
                                    : (verification == 'needs_revision' ? 'needs_revision' : 'pending'),
                                label: active
                                    ? 'منشور'
                                    : (verification == 'needs_revision' ? 'بحاجة لتعديل المالك' : 'بانتظار الاعتماد'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_categoryLabel(category)} · $location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: BookingAdminTheme.textSub(context),
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'المالك: $ownerName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: BookingAdminTheme.textMute(context),
                              fontSize: 11,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: BookingAdminTheme.border(context), height: 1),
                const SizedBox(height: 10),

                // شريط الأسعار والإجراء السريع بعرض البطاقة الكامل لضمان عدم الاقتطاع
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _venuePricePill('السعر:', bookingMoney(price), BookingAdminTheme.text(context)),
                          _venuePricePill('العربون:', bookingMoney(deposit), BookingAdminTheme.gold),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'فحص واعتماد',
                          style: TextStyle(
                            color: BookingAdminTheme.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 11, color: BookingAdminTheme.gold),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _venuePricePill(String label, String value, Color valueColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            color: BookingAdminTheme.textMute(context),
            fontSize: 11,
            fontFamily: 'Cairo',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  void _openVenueInspectionSheet(BuildContext context, String venueId, Map<String, dynamic> v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VenueInspectionSheet(venueId: venueId, initialData: v),
    );
  }

  static String _categoryLabel(String c) {
    switch (c) {
      case 'chalet':
        return 'شاليه';
      case 'farm':
        return 'مزرعة';
      case 'hall':
        return 'قاعة';
      default:
        return 'أخرى';
    }
  }
}

/// نافذة مراجعة وتدقيق واعتماد المكان (SaaS Venue Inspection Sheet)
class _VenueInspectionSheet extends StatefulWidget {
  final String venueId;
  final Map<String, dynamic> initialData;

  const _VenueInspectionSheet({required this.venueId, required this.initialData});

  @override
  State<_VenueInspectionSheet> createState() => _VenueInspectionSheetState();
}

class _VenueInspectionSheetState extends State<_VenueInspectionSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final dark = BookingAdminTheme.isDark(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('booking_venues').doc(widget.venueId).snapshots(),
      builder: (context, snapshot) {
        final rawData = snapshot.data?.data() ?? widget.initialData;
        final data = BookingAdminDataSanitizer.sanitizeVenueMap({
          ...widget.initialData,
          ...rawData,
        });
        final active = data['active'] == true;
        final verification = (data['verificationStatus'] ?? 'pending').toString();
        final media = (data['mediaPaths'] as List?) ?? [];
        final videoUrl = data['videoUrl']?.toString();

        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: dark ? BookingAdminTheme.bgPrimary : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // مقبض النافذة
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: BookingAdminTheme.border(context),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // شريط العنوان
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: BookingAdminTheme.icon(context)),
                      tooltip: 'إغلاق والرجوع للقائمة',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] ?? 'تفاصيل المكان',
                            softWrap: true,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: BookingAdminTheme.text(context),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            'المعرف: ${widget.venueId} · ${data['location'] ?? ''}',
                            softWrap: true,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: BookingAdminTheme.textMute(context),
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    BookingAdminStatusBadge(
                      status: active ? 'approved' : verification,
                      label: active ? 'منشور للعامة' : 'معلق / غير منشور',
                    ),
                  ],
                ),
              ),
              Divider(color: BookingAdminTheme.border(context), height: 1),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // معرض الصور والفيديو
                    if (media.isNotEmpty || (videoUrl != null && videoUrl.isNotEmpty)) ...[
                      Text(
                        'معرض وسائط المكان المرفوعة:',
                        style: TextStyle(
                          color: BookingAdminTheme.textSub(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 110,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final img in media)
                              Container(
                                width: 110,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: BookingAdminTheme.border(context)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    img.toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Icon(Icons.broken_image_outlined, color: BookingAdminTheme.icon(context)),
                                    ),
                                  ),
                                ),
                              ),
                            if (videoUrl != null && videoUrl.isNotEmpty)
                              Container(
                                width: 110,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: BookingAdminTheme.surfaceSecondary(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: BookingAdminTheme.gold),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.play_circle_fill_rounded, color: BookingAdminTheme.gold, size: 36),
                                      SizedBox(height: 4),
                                      Text('فيديو المكان', style: TextStyle(color: BookingAdminTheme.gold, fontSize: 11, fontFamily: 'Cairo')),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // بيانات المالك والأسعار
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BookingAdminTheme.cardDecoration(context: context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoItem('المالك المسجل:', data['ownerName'] ?? 'غير متوفر'),
                          _infoItem('معرف المالك (UID):', data['ownerId'] ?? 'غير متوفر'),
                          _infoItem('السعر الأساسي:', bookingMoney(data['price'])),
                          _infoItem('العربون المطلوب:', bookingMoney(data['deposit'])),
                          _infoItem('العمولة (BPS):', '${data['commissionBps'] ?? 0} نقطة أساس'),
                          _infoItem('الشروط والتعليمات:', data['terms'] ?? 'لا توجد شروط مدونة'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // إثبات الملكية
                    _buildProofOfOwnershipSection(),
                    const SizedBox(height: 16),

                    // الإجراءات الإدارية الصارمة (مع التأكيد للمهام الحساسة)
                    _buildVenueAdminActions(active, verification, data),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              softWrap: true,
              style: TextStyle(
                color: BookingAdminTheme.text(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofOfOwnershipSection() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('booking_ownership_proofs').doc(widget.venueId).snapshots(),
      builder: (context, snap) {
        final proof = snap.data?.data();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BookingAdminTheme.cardDecoration(context: context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 18, color: BookingAdminTheme.gold),
                  const SizedBox(width: 8),
                  Text(
                    'وثائق وإثبات ملكية المكان',
                    style: TextStyle(
                      color: BookingAdminTheme.text(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (proof == null)
                Text(
                  'لم يتم رفع وثيقة إثبات ملكية منفصلة لهذا المكان بعد.',
                  style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
                )
              else ...[
                _infoItem('حالة الوثيقة:', proof['status'] ?? 'pending'),
                if (proof['path'] != null)
                  _infoItem('مسار الوثيقة:', proof['path'].toString()),
                if (proof['reason'] != null)
                  _infoItem('ملاحظات المراجعة:', proof['reason'].toString()),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildVenueAdminActions(bool active, String verification, Map<String, dynamic> venue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BookingAdminTheme.cardDecoration(
        context: context,
        borderColor: BookingAdminTheme.gold.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel_outlined, size: 18, color: BookingAdminTheme.gold),
              SizedBox(width: 8),
              Text(
                'قرارات الإدارة بشأن هذا المكان',
                style: TextStyle(color: BookingAdminTheme.gold, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_busy)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: BookingAdminTheme.gold)))
          else ...[
            // زر الاعتماد والتفعيل
            if (!active || verification != 'verified') ...[
              BookingAdminButton(
                isFullWidth: true,
                isPrimary: true,
                icon: Icons.check_circle_outline,
                label: 'اعتماد المكان وتفعيل نشره للعامة',
                onPressed: () async {
                  final ok = await BookingAdminConfirmDialog.show(
                    context: context,
                    title: 'اعتماد المكان ونشره',
                    message: 'سيتم توثيق المكان وتفعيله فورياً ليظهر في نتائج البحث لجميع المستخدمين.',
                    confirmLabel: 'نعم، اعتمد المكان',
                  );
                  if (ok) _approveAndActivateVenue(venue);
                },
              ),
              const SizedBox(height: 8),
            ],

            // زر إعادة للمالك لاستكمال البيانات
            BookingAdminButton(
              isFullWidth: true,
              icon: Icons.edit_note_rounded,
              label: 'إعادة المكان إلى المالك لاستكمال البيانات',
              onPressed: () => _returnToOwnerForRevision(venue),
            ),
            const SizedBox(height: 8),

            // زر إيقاف / إعادة تفعيل النشر
            if (active) ...[
              BookingAdminButton(
                isFullWidth: true,
                isDanger: true,
                icon: Icons.pause_circle_outline,
                label: 'إيقاف نشر المكان مؤقتاً (إخفاء من البحث)',
                onPressed: () async {
                  final ok = await BookingAdminConfirmDialog.show(
                    context: context,
                    title: 'إيقاف نشر المكان',
                    message: 'هل تريد إخفاء هذا المكان مؤقتاً من نتائج البحث للمستخدمين؟',
                    confirmLabel: 'إيقاف النشر',
                    isDestructive: true,
                  );
                  if (ok) _toggleActiveState(venue, false);
                },
              ),
            ] else ...[
              BookingAdminButton(
                isFullWidth: true,
                icon: Icons.play_circle_outline,
                label: 'إعادة تفعيل النشر للجمهور',
                onPressed: () => _toggleActiveState(venue, true),
              ),
            ],
            const SizedBox(height: 8),

            // رفض المكان نهائياً
            BookingAdminButton(
              isFullWidth: true,
              icon: Icons.block,
              label: 'رفض المكان نهائياً مع تسجيل السبب',
              onPressed: () => _rejectVenueWithReason(venue),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _approveAndActivateVenue(Map<String, dynamic> v) async {
    setState(() => _busy = true);
    try {
      try {
        await bookingCall('reviewBookingOwnershipProof', {
          'venueId': widget.venueId,
          'approved': true,
          'reason': 'معتمد ومحقق من قبل الإدارة',
        });
      } catch (_) {}

      await bookingCall('saveBookingVenue', {
        'id': widget.venueId,
        'ownerId': v['ownerId'],
        'name': v['name'],
        'category': v['category'] ?? 'chalet',
        'location': v['location'] ?? 'الأنبار',
        'price': v['price'] ?? 100000,
        'deposit': v['deposit'] ?? 50000,
        'active': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد وتفعيل نشر المكان بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر اعتماد المكان: $e', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleActiveState(Map<String, dynamic> v, bool active) async {
    setState(() => _busy = true);
    try {
      await bookingCall('saveBookingVenue', {
        'id': widget.venueId,
        'ownerId': v['ownerId'],
        'name': v['name'],
        'category': v['category'] ?? 'chalet',
        'location': v['location'] ?? 'الأنبار',
        'price': v['price'] ?? 100000,
        'deposit': v['deposit'] ?? 50000,
        'active': active,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(active ? 'تم تفعيل المكان' : 'تم إيقاف نشر المكان', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحديث الحالة: $e', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnToOwnerForRevision(Map<String, dynamic> v) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BookingAdminTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('طلب تعديلات من المالك', style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo')),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo'),
          decoration: InputDecoration(
            hintText: 'اكتب التعديلات المطلوبة (الصور، الترخيص، الأسعار)...',
            hintStyle: TextStyle(color: BookingAdminTheme.textMute(context), fontFamily: 'Cairo'),
            filled: true,
            fillColor: BookingAdminTheme.surfaceSecondary(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: BookingAdminTheme.textMute(context), fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BookingAdminTheme.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إرسال للمالك', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirm == true && ctrl.text.trim().isNotEmpty) {
      setState(() => _busy = true);
      try {
        await FirebaseFirestore.instance.collection('booking_venues').doc(widget.venueId).update({
          'verificationStatus': 'needs_revision',
          'revisionReason': ctrl.text.trim(),
          'active': false,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إعادة المكان للمالك بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الإجراء: $e', style: const TextStyle(fontFamily: 'Cairo'))),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _rejectVenueWithReason(Map<String, dynamic> v) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BookingAdminTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('رفض المكان نهائياً', style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo')),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo'),
          decoration: InputDecoration(
            hintText: 'سبب الرفض (مخالفة الشروط، وثائق غير صحيحة)...',
            hintStyle: TextStyle(color: BookingAdminTheme.textMute(context), fontFamily: 'Cairo'),
            filled: true,
            fillColor: BookingAdminTheme.surfaceSecondary(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: BookingAdminTheme.textMute(context), fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirm == true && ctrl.text.trim().isNotEmpty) {
      setState(() => _busy = true);
      try {
        await FirebaseFirestore.instance.collection('booking_venues').doc(widget.venueId).update({
          'verificationStatus': 'rejected',
          'rejectReason': ctrl.text.trim(),
          'active': false,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل رفض المكان', style: TextStyle(fontFamily: 'Cairo'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الإجراء: $e', style: const TextStyle(fontFamily: 'Cairo'))),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }
}
