import 'package:flutter/material.dart';
import 'booking_form_validator.dart';
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

class BookingSupportForm extends StatefulWidget {
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
  State<BookingSupportForm> createState() => _BookingSupportFormState();
}

class _BookingSupportFormState extends State<BookingSupportForm> {
  String? _subjectError;
  String? _messageError;

  void _validateAndSubmit() {
    final sErr = BookingFormValidator.requiredText(
      widget.subject.text,
      fieldName: 'موضوع الطلب',
      minLength: 2,
      maxLength: 200,
    );
    final mErr = BookingFormValidator.requiredText(
      widget.message.text,
      fieldName: 'تفاصيل المشكلة',
      minLength: 5,
      maxLength: 2000,
    );
    if (sErr != null || mErr != null) {
      setState(() {
        _subjectError = sErr;
        _messageError = mErr;
      });
      return;
    }
    if (_subjectError != null || _messageError != null) {
      setState(() {
        _subjectError = null;
        _messageError = null;
      });
    }
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) => BookingSection(
      title: 'كيف نساعدك؟',
      subtitle: 'يرتبط طلبك بهذا الحجز لتتمكن الإدارة من متابعة التفاصيل.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
            controller: widget.subject,
            enabled: !widget.busy,
            maxLength: 200,
            onChanged: (_) {
              if (_subjectError != null) setState(() => _subjectError = null);
            },
            decoration: InputDecoration(
                labelText: 'موضوع الطلب',
                errorText: _subjectError,
                suffix: const Text('*',
                    style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.bold)),
                prefixIcon: const Icon(Icons.subject))),
        const SizedBox(height: 12),
        TextField(
            controller: widget.message,
            enabled: !widget.busy,
            maxLength: 2000,
            maxLines: 4,
            onChanged: (_) {
              if (_messageError != null) setState(() => _messageError = null);
            },
            decoration: InputDecoration(
                labelText: 'تفاصيل المشكلة',
                errorText: _messageError,
                suffix: const Text('*',
                    style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.bold)),
                hintText: 'ما الذي حدث؟ وكيف يمكننا مساعدتك؟')),
        Text('لحماية حسابك، لا تشارك كلمة المرور أو معلومات البطاقة.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.8)),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: widget.busy ? null : _validateAndSubmit,
            icon: Icon(widget.busy ? Icons.hourglass_top : Icons.support_agent),
            label: Text(widget.busy ? 'جارٍ الإرسال' : 'فتح تذكرة دعم')),
      ]));
}

class BookingSupportTicket extends StatelessWidget {
  const BookingSupportTicket(
      {super.key, required this.data, this.actions = const []});
  final Map<String, dynamic> data;
  final List<Widget> actions;

  static const typeNames = {
    'no_access': 'عدم تسليم المكان',
    'description_mismatch': 'اختلاف وصف الشاليه',
    'property_damage': 'تلف أو ضرر',
    'cancellation_dispute': 'نزاع إلغاء',
    'deposit_dispute': 'خلاف على العربون أو الاسترداد',
    'stay_issue': 'مشكلة أثناء الإقامة',
    'general': 'دعم واستفسار عام',
  };

  static const statusNames = {
    'open': 'مفتوحة',
    'under_review': 'قيد المراجعة الإدارية',
    'in_progress': 'قيد المتابعة',
    'awaiting_customer': 'بانتظار رد الزبون',
    'awaiting_owner': 'بانتظار رد المالك',
    'resolved': 'تم الحل',
    'closed': 'مغلقة'
  };

