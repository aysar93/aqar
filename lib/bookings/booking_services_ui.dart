import 'booking_decision_ui.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'booking_widgets.dart';
import 'booking_experience.dart';

class BookingChatPanel extends StatelessWidget {
  const BookingChatPanel(
      {super.key,
      required this.messages,
      required this.uid,
      required this.controller,
      required this.busy,
      required this.retry,
      required this.onSend});
  final List<Map<String, dynamic>> messages;
  final String uid;
  final TextEditingController controller;
  final bool busy, retry;
  final VoidCallback? onSend;
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'مساحة خاصة لأطراف الحجز · تجنب الروابط ومعلومات الدفع الحساسة.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.7))),
        Expanded(
            child: messages.isEmpty
                ? const BookingStateView(
                    title: 'ابدأ المحادثة',
                    detail: 'اتفق على تفاصيل الزيارة مع الطرف الآخر هنا.',
                    icon: Icons.forum_outlined)
                : ListView(padding: const EdgeInsets.all(16), children: [
                    for (final message in messages)
                      Align(
                          alignment: message['senderId'] == uid
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * .82),
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: message['senderId'] == uid
                                      ? bookingNavy
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        message['senderId'] == uid
                                            ? 'أنت'
                                            : 'الطرف الآخر',
                                        style: TextStyle(
                                            color: message['senderId'] == uid
                                                ? bookingGold
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                            fontSize: 12)),
                                    const SizedBox(height: 6),
                                    Text('${message['message'] ?? ''}',
                                        style: TextStyle(
                                            color: message['senderId'] == uid
                                                ? Colors.white
                                                : Theme.of(context).colorScheme.onSurface,
                                            height: 1.8)),
                                  ]))),
                  ])),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (retry)
                        const Text(
                            'تعذر تأكيد الإرسال. إعادة المحاولة تستخدم الرسالة نفسها لتجنب التكرار.',
                            style: TextStyle(height: 1.7)),
                      TextField(
                          controller: controller,
                          enabled: !busy && !retry && onSend != null,
                          maxLength: 2000,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              labelText: 'رسالتك',
                              hintText: 'اكتب رسالة دون روابط خارجية')),
                      FilledButton.icon(
                          onPressed: busy ? null : onSend,
                          icon: Icon(
                              busy ? Icons.hourglass_top : Icons.send_rounded),
                          label: Text(busy
                              ? 'جارٍ الإرسال'
                              : retry
                                  ? 'إعادة إرسال الرسالة نفسها'
                                  : 'إرسال الرسالة')),
                    ]))),
      ]);
}

class BookingTransferCard extends StatefulWidget {
  const BookingTransferCard(
      {super.key,
      required this.data,
      required this.admin,
      required this.onAction});
  final Map<String, dynamic> data;
  final bool admin;
  final Future<void> Function(String)? onAction;
  @override
  State<BookingTransferCard> createState() => _TransferState();
}

class _TransferState extends State<BookingTransferCard> {
  bool busy = false;
  Future<void> run(String action) async {
    if (busy || widget.onAction == null) return;
    setState(() => busy = true);
    try {
      await widget.onAction!(action);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'];
    final actionable = widget.admin
        ? status == 'pending_admin'
        : status == 'pending_acceptance';
    return BookingSection(
        title: 'المكان ${widget.data['venueId'] ?? ''}',
        subtitle: const {
              'pending_acceptance': 'بانتظار قبول المالك الجديد',
              'pending_admin': 'بانتظار المراجعة الإدارية',
              'approved': 'تم نقل الملكية'
            }[status] ??
            'حالة تحتاج مراجعة',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${widget.data['reason'] ?? ''}',
              style: const TextStyle(height: 1.8)),
          const SizedBox(height: 16),
          for (final entry in const {
            'ownerId': 'المالك الحالي',
            'newOwnerId': 'المالك الجديد'
          }.entries)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                    '${entry.value}: ${widget.data[entry.key] ?? 'غير متوفر'}')),
          const SizedBox(height: 12),
          Text(
              'قبول المالك الجديد ثم مراجعة إدارية مستقلة. يجب تسوية الحجوزات والاستردادات القائمة قبل الاعتماد.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.8)),
          if (actionable)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.icon(
                    onPressed: busy || widget.onAction == null
                        ? null
                        : () => run(widget.admin ? 'approve' : 'accept'),
                    icon: const Icon(Icons.verified_user_outlined),
                    label: Text(busy
                        ? 'جارٍ تنفيذ الطلب'
                        : widget.admin
                            ? 'اعتماد النقل'
                            : 'قبول الملكية'))),
        ]));
  }
}

