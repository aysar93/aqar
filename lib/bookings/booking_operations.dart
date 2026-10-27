import 'package:flutter/material.dart';
import 'booking_widgets.dart';
import 'booking_experience.dart';

/// Used by the live editor. Sections keep the same controllers and save action.
class BookingEditorPage extends StatelessWidget {
  const BookingEditorPage(
      {super.key,
      required this.title,
      required this.detail,
      required this.icon,
      required this.children});
  final String title, detail;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Icon(icon, color: bookingGold),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.bold)))
        ]),
        const SizedBox(height: 8),
        Text(detail,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.8)),
        const SizedBox(height: 20),
        for (final child in children)
          Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
      ]);
}

class BookingSupportForm extends StatelessWidget {
  const BookingSupportForm(
      {super.key,
      required this.subject,
      required this.message,
      required this.busy,
      required this.onSubmit});
  final TextEditingController subject, message;
  final bool busy;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => BookingSection(
      title: 'كيف نساعدك؟',
      subtitle: 'يرتبط طلبك بهذا الحجز لتتمكن الإدارة من متابعة التفاصيل.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
            controller: subject,
            enabled: !busy,
            maxLength: 200,
            decoration: const InputDecoration(
                labelText: 'موضوع الطلب', prefixIcon: Icon(Icons.subject))),
        const SizedBox(height: 12),
        TextField(
            controller: message,
            enabled: !busy,
            maxLength: 2000,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'تفاصيل المشكلة',
                hintText: 'ما الذي حدث؟ وكيف يمكننا مساعدتك؟')),
        Text('لحماية حسابك، لا تشارك كلمة المرور أو معلومات البطاقة.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.8)),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: busy ? null : onSubmit,
            icon: Icon(busy ? Icons.hourglass_top : Icons.support_agent),
            label: Text(busy ? 'جارٍ الإرسال' : 'فتح تذكرة دعم')),
      ]));
}

class BookingSupportTicket extends StatelessWidget {
  const BookingSupportTicket(
      {super.key, required this.data, this.actions = const []});
  final Map<String, dynamic> data;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => BookingSection(
      title: '${data['subject'] ?? 'طلب دعم'}',
      subtitle: const {
            'open': 'مفتوحة',
            'in_progress': 'قيد المتابعة',
            'resolved': 'تم الحل'
          }[data['status']] ??
          'حالة غير معروفة',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${data['message'] ?? ''}', style: const TextStyle(height: 1.8)),
        if (data['response'] != null)
          Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16)),
              child: Text('رد الدعم\n${data['response']}',
                  style: const TextStyle(height: 1.8))),
        if (actions.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(spacing: 8, children: actions)),
      ]));
}

class BookingReviewCard extends StatelessWidget {
  const BookingReviewCard(
      {super.key,
      required this.rating,
      required this.comment,
      this.actions = const [],
      this.verified = false});
  final dynamic rating;
  final String comment;
  final List<Widget> actions;
  final bool verified;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.star_rounded, color: bookingGold),
              const SizedBox(width: 8),
              Text('$rating / 5',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 8),
            Text(verified ? 'حجز مكتمل موثوق' : 'بانتظار قرار المراجعة',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Text(comment, style: const TextStyle(height: 1.8)),
            if (actions.isNotEmpty) Wrap(spacing: 12, children: actions),
          ])));
}

class BookingStaffPermissions extends StatelessWidget {
  const BookingStaffPermissions(
      {super.key,
      required this.controller,
      required this.scopes,
      required this.onChanged,
      required this.onSave,
      required this.busy});
  final TextEditingController controller;
  final Set<String> scopes;
  final void Function(String, bool) onChanged;
  final VoidCallback onSave;
  final bool busy;
  @override
  Widget build(BuildContext context) => BookingSection(
      title: 'فريق المكان',
      subtitle: 'امنح كل موظف ما يحتاجه فقط. هذه الصلاحيات لا تشمل المالية.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
            controller: controller,
            enabled: !busy,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
                labelText: 'UID حساب الموظف',
                prefixIcon: Icon(Icons.badge_outlined))),
        const SizedBox(height: 12),
        for (final entry in const {
          'calendar': 'إدارة الإغلاقات',
          'bookings': 'قبول ورفض الطلبات',
          'checkin': 'تسجيل الوصول والانتهاء'
        }.entries)
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              value: scopes.contains(entry.key),
              onChanged:
                  busy ? null : (value) => onChanged(entry.key, value == true)),
        Text('إلغاء جميع الاختيارات ثم الحفظ يسحب الصلاحيات.',
            style: TextStyle(
                height: 1.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: busy ? null : onSave,
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('حفظ الصلاحيات')),
      ]));
}

class BookingMediaPanel extends StatelessWidget {
  const BookingMediaPanel({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => BookingSection(
      title: 'صور وفيديو المكان',
      subtitle:
          'استعرض الملفات المنشورة وتابع المراجعة. الصورة حتى 10 MB والفيديو حتى 50 MB.',
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
}

class BookingReportCard extends StatelessWidget {
  const BookingReportCard(
      {super.key, required this.data, required this.onOpen, this.onResolve});
  final Map<String, dynamic> data;
  final VoidCallback onOpen;
  final VoidCallback? onResolve;
  @override
  Widget build(BuildContext context) => BookingSection(
      title: 'بلاغ مرتبط بحجز',
      subtitle:
          data['status'] == 'resolved' ? 'تمت المعالجة' : 'بحاجة إلى المتابعة',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${data['reason'] ?? ''}',
            style: const TextStyle(fontSize: 18, height: 1.8)),
        const SizedBox(height: 8),
        Text('مقدم البلاغ: ${data['userName'] ?? 'غير متوفر'}'),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('فتح الحجز')),
          if (onResolve != null)
            FilledButton.icon(
                onPressed: onResolve,
                icon: const Icon(Icons.done),
                label: const Text('تحديد كمعالج')),
        ])
      ]));
}

class BookingMapSearchHeader extends StatelessWidget {
  const BookingMapSearchHeader({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        const Icon(Icons.travel_explore, color: bookingGold, size: 30),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('اكتشف أماكن الأنبار',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('$count مكانًا يطابق البحث',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]))
      ]));
}

class BookingMediaReviewCard extends StatefulWidget {
  const BookingMediaReviewCard(
      {super.key,
      required this.venueId,
      required this.preview,
      required this.onReview});
  final String venueId;
  final Widget preview;
  final Future<void> Function(bool)? onReview;
  @override
  State<BookingMediaReviewCard> createState() => _MediaReviewState();
}

class _MediaReviewState extends State<BookingMediaReviewCard> {
  bool busy = false;
  Future<void> review(bool approved) async {
    if (busy || widget.onReview == null) return;
    setState(() => busy = true);
    try {
      await widget.onReview!(approved);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => BookingSection(
      title: 'مراجعة ملف المكان',
      subtitle: 'المكان ${widget.venueId} · بانتظار المراجعة',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        widget.preview,
        const SizedBox(height: 16),
        const Text('راجع محتوى الملف قبل اعتماده ليظهر للضيوف.',
            style: TextStyle(height: 1.8)),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed:
                  busy || widget.onReview == null ? null : () => review(true),
              icon: const Icon(Icons.check),
              label: const Text('اعتماد وعرض الملف')),
          OutlinedButton.icon(
              onPressed:
                  busy || widget.onReview == null ? null : () => review(false),
              icon: const Icon(Icons.close),
              label: const Text('رفض الملف')),
        ])
      ]));
}
