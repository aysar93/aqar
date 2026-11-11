import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../booking_admin_theme.dart';
import '../../booking_widgets.dart' show bookingMoney;

class BookingAdminReportsTab extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? bookingsStream;

  const BookingAdminReportsTab({super.key, this.bookingsStream});

  @override
  State<BookingAdminReportsTab> createState() => _BookingAdminReportsTabState();
}

class _BookingAdminReportsTabState extends State<BookingAdminReportsTab> with AutomaticKeepAliveClientMixin {
  String _period = 'all'; // all, month, week
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
      stream: widget.bookingsStream ?? FirebaseFirestore.instance.collection('bookings').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'حدث خطأ في تحميل بيانات التقارير: ${snap.error}',
                style: TextStyle(color: BookingAdminTheme.textMute(context), fontFamily: 'Cairo'),
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
            final venueName = BookingAdminDataSanitizer.cleanVenueName(rawVenueName);
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          child: const Icon(Icons.bar_chart_rounded, size: 18, color: BookingAdminTheme.gold),
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
                    Divider(color: BookingAdminTheme.border(context), height: 1),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // كروت الملخص المالي للتقارير بتخطيط متجاوب خالٍ من IntrinsicHeight
              _buildResponsiveKPIs(totalGMV: totalGMV, totalDeposits: totalDeposits),
              const SizedBox(height: 12),

              // تقرير الأماكن الأكثر طلباً وحجزاً
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BookingAdminTheme.cardDecoration(context: context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.leaderboard_outlined, size: 20, color: BookingAdminTheme.gold),
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
                            style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < sortedVenues.take(8).length; i++) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: i < 3
                                          ? BookingAdminTheme.goldSubtle
                                          : BookingAdminTheme.surfaceSecondary(context),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          color: i < 3 ? BookingAdminTheme.gold : BookingAdminTheme.textMute(context),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sortedVenues[i].key,
                                          softWrap: true,
                                          maxLines: 2,
                                          style: TextStyle(
                                            color: BookingAdminTheme.text(context),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: sortedVenues.first.value == 0
                                                ? 0
                                                : sortedVenues[i].value / sortedVenues.first.value,
                                            backgroundColor: BookingAdminTheme.surfaceSecondary(context),
                                            color: i < 3 ? BookingAdminTheme.gold : const Color(0xFF38BDF8),
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
                                      color: BookingAdminTheme.textSub(context),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (i < sortedVenues.take(8).length - 1)
                              Divider(color: BookingAdminTheme.border(context), height: 1),
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
                decoration: BookingAdminTheme.cardDecoration(context: context),
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
                            style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
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
                                  style: TextStyle(color: BookingAdminTheme.textSub(context), fontSize: 13, fontFamily: 'Cairo'),
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
          );
        } catch (e, stack) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                'خطأ في معالجة التقرير: $e\n$stack',
                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildResponsiveKPIs({required num totalGMV, required num totalDeposits}) {
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

  void _exportToCsv(List<Map<String, dynamic>> list) {
    final buffer = StringBuffer();
    buffer.writeln('BookingId,VenueName,CustomerName,Phone,OwnerName,Status,Total,Deposit,Remaining,PaymentMethod');

    for (final b in list) {
      final vs = b['venueSnapshot'];
      final cs = b['customerSnapshot'];
      final id = _escapeCsv(b['id'] ?? b['_id'] ?? '');
      final venue = _escapeCsv((vs is Map ? vs['name'] : b['venueName']) ?? '');
      final customer = _escapeCsv((cs is Map ? cs['name'] : b['customerName']) ?? '');
      final phone = _escapeCsv((cs is Map ? cs['phone'] : b['customerPhone']) ?? '');
      final owner = _escapeCsv(b['ownerName'] ?? '');
      final status = _escapeCsv(b['status'] ?? '');
      final total = b['total'] ?? 0;
      final deposit = b['deposit'] ?? b['paid'] ?? 0;
      final remaining = b['remaining'] ?? 0;
      final method = _escapeCsv(b['paymentMethod'] ?? '');

      buffer.writeln('$id,$venue,$customer,$phone,$owner,$status,$total,$deposit,$remaining,$method');
    }

    final csvString = buffer.toString();
    Clipboard.setData(ClipboardData(text: csvString));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BookingAdminTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تم نسخ تقرير CSV إلى الحافظة', style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تم نسخ بيانات التقرير (${list.length} سجل) بتنسيق CSV إلى الحافظة بنجاح، ويمكنك لصقها مباشرة في Excel أو Google Sheets.',
              style: TextStyle(color: BookingAdminTheme.textSub(context), fontSize: 13, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: BookingAdminTheme.surfaceSecondary(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  csvString,
                  style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BookingAdminTheme.gold),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  String _escapeCsv(dynamic val) {
    final str = val?.toString() ?? '';
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  List<Map<String, dynamic>> _filterList(List<Map<String, dynamic>> list, String p) {
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