class BookingSettingsPanel extends StatelessWidget {
  const BookingSettingsPanel(
      {super.key,
      required this.hold,
      required this.busy,
      required this.onSave,
      required this.onAccounts,
      required this.reviewers,
      this.chaletDeposit,
      this.farmDeposit,
      this.hallDeposit,
      this.otherDeposit});
  final TextEditingController hold;
  final TextEditingController? chaletDeposit;
  final TextEditingController? farmDeposit;
  final TextEditingController? hallDeposit;
  final TextEditingController? otherDeposit;
  final bool busy;
  final VoidCallback? onSave, onAccounts;
  final Widget reviewers;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        if (chaletDeposit != null || farmDeposit != null || hallDeposit != null || otherDeposit != null)
          BookingSection(
              title: 'مبالغ العربون الثابتة حسب فئة المكان',
              subtitle:
                  'تُحدد مبالغ العربون الإلزامية لكل فئة. تطبق تلقائياً على كافة الحجوزات الجديدة.',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (chaletDeposit != null) ...[
                      TextField(
                          controller: chaletDeposit,
                          enabled: !busy && onSave != null,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'عربون الشاليهات (د.ع)',
                              prefixIcon: Icon(Icons.pool_outlined))),
                      const SizedBox(height: 12),
                    ],
                    if (farmDeposit != null) ...[
                      TextField(
                          controller: farmDeposit,
                          enabled: !busy && onSave != null,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'عربون المزارع والاستراحات (د.ع)',
                              prefixIcon: Icon(Icons.nature_people_outlined))),
                      const SizedBox(height: 12),
                    ],
                    if (hallDeposit != null) ...[
                      TextField(
                          controller: hallDeposit,
                          enabled: !busy && onSave != null,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'عربون القاعات والمناسبات (د.ع)',
                              prefixIcon: Icon(Icons.celebration_outlined))),
                      const SizedBox(height: 12),
                    ],
                    if (otherDeposit != null) ...[
                      TextField(
                          controller: otherDeposit,
                          enabled: !busy && onSave != null,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'عربون الفئات الأخرى (د.ع)',
                              prefixIcon: Icon(Icons.holiday_village_outlined))),
                      const SizedBox(height: 12),
                    ],
                  ])),
        BookingSection(
            title: 'سياسة الحجز المؤقت',
            subtitle:
                'تُقرأ المدة من الإعدادات الحالية. الحفظ إجراء إداري يؤثر في الحجوزات الجديدة.',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                      controller: hold,
                      enabled: !busy && onSave != null,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'المدة بالدقائق',
                          helperText: 'النطاق المسموح 5–10080 دقيقة',
                          prefixIcon: Icon(Icons.timer_outlined))),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: busy ? null : onSave,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(busy ? 'جارٍ الحفظ' : 'حفظ الإعدادات')),
                ])),
        BookingSection(
            title: 'قنوات الدفع اليدوي',
            subtitle:
                'حسابات مشتركة مع اشتراكات المكاتب. لا يُفعّل زين كاش دون حساب موثّق.',
            child: OutlinedButton.icon(
                onPressed: onAccounts,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('إدارة حسابات الدفع المشتركة'))),
        BookingSection(
            title: 'مراجعو المدفوعات',
            subtitle: 'صلاحية مستقلة عن الإدارة. اختر حسابات مخولة فقط.',
            child: reviewers),
        Text(
            'الإلغاء بواسطة المالك أو الإدارة يعيد كامل العربون. التسوية اليدوية تحتاج مرجع تحويل.',
            style: TextStyle(
                height: 1.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]);
}

