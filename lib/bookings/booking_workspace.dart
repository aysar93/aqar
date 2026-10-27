import 'booking_owner_metrics.dart';
import 'package:flutter/material.dart';
import 'booking_widgets.dart';
import 'booking_experience.dart';

/// Unknown or malformed historical amounts must not become a zero total.
Map<String, int?> bookingLedgerTotals(List<Map<String, dynamic>> entries) {
  const maxSafe = 9007199254740991;
  return {
    for (final key in [
      'depositCollected',
      'refundPaid',
      'ownerPaid',
      'platformCommission'
    ])
      key: (() {
        var sum = 0;
        for (final entry in entries) {
          final v = entry[key];
          if (v is! num ||
              !v.isFinite ||
              v < 0 ||
              v > maxSafe ||
              v != v.truncateToDouble()) return null;
          sum += v.toInt();
          if (sum > maxSafe) return null;
        }
        return sum;
      })()
  };
}

class BookingLedgerContent extends StatelessWidget {
  const BookingLedgerContent({super.key, required this.entries});
  final List<Map<String, dynamic>> entries;
  @override
  Widget build(BuildContext context) {
    final totals = bookingLedgerTotals(entries);
    return Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const BookingWorkspaceHeader(
                  title: 'صورة واضحة لأموال الحجوزات',
                  subtitle:
                      'المحصّل هو العربون المعتمد فقط؛ المتبقي من سعر الحجز ليس مبلغًا مقبوضًا.',
                  icon: Icons.account_balance_outlined),
              const SizedBox(height: 20),
              if (totals.values.any((v) => v == null))
                const BookingStateView(
                    title: 'توجد مبالغ غير مكتملة',
                    detail:
                        'بعض القيود القديمة أو غير الصالحة تمنع اعتماد إجمالياتها. راجع القيود قبل اتخاذ قرار مالي.',
                    icon: Icons.info_outline),
              for (final item in [
                (
                  'depositCollected',
                  'العربون المحصّل',
                  Icons.account_balance_wallet_outlined
                ),
                ('refundPaid', 'الاستردادات المدفوعة', Icons.undo),
                (
                  'ownerPaid',
                  'تسويات المالكين المدفوعة',
                  Icons.account_balance_outlined
                ),
                ('platformCommission', 'العمولات المسجلة', Icons.receipt_long),
              ])
                BookingMetricCard(
                    title: item.$2,
                    value: bookingMoney(totals[item.$1]),
                    icon: item.$3),
              const SizedBox(height: 24),
              BookingSection(
                  title: 'حركة الدفتر',
                  subtitle: '${entries.length} قيد في السجل المعروض',
                  child: Column(children: [
                    if (entries.isEmpty)
                      const BookingStateView(
                          title: 'لا توجد قيود مالية بعد',
                          detail:
                              'ستظهر الحركات بعد اعتماد العربون أو تسجيل الاسترداد والتسوية.',
                          icon: Icons.receipt_long_outlined),
                    for (final e in entries)
                      ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          leading: const Icon(Icons.receipt_long_outlined,
                              color: bookingGold),
                          title: Text(
                              const {
                                    'confirmPayment': 'اعتماد العربون',
                                    'settleRefund': 'استرداد العربون',
                                    'settleOwner': 'تسوية المالك'
                                  }[e['action']] ??
                                  'قيد مالي غير مصنّف',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              'الحجز: ${e['bookingId'] ?? 'غير متوفر'}\nالمرجع: ${e['reference'] ?? 'غير متوفر'}',
                              style: const TextStyle(height: 1.8))),
                  ])),
            ])));
  }
}

class BookingWorkspaceHeader extends StatelessWidget {
  const BookingWorkspaceHeader(
      {super.key,
      required this.title,
      required this.subtitle,
      this.icon = Icons.holiday_village_outlined});
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [bookingNavy, Color(0xFF1E2C46)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: Icon(icon, color: bookingGold, size: 30)),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 8),
        Text(subtitle,
            style: const TextStyle(height: 1.8, color: Colors.white70)),
      ]));
}

