import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../reports/content_report.dart';
import '../../services/notification_navigation_service.dart';

class ContentReportsScreen extends StatefulWidget {
  const ContentReportsScreen({super.key});
  @override
  State<ContentReportsScreen> createState() => _ContentReportsScreenState();
}

class _ContentReportsScreenState extends State<ContentReportsScreen> {
  final _subscriptions =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  final _groups = <bool, List<ContentReport>>{};
  final _errors = <bool>{};
  String _type = 'all', _status = 'open', _search = '';
  static const _gold = Color(0xffD4AF37);
  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    for (final office in [false, true]) {
      _subscriptions.add(FirebaseFirestore.instance
          .collection(office ? 'office_reports' : 'property_reports')
          .snapshots()
          .listen((s) {
        if (!mounted) return;
        setState(() {
          _groups[office] =
              s.docs.map((d) => ContentReport(d.id, office, d.data())).toList();
          _errors.remove(office);
        });
      }, onError: (Object e) {
        if (mounted) setState(() => _errors.add(office));
      }));
    }
  }

  void _retry() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    setState(() {
      _errors.clear();
      _groups.clear();
    });
    _listen();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  String _date(ContentReport r) {
    final d = r.createdAt?.toLocal();
    if (d == null) return 'التاريخ غير متوفر';
    return '${d.year}/${d.month}/${d.day} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final all = _groups.values.expand((v) => v).toList();
    final reports = all
        .where((r) =>
            (_type == 'all' || r.isOffice == (_type == 'office')) &&
            (_status == 'all' ||
                (_status == 'open' ? r.isOpen : r.status == _status)) &&
            '${r.title} ${r.targetId} ${r.reason} ${r.data['userId'] ?? ''}'
                .toLowerCase()
                .contains(_search.toLowerCase()))
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));
    return Theme(
        data: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(
                seedColor: _gold, brightness: Brightness.dark),
            scaffoldBackgroundColor: const Color(0xff0F172A)),
        child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AppBar(title: const Text('بلاغات العقارات والمكاتب')),
              body: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            Chip(
                                avatar: const Icon(Icons.flag_outlined),
                                label: Text('الإجمالي ${all.length}')),
                            Chip(
                                label: Text(
                                    'بانتظار المعالجة ${all.where((r) => r.isOpen).length}')),
                            Chip(
                                label: Text(
                                    'العقارات ${all.where((r) => !r.isOffice).length}')),
                            Chip(
                                label: Text(
                                    'المكاتب ${all.where((r) => r.isOffice).length}')),
                          ]),
                          const SizedBox(height: 12),
                          TextField(
                              onChanged: (v) =>
                                  setState(() => _search = v.trim()),
                              decoration: const InputDecoration(
                                  hintText:
                                      'ابحث بالعنوان أو المعرّف أو سبب البلاغ',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder())),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: DropdownButtonFormField<String>(
                                    value: _type,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'نوع البلاغ'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'all', child: Text('الكل')),
                                      DropdownMenuItem(
                                          value: 'property',
                                          child: Text('العقارات')),
                                      DropdownMenuItem(
                                          value: 'office',
                                          child: Text('المكاتب'))
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _type = v!))),
                            const SizedBox(width: 16),
                            Expanded(
                                child: DropdownButtonFormField<String>(
                                    value: _status,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'الحالة'),
                                    items: {
                                      'open': 'بانتظار المعالجة',
                                      'all': 'جميع الحالات',
                                      ...reportStatuses
                                    }
                                        .entries
                                        .map((e) => DropdownMenuItem(
                                            value: e.key, child: Text(e.value)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _status = v!))),
                          ]),
                        ])),
                Expanded(
                    child: _errors.isNotEmpty
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                const Text(
                                    'تعذر تحميل البلاغات. تحقق من الاتصال والصلاحيات.'),
                                TextButton(
                                    onPressed: _retry,
                                    child: const Text('إعادة المحاولة'))
                              ]))
                        : _groups.length < 2
                            ? const Center(child: CircularProgressIndicator())
                            : reports.isEmpty
                                ? const Center(
                                    child:
                                        Text('لا توجد بلاغات تطابق الاختيار'))
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 24),
                                    itemCount: reports.length,
                                    itemBuilder: (context, i) {
                                      final r = reports[i];
                                      return Card(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.all(16),
                                            leading: CircleAvatar(
                                                backgroundColor: _gold
                                                    .withValues(alpha: .15),
                                                child: Icon(
                                                    r.isOffice
                                                        ? Icons.business
                                                        : Icons
                                                            .home_work_outlined,
                                                    color: _gold)),
                                            title: Text(r.title,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            subtitle: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child: Text(
                                                    '${r.kind} • ${reportStatuses[r.status] ?? r.status}\n${r.reason}\n${_date(r)}')),
                                            trailing:
                                                const Icon(Icons.chevron_left),
                                            onTap: () => _details(context, r),
                                          ));
                                    })),
              ]),
            )));
  }

  Future<void> _details(BuildContext context, ContentReport report) async {
    await showDialog<void>(
        context: context,
        builder: (_) =>
            _ReportReviewDialog(report: report, date: _date(report)));
  }
}

