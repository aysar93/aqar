import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'content_report.dart';

Future<void> showContentReportDialog(BuildContext context,
    {required bool isOffice,
    required String targetId,
    required String title,
    String? officeOwnerId}) async {
  if (FirebaseAuth.instance.currentUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل الدخول أولاً لإرسال البلاغ.')));
    return;
  }
  if (targetId.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديد الإعلان. أعد فتح الصفحة.')));
    return;
  }
  final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReportDialog(
          isOffice: isOffice,
          targetId: targetId,
          title: title,
          officeOwnerId: officeOwnerId));
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إرسال البلاغ إلى الإدارة للمراجعة. شكراً لك.')));
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog(
      {required this.isOffice,
      required this.targetId,
      required this.title,
      this.officeOwnerId});
  final bool isOffice;
  final String targetId, title;
  final String? officeOwnerId;
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _details = TextEditingController();
  String? _reason, _error;
  bool _sending = false;
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    if (_reason == null ||
        (_reason == 'سبب آخر' && _details.text.trim().isEmpty)) {
      setState(
          () => _error = 'اختر سبب البلاغ، واكتب التفاصيل عند اختيار سبب آخر.');
      return;
    }
    if (user == null) {
      setState(() => _error = 'انتهت جلسة الدخول. سجّل الدخول مجدداً.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection(widget.isOffice ? 'office_reports' : 'property_reports')
          .add({
        widget.isOffice ? 'officeId' : 'propertyId': widget.targetId,
        if (widget.isOffice) 'officeOwnerId': widget.officeOwnerId ?? '',
        'targetTitle': widget.title.length > 300
            ? widget.title.substring(0, 300)
            : widget.title,
        'userId': user.uid,
        'reason': _reason,
        'details': _details.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          _sending = false;
          _error = 'تعذر إرسال البلاغ. تحقق من الاتصال وحاول مجدداً.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_sending,
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(
                widget.isOffice ? 'الإبلاغ عن المكتب' : 'الإبلاغ عن العقار'),
            content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(widget.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      const Text(
                          'تصل تفاصيل البلاغ إلى الإدارة فقط لمراجعتها.'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _reason,
                          decoration: const InputDecoration(
                              labelText: 'سبب البلاغ',
                              border: OutlineInputBorder()),
                          items: reportReasons
                              .map((r) => DropdownMenuItem(
                                  value: r,
                                  child:
                                      Text(r, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: _sending
                              ? null
                              : (v) => setState(() => _reason = v)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _details,
                          enabled: !_sending,
                          maxLength: 1500,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                              labelText: 'تفاصيل تساعدنا في المراجعة',
                              border: OutlineInputBorder())),
                      if (_error != null)
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                    ]))),
            actions: [
              TextButton(
                  onPressed: _sending ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: _sending ? null : _send,
                  child: Text(_sending ? 'جارٍ الإرسال…' : 'إرسال البلاغ'))
            ],
          )));
}