  @override
  Widget build(BuildContext context) {
    final typeKey = data['type'] ?? data['disputeType'];
    final typeLabel = typeNames[typeKey];
    final statusLabel = statusNames[data['status']] ?? 'حالة غير معروفة';
    final messages = (data['messages'] is List) ? (data['messages'] as List) : null;

    return BookingSection(
      title: '${data['subject'] ?? 'طلب دعم أو نزاع'}',
      subtitle: typeLabel != null ? '$statusLabel • $typeLabel' : statusLabel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (data['venueName'] != null && data['venueName'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('المكان: ${data['venueName']}',
                style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
          ),
        if (messages != null && messages.isNotEmpty) ...[
          const Text('سجل المحادثة والردود:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          for (final m in messages)
            if (m is Map)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: m['senderRole'] == 'admin'
                      ? const Color(0xFFF0FDF4)
                      : (m['senderRole'] == 'owner' ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: m['senderRole'] == 'admin'
                        ? const Color(0xFFBBF7D0)
                        : (m['senderRole'] == 'owner' ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(
                      m['senderRole'] == 'admin'
                          ? 'الإدارة'
                          : (m['senderRole'] == 'owner' ? 'المالك' : 'الزبون'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: m['senderRole'] == 'admin'
                            ? const Color(0xFF166534)
                            : (m['senderRole'] == 'owner' ? const Color(0xFF92400E) : const Color(0xFF1E293B)),
                      ),
                    ),
                    if (m['senderName'] != null)
                      Text('${m['senderName']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 6),
                  Text('${m['text'] ?? ''}', style: const TextStyle(height: 1.6)),
                ]),
              ),
        ] else ...[
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
        ],
        if (data['resolution'] != null && data['resolution'].toString().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(Icons.gavel, color: Color(0xFF059669), size: 20),
                const SizedBox(width: 8),
                const Flexible(child: Text('القرار الإداري النهائي', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)))),
              ]),
              const SizedBox(height: 8),
              Text('${data['resolution']}', style: const TextStyle(height: 1.8, color: Color(0xFF065F46))),
            ]),
          ),
        if (actions.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
      ]),
    );
  }
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

class BookingStaffPermissions extends StatefulWidget {
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
  State<BookingStaffPermissions> createState() =>
      _BookingStaffPermissionsState();
}

class _BookingStaffPermissionsState extends State<BookingStaffPermissions> {
  String? _uidError;

  void _validateAndSave() {
    final err = BookingFormValidator.requiredText(
      widget.controller.text,
      fieldName: 'UID حساب الموظف',
      minLength: 2,
      maxLength: 128,
    );
    if (err != null) {
      setState(() => _uidError = err);
      return;
    }
    if (_uidError != null) setState(() => _uidError = null);
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) => BookingSection(
      title: 'فريق المكان',
      subtitle: 'امنح كل موظف ما يحتاجه فقط. هذه الصلاحيات لا تشمل المالية.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
            controller: widget.controller,
            enabled: !widget.busy,
            textDirection: TextDirection.ltr,
            onChanged: (_) {
              if (_uidError != null) setState(() => _uidError = null);
            },
            decoration: InputDecoration(
                labelText: 'UID حساب الموظف',
                errorText: _uidError,
                suffix: const Text('*',
                    style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.bold)),
                prefixIcon: const Icon(Icons.badge_outlined))),
        const SizedBox(height: 12),
        for (final entry in const {
          'calendar': 'إدارة الإغلاقات',
          'bookings': 'قبول ورفض الطلبات',
          'checkin': 'تسجيل الوصول والانتهاء'
        }.entries)
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              value: widget.scopes.contains(entry.key),
              onChanged: widget.busy
                  ? null
                  : (value) => widget.onChanged(entry.key, value == true)),
        Text('إلغاء جميع الاختيارات ثم الحفظ يسحب الصلاحيات.',
            style: TextStyle(
                height: 1.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: widget.busy ? null : _validateAndSave,
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
  Widget build(BuildContext context) {
    final isBooking = data['bookingId'] != null && data['bookingId'].toString().isNotEmpty;
    return BookingSection(
      title: isBooking ? 'بلاغ مرتبط بحجز' : 'بلاغ عن شاليه/مكان',
      subtitle:
          data['status'] == 'resolved' ? 'تمت المعالجة' : 'بحاجة إلى المتابعة',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${data['reason'] ?? ''}',
            style: const TextStyle(fontSize: 18, height: 1.8)),
        if (data['details'] != null && data['details'].toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${data['details']}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
        ],
        const SizedBox(height: 8),
        if (data['venueName'] != null) Text('المكان: ${data['venueName']}'),
        Text('مقدم البلاغ: ${data['userName'] ?? 'غير متوفر'}'),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: onOpen,
              icon: Icon(isBooking ? Icons.receipt_long_outlined : Icons.cottage_outlined),
              label: Text(isBooking ? 'فتح الحجز' : 'فتح المكان')),
          if (onResolve != null)
            FilledButton.icon(
                onPressed: onResolve,
                icon: const Icon(Icons.done),
                label: const Text('تحديد كمعالج')),
        ])
      ]));
  }
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
