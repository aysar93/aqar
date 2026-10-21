import 'package:flutter/material.dart';
import 'booking_widgets.dart';
import 'booking_experience.dart';

bool bookingKnownMoney(dynamic value) =>
    value is num &&
    value.isFinite &&
    value >= 0 &&
    value <= 9007199254740991 &&
    value == value.truncateToDouble();

class BookingActionReason extends StatelessWidget {
  const BookingActionReason({super.key, required this.reason});
  final String reason;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 18, color: Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(reason,
                style: const TextStyle(color: Color(0xFF475569), height: 1.7)))
      ]));
}

/// These are the immutable booking fields, never the venue's current policy.
class BookingAgreedPolicy extends StatelessWidget {
  const BookingAgreedPolicy({super.key, required this.booking});
  final Map<String, dynamic> booking;
  @override
  Widget build(BuildContext context) {
    final terms = booking['terms'];
    final policy = booking['cancellationPolicy'];
    final validPolicy = policy is Map &&
        policy['freeCancellationHours'] is int &&
        policy['freeCancellationHours'] >= 0 &&
        policy['freeCancellationHours'] <= 8760 &&
        policy['lateRefundPercent'] is int &&
        policy['lateRefundPercent'] >= 0 &&
        policy['lateRefundPercent'] <= 100;
    return BookingSection(
        title: 'الشروط المعتمدة لهذا الحجز',
        subtitle:
            'نسخة محفوظة وقت إنشاء الطلب؛ لا تستبدل بشروط المكان الحالية.',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              terms is String && terms.trim().isNotEmpty
                  ? terms
                  : 'الشروط الأصلية غير محفوظة لهذا الحجز. راجع الدعم؛ لا توجد شروط بديلة مفترضة.',
              style: const TextStyle(height: 1.9)),
          const SizedBox(height: 16),
          const Text('سياسة الإلغاء المعتمدة',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              validPolicy
                  ? 'استرداد كامل العربون عند الإلغاء قبل الدخول بـ${policy['freeCancellationHours']} ساعة أو أكثر. بعد ذلك: ${policy['lateRefundPercent']}٪ من العربون وفق السياسة المحفوظة.'
                  : 'سياسة الإلغاء الأصلية غير مكتملة. لا يمكن استنتاج نسبة استرداد من البيانات القديمة.',
              style: const TextStyle(height: 1.9)),
        ]));
  }
}

class BookingFinanceContext extends StatelessWidget {
  const BookingFinanceContext({super.key, required this.preview});
  final Map<String, dynamic> preview;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: bookingNavy, borderRadius: BorderRadius.circular(18)),
            child: Text(bookingMoney(preview['amount']),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        Text('الحجز المرتبط: ${preview['bookingId']}'),
        const SizedBox(height: 8),
        Text(
            'المستفيد: ${(preview['beneficiary'] as Map)['name'] ?? 'الاسم غير محفوظ'}'),
        SelectableText(
            'معرف المستفيد: ${(preview['beneficiary'] as Map)['id']}',
            textDirection: TextDirection.ltr),
        const SizedBox(height: 8),
        Text(
            preview['reason'] == 'completed_booking'
                ? 'سبب الاستحقاق: تسوية حجز مكتمل وفق الحساب المعتمد في الخادم.'
                : 'سبب الاستحقاق: استرداد عربون مستحق لحجز ملغى.',
            style: const TextStyle(height: 1.8)),
      ]);
}

Map<String, dynamic> bookingVerifiedFinancePreview(
    Map<String, dynamic> data, String bookingId, String action, int? version) {
  final beneficiary = data['beneficiary'];
  if (data['bookingId'] != bookingId ||
      data['action'] != action ||
      data['currency'] != 'IQD' ||
      !bookingKnownMoney(data['amount']) ||
      data['version'] is! int ||
      (version != null && data['version'] != version) ||
      beneficiary is! Map ||
      beneficiary['id'] is! String ||
      (beneficiary['id'] as String).trim().isEmpty ||
      data['reason'] !=
          (action == 'settleOwner'
              ? 'completed_booking'
              : 'cancelled_booking_refund'))
    throw StateError('تعذر التحقق من سياق التسوية');
  return data;
}

class BookingRecordedMoney extends StatelessWidget {
  const BookingRecordedMoney({super.key, required this.booking});
  final Map<String, dynamic> booking;
  @override
  Widget build(BuildContext context) => BookingSection(
      title: 'البيانات المالية المسجلة',
      subtitle:
          'قيم محفوظة مع الحجز؛ المفقود يبقى غير متوفر ولا يتحول إلى صفر.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final field in const {
          'paid': 'العربون المحصل',
          'refundDue': 'الاسترداد المستحق',
          'refunded': 'المبلغ المعاد',
          'ownerSettled': 'المبلغ المسوّى للمالك',
          'platformCommission': 'العمولة المسجلة'
        }.entries)
          if (booking.containsKey(field.key) || field.key == 'refunded')
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                    '${field.value}: ${bookingKnownMoney(booking[field.key]) ? bookingMoney(booking[field.key]) : 'غير متوفر'}')),
        if (booking['paymentAccountSnapshot'] is Map) ...[
          const SizedBox(height: 8),
          const Text('مستلم التحويل وقت تقديم الإيصال',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
              (booking['paymentAccountSnapshot'] as Map)['number'] is String
                  ? (booking['paymentAccountSnapshot'] as Map)['number']
                  : 'الرقم غير محفوظ',
              textDirection: TextDirection.ltr),
        ] else if (booking['receiptPath'] != null)
          const Text(
              'بيانات مستلم التحويل الأصلية غير محفوظة؛ لا تُستبدل بالحساب الحالي.'),
      ]));
}