class BookingWorkspaceAction extends StatelessWidget {
  const BookingWorkspaceAction(
      {super.key, required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final large = MediaQuery.textScalerOf(context).scale(14) > 20;
    return SizedBox(
        width: width < 380 || large
            ? width - 64
            : width < 600
                ? (width - 76) / 2
                : 240,
        child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(18),
                minimumSize: const Size(0, 80),
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Row(children: [
              const Icon(Icons.arrow_outward, size: 20, color: bookingGold),
              const SizedBox(width: 12),
              Expanded(
                  child: DefaultTextStyle.merge(
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface),
                      child: child))
            ])));
  }
}

class BookingOwnerOverview extends StatelessWidget {
  const BookingOwnerOverview({super.key, required this.bookings});
  final List<Map<String, dynamic>> bookings;
  Widget tile(BuildContext c, String title, String value, IconData icon) =>
      Card(
          margin: EdgeInsets.zero,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon,
                        size: 20,
                        color: Theme.of(c).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 10),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 22,
                            height: 1.35,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Theme.of(c).colorScheme.onSurfaceVariant))
                  ])));
  Widget grid(BuildContext c, List<(String, String, IconData)> values) =>
      Column(children: [
        for (var i = 0; i < values.length; i += 2)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Expanded(
                        child:
                            tile(c, values[i].$1, values[i].$2, values[i].$3)),
                    const SizedBox(width: 10),
                    if (i + 1 < values.length)
                      Expanded(
                          child: tile(c, values[i + 1].$1, values[i + 1].$2,
                              values[i + 1].$3))
                    else
                      const Spacer()
                  ])))
      ]);
  @override
  Widget build(BuildContext context) {
    final m = bookingOwnerMetrics(bookings);
    final waiting = bookings
        .where((b) => ['held', 'payment_rejected'].contains(b['status']))
        .length;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('ملخص الحجوزات',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('${bookings.length} حجز ضمن النطاق المحدد',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13)),
          const SizedBox(height: 16),
          if (m['new'] > 0)
            Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  const Icon(Icons.notifications_active_outlined,
                      size: 20, color: bookingGold),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('${m['new']} طلب بانتظار موافقتك',
                          style: const TextStyle(fontWeight: FontWeight.w700)))
                ])),
          grid(context, [
            ('بانتظار الموافقة', '${m['new']}', Icons.inbox_outlined),
            ('بانتظار العربون', '$waiting', Icons.receipt_long_outlined),
            ('حجوزات مؤكدة', '${m['confirmed']}', Icons.verified_outlined),
            ('حجوزات قادمة', '${m['upcoming']}', Icons.event_outlined)
          ]),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('ملخص الإيرادات والعربون',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              children: [
                grid(context, [
                  (
                    'العربون المعتمد المسجّل — قبل الاسترداد',
                    bookingMoney(m['paid']),
                    Icons.account_balance_wallet_outlined
                  ),
                  (
                    'قيمة حجوزات متوقعة وليست إيرادًا محصّلًا',
                    bookingMoney(m['expected']),
                    Icons.trending_up
                  ),
                  (
                    'مبالغ متبقية غير مقبوضة',
                    bookingMoney(m['remaining']),
                    Icons.payments_outlined
                  ),
                  (
                    'قيمة الحجوزات المعتمدة والمكتملة',
                    bookingMoney(m['recorded']),
                    Icons.fact_check_outlined
                  )
                ]),
                const Text(
                    'الملخص قبل الاستردادات؛ راجع دفتر المالية للتسوية الصافية.',
                    style: TextStyle(fontSize: 12, height: 1.6)),
                const SizedBox(height: 12)
              ]),
          const SizedBox(height: 8),
          Text(
              'مكتملة ${m['completed']} · ملغاة ومرفوضة ومنتهية ${m['cancelled']}',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const Divider(height: 28),
        ]));
  }
}

/// Complete owner query content, rendered only after the parent verifies data.
class BookingOwnerPanel extends StatefulWidget {
  const BookingOwnerPanel(
      {super.key,
      required this.bookings,
      required this.onOpen,
      this.onManageVenues});
  final List<Map<String, dynamic>> bookings;
  final ValueChanged<String>? onOpen;
  final VoidCallback? onManageVenues;
  @override
  State<BookingOwnerPanel> createState() => _BookingOwnerPanelState();
}