class BookingQrPass extends StatefulWidget {
  const BookingQrPass(
      {super.key,
      required this.code,
      required this.expiresAt,
      this.now,
      this.sessions,
      this.currentUserId,
      this.issuedUid});
  final Stream<String?>? sessions;
  final String? Function()? currentUserId;
  final String? issuedUid;
  final String code;
  final DateTime? expiresAt;
  final DateTime Function()? now;
  @override
  State<BookingQrPass> createState() => _QrPassState();
}

class _QrPassState extends State<BookingQrPass> {
  Timer? timer;
  StreamSubscription<String?>? listener;
  bool revoked = false;
  @override
  void initState() {
    super.initState();
    listener = widget.sessions?.listen((uid) {
      if (mounted && uid != widget.issuedUid) setState(() => revoked = true);
    }, onError: (_) {
      if (mounted) setState(() => revoked = true);
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    listener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        widget.expiresAt?.difference(widget.now?.call() ?? DateTime.now());
    final valid = !revoked &&
        (widget.currentUserId == null ||
            widget.currentUserId!() == widget.issuedUid) &&
        remaining != null &&
        remaining > Duration.zero;
    if (!valid)
      return const BookingStateView(
          title: 'انتهت صلاحية رمز الوصول',
          detail:
              'أغلق هذه النافذة واطلب رمزًا جديدًا. اعتماد الوصول يحتاج تحقق الخادم.',
          icon: Icons.qr_code_2);
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.qr_code_2, color: bookingGold, size: 36),
          const SizedBox(height: 12),
          const Text('مرحبًا بك، زيارتك تبدأ هنا',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('اعرض الرمز للمالك عند الوصول. لا تشاركه مع الآخرين.',
              textAlign: TextAlign.center, style: TextStyle(height: 1.8)),
          const SizedBox(height: 16),
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: AspectRatio(
                      aspectRatio: 1,
                      child: QrImageView(
                          data: widget.code, backgroundColor: Colors.white)))),
          const SizedBox(height: 16),
          Text(
              'الوقت المتبقي ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ExpansionTile(title: const Text('نسخ الرمز نصيًا'), children: [
            SelectableText(widget.code, textDirection: TextDirection.ltr)
          ]),
        ]);
  }
}

class BookingScannerPanel extends StatelessWidget {
  const BookingScannerPanel(
      {super.key,
      required this.camera,
      this.error,
      this.onRetry,
      required this.busy});
  final Widget camera;
  final String? error;
  final VoidCallback? onRetry;
  final bool busy;
  @override
  Widget build(BuildContext context) => Column(children: [
        const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
                'وجّه الكاميرا إلى رمز الزبون. يعتمد الخادم الوصول للحجز والموعد الصحيحين.',
                style: TextStyle(height: 1.8),
                textAlign: TextAlign.center)),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(24), child: camera))),
        if (busy && error == null)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('جارٍ التحقق من الرمز…')),
        if (error != null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.8))),
        if (onRetry != null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المسح'))),
        SafeArea(
            top: false,
            child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('يلزم اتصال بالخادم لاعتماد الوصول.',
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)))),
      ]);
}

class BookingManualSettlement extends StatefulWidget {
  const BookingManualSettlement(
      {super.key,
      required this.title,
      required this.reference,
      required this.busy,
      required this.onSubmit,
      required this.label,
      this.bookingId,
      this.action,
      this.version,
      this.loadPreview});
  final String title, label;
  final String? bookingId, action;
  final int? version;
  final Future<Map<String, dynamic>> Function()? loadPreview;
  final TextEditingController reference;
  final bool busy;
  final VoidCallback? onSubmit;
  @override
  State<BookingManualSettlement> createState() => _ManualSettlementState();
}

