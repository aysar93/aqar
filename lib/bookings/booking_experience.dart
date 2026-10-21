import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'booking_decision_ui.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'booking_widgets.dart';
import 'booking_filters.dart';

class BookingSection extends StatelessWidget {
  const BookingSection(
      {super.key, required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            if (subtitle != null)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(subtitle!,
                      style: const TextStyle(
                          color: Color(0xFF64748B), height: 1.7))),
            const SizedBox(height: 16),
            child,
          ])));
}

class BookingVenueIdentity extends StatelessWidget {
  const BookingVenueIdentity({super.key, required this.venue});
  final Map<String, dynamic> venue;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${venueCategory(venue['category'])} · ${venue['location'] ?? ''}',
            style: const TextStyle(color: Color(0xFF64748B), height: 1.8)),
        Text('${venue['name'] ?? ''}',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if ((venue['capacity'] as num? ?? 0) > 0)
            Chip(
                avatar: const Icon(Icons.people_outline, size: 18),
                label: Text('${venue['capacity']} ضيف')),
          if ((venue['bedrooms'] as num? ?? 0) > 0)
            Chip(
                avatar: const Icon(Icons.bed_outlined, size: 18),
                label: Text('${venue['bedrooms']} غرف')),
          for (final amenity in venue['amenities'] as List? ?? [])
            if (bookingAmenities.containsKey(amenity))
              Chip(label: Text(bookingAmenities[amenity]!)),
        ]),
        const SizedBox(height: 20),
      ]);
}

class BookingCheckoutHeader extends StatelessWidget {
  const BookingCheckoutHeader({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('رحلتك إلى حجز مريح',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < 3; i++)
            Expanded(
                child: Semantics(
                    label: 'الخطوة ${i + 1} من 3، ${[
                      'المكان',
                      'الموعد',
                      'المراجعة'
                    ][i]}${i == step ? '، الحالية' : ''}',
                    child: Column(children: [
                      Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: i <= step
                                  ? bookingNavy
                                  : const Color(0xFFE2E8F0),
                              shape: BoxShape.circle),
                          child: Center(
                              child: i < step
                                  ? const Icon(Icons.check,
                                      size: 18, color: bookingGold)
                                  : Text('${i + 1}',
                                      style: TextStyle(
                                          color: i <= step
                                              ? Colors.white
                                              : bookingNavy,
                                          fontWeight: FontWeight.w700)))),
                      const SizedBox(height: 8),
                      Text(['المكان', 'الموعد', 'المراجعة'][i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: i == step
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                    ]))),
        ]),
      ]));
}

DateTime? bookingHoldDeadline(dynamic value) {
  if (value is! num || !value.isFinite || value != value.truncateToDouble())
    return null;
  try {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  } on RangeError {
    return null;
  }
}

/// Local presentation timer only. Server deadlines and authorization are unchanged.
class BookingHoldNotice extends StatefulWidget {
  const BookingHoldNotice(
      {super.key,
      required this.until,
      required this.onExpired,
      this.now = DateTime.now,
      this.compact = false});
  final DateTime until;
  final VoidCallback onExpired;
  final DateTime Function() now;
  final bool compact;
  @override
  State<BookingHoldNotice> createState() => _BookingHoldNoticeState();
}

class _BookingHoldNoticeState extends State<BookingHoldNotice> {
  Timer? timer;
  bool notified = false;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => tick());
  }

  @override
  void didUpdateWidget(covariant BookingHoldNotice old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) notified = false;
  }

  void tick() {
    if (!mounted) return;
    final expired = !widget.until.isAfter(widget.now());
    setState(() {});
    if (expired && !notified) {
      notified = true;
      widget.onExpired();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.until.difference(widget.now()).inMilliseconds;
    final seconds = ((remaining + 999) ~/ 1000).clamp(0, 1 << 31);
    if (widget.compact)
      return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF4EAD0),
              borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            const Icon(Icons.timer_outlined, color: bookingNavy),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      seconds == 0
                          ? 'انتهت مهلة العربون'
                          : 'الحجز مؤقت · أرسل العربون قبل انتهاء المهلة',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                      seconds == 0
                          ? 'بانتظار تحديث حالة الخادم'
                          : 'المتبقي ${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds % 3600 ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w700)),
                ]))
          ]));
    return BookingSection(
        title: seconds == 0 ? 'انتهت مهلة العربون' : 'مكانك محفوظ مؤقتًا',
        subtitle: seconds == 0
            ? 'حدّث الحجز للتحقق من الحالة. لا ترسل دفعة اعتمادًا على مهلة منتهية.'
            : 'أرسل الإيصال قبل انتهاء المهلة؛ تأكيد الحجز يتطلب مراجعة الإدارة.',
        child: Row(children: [
          const Icon(Icons.timer_outlined, color: bookingGold),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
                  seconds == 0
                      ? 'بانتظار تحديث حالة الخادم'
                      : 'المتبقي ${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds % 3600 ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700)))
        ]));
  }
}