class _ReportReviewDialog extends StatefulWidget {
  const _ReportReviewDialog({required this.report, required this.date});
  final ContentReport report;
  final String date;
  @override
  State<_ReportReviewDialog> createState() => _ReportReviewDialogState();
}

class _ReportReviewDialogState extends State<_ReportReviewDialog> {
  late final _notes = TextEditingController(
      text: widget.report.data['adminNotes']?.toString() ?? '');
  late String _status = reportStatuses.containsKey(widget.report.status)
      ? widget.report.status
      : 'pending';
  bool _saving = false, _opening = false;
  String? _error;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'يرجى تسجيل الدخول مجدداً.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection(widget.report.collection)
          .doc(widget.report.id)
          .update({
        'status': _status,
        'adminNotes': _notes.text.trim(),
        'reviewedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ المعالجة. حاول مجدداً.';
        });
    }
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final r = widget.report;
      final doc = await FirebaseFirestore.instance
          .collection(r.isOffice ? 'offices' : 'properties')
          .doc(r.targetId)
          .get();
      if (!mounted) return;
      if (!doc.exists) {
        setState(() =>
            _error = 'المحتوى محذوف أو لم يعد موجوداً. يبقى البلاغ محفوظاً.');
        return;
      }
      await NotificationNavigationService.handleNotification(context, {
        'type': r.isOffice ? 'office' : 'property',
        r.isOffice ? 'officeId' : 'propertyId': r.targetId
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر فتح المحتوى.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('مراجعة البلاغ'),
            content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(widget.report.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('${widget.report.kind} • ${widget.date}'),
                      const Divider(),
                      SelectableText(
                          'السبب: ${widget.report.reason}\n\nالتفاصيل: ${widget.report.data['details']?.toString().isNotEmpty == true ? widget.report.data['details'] : 'لم تُرفق تفاصيل'}\n\nمعرّف المبلّغ: ${widget.report.data['userId'] ?? 'غير متوفر'}\nمعرّف المحتوى: ${widget.report.targetId}'),
                      TextButton.icon(
                          onPressed: _saving || _opening ? null : _open,
                          icon: const Icon(Icons.open_in_new),
                          label: Text(_opening
                              ? 'جارٍ الفتح…'
                              : 'فتح المحتوى المبلّغ عنه')),
                      const Divider(),
                      DropdownButtonFormField<String>(
                          value: _status,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'حالة المعالجة'),
                          items: reportStatuses.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _status = v!)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _notes,
                          enabled: !_saving,
                          maxLength: 1500,
                          minLines: 2,
                          maxLines: 5,
                          decoration: const InputDecoration(
                              labelText: 'ملاحظات الإدارة والإجراء المتخذ',
                              border: OutlineInputBorder())),
                      const Text(
                          'تغيير الحالة يسجل نتيجة المراجعة فقط. إخفاء الإعلان أو إيقاف المكتب يتم من صفحة إدارته.'),
                      if (_error != null)
                        Text(_error!,
                            style: const TextStyle(color: Colors.redAccent)),
                    ]))),
            actions: [
              TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('إغلاق')),
              FilledButton(
                  onPressed: _saving || _opening ? null : _save,
                  child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ المعالجة'))
            ],
          )));
}
