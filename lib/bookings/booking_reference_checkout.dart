import 'package:flutter/material.dart';
import 'booking_widgets.dart';

String shortBookingCode(String id) {
  if (id.length <= 8) return id;
  final clean = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  return 'AQAR-${clean.length > 5 ? clean.substring(0, 5) : clean}';
}

DateTime? bookingSafeDateTime(dynamic value) {
  if (value is num && value.isFinite) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    } catch (_) {
      return null;
    }
  }
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  try {
    final dynamic dyn = value;
    if (dyn.toDate != null) return (dyn.toDate() as DateTime).toUtc();
  } catch (_) {}
  return null;
}

class BookingArrivalSummary extends StatelessWidget {
  const BookingArrivalSummary(
      {super.key, required this.start, required this.end});
  final DateTime? start, end;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (final e in [('تاريخ الوصول', start), ('تاريخ المغادرة', end)])
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 20,
                      runSpacing: 6,
                      children: [
                        Text(e.$1,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                        Text(
                            e.$2 != null
                                ? bookingVisitTime(e.$2!.toUtc().add(const Duration(hours: 3)))
                                : 'غير متوفر',
                            style: const TextStyle(fontWeight: FontWeight.w700))
                      ]))
          ])));
}

class BookingRequestConfirmation extends StatefulWidget {
  const BookingRequestConfirmation(
      {super.key,
      required this.venue,
      required this.total,
      required this.start,
      required this.end,
      this.shiftName});
  final Map<String, dynamic> venue;
  final num total;
  final DateTime? start, end;
  final String? shiftName;
  @override
  State<BookingRequestConfirmation> createState() =>
      _BookingRequestConfirmationState();
}

class _BookingRequestConfirmationState
    extends State<BookingRequestConfirmation> {
  bool decided = false;
  void decide(bool value) {
    if (decided) return;
    decided = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue,
        total = widget.total,
        start = widget.start,
        end = widget.end,
        shiftName = widget.shiftName;
    return SafeArea(
        child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: .5),
                              borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 20),
                  const Text('مراجعة طلب الحجز',
                      style:
                          TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text('${venue['name']}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  if (shiftName != null) Text(shiftName),
                  if (bookingGuestLabel(venue['guestType']) != null)
                    Text(bookingGuestLabel(venue['guestType'])!),
                  BookingArrivalSummary(start: start, end: end),
                  Builder(builder: (context) {
                    final rawDeposit = venue['deposit'];
                    final depositNum = rawDeposit is num
                        ? rawDeposit
                        : (num.tryParse(rawDeposit?.toString() ?? '') ?? 0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final e in {
                          'الإجمالي': total,
                          'العربون المطلوب': rawDeposit ?? depositNum,
                          'المتبقي بعد اعتماد العربون': total - depositNum
                        }.entries)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 16,
                                  runSpacing: 4,
                                  children: [
                                    Text(e.key),
                                    Text(bookingMoney(e.value),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700))
                                  ])),
                      ],
                    );
                  }),
                  const Divider(height: 24),
                  Text('${venue['terms']}',
                      style: const TextStyle(fontSize: 13, height: 1.7)),
                  const SizedBox(height: 10),
                  const Text(
                      'يُرسل الطلب إلى المالك للمراجعة. رفع الإيصال لاحقًا لا يعني تأكيد الحجز قبل المراجعة المعتمدة.',
                      style: TextStyle(fontSize: 13, height: 1.7)),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                      key: const ValueKey('booking-confirm-sheet-send'),
                      style: FilledButton.styleFrom(
                          backgroundColor: bookingNavy,
                          foregroundColor: Colors.white),
                      onPressed: () => decide(true),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('تأكيد إرسال الطلب')),
                  TextButton(
                      onPressed: () => decide(false),
                      child: const Text('الرجوع للمراجعة'))
                ])));
  }
}

class BookingReservationHeader extends StatelessWidget {
  const BookingReservationHeader(
      {super.key, required this.booking, required this.id, this.venue});
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? venue;
  final String id;
  @override
  Widget build(BuildContext context) {
    final snapshot = booking['venueSnapshot'] is Map ? (booking['venueSnapshot'] as Map) : null;
    final v = (venue != null && venue!['id'] == booking['venueId'])
        ? venue
        : (snapshot != null ? Map<String, dynamic>.from(snapshot) : null);
    final rawPaths = v?['mediaPaths'] ?? booking['mediaPaths'] ?? [];
    final paths = (rawPaths is Iterable ? rawPaths : const [])
        .map((e) => e.toString())
        .where((p) => !p.toLowerCase().endsWith('.mp4'))
        .toList();
    final statusText = bookingStatusLabel(booking['status']);
    return Card(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text('رقم الحجز: ${shortBookingCode(id)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(statusText)
                      ]),
                  const SizedBox(height: 14),
                  if (paths.isNotEmpty)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BookingCardMedia(
                            paths: [paths.first],
                            name: '${booking['venueName'] ?? ''}',
                            category: venueCategory(booking['category']))),
                  const SizedBox(height: 12),
                  Text('${booking['venueName'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w700)),
                  Text('${booking['location'] ?? ''}'),
                  BookingArrivalSummary(
                      start: bookingSafeDateTime(booking['start']),
                      end: bookingSafeDateTime(booking['end'])),
                  if (booking['pricing'] is Map &&
                      booking['pricing']['name'] is String)
                    Text('الفترة: ${booking['pricing']['name']}'),
                  if (bookingGuestLabel(v?['guestType']) != null)
                    Text(bookingGuestLabel(v?['guestType'])!),
                  const SizedBox(height: 8),
                  Text('الإجمالي ${bookingMoney(booking['total'])}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Builder(builder: (_) {
                    final totalNum = booking['total'] is num
                        ? (booking['total'] as num)
                        : num.tryParse('${booking['total'] ?? ''}');
                    final depositNum = booking['deposit'] is num
                        ? (booking['deposit'] as num)
                        : num.tryParse('${booking['deposit'] ?? ''}');
                    final remainingCalc = booking['status'] == 'cancelled'
                        ? 0
                        : ((totalNum != null && depositNum != null && totalNum > depositNum)
                            ? (totalNum - depositNum)
                            : (booking['remaining'] ?? 0));
                    return Text(
                        'العربون ${bookingMoney(booking['deposit'])} · المتبقي ${bookingMoney(remainingCalc)}');
                  }),
                  const SizedBox(height: 8),
                  const Text(
                      'حالة الدفع من السجل المعتمد؛ إرسال الطلب لا يعني تأكيد الحجز.',
                      style: TextStyle(fontSize: 12, height: 1.6))
                ])));
  }
}
