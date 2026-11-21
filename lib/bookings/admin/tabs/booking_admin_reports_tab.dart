import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../booking_admin_theme.dart';
import '../booking_csv_export_service.dart';
import '../../booking_widgets.dart' show bookingMoney;

class BookingAdminReportsTab extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? bookingsStream;

  const BookingAdminReportsTab({super.key, this.bookingsStream});

  @override
  State<BookingAdminReportsTab> createState() => _BookingAdminReportsTabState();
}

class _BookingAdminReportsTabState extends State<BookingAdminReportsTab>
    with AutomaticKeepAliveClientMixin {
  String _period = 'all'; // all, month, week
  String _reportType = 'bookings'; // bookings, ledger
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.bookingsStream ??
          FirebaseFirestore.instance.collection('bookings').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'حدث خطأ في تحميل بيانات التقارير: ${snap.error}',
                style: TextStyle(
                    color: BookingAdminTheme.textMute(context),
                    fontFamily: 'Cairo'),
              ),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: BookingAdminTheme.gold),
          );
        }

        try {
          final docs = snap.data?.docs.map((d) => d.data()).toList() ?? [];
          final filtered = _filterList(docs, _period);

          // حسابات التقارير
          num totalGMV = 0;
          num totalDeposits = 0;
          final venueCounts = <String, int>{};
          final categoryCounts = <String, int>{};

          for (final b in filtered) {
            final total = (b['total'] as num?) ?? 0;
            final deposit = (b['deposit'] as num?) ?? (b['paid'] as num?) ?? 0;
            final s = (b['status'] ?? '').toString();

            if (s == 'confirmed' || s == 'completed' || s == 'arrived') {
              totalGMV += total;
              totalDeposits += deposit;
            }

            final vs = b['venueSnapshot'];
            final rawVenueName = (vs is Map && vs['name'] != null)
                ? vs['name'].toString()
                : (b['venueName'] ?? 'شاليه الرافدين الملكي').toString();
            final venueName =
                BookingAdminDataSanitizer.cleanVenueName(rawVenueName);
            venueCounts[venueName] = (venueCounts[venueName] ?? 0) + 1;

            final category = (vs is Map && vs['category'] != null)
                ? vs['category'].toString()
                : (b['category'] ?? 'chalet').toString();
            categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
          }

          final sortedVenues = venueCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return ListView(
            controller: _scrollController,
            primary: false,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              // شريط العنوان وتصفية الفترة وتصدير التقرير (SaaS Unified Compact Header)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BookingAdminTheme.cardDecoration(context: context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: BookingAdminTheme.goldSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.bar_chart_rounded,
                              size: 18, color: BookingAdminTheme.gold),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'تقارير وإحصائيات الحجوزات والتحصيل',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: BookingAdminTheme.text(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              Text(
                                'إجمالي البيانات المشمولة بالتحليل: ${filtered.length} حجز',
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
                        BookingAdminButton(
                          isPrimary: true,
                          icon: Icons.file_download_outlined,
                          label: 'تصدير CSV',
                          onPressed: () => _exportToCsv(filtered),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(
                        color: BookingAdminTheme.border(context), height: 1),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      child: Row(
                        children: [
                          Text(
                            'نطاق التحليل:',
                            style: TextStyle(
                              color: BookingAdminTheme.textMute(context),
                              fontSize: 11,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _chip('كل الفترات', 'all'),
                          _chip('هذا الشهر', 'month'),
                          _chip('هذا الأسبوع', 'week'),
                          const SizedBox(width: 10),
                          Container(
                              width: 1,
                              height: 16,
                              color: BookingAdminTheme.border(context)),
                          const SizedBox(width: 10),
                          Text(
                            'المصدر:',
                            style: TextStyle(
                              color: BookingAdminTheme.textMute(context),
                              fontSize: 11,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _sourceChip('الحجوزات التشغيلية', 'bookings'),
                          _sourceChip('سجل القيود المالية (Ledger)', 'ledger'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_reportType == 'ledger')
                _buildLedgerSection()
              else ...[
                // كروت الملخص المالي للتقارير بتخطيط متجاوب خالٍ من IntrinsicHeight
                _buildResponsiveKPIs(
                    totalGMV: totalGMV, totalDeposits: totalDeposits),
                const SizedBox(height: 12),

                // تقرير الأماكن الأكثر طلباً وحجزاً
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration:
                      BookingAdminTheme.cardDecoration(context: context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.leaderboard_outlined,
                              size: 20, color: BookingAdminTheme.gold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'الأماكن الأكثر طلباً وحجزاً في الأنبار',
                              style: TextStyle(
                                color: BookingAdminTheme.text(context),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (sortedVenues.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'لا توجد بيانات حجوزات لتصنيف الأماكن.',
                              style: TextStyle(
                                  color: BookingAdminTheme.textMute(context),
                                  fontSize: 12,
                                  fontFamily: 'Cairo'),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            for (int i = 0;
                                i < sortedVenues.take(8).length;
                                i++) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: i < 3
                                            ? BookingAdminTheme.goldSubtle
                                            : BookingAdminTheme
                                                .surfaceSecondary(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            color: i < 3
                                                ? BookingAdminTheme.gold
                                                : BookingAdminTheme.textMute(
                                                    context),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sortedVenues[i].key,
                                            softWrap: true,
                                            maxLines: 2,
                                            style: TextStyle(
                                              color: BookingAdminTheme.text(
                                                  context),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              fontFamily: 'Cairo',
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: sortedVenues.first.value ==
                                                      0
                                                  ? 0
                                                  : sortedVenues[i].value /
                                                      sortedVenues.first.value,
                                              backgroundColor: BookingAdminTheme
                                                  .surfaceSecondary(context),
                                              color: i < 3
                                                  ? BookingAdminTheme.gold
                                                  : const Color(0xFF38BDF8),
                                              minHeight: 4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${sortedVenues[i].value} حجز',
                                      style: TextStyle(
                                        color:
                                            BookingAdminTheme.textSub(context),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (i < sortedVenues.take(8).length - 1)
                                Divider(
                                    color: BookingAdminTheme.border(context),
                                    height: 1),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // توزيع الحجوزات حسب تصنيف العقار
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration:
                      BookingAdminTheme.cardDecoration(context: context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نسب الحجوزات حسب نوع المنشأة',
                        style: TextStyle(
                          color: BookingAdminTheme.text(context),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (categoryCounts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'لا توجد حجوزات في هذه الفترة.',
                              style: TextStyle(
                                  color: BookingAdminTheme.textMute(context),
                                  fontSize: 12,
                                  fontFamily: 'Cairo'),
                            ),
                          ),
                        )
                      else
                        for (final entry in categoryCounts.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _categoryName(entry.key),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color:
                                            BookingAdminTheme.textSub(context),
                                        fontSize: 13,
                                        fontFamily: 'Cairo'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${entry.value} حجز (${((entry.value / (filtered.isEmpty ? 1 : filtered.length)) * 100).toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    color: BookingAdminTheme.text(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ],
          );
        } catch (e, stack) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                'خطأ في معالجة التقرير: $e\n$stack',
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildResponsiveKPIs(
      {required num totalGMV, required num totalDeposits}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BookingAdminStatCard(
                title: 'إجمالي القيمة التعاقدية (GMV)',
                value: bookingMoney(totalGMV),
                subtitle: 'للحجوزات المؤكدة والمنفذة',
                icon: Icons.trending_up_rounded,
                badgeText: 'تعاقدي',
                badgeColor: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BookingAdminStatCard(
                title: 'إجمالي العربون المحصل',
                value: bookingMoney(totalDeposits),
                subtitle: 'في منصة عقارات الأنبار',
                icon: Icons.savings_outlined,
                badgeText: 'عربون',
                badgeColor: BookingAdminTheme.gold,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, String value) {
    final selected = _period == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (s) {
          if (s) setState(() => _period = value);
        },
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        selectedColor: BookingAdminTheme.goldSubtle,
        backgroundColor: BookingAdminTheme.surfaceSecondary(context),
        labelStyle: TextStyle(
          color: selected
              ? BookingAdminTheme.gold
              : BookingAdminTheme.textMute(context),
          fontSize: 11,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Cairo',
        ),
        side: BorderSide(
          color: selected
              ? BookingAdminTheme.gold
              : BookingAdminTheme.border(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _sourceChip(String label, String value) {
    final selected = _reportType == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (s) {
          if (s) setState(() => _reportType = value);
        },
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        selectedColor: BookingAdminTheme.goldSubtle,
        backgroundColor: BookingAdminTheme.surfaceSecondary(context),
        labelStyle: TextStyle(
          color: selected
              ? BookingAdminTheme.gold
              : BookingAdminTheme.textMute(context),
          fontSize: 11,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Cairo',
        ),
        side: BorderSide(
          color: selected
              ? BookingAdminTheme.gold
              : BookingAdminTheme.border(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildLedgerSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('booking_ledger')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'تعذر تحميل سجل القيود المالية: ${snap.error}',
                style: TextStyle(
                    color: BookingAdminTheme.textMute(context),
                    fontFamily: 'Cairo'),
              ),
            ),
          );
        }

        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                      color: BookingAdminTheme.gold)));
        }

        final entries = snap.data?.docs.map((d) {
              final m = d.data();
              m['_id'] = d.id;
              return m;
            }).toList() ??
            [];

        num totalDepositsCollected = 0;
        num totalCommissions = 0;
        num totalRefundsPaid = 0;
        num totalOwnerPaid = 0;

        final ownerMap = <String, Map<String, dynamic>>{};

        for (final entry in entries) {
          final dep = (entry['depositCollected'] as num?) ?? 0;
          final com = (entry['platformCommission'] as num?) ?? 0;
          final ref = (entry['refundPaid'] as num?) ?? 0;
          final own = (entry['ownerPaid'] as num?) ?? 0;

          totalDepositsCollected += dep;
          totalCommissions += com;
          totalRefundsPaid += ref;
          totalOwnerPaid += own;

          final ownerId = (entry['ownerId'] ?? 'unknown').toString();
          final rec = ownerMap.putIfAbsent(
              ownerId,
              () => {
                    'ownerId': ownerId,
                    'deposits': 0,
                    'commission': 0,
                    'settled': 0,
                    'count': 0,
                  });
          rec['deposits'] = (rec['deposits'] as num) + dep;
          rec['commission'] = (rec['commission'] as num) + com;
          rec['settled'] = (rec['settled'] as num) + own;
          rec['count'] = (rec['count'] as int) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقات القيود المالية غير القابلة للتعديل
            Row(
              children: [
                Expanded(
                  child: BookingAdminStatCard(
                    title: 'العربون المقبوض فعلياً',
                    value: bookingMoney(totalDepositsCollected),
                    subtitle: 'قيود مؤكدة في الـ Ledger',
                    icon: Icons.account_balance_wallet,
                    badgeText: 'مقيد',
                    badgeColor: BookingAdminTheme.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BookingAdminStatCard(
                    title: 'عمولة المنصة المستحقة',
                    value: bookingMoney(totalCommissions),
                    subtitle: 'حسب نسب العقود',
                    icon: Icons.pie_chart_outline,
                    badgeText: 'إيراد',
                    badgeColor: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: BookingAdminStatCard(
                    title: 'تسويات الملاك المدفوعة',
                    value: bookingMoney(totalOwnerPaid),
                    subtitle: 'حوالات معتمدة',
                    icon: Icons.payments_outlined,
                    badgeText: 'مسوى',
                    badgeColor: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BookingAdminStatCard(
                    title: 'الاستردادات المرجعة',
                    value: bookingMoney(totalRefundsPaid),
                    subtitle: 'للعملاء الملغين',
                    icon: Icons.assignment_return_outlined,
                    badgeText: 'مسترد',
                    badgeColor: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // كشف حساب الملاك المجمع
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BookingAdminTheme.cardDecoration(context: context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'كشوفات حسابات الملاك والوسطاء (Statement of Accounts)',
                        style: TextStyle(
                          color: BookingAdminTheme.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        '${ownerMap.length} مالك',
                        style: const TextStyle(
                            color: BookingAdminTheme.gold,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (ownerMap.isEmpty)
                    Text('لا توجد قيود تسوية مسجلة بعد في دفتر الأستاذ.',
                        style: TextStyle(
                            color: BookingAdminTheme.textMute(context),
                            fontSize: 12,
                            fontFamily: 'Cairo'))
                  else
                    for (final o in ownerMap.values) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BookingAdminTheme.surfaceSecondary(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: BookingAdminTheme.border(context)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_pin_outlined,
                                size: 20, color: BookingAdminTheme.gold),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'المالك: ${o['ownerId']}',
                                    style: TextStyle(
                                        color: BookingAdminTheme.text(context),
                                        fontSize: 11,
                                        fontFamily: 'monospace'),
                                  ),
                                  Text(
                                    'إجمالي العمليات: ${o['count']} قيد • العمولة: ${bookingMoney(o['commission'])}',
                                    style: TextStyle(
                                        color:
                                            BookingAdminTheme.textMute(context),
                                        fontSize: 10,
                                        fontFamily: 'Cairo'),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              bookingMoney(o['settled']),
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // قائمة قيود دفتر الأستاذ (Immutable Ledger Entries)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BookingAdminTheme.cardDecoration(context: context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'قيود دفتر الأستاذ المالي غير القابلة للتعديل (Ledger Journal)',
                    style: TextStyle(
                      color: BookingAdminTheme.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    Text('لا توجد قيود مالية مسجلة بعد.',
                        style: TextStyle(
                            color: BookingAdminTheme.textMute(context),
                            fontSize: 12,
                            fontFamily: 'Cairo'))
                  else
                    for (final entry in entries) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BookingAdminTheme.goldSubtle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry['action'] ?? 'قيد',
                                style: const TextStyle(
                                    color: BookingAdminTheme.gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'حجز: ${entry['bookingId']} • مرجع: ${entry['reference'] ?? 'تلقائي'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: BookingAdminTheme.textSub(context),
                                    fontSize: 11,
                                    fontFamily: 'monospace'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry['action'] == 'confirmPayment'
                                  ? '+${entry['depositCollected']} د.ع'
                                  : entry['action'] == 'settleRefund'
                                      ? '-${entry['refundPaid']} د.ع'
                                      : '${entry['ownerPaid']} د.ع',
                              style: TextStyle(
                                color: entry['action'] == 'confirmPayment'
                                    ? Colors.greenAccent
                                    : entry['action'] == 'settleRefund'
                                        ? Colors.orangeAccent
                                        : Colors.blueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                          color: BookingAdminTheme.border(context), height: 8),
                    ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _exportToCsv(List<Map<String, dynamic>> list) {
    final csvString = BookingCsvExportService.generateBookingsCsv(list);
    Clipboard.setData(ClipboardData(text: csvString));
    BookingCsvExportService.exportAndShareCsv(
      context,
      fileName:
          'aqar_bookings_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      csvContent: csvString,
      title: 'تصدير تقرير الحجوزات والتحصيل',
    );
  }

  List<Map<String, dynamic>> _filterList(
      List<Map<String, dynamic>> list, String p) {
    if (p == 'all') return list;
    final now = DateTime.now();
    return list.where((b) {
      final raw = b['createdAt'] ?? b['start'];
      DateTime? dt;
      if (raw is Timestamp) dt = raw.toDate();
      if (raw is num) dt = DateTime.fromMillisecondsSinceEpoch(raw.toInt());
      if (raw is String) dt = DateTime.tryParse(raw);
      if (dt == null) return true;

      if (p == 'month') return dt.year == now.year && dt.month == now.month;
      if (p == 'week') return now.difference(dt).inDays <= 7;
      return true;
    }).toList();
  }

  String _categoryName(String c) {
    switch (c) {
      case 'chalet':
        return 'شاليهات';
      case 'farm':
        return 'مزارع';
      case 'hall':
        return 'قاعات';
      default:
        return 'أخرى';
    }
  }
}