/// Rendered inside the authenticated booking details screen; callbacks keep the
/// existing verified-upload and server authorization path.
class BookingPaymentPanel extends StatelessWidget {
  const BookingPaymentPanel(
      {super.key,
      required this.deposit,
      required this.accounts,
      required this.method,
      required this.transaction,
      required this.busy,
      required this.onMethod,
      required this.onSubmit,
      this.receiptBytes,
      this.onPickReceipt});
  final dynamic deposit;
  final Map<String, dynamic> accounts;
  final String method;
  final TextEditingController transaction;
  final bool busy;
  final ValueChanged<String> onMethod;
  final VoidCallback? onSubmit, onPickReceipt;
  final Uint8List? receiptBytes;
  @override
  Widget build(BuildContext context) {
    final selected = accounts[method];
    final number = selected is Map &&
            selected['number'] is String &&
            (selected['number'] as String).trim().isNotEmpty
        ? selected['number'] as String
        : null;
    return BookingSection(
        title: 'دفع عربون الحجز',
        subtitle:
            'راجع المستلم، ثم حوّل العربون وأرفق الإيصال قبل إرساله للمراجعة.',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: bookingNavy, borderRadius: BorderRadius.circular(18)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('العربون المطلوب',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(bookingMoney(deposit),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold))
                  ])),
          const SizedBox(height: 20),
          const Text('١ · اختر وسيلة التحويل',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final entry in accounts.entries)
            RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: entry.key,
                groupValue: method,
                title: Text(entry.key == 'qicard' ? 'Ki / Qi' : 'Zain Cash'),
                subtitle: Text('${entry.value['number'] ?? 'رقم غير متاح'}',
                    textDirection: TextDirection.ltr),
                onChanged: busy
                    ? null
                    : (value) {
                        if (value != null) onMethod(value);
                      }),
          if (number != null)
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('بيانات المستلم المعتمدة',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SelectableText(number,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.bold)),
                      const Text(
                          'اسم صاحب الحساب غير محفوظ في إعدادات الدفع؛ تحقق من الاسم الظاهر في تطبيق التحويل.',
                          style: TextStyle(height: 1.7)),
                      OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: number));
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('تم نسخ رقم المستلم')));
                                },
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('نسخ رقم المستلم')),
                    ])),
          const SizedBox(height: 20),
          const Text('٢ · بيانات التحويل والإيصال',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
              controller: transaction,
              enabled: !busy,
              maxLength: 200,
              decoration: const InputDecoration(
                  labelText: 'رقم التحويل',
                  prefixIcon: Icon(Icons.receipt_long_outlined))),
          OutlinedButton.icon(
              onPressed: busy ? null : onPickReceipt,
              icon: const Icon(Icons.attach_file_outlined),
              label: Text(receiptBytes == null
                  ? 'اختيار إيصال للمعاينة'
                  : 'تغيير الإيصال')),
          if (receiptBytes != null) ...[
            const SizedBox(height: 12),
            const Text('معاينة الإيصال قبل الإرسال'),
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(receiptBytes!,
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('تعذر عرض الإيصال. اختر صورة واضحة أخرى.'))),
            TextButton(
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                        child: InteractiveViewer(
                            child: Image.memory(receiptBytes!)))),
                child: const Text('تكبير الإيصال')),
          ],
          const SizedBox(height: 16),
          ValueListenableBuilder<TextEditingValue>(
              valueListenable: transaction,
              builder: (context, value, _) {
                final reason = busy
                    ? 'الإرسال معطل أثناء التحقق من عملية سابقة.'
                    : !bookingKnownMoney(deposit) || deposit <= 0
                        ? 'الإرسال معطل: العربون غير متحقق منه.'
                        : number == null
                            ? 'الإرسال معطل: لا توجد بيانات مستلم معتمدة.'
                            : value.text.trim().isEmpty
                                ? 'أدخل رقم التحويل لتفعيل الإرسال.'
                                : receiptBytes == null
                                    ? 'اختر الإيصال وراجع صورته قبل إرسال الطلب.'
                                    : onSubmit == null
                                        ? 'الإرسال غير متاح الآن؛ تحقق من المهلة والاتصال.'
                                        : null;
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (reason != null) BookingActionReason(reason: reason),
                      FilledButton.icon(
                          onPressed: reason == null ? onSubmit : null,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(busy
                              ? 'جارٍ التحقق من الإيصال…'
                              : 'إرسال الإيصال للمراجعة'))
                    ]);
              }),
          const SizedBox(height: 8),
          const Text(
              'إرسال الإيصال لا يؤكد الحجز. انتظر اعتماد المراجع المالي.',
              style: TextStyle(height: 1.8, color: Color(0xFF64748B))),
        ]));
  }
}
