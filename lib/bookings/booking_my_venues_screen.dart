import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_widgets.dart';
import 'booking_browse_ui.dart';
import 'booking_management.dart';
import 'booking_media_image.dart';
import 'booking_screen.dart';

/// Manage My Venues screen («إدارة أماكني»).
/// Displays all venues owned by the current user with verification badges,
/// quick editor access, calendar closures, and booking request tracking.
class BookingMyVenuesScreen extends StatefulWidget {
  final String? userId;

  const BookingMyVenuesScreen({super.key, this.userId});

  @override
  State<BookingMyVenuesScreen> createState() => _BookingMyVenuesScreenState();
}

class _BookingMyVenuesScreenState extends State<BookingMyVenuesScreen> {
  String _selectedFilter = 'all'; // all, approved, pending, rejected

  String get _currentUid =>
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (_currentUid.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('إدارة أماكني')),
        body: const Center(
          child: Text('يرجى تسجيل الدخول لعرض أماكنك المسجلة'),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('إدارة أماكني'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.add_business_outlined, color: bookingGold),
              tooltip: 'إضافة مكان جديد',
              onPressed: () => _openVenueEditor(context),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('booking_venues')
              .where('ownerId', isEqualTo: _currentUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: bookingGold),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'تعذر تحميل الأماكن: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final allDocs = snapshot.data?.docs ?? [];
            final venues = allDocs.map((d) => <String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                }).toList();

            // Compute summary metrics
            final totalCount = venues.length;
            final approvedCount = venues.where((v) =>
                v['verificationStatus'] == 'approved' ||
                (v['active'] == true && v['verificationStatus'] != 'rejected')).length;
            final pendingCount = venues.where((v) =>
                v['verificationStatus'] == 'pending' ||
                (v['active'] != true && v['verificationStatus'] != 'rejected')).length;
            final rejectedCount = venues.where((v) =>
                v['verificationStatus'] == 'rejected').length;

            // Filter venues based on selected tab
            final filteredVenues = venues.where((v) {
              final status = v['verificationStatus'] ?? (v['active'] == true ? 'approved' : 'pending');
              if (_selectedFilter == 'approved') {
                return status == 'approved' || v['active'] == true;
              }
              if (_selectedFilter == 'pending') {
                return status == 'pending' && v['active'] != true;
              }
              if (_selectedFilter == 'rejected') {
                return status == 'rejected';
              }
              return true;
            }).toList();

