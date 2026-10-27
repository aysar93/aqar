import 'package:flutter/material.dart';
import 'booking_widgets.dart';

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
                            bookingVisitTime(
                                e.$2?.toUtc().add(const Duration(hours: 3))),
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
                  for (final e in {
                    'الإجمالي': total,
                    'العربون المطلوب': venue['deposit'],
                    'المتبقي بعد اعتماد العربون':
                        total - (venue['deposit'] as num)
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
    final v =
        venue != null && venue!['id'] == booking['venueId'] ? venue : null;
    final paths = List<String>.from(v?['mediaPaths'] ?? [])
        .where((p) => !p.toLowerCase().endsWith('.mp4'))
        .toList();
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
                        Text('رقم الحجز: $id',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(bookingStatusNames[booking['status']] ??
                            'حالة غير معروفة')
                      ]),
                  const SizedBox(height: 14),
                  if (paths.isNotEmpty)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BookingCardMedia(
                            paths: [paths.first],
                            name: '${booking['venueName']}',
                            category: venueCategory(booking['category']))),
                  const SizedBox(height: 12),
                  Text('${booking['venueName'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w700)),
                  Text('${booking['location'] ?? ''}'),
                  BookingArrivalSummary(
                      start: booking['start'] is num
                          ? DateTime.fromMillisecondsSinceEpoch(
                              (booking['start'] as num).toInt(),
                              isUtc: true)
                          : null,
                      end: booking['end'] is num
                          ? DateTime.fromMillisecondsSinceEpoch(
                              (booking['end'] as num).toInt(),
                              isUtc: true)
                          : null),
                  if (booking['pricing'] is Map &&
                      booking['pricing']['name'] is String)
                    Text('الفترة: ${booking['pricing']['name']}'),
                  if (bookingGuestLabel(v?['guestType']) != null)
                    Text(bookingGuestLabel(v?['guestType'])!),
                  const SizedBox(height: 8),
                  Text('الإجمالي ${bookingMoney(booking['total'])}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(
                      'العربون ${bookingMoney(booking['deposit'])} · المتبقي ${bookingMoney(booking['remaining'])}'),
                  const SizedBox(height: 8),
                  const Text(
                      'حالة الدفع من السجل المعتمد؛ إرسال الطلب لا يعني تأكيد الحجز.',
                      style: TextStyle(fontSize: 12, height: 1.6))
                ])));
  }
}