class _ManualSettlementState extends State<BookingManualSettlement> {
  late Future<Map<String, dynamic>> preview = load();
  bool checking = false;
  Future<Map<String, dynamic>> load() async {
    if (widget.loadPreview == null ||
        widget.bookingId == null ||
        widget.action == null) throw StateError('لا توجد معاينة خادمية');
    return bookingVerifiedFinancePreview(await widget.loadPreview!(),
        widget.bookingId!, widget.action!, widget.version);
  }

  Future<void> review(Map<String, dynamic> shown) async {
    if (checking ||
        widget.busy ||
        widget.onSubmit == null ||
        widget.reference.text.trim().isEmpty) return;
    setState(() => checking = true);
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('مراجعة التسجيل المالي'),
                  content: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        BookingFinanceContext(preview: shown),
                        const SizedBox(height: 16),
                        Text('مرجع التحويل: ${widget.reference.text.trim()}'),
                        const BookingActionReason(
                            reason:
                                'هذا تسجيل لتحويل منفذ فعليًا، وليس أمرًا لإرسال أموال.')
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('رجوع')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('تأكيد التسجيل'))
                  ]));
      if (confirmed != true || !mounted) return;
      final fresh = await load();
      if (!mounted) return;
      if (fresh['version'] != shown['version'] ||
          fresh['amount'] != shown['amount'] ||
          (fresh['beneficiary'] as Map)['id'] !=
              (shown['beneficiary'] as Map)['id']) {
        setState(() {
          preview = Future.value(fresh);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'تغيرت بيانات الاستحقاق. راجع المعاينة الجديدة قبل التسجيل.')));
        return;
      }
      widget.onSubmit!();
    } catch (_) {
      if (mounted) {
        setState(() {
          preview = load();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر التحقق من التسوية. لم يُرسل تسجيل مالي.')));
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => BookingSection(
      title: widget.title,
      subtitle: 'معاينة من الخادم قبل تسجيل التحويل الفعلي.',
      child: FutureBuilder<Map<String, dynamic>>(
          future: preview,
          builder: (context, s) {
            if (s.hasError)
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BookingActionReason(
                        reason:
                            'التسجيل معطل: مبلغ الاستحقاق أو المستفيد غير متحقق منه. أعد الاتصال؛ البيانات القديمة لا تُستكمل افتراضيًا.'),
                    OutlinedButton(
                        onPressed: widget.loadPreview == null
                            ? null
                            : () => setState(() {
                                  preview = load();
                                }),
                        child: const Text('تحديث بيانات الاستحقاق'))
                  ]);
            if (!s.hasData)
              return const Column(children: [
                LinearProgressIndicator(),
                BookingActionReason(
                    reason:
                        'التسجيل معطل أثناء التحقق من المبلغ والمستفيد في الخادم.')
              ]);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BookingFinanceContext(preview: s.data!),
                  const SizedBox(height: 16),
                  TextField(
                      controller: widget.reference,
                      enabled: !widget.busy && !checking,
                      maxLength: 200,
                      decoration: const InputDecoration(
                          labelText: 'مرجع التحويل الفعلي',
                          prefixIcon: Icon(Icons.receipt_long_outlined))),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.reference,
                      builder: (context, value, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.busy || checking)
                                  const BookingActionReason(
                                      reason:
                                          'الإجراء معطل أثناء التحقق أو تنفيذ تسجيل سابق.')
                                else if (value.text.trim().isEmpty)
                                  const BookingActionReason(
                                      reason:
                                          'أدخل مرجع التحويل الفعلي لتفعيل مراجعة التسجيل.')
                                else if (widget.onSubmit == null)
                                  const BookingActionReason(
                                      reason:
                                          'التسجيل غير متاح في هذه الحالة.'),
                                FilledButton.icon(
                                    onPressed: widget.busy ||
                                            checking ||
                                            widget.onSubmit == null ||
                                            value.text.trim().isEmpty
                                        ? null
                                        : () => review(s.data!),
                                    icon: const Icon(Icons.fact_check_outlined),
                                    label: Text(widget.label)),
                              ])),
                ]);
          }));
}