            return CustomScrollView(
              slivers: [
                // Top Metrics & Add Action Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Metric Cards Row
                        Row(
                          children: [
                            _buildMetricBox(
                              title: 'إجمالي الأماكن',
                              value: '$totalCount',
                              color: bookingGold,
                              surfaceColor: surfaceColor,
                              borderColor: cardBorder,
                            ),
                            const SizedBox(width: 8),
                            _buildMetricBox(
                              title: 'معتمدة ونشطة',
                              value: '$approvedCount',
                              color: const Color(0xFF10B981),
                              surfaceColor: surfaceColor,
                              borderColor: cardBorder,
                            ),
                            const SizedBox(width: 8),
                            _buildMetricBox(
                              title: 'قيد المراجعة',
                              value: '$pendingCount',
                              color: const Color(0xFFF59E0B),
                              surfaceColor: surfaceColor,
                              borderColor: cardBorder,
                            ),
                            if (rejectedCount > 0) ...[
                              const SizedBox(width: 8),
                              _buildMetricBox(
                                title: 'مرفوضة',
                                value: '$rejectedCount',
                                color: const Color(0xFFEF4444),
                                surfaceColor: surfaceColor,
                                borderColor: cardBorder,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Add Venue Call to Action Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _openVenueEditor(context),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text(
                              'إضافة مكان جديد (شاليه، مزرعة، قاعة)',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: bookingGold,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('الكل ($totalCount)', 'all'),
                              const SizedBox(width: 8),
                              _buildFilterChip('معتمدة ($approvedCount)', 'approved'),
                              const SizedBox(width: 8),
                              _buildFilterChip('قيد المراجعة ($pendingCount)', 'pending'),
                              if (rejectedCount > 0) ...[
                                const SizedBox(width: 8),
                                _buildFilterChip('مرفوضة ($rejectedCount)', 'rejected'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Venues List or Empty State
                if (filteredVenues.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.holiday_village_outlined,
                              size: 72,
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilter == 'all'
                                  ? 'لم تقم بإضافة أي أماكن بعد'
                                  : 'لا توجد أماكن في هذا التصنيف',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'اعرض مكانك لآلاف الزوار في محافظة الأنبار وابدأ باستقبال الحجوزات بكل سهولة وموثوقية.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _openVenueEditor(context),
                              icon: const Icon(Icons.add),
                              label: const Text('أضف مكانك الآن'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: bookingGold,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final venue = filteredVenues[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: _buildVenueManageCard(
                            context: context,
                            venue: venue,
                            surfaceColor: surfaceColor,
                            borderColor: cardBorder,
                            isDark: isDark,
                          ),
                        );
                      },
                      childCount: filteredVenues.length,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricBox({
    required String title,
    required String value,
    required Color color,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 10,
                color: Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: bookingGold,
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        color: selected ? Colors.white : null,
        fontWeight: selected ? FontWeight.bold : null,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildVenueManageCard({
    required BuildContext context,
    required Map<String, dynamic> venue,
    required Color surfaceColor,
    required Color borderColor,
    required bool isDark,
  }) {
    final venueId = venue['id'] as String;
    final name = venue['name']?.toString() ?? 'بدون اسم';
    final location = venue['location']?.toString() ?? 'الأنبار';
    final category = venue['category']?.toString() ?? 'chalet';
    final categoryName = _getCategoryName(category);
    final status = venue['verificationStatus'] ?? (venue['active'] == true ? 'approved' : 'pending');
    final rejectionReason = venue['rejectionReason']?.toString() ?? venue['adminNotes']?.toString();
    final images = List<String>.from(venue['images'] ?? []);
    final firstImage = images.isNotEmpty ? images.first : null;
    final price = venue['price'] ?? 0;
    final deposit = venue['deposit'] ?? 0;

    return Card(
      elevation: 0,
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image & Badges
          Stack(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                child: firstImage != null
                    ? BookingMediaImage(
                        url: firstImage,
                        height: 140,
                        width: double.infinity,
                      )
                    : Center(
                        child: Icon(
                          Icons.holiday_village_outlined,
                          size: 48,
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                      ),
              ),
              // Category Chip
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    categoryName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Status Badge
              Positioned(
                top: 10,
                left: 10,
                child: _buildStatusBadge(status),
              ),
            ],
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} د.ع',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: bookingGold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (deposit > 0)
                      Text(
                        'عربون: ${deposit.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} د.ع',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                  ],
                ),

                // Rejection Reason Alert if rejected
                if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سبب الرفض: $rejectionReason',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 11,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Action Buttons Grid (Responsive & Compact without overflow)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // 1. Edit Venue
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingVenueEditor(
                              venueId: venueId,
                              data: venue,
                              ownerMode: true,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('تعديل', style: TextStyle(fontSize: 11.5, fontFamily: 'Cairo')),
                    ),

                    // 2. Manage Availability & Closures
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingOwnerTools(venueId: venueId),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.calendar_month_outlined, size: 14),
                      label: const Text('التوفر', style: TextStyle(fontSize: 11.5, fontFamily: 'Cairo')),
                    ),

                    // 3. Incoming Requests with pending badge
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('bookings')
                          .where('venueId', isEqualTo: venueId)
                          .where('status', isEqualTo: 'requested')
                          .snapshots(),
                      builder: (context, snap) {
                        final pending = snap.data?.docs.length ?? 0;
                        return OutlinedButton.icon(
                          onPressed: () => _viewVenueRequests(context, venueId, name),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(
                              color: pending > 0 ? const Color(0xFFDC2626) : const Color(0xFFC5A16B).withValues(alpha: 0.5),
                              width: pending > 0 ? 1.5 : 1.0,
                            ),
                          ),
                          icon: Icon(
                            Icons.receipt_long_outlined,
                            size: 14,
                            color: pending > 0 ? const Color(0xFFDC2626) : null,
                          ),
                          label: Text(
                            pending > 0 ? 'الطلبات ($pending)' : 'الطلبات',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'Cairo',
                              fontWeight: pending > 0 ? FontWeight.bold : FontWeight.normal,
                              color: pending > 0 ? const Color(0xFFDC2626) : null,
                            ),
                          ),
                        );
                      },
                    ),

                    // 4. Delete Venue Button
                    OutlinedButton.icon(
                      onPressed: () => _confirmDeleteVenue(context, venueId, name),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFFEF4444),
                        side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('حذف', style: TextStyle(fontSize: 11.5, fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;
    IconData icon;

    switch (status) {
      case 'approved':
        bg = const Color(0xFF10B981);
        fg = Colors.white;
        text = 'معتمد ونشط';
        icon = Icons.verified;
        break;
      case 'rejected':
        bg = const Color(0xFFEF4444);
        fg = Colors.white;
        text = 'مرفوض';
        icon = Icons.cancel;
        break;
      case 'pending':
      default:
        bg = const Color(0xFFF59E0B);
        fg = Colors.white;
        text = 'قيد المراجعة';
        icon = Icons.hourglass_top;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String cat) {
    switch (cat) {
      case 'chalet':
        return 'شاليه';
      case 'farm':
        return 'مزرعة';
      case 'hall':
        return 'قاعة';
      case 'other':
      default:
        return 'مكان ترفيهي';
    }
  }

  void _openVenueEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingVenueEditor(
          ownerMode: true,
          data: {'ownerId': _currentUid, 'active': false},
        ),
      ),
    );
  }

  void _viewVenueRequests(BuildContext context, String venueId, String venueName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'طلبات الحجز — $venueName',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('bookings')
                        .where('venueId', isEqualTo: venueId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: bookingGold));
                      }
                      final bookings = snapshot.data?.docs ?? [];
                      if (bookings.isEmpty) {
                        return const Center(
                          child: Text(
                            'لا توجد طلبات حجز لهذا المكان بعد',
                            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: bookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final b = bookings[idx].data();
                          final bId = bookings[idx].id;
                          return BookingRecordCard(
                            booking: b,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookingDetailsScreen(bookingId: bId),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteVenue(BuildContext context, String venueId, String venueName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text(
                'حذف المكان',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من حذف «$venueName»؟\n\n'
            '• إذا كان للمكان حجوزات سابقة سيتم أرشفته وإخفاؤه للحفاظ على السجلات المالية والتاريخية.\n'
            '• لا يمكن حذف أي مكان مرتبط بحجوزات نشطة أو قادمة حالياً.',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: bookingGold)),
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteBookingVenue');
      await callable.call({'venueId': venueId});
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المكان بنجاح')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        final msg = e.toString().contains('details')
            ? e.toString()
            : (e is FirebaseFunctionsException ? e.message : 'تعذر حذف المكان. تأكد من عدم وجود حجوزات نشطة');
        showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('تعذر الحذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              content: Text('$msg', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

}