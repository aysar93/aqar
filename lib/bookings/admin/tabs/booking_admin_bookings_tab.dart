import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../booking_admin_theme.dart';
import '../../booking_detail_access.dart' show bookingCanDisplayDetails;
import '../../booking_widgets.dart' show bookingMoney;
import '../../booking_screen.dart' show bookingCall;

class BookingAdminBookingsTab extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? bookingsStream;
  final Future<Uint8List?> Function(String path)? receiptLoader;
  final Future<dynamic> Function(String name, Map<String, dynamic> data)? callHook;

  const BookingAdminBookingsTab({
    super.key,
    this.bookingsStream,
    this.receiptLoader,
    this.callHook,
  });

  @override
  State<BookingAdminBookingsTab> createState() => _BookingAdminBookingsTabState();
}

class _BookingAdminBookingsTabState extends State<BookingAdminBookingsTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _categoryFilter = 'all';

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
      stream: widget.bookingsStream ?? FirebaseFirestore.instance.collection('bookings').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'حدث خطأ في تحميل بيانات الحجوزات: ${snapshot.error}',
                style: TextStyle(color: dark ? BookingAdminTheme.textMuted : const Color(0xFF64748B), fontFamily: 'Cairo'),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: BookingAdminTheme.gold));
        }

        final docs = snapshot.data!.docs;
        final filteredDocs = docs.where((doc) {
          final data = doc.data();
          final id = doc.id.toLowerCase();
          final hashIdx = doc.id.hashCode.abs();
          final rawVenueName = (data['venueSnapshot']?['name'] ?? data['venueName'] ?? '').toString();
          final cleanVenue = BookingAdminDataSanitizer.cleanVenueName(rawVenueName, index: hashIdx).toLowerCase();
          final rawCustomerName = (data['customerSnapshot']?['name'] ?? data['customerName'] ?? '').toString();
          final cleanCustomer = BookingAdminDataSanitizer.cleanCustomerName(rawCustomerName, index: hashIdx).toLowerCase();
          final phone = (data['customerSnapshot']?['phone'] ?? data['customerPhone'] ?? '').toString().toLowerCase();
          final rawOwnerName = (data['ownerName'] ?? '').toString();
          final cleanOwner = BookingAdminDataSanitizer.cleanOwnerName(rawOwnerName, index: hashIdx).toLowerCase();
          final status = (data['status'] ?? '').toString().toLowerCase();
          final category = (data['venueSnapshot']?['category'] ?? data['category'] ?? '').toString().toLowerCase();

          // البحث
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matches = id.contains(q) ||
                rawVenueName.toLowerCase().contains(q) ||
                cleanVenue.contains(q) ||
                rawCustomerName.toLowerCase().contains(q) ||
                cleanCustomer.contains(q) ||
                phone.contains(q) ||
                rawOwnerName.toLowerCase().contains(q) ||
                cleanOwner.contains(q);
            if (!matches) return false;
          }

          // تصفية الحالة
          if (_statusFilter != 'all') {
            if (_statusFilter == 'pending_action') {
              if (status != 'requested' && status != 'payment_review' && status != 'held') return false;
            } else if (_statusFilter == 'payment_review') {
              if (status != 'payment_review' && status != 'cancel_requested') return false;
            } else if (_statusFilter == 'confirmed_active') {
              if (status != 'confirmed' && status != 'arrived') return false;
            } else if (_statusFilter == 'completed') {
              if (status != 'completed') return false;
            } else if (_statusFilter == 'cancelled_rejected') {
              if (status != 'cancelled' && status != 'rejected' && status != 'expired' && status != 'payment_rejected') {
                return false;
              }
            } else if (_statusFilter != status) {
              return false;
            }
          }

          // تصفية نوع المنشأة
          if (_categoryFilter != 'all' && category != _categoryFilter) {
            return false;
          }

          return true;
        }).toList();

        final pendingCount = docs.where((d) {
          final s = (d.data()['status'] ?? '').toString();
          return s == 'requested' || s == 'payment_review' || s == 'held';
        }).length;

        final paymentReviewCount = docs.where((d) {
          final s = (d.data()['status'] ?? '').toString();
          return s == 'payment_review' || s == 'cancel_requested';
        }).length;

        return Column(
          children: [
            // شريط البحث والتصفية المطور (SaaS Search & Filter Suite)
            _buildSearchAndFilters(
              docsCount: docs.length,
              pendingCount: pendingCount,
              paymentReviewCount: paymentReviewCount,
            ),

            // شريط عداد النتائج وحالة الفلترة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Text(
                    'النتائج المعروضة: ${filteredDocs.length} حجز من أصل ${docs.length}',
                    style: TextStyle(
                      color: BookingAdminTheme.textMute(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const Spacer(),
                  if (_searchQuery.isNotEmpty || _statusFilter != 'all' || _categoryFilter != 'all')
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.clear_all, size: 16, color: BookingAdminTheme.gold),
                      label: const Text(
                        'إلغاء الفلاتر',
                        style: TextStyle(color: BookingAdminTheme.gold, fontSize: 11, fontFamily: 'Cairo'),
                      ),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _statusFilter = 'all';
                          _categoryFilter = 'all';
                        });
                      },
                    ),
                ],
              ),
            ),

            // قائمة الحجوزات
            Expanded(
              child: filteredDocs.isEmpty
                  ? BookingAdminEmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: 'لا توجد حجوزات مطابقة',
                      description: 'لم يتم العثور على أي حجز يطابق معايير البحث والتصفية المحددة حالياً.',
                      actionLabel: (_searchQuery.isNotEmpty || _statusFilter != 'all' || _categoryFilter != 'all')
                          ? 'إعادة تعيين البحث والتصفية'
                          : null,
                      onAction: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _statusFilter = 'all';
                          _categoryFilter = 'all';
                        });
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data();
                        return _buildBookingRowCard(doc.id, data);
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
    required int paymentReviewCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // حقل البحث الذكي مع زر مسح سريع
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: TextStyle(color: BookingAdminTheme.text(context), fontSize: 13, fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: 'ابحث برقم الحجز، المكان، اسم العميل، الهاتف، أو المالك...',
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

          // فلاتر الحالات (Status Filter Pills with live counts)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusChip('الكل ($docsCount)', 'all'),
                _statusChip(
                  pendingCount > 0 ? 'بانتظار إجراء ($pendingCount)' : 'بانتظار إجراء',
                  'pending_action',
                  highlight: pendingCount > 0,
                ),
                _statusChip(
                  paymentReviewCount > 0 ? 'مراجعة العربون ($paymentReviewCount)' : 'مراجعة العربون',
                  'payment_review',
                  highlight: paymentReviewCount > 0,
                ),
                _statusChip('مؤكدة ونشطة', 'confirmed_active'),
                _statusChip('مكتملة', 'completed'),
                _statusChip('ملغاة / مرفوضة', 'cancelled_rejected'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // فلاتر التصنيف (Category Filters)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryChip('كل التصنيفات', 'all'),
                _categoryChip('الشاليهات', 'chalet'),
                _categoryChip('المزارع', 'farm'),
                _categoryChip('القاعات', 'hall'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String value, {bool highlight = false}) {
    final selected = _statusFilter == value;
    final color = highlight ? const Color(0xFFEAB308) : BookingAdminTheme.gold;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (s) {
          if (s) setState(() => _statusFilter = value);
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

  Widget _categoryChip(String label, String value) {
    final selected = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (s) {
          setState(() => _categoryFilter = s ? value : 'all');
        },
        selectedColor: BookingAdminTheme.goldSubtle,
        backgroundColor: Colors.transparent,
        labelStyle: TextStyle(
          color: selected ? BookingAdminTheme.gold : BookingAdminTheme.textMute(context),
          fontSize: 11,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Cairo',
        ),
        side: BorderSide(
          color: selected ? BookingAdminTheme.gold : BookingAdminTheme.border(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildBookingRowCard(String id, Map<String, dynamic> b) {
    final hashIdx = id.hashCode.abs();
    final venueName = BookingAdminDataSanitizer.cleanVenueName(
      (b['venueSnapshot']?['name'] ?? b['venueName'])?.toString(),
      index: hashIdx,
    );
    final customerName = BookingAdminDataSanitizer.cleanCustomerName(
      (b['customerSnapshot']?['name'] ?? b['customerName'])?.toString(),
      index: hashIdx,
    );
    final phone = b['customerSnapshot']?['phone'] ?? b['customerPhone'] ?? '';
    final ownerName = BookingAdminDataSanitizer.cleanOwnerName(
      b['ownerName']?.toString(),
      index: hashIdx,
    );
    final status = (b['status'] ?? 'unknown').toString();
    final total = b['total'] is num ? (b['total'] as num) : (num.tryParse('${b['total'] ?? ''}') ?? 0);
    final deposit = b['deposit'] is num
        ? (b['deposit'] as num)
        : (b['paid'] is num
            ? (b['paid'] as num)
            : (num.tryParse('${b['deposit'] ?? b['paid'] ?? ''}') ?? 0));
    final remaining = (status == 'cancelled')
        ? 0
        : ((total > deposit) ? (total - deposit) : (b['remaining'] is num ? (b['remaining'] as num) : 0));
    final paymentMethod = BookingAdminDataSanitizer.formatPaymentMethod(b['paymentMethod']);
    final dateStr = _formatDate(b['start'] ?? b['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openBookingDetailsSheet(context, id, b),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس البطاقة: رقم الحجز، التاريخ، والشارة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: BookingAdminTheme.surfaceSecondary(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: BookingAdminTheme.border(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark_outline_rounded, size: 13, color: BookingAdminTheme.gold),
                              const SizedBox(width: 4),
                              Text(
                                id.length > 8 ? '#${id.substring(0, 8)}' : '#$id',
                                style: TextStyle(
                                  color: BookingAdminTheme.text(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: BookingAdminTheme.textMute(context),
                            fontSize: 11,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                    BookingAdminStatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 12),

                // تفاصيل المكان والضيف
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // أيقونة مبنى الحجز
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: BookingAdminTheme.surfaceSecondary(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: BookingAdminTheme.border(context)),
                      ),
                      child: Icon(Icons.villa_outlined, size: 22, color: BookingAdminTheme.icon(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            venueName,
                            maxLines: 2,
                            softWrap: true,
                            style: TextStyle(
                              color: BookingAdminTheme.text(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'الضيف: $customerName ${phone.isNotEmpty ? "($phone)" : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: BookingAdminTheme.textSub(context),
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            'المالك: $ownerName · وسيلة الدفع: $paymentMethod',
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

                // شريط المبالغ المالية وزر الإجراء السريع (3-Part Financial Strip)
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _pricePill('الإجمالي:', bookingMoney(total), BookingAdminTheme.text(context)),
                          _pricePill('العربون:', bookingMoney(deposit), BookingAdminTheme.gold),
                          if (remaining > 0)
                            _pricePill('المتبقي:', bookingMoney(remaining), BookingAdminTheme.textMute(context)),
                        ],
                      ),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'عرض وإدارة',
                          style: TextStyle(
                            color: BookingAdminTheme.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: BookingAdminTheme.gold),
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

  Widget _pricePill(String label, String value, Color valueColor) {
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

  void _openBookingDetailsSheet(BuildContext context, String bookingId, Map<String, dynamic> b) {
    BookingAdminDetailsSheet.show(
      context: context,
      bookingId: bookingId,
      initialData: b,
      receiptLoader: widget.receiptLoader,
      callHook: widget.callHook,
    );
  }

  static String _formatDate(dynamic val) {
    if (val == null) return 'غير محدد';
    DateTime? dt;
    if (val is Timestamp) dt = val.toDate();
    if (val is num) dt = DateTime.fromMillisecondsSinceEpoch(val.toInt());
    if (val is String) dt = DateTime.tryParse(val);
    if (dt == null) return val.toString();
    return '${dt.year}/${dt.month}/${dt.day}';
  }
}

/// نافذة تفاصيل الحجز الشاملة والعمليات الإدارية ومراجعة إيصال العربون (SaaS Booking Details Modal)
class BookingAdminDetailsSheet extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> initialData;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? bookingDocStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? auditStream;
  final Future<Uint8List?> Function(String path)? receiptLoader;
  final Future<dynamic> Function(String name, Map<String, dynamic> data)? callHook;
  final String? currentUid;
  final bool isAdminOrFinance;

  const BookingAdminDetailsSheet({
    super.key,
    required this.bookingId,
    required this.initialData,
    this.bookingDocStream,
    this.auditStream,
    this.receiptLoader,
    this.callHook,
    this.currentUid,
    this.isAdminOrFinance = true,
  });

  static Future<void> show({
    required BuildContext context,
    required String bookingId,
    required Map<String, dynamic> initialData,
    Future<Uint8List?> Function(String path)? receiptLoader,
    Future<dynamic> Function(String name, Map<String, dynamic> data)? callHook,
    String? currentUid,
    bool isAdminOrFinance = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingAdminDetailsSheet(
        bookingId: bookingId,
        initialData: initialData,
        receiptLoader: receiptLoader,
        callHook: callHook,
        currentUid: currentUid,
        isAdminOrFinance: isAdminOrFinance,
      ),
    );
  }

  @override
  State<BookingAdminDetailsSheet> createState() => _BookingAdminDetailsSheetState();
}

class _BookingAdminDetailsSheetState extends State<BookingAdminDetailsSheet> {
  bool _busy = false;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _docStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _auditStream;

  @override
  void initState() {
    super.initState();
    _docStream = widget.bookingDocStream ?? _safeBookingDocStream();
    _auditStream = widget.auditStream ?? _safeAuditStream();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _safeBookingDocStream() {
    try {
      return FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _safeAuditStream() {
    try {
      return FirebaseFirestore.instance
          .collection('booking_action_audit')
          .where('bookingId', isEqualTo: widget.bookingId)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = BookingAdminTheme.isDark(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _docStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? widget.initialData;
        final status = (data['status'] ?? 'unknown').toString();
        final hashIdx = widget.bookingId.hashCode.abs();
        final venueName = BookingAdminDataSanitizer.cleanVenueName(
          (data['venueSnapshot']?['name'] ?? data['venueName'])?.toString(),
          index: hashIdx,
        );
        final customerName = BookingAdminDataSanitizer.cleanCustomerName(
          (data['customerSnapshot']?['name'] ?? data['customerName'])?.toString(),
          index: hashIdx,
        );
        final customerPhone = (data['customerSnapshot']?['phone'] ?? data['customerPhone'] ?? 'غير متوفر').toString();
        final ownerName = BookingAdminDataSanitizer.cleanOwnerName(
          data['ownerName']?.toString(),
          index: hashIdx,
        );
        final paymentMethod = BookingAdminDataSanitizer.formatPaymentMethod(data['paymentMethod']);
        final effectiveUid = widget.currentUid ?? 'admin_dashboard_session';
        final canViewDetails = bookingCanDisplayDetails(
          booking: data,
          uid: effectiveUid,
          admin: widget.isAdminOrFinance,
          finance: widget.isAdminOrFinance,
          privilegedUid: widget.isAdminOrFinance ? effectiveUid : null,
        );
        final rawReceiptPath = data['receiptPath']?.toString();
        final showReceiptSection = (rawReceiptPath != null && rawReceiptPath.trim().isNotEmpty) ||
            status == 'payment_review' ||
            status == 'payment_rejected' ||
            status == 'cancel_requested';

        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: dark ? BookingAdminTheme.bgPrimary : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // مقبض النافذة العلوي
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: BookingAdminTheme.border(context),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // شريط العنوان العلوي المنظم
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
                            'تفاصيل الحجز #${widget.bookingId}',
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
                            venueName,
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
                    BookingAdminStatusBadge(status: status),
                  ],
                ),
              ),
              Divider(color: BookingAdminTheme.border(context), height: 1),

              // التحقق من صلاحية الوصول قبل عرض بيانات الحجز أو الإيصال
              if (!canViewDetails)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BookingAdminTheme.cardDecoration(
                          context: context,
                          borderColor: BookingAdminTheme.badgeCancelledText.withValues(alpha: 0.4),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 44,
                              color: BookingAdminTheme.badgeCancelledText,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'لا تملك صلاحية عرض إيصال هذا الحجز (غير مخوّل)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: BookingAdminTheme.text(context),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'الوصول إلى تفاصيل الحجز وإيصال العربون المالي مقصور على الإدارة أو المراجع المالي المعتمد أو طرفي الحجز فقط.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: BookingAdminTheme.textMute(context),
                                fontSize: 12,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                // محتوى تفاصيل الحجز القابل للتمرير للمستخدم المخوّل
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // بيانات الإقامة والضيف
                      _buildSectionCard(
                        title: 'بيانات الحجز والضيف',
                        icon: Icons.person_outline_rounded,
                        children: [
                          _infoRow('اسم الضيف (العميل):', customerName),
                          _infoRow('رقم هاتف الضيف:', customerPhone),
                          _infoRow('المالك المسجل:', ownerName),
                          _infoRow('عدد الضيوف:', '${data['guestsCount'] ?? data['guestCount'] ?? 1} أشخاص'),
                          _infoRow('تاريخ الوصول:', _formatDateTime(data['start'])),
                          _infoRow('تاريخ المغادرة:', _formatDateTime(data['end'])),
                          if (data['notes'] != null &&
                              data['notes'].toString().isNotEmpty &&
                              !BookingAdminDataSanitizer.isSyntheticString(data['notes'].toString()))
                            _infoRow('ملاحظات الضيف:', data['notes'].toString()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // التفاصيل المالية والإيصال
                      _buildSectionCard(
                        title: 'البيانات المالية وطريقة الدفع',
                        icon: Icons.account_balance_wallet_outlined,
                        children: [
                          _infoRow('المبلغ الإجمالي:', bookingMoney(data['total'])),
                          _infoRow('العربون المعتمد:', bookingMoney(data['deposit'] ?? data['paid'])),
                          Builder(builder: (_) {
                            final tot = data['total'] is num ? (data['total'] as num) : (num.tryParse('${data['total'] ?? ''}') ?? 0);
                            final dep = data['deposit'] is num
                                ? (data['deposit'] as num)
                                : (data['paid'] is num ? (data['paid'] as num) : (num.tryParse('${data['deposit'] ?? data['paid'] ?? ''}') ?? 0));
                            final rem = status == 'cancelled'
                                ? 0
                                : ((tot > dep) ? (tot - dep) : (data['remaining'] ?? 0));
                            return _infoRow('المبلغ المتبقي للمالك:', bookingMoney(rem));
                          }),
                          _infoRow('وسيلة الدفع:', paymentMethod),
                          if (data['transactionNumber'] != null && data['transactionNumber'].toString().trim().isNotEmpty)
                            _infoRow('رقم الحوالة / الإيصال:', data['transactionNumber'].toString()),
                          if (data['reviewedBy'] != null)
                            _infoRow('مراجع العربون:', data['reviewedBy'].toString()),
                          if (showReceiptSection) ...[
                            const SizedBox(height: 10),
                            Text(
                              'صورة إيصال التحويل المرفوع:',
                              style: TextStyle(
                                color: BookingAdminTheme.textSub(context),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            const SizedBox(height: 8),
                            BookingAdminReceiptViewer(
                              receiptPath: rawReceiptPath,
                              isAuthorized: canViewDetails,
                              receiptLoader: widget.receiptLoader,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // الإجراءات الإدارية المتاحة (مع تأكيد العمليات الحساسة)
                      _buildAdminActions(status, data),
                      const SizedBox(height: 16),

                      // سجل العمليات والتدقيق (Audit Trail)
                      _buildAuditLogSection(),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BookingAdminTheme.goldSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: BookingAdminTheme.gold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: BookingAdminTheme.text(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: BookingAdminTheme.textMute(context),
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
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

  Widget _buildAdminActions(String status, Map<String, dynamic> data) {
    final canReviewDeposit = status == 'payment_review' ||
        (status == 'cancel_requested' && data['depositVerified'] != true && data['receiptPath'] != null);
    final isPartyToBooking = widget.currentUid != null &&
        (widget.currentUid == data['ownerId']?.toString() || widget.currentUid == data['customerId']?.toString());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BookingAdminTheme.cardDecoration(
        context: context,
        borderColor: BookingAdminTheme.gold.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, size: 18, color: BookingAdminTheme.gold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الإجراءات الإدارية والمالية المتاحة',
                  style: TextStyle(
                    color: BookingAdminTheme.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_busy)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: BookingAdminTheme.gold)))
          else ...[
            // 1. إجراءات مراجعة العربون (تتطلب مراجعاً مالياً مستقلاً عن طرفي الحجز)
            if (canReviewDeposit) ...[
              if (isPartyToBooking)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BookingAdminTheme.surfaceSecondary(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BookingAdminTheme.border(context)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: BookingAdminTheme.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'يتطلب اعتماد أو رفض العربون مراجعاً مالياً مستقلاً عن طرفي الحجز.',
                          style: TextStyle(
                            color: BookingAdminTheme.textSub(context),
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                BookingAdminButton(
                  isFullWidth: true,
                  isPrimary: true,
                  icon: Icons.check_circle_outline,
                  label: 'اعتماد العربون وتأكيد الحجز',
                  onPressed: () async {
                    final ok = await BookingAdminConfirmDialog.show(
                      context: context,
                      title: 'اعتماد العربون المالي',
                      message: 'هل تأكدت من وصول العربون إلى الحساب المعتمد وتريد اعتماد الحجز نهائياً؟',
                      confirmLabel: 'نعم، اعتمد الحجز',
                    );
                    if (ok) {
                      await _executeAction('confirmPayment', {
                        if (data['version'] is int) 'version': data['version'],
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                BookingAdminButton(
                  isFullWidth: true,
                  isDanger: true,
                  icon: Icons.cancel_outlined,
                  label: 'رفض الإيصال المالي',
                  onPressed: () => _promptReasonAndExecute(
                    'rejectPayment',
                    'رفض الإيصال المالي',
                    version: data['version'] is int ? data['version'] as int : null,
                  ),
                ),
              ],
            ],

            // 2. إجراءات الطلب الجديد
            if (status == 'requested') ...[
              BookingAdminButton(
                isFullWidth: true,
                isPrimary: true,
                icon: Icons.approval,
                label: 'الموافقة على الطلب وحجز الموعد',
                onPressed: () async {
                  final ok = await BookingAdminConfirmDialog.show(
                    context: context,
                    title: 'الموافقة على طلب الحجز',
                    message: 'سيتم قبول الطلب وإشعار العميل والمالك بدفع العربون.',
                    confirmLabel: 'موافقة',
                  );
                  if (ok) _executeAction('approve');
                },
              ),
              const SizedBox(height: 8),
              BookingAdminButton(
                isFullWidth: true,
                isDanger: true,
                icon: Icons.block,
                label: 'رفض طلب الحجز',
                onPressed: () => _promptReasonAndExecute('reject', 'رفض طلب الحجز'),
              ),
            ],

            // 3. إجراءات الحجز المؤكد
            if (status == 'confirmed') ...[
              BookingAdminButton(
                isFullWidth: true,
                icon: Icons.how_to_reg_outlined,
                label: 'تسجيل وصول الضيف (Check-in)',
                onPressed: () async {
                  final ok = await BookingAdminConfirmDialog.show(
                    context: context,
                    title: 'تسجيل وصول الضيف',
                    message: 'هل وصل الضيف إلى المكان لبدء فترة الإقامة؟',
                    confirmLabel: 'تسجيل الوصول',
                  );
                  if (ok) _executeAction('arrive');
                },
              ),
              const SizedBox(height: 8),
              BookingAdminButton(
                isFullWidth: true,
                isDanger: true,
                icon: Icons.cancel_outlined,
                label: 'إلغاء الحجز من الإدارة',
                onPressed: () => _promptReasonAndExecute('cancel', 'إلغاء الحجز من الإدارة'),
              ),
            ],

            // 4. إجراءات الحجز في حالة الوصول
            if (status == 'arrived') ...[
              BookingAdminButton(
                isFullWidth: true,
                isPrimary: true,
                icon: Icons.task_alt,
                label: 'إكمال الحجز وتسوية المدة',
                onPressed: () async {
                  final ok = await BookingAdminConfirmDialog.show(
                    context: context,
                    title: 'إكمال الحجز النهائي',
                    message: 'سيتم إغلاق الحجز وتسجيله كمكتمل بعد انتهاء فترة الإقامة.',
                    confirmLabel: 'إكمال الحجز',
                  );
                  if (ok) _executeAction('complete');
                },
              ),
            ],

            // 5. تسوية الاسترداد
            if (status == 'cancelled' && data['refundStatus'] == 'pending') ...[
              BookingAdminButton(
                isFullWidth: true,
                isPrimary: true,
                icon: Icons.money_off,
                label: 'تسوية الاسترداد المالي للعميل',
                onPressed: () => _promptRefundSettlement(
                  version: data['version'] is int ? data['version'] as int : null,
                ),
              ),
            ],

            if (status != 'requested' &&
                !canReviewDeposit &&
                status != 'confirmed' &&
                status != 'arrived' &&
                !(status == 'cancelled' && data['refundStatus'] == 'pending'))
              Text(
                'الحجز في حالة نهائية أو لا يتطلب اتخاذ إجراءات فورية.',
                style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditLogSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _auditStream,
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BookingAdminTheme.cardDecoration(context: context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: BookingAdminTheme.icon(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سجل العمليات والتدقيق على هذا الحجز',
                      style: TextStyle(
                        color: BookingAdminTheme.text(context),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                Text(
                  'لا توجد عمليات إدارية مسجلة على هذا الحجز بعد.',
                  style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
                )
              else
                Column(
                  children: [
                    for (final d in docs)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 6, color: BookingAdminTheme.gold),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d.data()['action'] ?? 'تحديث حالة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: BookingAdminTheme.textSub(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateTime(d.data()['createdAt']),
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
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeAction(String action, [Map<String, dynamic>? extra]) async {
    setState(() => _busy = true);
    try {
      final payload = <String, dynamic>{
        'bookingId': widget.bookingId,
        'action': action,
        if (extra != null) ...extra,
      };
      if (widget.callHook != null) {
        await widget.callHook!('actOnBooking', payload);
      } else {
        await bookingCall('actOnBooking', payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تنفيذ الإجراء بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
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

  Future<void> _promptReasonAndExecute(String action, String title, {int? version}) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BookingAdminTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo')),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo'),
          decoration: InputDecoration(
            hintText: 'اكتب سبب الإجراء للتوثيق والإشعار...',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: BookingAdminTheme.gold,
              foregroundColor: Colors.black,
              minimumSize: const Size(88, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirm == true && ctrl.text.trim().isNotEmpty) {
      await _executeAction(action, {
        'reason': ctrl.text.trim(),
        if (version != null) 'version': version,
      });
    }
  }

  Future<void> _promptRefundSettlement({int? version}) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BookingAdminTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تسوية الاسترداد المالي', style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo')),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo'),
          decoration: InputDecoration(
            hintText: 'أدخل رقم مرجع الحوالة أو الإيصال المسترد...',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: BookingAdminTheme.gold,
              foregroundColor: Colors.black,
              minimumSize: const Size(110, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد التسوية', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirm == true && ctrl.text.trim().isNotEmpty) {
      await _executeAction('settleRefund', {
        'refundReference': ctrl.text.trim(),
        if (version != null) 'version': version,
      });
    }
  }

  static String _formatDateTime(dynamic val) {
    if (val == null) return 'غير محدد';
    DateTime? dt;
    if (val is Timestamp) dt = val.toDate();
    if (val is num) dt = DateTime.fromMillisecondsSinceEpoch(val.toInt());
    if (val is String) dt = DateTime.tryParse(val);
    if (dt == null) return val.toString();
    return '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// عارض إيصال العربون المالي الآمن عبر Firebase Storage SDK مع معالجة كافة الحالات
class BookingAdminReceiptViewer extends StatefulWidget {
  final String? receiptPath;
  final bool isAuthorized;
  final Future<Uint8List?> Function(String path)? receiptLoader;

  const BookingAdminReceiptViewer({
    super.key,
    required this.receiptPath,
    this.isAuthorized = true,
    this.receiptLoader,
  });

  @override
  State<BookingAdminReceiptViewer> createState() => _BookingAdminReceiptViewerState();
}

class _BookingAdminReceiptViewerState extends State<BookingAdminReceiptViewer> {
  Future<Uint8List?>? _receiptFuture;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  @override
  void didUpdateWidget(covariant BookingAdminReceiptViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receiptPath != widget.receiptPath ||
        oldWidget.isAuthorized != widget.isAuthorized ||
        oldWidget.receiptLoader != widget.receiptLoader) {
      _initLoad();
    }
  }

  void _initLoad() {
    final path = widget.receiptPath?.trim() ?? '';
    if (!widget.isAuthorized || path.isEmpty) {
      _receiptFuture = null;
      return;
    }
    _receiptFuture = _loadBytes(path);
  }

  Future<Uint8List?> _loadBytes(String path) async {
    if (widget.receiptLoader != null) {
      return widget.receiptLoader!(path);
    }
    return FirebaseStorage.instance.ref(path).getData(10 * 1024 * 1024);
  }

  void _retry() {
    setState(() {
      _initLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. حالة المستخدم غير المخوّل
    if (!widget.isAuthorized) {
      return _buildStateBox(
        context: context,
        icon: Icons.lock_outline_rounded,
        iconColor: BookingAdminTheme.badgeCancelledText,
        title: 'لا تملك صلاحية عرض إيصال هذا الحجز (غير مخوّل)',
        subtitle: 'عرض الإيصال المالي مقصور على الإدارة أو المراجع المالي أو طرفي الحجز.',
      );
    }

    // 2. حالة عدم وجود إيصال مرفوع
    final path = widget.receiptPath?.trim() ?? '';
    if (path.isEmpty) {
      return _buildStateBox(
        context: context,
        icon: Icons.receipt_long_outlined,
        iconColor: BookingAdminTheme.textMute(context),
        title: 'لا يوجد إيصال تحويل مرفوع لهذا الحجز',
        subtitle: 'لم يقم العميل برفع صورة إيصال العربون بعد.',
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _receiptFuture,
      builder: (context, snap) {
        // 3. حالة التحميل
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: BookingAdminTheme.surfaceSecondary(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BookingAdminTheme.border(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: BookingAdminTheme.gold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'جارٍ تحميل صورة الإيصال المالي...',
                  style: TextStyle(
                    color: BookingAdminTheme.textSub(context),
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          );
        }

        // 4. حالة الخطأ (صلاحيات Storage أو ملف مفقود أو فشل شبكة)
        if (snap.hasError) {
          final err = snap.error;
          final errCode = err is FirebaseException ? err.code.toLowerCase() : err.toString().toLowerCase();
          if (errCode.contains('unauthorized') || errCode.contains('permission-denied') || errCode.contains('permission_denied')) {
            return _buildStateBox(
              context: context,
              icon: Icons.lock_outline_rounded,
              iconColor: BookingAdminTheme.badgeCancelledText,
              title: 'لا تملك صلاحية عرض إيصال هذا الحجز (غير مخوّل)',
              subtitle: 'رفضت قواعد أمان التخزين السحابي الوصول إلى ملف الإيصال.',
            );
          }
          if (errCode.contains('object-not-found') || errCode.contains('not-found') || errCode.contains('not_found')) {
            return _buildStateBox(
              context: context,
              icon: Icons.find_in_page_outlined,
              iconColor: BookingAdminTheme.badgePendingText,
              title: 'ملف الإيصال غير موجود في التخزين السحابي',
              subtitle: 'المسار المسجل: $path',
              onRetry: _retry,
            );
          }
          return _buildStateBox(
            context: context,
            icon: Icons.broken_image_outlined,
            iconColor: BookingAdminTheme.badgeCancelledText,
            title: 'تعذر تحميل أو عرض صورة الإيصال المالي',
            subtitle: 'تحقق من الاتصال بالشبكة أو أعد المحاولة.',
            onRetry: _retry,
          );
        }

        // 5. حالة البيانات الفارغة
        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty) {
          return _buildStateBox(
            context: context,
            icon: Icons.receipt_long_outlined,
            iconColor: BookingAdminTheme.textMute(context),
            title: 'لا يوجد إيصال تحويل مرفوع لهذا الحجز',
            subtitle: 'ملف الإيصال فارغ أو غير متوفر حالياً.',
            onRetry: _retry,
          );
        }

        // 6. عرض صورة الإيصال الفعلية مع إمكانية التكبير والمعاينة الدقيقة
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 240, minHeight: 140),
                color: BookingAdminTheme.surfaceSecondary(context),
                child: Image.memory(
                  bytes,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _buildStateBox(
                    context: context,
                    icon: Icons.broken_image_outlined,
                    iconColor: BookingAdminTheme.badgeCancelledText,
                    title: 'تعذر تحميل أو عرض صورة الإيصال المالي',
                    subtitle: 'بيانات الصورة تالفة أو بصيغة غير مدعومة.',
                    onRetry: _retry,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: BookingAdminTheme.gold,
                ),
                icon: const Icon(Icons.zoom_in_rounded, size: 18, color: BookingAdminTheme.gold),
                label: const Text(
                  'تكبير ومعاينة الإيصال الكامل',
                  style: TextStyle(
                    color: BookingAdminTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => Dialog(
                      backgroundColor: BookingAdminTheme.surface(ctx),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'معاينة إيصال العربون المالي',
                                    style: TextStyle(
                                      color: BookingAdminTheme.text(ctx),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close_rounded, color: BookingAdminTheme.icon(ctx)),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4.0,
                              child: Image.memory(
                                bytes,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'تعذر تحميل أو عرض صورة الإيصال المالي',
                                    style: TextStyle(
                                      color: BookingAdminTheme.textMute(ctx),
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
  }

  Widget _buildStateBox({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    VoidCallback? onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BookingAdminTheme.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BookingAdminTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  softWrap: true,
                  style: TextStyle(
                    color: BookingAdminTheme.text(context),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              softWrap: true,
              style: TextStyle(
                color: BookingAdminTheme.textMute(context),
                fontSize: 11,
                fontFamily: 'Cairo',
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: BookingAdminTheme.gold,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16, color: BookingAdminTheme.gold),
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(
                    color: BookingAdminTheme.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                onPressed: onRetry,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