class _BookingOwnerPanelState extends State<BookingOwnerPanel> {
  String? venueId;
  DateTimeRange? period;
  @override
  Widget build(BuildContext context) {
    final ids = {
      for (final b in widget.bookings)
        if (b['venueId'] is String)
          b['venueId'] as String: '${b['venueName'] ?? 'مكان الحجز'}'
    };
    final selected = ids.containsKey(venueId) ? venueId : null;
    final bookings = widget.bookings
        .where((b) =>
            (selected == null || b['venueId'] == selected) &&
            (period == null ||
                (b['start'] is num &&
                    b['start'] >=
                        DateTime.utc(period!.start.year, period!.start.month,
                                period!.start.day)
                            .subtract(const Duration(hours: 3))
                            .millisecondsSinceEpoch &&
                    b['start'] <
                        DateTime.utc(period!.end.year, period!.end.month,
                                period!.end.day)
                            .subtract(const Duration(hours: 3))
                            .add(const Duration(days: 1))
                            .millisecondsSinceEpoch)))
        .toList();
    final onOpen = widget.onOpen;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 12),
            const Text('لوحة المالك',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'تقرير المكان'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('جميع أماكن الحساب')),
                  for (final e in ids.entries)
                    DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            maxLines: 2, overflow: TextOverflow.ellipsis))
                ],
                onChanged: (id) => setState(() => venueId = id)),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(period == null
                      ? 'تحديد فترة التقرير'
                      : 'من ${bookingVisitTime(period!.start)} إلى ${bookingVisitTime(period!.end)}'),
                  onPressed: () async {
                    final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                        initialDateRange: period);
                    if (mounted && range != null)
                      setState(() => period = range);
                  }),
              if (period != null)
                TextButton(
                    onPressed: () => setState(() => period = null),
                    child: const Text('كل الفترات'))
            ]),
          ])),
      BookingOwnerOverview(bookings: bookings),
      Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('إدارة المكان',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in const [
                ('أماكني', Icons.domain_outlined),
                ('الأسعار والشفتات', Icons.payments_outlined),
                ('الصور والفيديو', Icons.collections_outlined),
                ('شروط الاستضافة', Icons.rule_outlined),
                ('التقويم والإتاحة', Icons.calendar_month_outlined)
              ])
                OutlinedButton.icon(
                    onPressed: e.$1 == 'التقويم والإتاحة'
                        ? null
                        : widget.onManageVenues,
                    icon: Icon(e.$2, size: 18),
                    label: Text(
                        e.$1 == 'التقويم والإتاحة'
                            ? 'الإتاحة — غير موصولة'
                            : e.$1,
                        style: const TextStyle(fontSize: 13)))
            ]),
            const SizedBox(height: 8),
            const Text(
                'اختر المكان من «أماكني» لإدارة إعداداته. المحادثات والتقييمات والدعم من تفاصيل الحجز.',
                style: TextStyle(fontSize: 12, height: 1.6))
          ])),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
              bookings.any((b) => b['status'] == 'requested')
                  ? 'طلبات تحتاج إجراءً'
                  : 'قائمة الحجوزات',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
      if (bookings.isEmpty)
        const BookingStateView(
            title: 'لا حجوزات في النطاق المحدد',
            detail:
                'غيّر المكان أو فترة التقرير؛ لا توجد مبالغ محصّلة تُفترض هنا.'),
      for (final b in [
        ...bookings.where((b) => b['status'] == 'requested'),
        ...bookings.where((b) => b['status'] != 'requested')
      ])
        Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onOpen == null ? null : () => onOpen('${b['id']}'),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('${b['venueName'] ?? 'مكان الحجز'}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                              bookingStatusNames[b['status']] ??
                                  'حالة غير معروفة',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          const Divider(height: 28),
                          Text(
                              b['pricing'] is Map &&
                                      b['pricing']['name'] is String
                                  ? 'الفترة: ${b['pricing']['name']}'
                                  : 'الفترة: حسب الموعد المسجّل',
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 6),
                          Text('الضيف: ${b['customerName'] ?? 'غير متوفر'}'),
                          const SizedBox(height: 8),
                          Text(
                              'الدخول: ${bookingVisitTime(bookingHoldDeadline(b['start'])?.add(const Duration(hours: 3)))}'),
                          const SizedBox(height: 8),
                          Text('قيمة الحجز: ${bookingMoney(b['total'])}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          if (onOpen != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text('مراجعة تفاصيل الطلب',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700))),
                        ]))))
    ]);
  }
}
