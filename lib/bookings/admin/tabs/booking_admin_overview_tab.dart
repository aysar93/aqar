import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../booking_admin_theme.dart';
import '../../booking_widgets.dart' show bookingMoney;

class BookingAdminOverviewTab extends StatefulWidget {
  final Function(int tabIndex)? onNavigateToTab;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? bookingsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? venuesStream;

  const BookingAdminOverviewTab({
    super.key,
    this.onNavigateToTab,
    this.bookingsStream,
    this.venuesStream,
  });

  @override
  State<BookingAdminOverviewTab> createState() => _BookingAdminOverviewTabState();
}

class _BookingAdminOverviewTabState extends State<BookingAdminOverviewTab> with AutomaticKeepAliveClientMixin {
  String _selectedPeriod = 'all'; // all, today, week, month

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.bookingsStream ?? FirebaseFirestore.instance.collection('bookings').snapshots(),
      builder: (context, bookingsSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.venuesStream ?? FirebaseFirestore.instance.collection('booking_venues').snapshots(),
          builder: (context, venuesSnap) {
            if ((bookingsSnap.connectionState == ConnectionState.waiting && !bookingsSnap.hasData) ||
                (venuesSnap.connectionState == ConnectionState.waiting && !venuesSnap.hasData)) {
              return const Center(child: CircularProgressIndicator(color: BookingAdminTheme.gold));
            }

            final allBookings = bookingsSnap.data?.docs.map((d) {
              final map = d.data();
              map['_id'] = d.id;
              return map;
            }).toList() ?? [];

            final rawVenues = venuesSnap.data?.docs.map((d) {
              final map = d.data();
              map['_id'] = d.id;
              return map;
            }).toList() ?? [];

            final allVenues = BookingAdminDataSanitizer.prepareCleanVenuesList(rawVenues);

            final filteredBookings = _filterByPeriod(allBookings, _selectedPeriod);

            // حساب الإحصائيات
            final totalBookings = filteredBookings.length;
            final pendingReview = filteredBookings.where((b) {
              final s = (b['status'] ?? '').toString();
              return s == 'requested' || s == 'payment_review' || s == 'held';
            }).length;

            final confirmed = filteredBookings.where((b) {
              final s = (b['status'] ?? '').toString();
              return s == 'confirmed' || s == 'arrived' || s == 'completed';
            }).length;

            final cancelled = filteredBookings.where((b) {
              final s = (b['status'] ?? '').toString();
              return s == 'cancelled' || s == 'rejected' || s == 'expired' || s == 'payment_rejected';
            }).length;

            num totalDeposit = 0;
            num totalRemaining = 0;
            for (final b in filteredBookings) {
              final s = (b['status'] ?? '').toString();
              if (s == 'confirmed' || s == 'completed' || s == 'arrived' || s == 'payment_review') {
                totalDeposit += (b['deposit'] as num?) ?? (b['paid'] as num?) ?? 0;
                totalRemaining += (b['remaining'] as num?) ?? 0;
              }
            }

            final publishedVenues = allVenues.where((v) => v['active'] == true).length;
            final pendingVenues = allVenues.where((v) {
              final vs = (v['verificationStatus'] ?? '').toString();
              return vs == 'pending' || (v['active'] != true && vs != 'verified');
            }).length;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                // شريط تصفية الفترة والتحكم السريع
                _buildPeriodFilter(),
                const SizedBox(height: 16),

                // شريط التنبيهات الإدارية العاجلة
                if (pendingReview > 0 || pendingVenues > 0) ...[
                  _buildUrgentAlertBanner(pendingReview: pendingReview, pendingVenues: pendingVenues),
                  const SizedBox(height: 16),
                ],

                // بطاقات الإحصائيات الرئيسية بتخطيط متجاوب خالٍ تماماً من IntrinsicHeight
                _buildResponsiveMetricGrid(
                  totalBookings: totalBookings,
                  pendingReview: pendingReview,
                  confirmed: confirmed,
                  cancelled: cancelled,
                  totalDeposit: totalDeposit,
                  totalRemaining: totalRemaining,
                  publishedVenues: publishedVenues,
                  pendingVenues: pendingVenues,
                ),
                const SizedBox(height: 20),

                // توزيع الحالات
                _buildStatusDistributionCard(
                  total: totalBookings,
                  pending: pendingReview,
                  confirmed: confirmed,
                  cancelled: cancelled,
                ),
                const SizedBox(height: 20),

                // تصنيف الأماكن
                _buildVenueCategoryCard(allVenues),
                const SizedBox(height: 20),

                // أحدث الحجوزات المسجلة
                _buildRecentBookingsPipeline(allBookings),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildUrgentAlertBanner({required int pendingReview, required int pendingVenues}) {
    final dark = BookingAdminTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1FEAB308),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66EAB308)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: Color(0xFFFDE047), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مهام إدارية عاجلة تتطلب اتخاذ قرار:',
                  style: TextStyle(
                    color: Color(0xFFFDE047),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pendingReview > 0)
                ActionChip(
                  backgroundColor: dark ? BookingAdminTheme.surfaceCard : Colors.white,
                  avatar: const Icon(Icons.pending_actions, size: 16, color: Color(0xFFFDE047)),
                  label: Text(
                    '$pendingReview طلب حجز بانتظار المراجعة والاعتماد',
                    style: TextStyle(
                      color: dark ? BookingAdminTheme.textPrimary : const Color(0xFF0F172A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  onPressed: () => widget.onNavigateToTab?.call(1),
                ),
              if (pendingVenues > 0)
                ActionChip(
                  backgroundColor: dark ? BookingAdminTheme.surfaceCard : Colors.white,
                  avatar: const Icon(Icons.verified_user_outlined, size: 16, color: BookingAdminTheme.gold),
                  label: Text(
                    '$pendingVenues مكان بانتظار التدقيق والتوثيق',
                    style: TextStyle(
                      color: dark ? BookingAdminTheme.textPrimary : const Color(0xFF0F172A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  onPressed: () => widget.onNavigateToTab?.call(2),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveMetricGrid({
    required int totalBookings,
    required int pendingReview,
    required int confirmed,
    required int cancelled,
    required num totalDeposit,
    required num totalRemaining,
    required int publishedVenues,
    required int pendingVenues,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final count = isWide ? 4 : 2;
        final ratio = isWide ? 1.50 : 1.28;

        return GridView.count(
          crossAxisCount: count,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: ratio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            BookingAdminStatCard(
              title: 'إجمالي الحجوزات',
              value: '$totalBookings',
              subtitle: 'جميع الطلبات المسجلة',
              icon: Icons.calendar_month_outlined,
              badgeText: 'الكل',
              onTap: () => widget.onNavigateToTab?.call(1),
            ),
            BookingAdminStatCard(
              title: 'بانتظار المراجعة',
              value: '$pendingReview',
              subtitle: 'تتطلب مراجعة واعتماد',
              icon: Icons.pending_actions_outlined,
              badgeText: pendingReview > 0 ? 'عاجل' : null,
              badgeColor: const Color(0xFFEAB308),
              onTap: () => widget.onNavigateToTab?.call(1),
            ),
            BookingAdminStatCard(
              title: 'حجوزات مؤكدة',
              value: '$confirmed',
              subtitle: 'معتمدة ومسددة العربون',
              icon: Icons.check_circle_outline_rounded,
              badgeText: 'نشطة',
              badgeColor: const Color(0xFF22C55E),
              onTap: () => widget.onNavigateToTab?.call(1),
            ),
            BookingAdminStatCard(
              title: 'ملغاة أو مرفوضة',
              value: '$cancelled',
              subtitle: 'ألغيت أو تم استردادها',
              icon: Icons.cancel_outlined,
              onTap: () => widget.onNavigateToTab?.call(1),
            ),
            BookingAdminStatCard(
              title: 'إجمالي العربون',
              value: bookingMoney(totalDeposit),
              subtitle: 'المحصل في المحفظة',
              icon: Icons.account_balance_wallet_outlined,
              badgeText: 'محصل',
              badgeColor: BookingAdminTheme.gold,
              onTap: () => widget.onNavigateToTab?.call(4),
            ),
            BookingAdminStatCard(
              title: 'المبالغ المتبقية',
              value: bookingMoney(totalRemaining),
              subtitle: 'تُدفع عند تسجيل الوصول',
              icon: Icons.payments_outlined,
              onTap: () => widget.onNavigateToTab?.call(4),
            ),
            BookingAdminStatCard(
              title: 'الأماكن المنشورة',
              value: '$publishedVenues',
              subtitle: 'متاحة للعامة بالبحث',
              icon: Icons.villa_outlined,
              badgeText: 'فعّال',
              badgeColor: const Color(0xFF22C55E),
              onTap: () => widget.onNavigateToTab?.call(2),
            ),
            BookingAdminStatCard(
              title: 'أماكن بانتظار الموافقة',
              value: '$pendingVenues',
              subtitle: 'بانتظار تدقيق الوثائق',
              icon: Icons.verified_user_outlined,
              badgeText: pendingVenues > 0 ? 'تدقيق' : null,
              badgeColor: const Color(0xFF38BDF8),
              onTap: () => widget.onNavigateToTab?.call(2),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPeriodFilter() {
    final periods = {
      'all': 'كل الفترات',
      'month': 'هذا الشهر',
      'week': 'هذا الأسبوع',
      'today': 'اليوم',
    };

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded, size: 18, color: BookingAdminTheme.icon(context)),
            const SizedBox(width: 8),
            Text(
              'الفترة:',
              style: TextStyle(
                color: BookingAdminTheme.textSub(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(width: 10),
            for (final entry in periods.entries) ...[
              ChoiceChip(
                label: Text(entry.value),
                selected: _selectedPeriod == entry.key,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedPeriod = entry.key);
                },
                selectedColor: BookingAdminTheme.goldSubtle,
                backgroundColor: BookingAdminTheme.surfaceSecondary(context),
                labelStyle: TextStyle(
                  color: _selectedPeriod == entry.key
                      ? BookingAdminTheme.gold
                      : BookingAdminTheme.textMute(context),
                  fontSize: 12,
                  fontWeight: _selectedPeriod == entry.key ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Cairo',
                ),
                side: BorderSide(
                  color: _selectedPeriod == entry.key
                      ? BookingAdminTheme.gold
                      : BookingAdminTheme.border(context),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDistributionCard({
    required int total,
    required int pending,
    required int confirmed,
    required int cancelled,
  }) {
    final pendingRatio = total == 0 ? 0.0 : pending / total;
    final confirmedRatio = total == 0 ? 0.0 : confirmed / total;
    final cancelledRatio = total == 0 ? 0.0 : cancelled / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'توزيع حالات الحجز',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BookingAdminTheme.text(context),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$total حجز إجمالي',
                style: TextStyle(
                  color: BookingAdminTheme.textMute(context),
                  fontSize: 12,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // شريط النسبة المتناسق
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (confirmedRatio > 0)
                    Expanded(
                      flex: (confirmedRatio * 100).round(),
                      child: Container(color: BookingAdminTheme.badgeConfirmedText),
                    ),
                  if (pendingRatio > 0)
                    Expanded(
                      flex: (pendingRatio * 100).round(),
                      child: Container(color: BookingAdminTheme.badgePendingText),
                    ),
                  if (cancelledRatio > 0)
                    Expanded(
                      flex: (cancelledRatio * 100).round(),
                      child: Container(color: BookingAdminTheme.badgeCancelledText),
                    ),
                  if (total == 0)
                    Expanded(
                      child: Container(color: BookingAdminTheme.surfaceSecondary(context)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12,
            runSpacing: 8,
            children: [
              _indicatorItem('مؤكدة', '$confirmed', BookingAdminTheme.badgeConfirmedText),
              _indicatorItem('بانتظار الإجراء', '$pending', BookingAdminTheme.badgePendingText),
              _indicatorItem('ملغاة / مرفوضة', '$cancelled', BookingAdminTheme.badgeCancelledText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _indicatorItem(String label, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            color: BookingAdminTheme.textMute(context),
            fontSize: 12,
            fontFamily: 'Cairo',
          ),
        ),
        Text(
          count,
          style: TextStyle(
            color: BookingAdminTheme.text(context),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildVenueCategoryCard(List<Map<String, dynamic>> venues) {
    int chalets = 0, farms = 0, halls = 0, others = 0;
    for (final v in venues) {
      switch ((v['category'] ?? '').toString()) {
        case 'chalet':
          chalets++;
          break;
        case 'farm':
          farms++;
          break;
        case 'hall':
          halls++;
          break;
        default:
          others++;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تصنيف الأماكن المسجلة في النظام',
            style: TextStyle(
              color: BookingAdminTheme.text(context),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _categoryMetric('الشاليهات', '$chalets', Icons.pool_outlined),
              _categoryMetric('المزارع', '$farms', Icons.forest_outlined),
              _categoryMetric('القاعات', '$halls', Icons.celebration_outlined),
              _categoryMetric('أخرى', '$others', Icons.category_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryMetric(String title, String count, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: BookingAdminTheme.surfaceSecondary(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BookingAdminTheme.border(context)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: BookingAdminTheme.icon(context)),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: BookingAdminTheme.textMute(context),
                fontSize: 11,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(
                color: BookingAdminTheme.text(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBookingsPipeline(List<Map<String, dynamic>> allBookings) {
    final recent = allBookings.take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'أحدث عمليات الحجز في النظام',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BookingAdminTheme.text(context),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => widget.onNavigateToTab?.call(1),
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(
                    color: BookingAdminTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < recent.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: BookingAdminTheme.surfaceSecondary(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: BookingAdminTheme.border(context)),
                    ),
                    child: Icon(Icons.bookmark_outline_rounded, size: 18, color: BookingAdminTheme.icon(context)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          BookingAdminDataSanitizer.cleanVenueName(
                            (recent[i]['venueSnapshot']?['name'] ?? recent[i]['venueName'])?.toString(),
                            index: i,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: BookingAdminTheme.text(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          '${BookingAdminDataSanitizer.cleanCustomerName((recent[i]['customerSnapshot']?['name'] ?? recent[i]['customerName'])?.toString(), index: i)} · ${bookingMoney(recent[i]['total'])}',
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
                  const SizedBox(width: 8),
                  BookingAdminStatusBadge(status: (recent[i]['status'] ?? 'unknown').toString()),
                ],
              ),
            ),
            if (i < recent.length - 1) Divider(color: BookingAdminTheme.border(context), height: 1),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterByPeriod(List<Map<String, dynamic>> list, String period) {
    if (period == 'all') return list;
    final now = DateTime.now();

    return list.where((b) {
      final raw = b['createdAt'] ?? b['start'];
      DateTime? dt;
      if (raw is Timestamp) dt = raw.toDate();
      if (raw is num) dt = DateTime.fromMillisecondsSinceEpoch(raw.toInt());
      if (raw is String) dt = DateTime.tryParse(raw);

      if (dt == null) return true;

      if (period == 'today') {
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      } else if (period == 'week') {
        return now.difference(dt).inDays <= 7;
      } else if (period == 'month') {
        return dt.year == now.year && dt.month == now.month;
      }
      return true;
    }).toList();
  }
}
