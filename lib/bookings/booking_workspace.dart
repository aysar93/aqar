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
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Row(children: [
              const Icon(Icons.arrow_outward, size: 20, color: bookingGold),
              const SizedBox(width: 12),
              Expanded(
                  child: DefaultTextStyle.merge(
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: bookingNavy),
                      child: child))
            ])));
  }
}

class BookingOwnerOverview extends StatelessWidget {
  const BookingOwnerOverview({super.key, required this.bookings});
  final List<Map<String, dynamic>> bookings;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BookingWorkspaceHeader(
            title: 'كل موعد، تحت سيطرتك',
            subtitle:
                'تابع الطلبات الجديدة والحجوزات المؤكدة، وافتح كل طلب لمراجعة تفاصيله.',
            icon: Icons.calendar_month_outlined),
        const SizedBox(height: 16),
        BookingMetricCard(
            title: 'طلبات بانتظار الموافقة',
            value:
                '${bookings.where((b) => b['status'] == 'requested').length}',
            icon: Icons.inbox_outlined),
        BookingMetricCard(
            title: 'حجوزات مؤكدة',
            value:
                '${bookings.where((b) => b['status'] == 'confirmed').length}',
            icon: Icons.event_available),
        const SizedBox(height: 16),
        const Text('قائمة الحجوزات',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      ]));
}

/// Complete owner query content, rendered only after the parent verifies data.
class BookingOwnerPanel extends StatelessWidget {
  const BookingOwnerPanel(
      {super.key, required this.bookings, required this.onOpen});
  final List<Map<String, dynamic>> bookings;
  final ValueChanged<String>? onOpen;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BookingOwnerOverview(bookings: bookings),
        for (final b in bookings)
          Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: onOpen == null ? null : () => onOpen!('${b['id']}'),
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${b['venueName'] ?? 'مكان الحجز'}',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(
                                bookingStatusNames[b['status']] ??
                                    'حالة غير معروفة',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B))),
                            const Divider(height: 28),
                            Text('الضيف: ${b['customerName'] ?? 'غير متوفر'}'),
                            const SizedBox(height: 8),
                            Text(
                                'الدخول: ${bookingVisitTime(bookingHoldDeadline(b['start'])?.add(const Duration(hours: 3)))}'),
                            const SizedBox(height: 8),
                            Text('قيمة الحجز: ${bookingMoney(b['total'])}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            if (onOpen != null)
                              const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: Text('مراجعة تفاصيل الطلب',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700))),
                          ]))))
      ]);
}
