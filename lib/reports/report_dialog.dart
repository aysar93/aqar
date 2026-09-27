import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'content_report.dart';
import '../moderation/user_blocks.dart';

Future<void> showContentReportDialog(BuildContext context,
    {bool isOffice = false,
    required String targetId,
    required String title,
    String? officeOwnerId,
    String? targetUid,
    String? targetPath}) async {
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
  final sent = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReportDialog(
          isOffice: isOffice,
          targetId: targetId,
          title: title,
          officeOwnerId: officeOwnerId,
          targetUid: targetUid ?? officeOwnerId,
          targetPath: targetPath));
  if (sent != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sent)));
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog(
      {required this.isOffice,
      required this.targetId,
      required this.title,
      this.officeOwnerId,
      this.targetUid,
      this.targetPath});
  final bool isOffice;
  final String targetId, title;
  final String? officeOwnerId, targetUid, targetPath;
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _details = TextEditingController();
  String? _reason, _error;
  bool _sending = false, _block = false;
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
      if (_block) {
        await UserBlocks.instance.block(widget.targetUid!,
            targetPath: widget.targetPath ??
                '${widget.isOffice ? 'offices' : 'properties'}/${widget.targetId}',
            officeId: widget.isOffice ? widget.targetId : '',
            reason: _reason!,
            details: _details.text.trim());
      } else if (widget.targetPath != null) {
        await FirebaseFirestore.instance.collection('user_reports').add({
          'userId': user.uid,
          'targetUid': widget.targetUid,
          'targetPath': widget.targetPath,
          'reason': _reason,
          'details': _details.text.trim(),
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
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
      }
      if (mounted)
        Navigator.pop(
            context,
            _block
                ? 'تم الحظر وإرسال البلاغ للإدارة.'
                : 'تم إرسال البلاغ إلى الإدارة للمراجعة. شكراً لك.');
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
            title: Text(widget.targetPath != null
                ? 'الإبلاغ عن المحتوى'
                : widget.isOffice
                    ? 'الإبلاغ عن المكتب'
                    : 'الإبلاغ عن العقار'),
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
                      if ((widget.targetUid ?? '').isNotEmpty &&
                          widget.targetUid !=
                              FirebaseAuth.instance.currentUser?.uid)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _block,
                          onChanged: _sending
                              ? null
                              : (value) =>
                                  setState(() => _block = value ?? false),
                          title: const Text('حظر المستخدم أيضًا'),
                          subtitle: const Text(
                              'ستختفي إعلاناته ومحتواه عنك فورًا، ويصل البلاغ إلى الإدارة للمراجعة.'),
                        ),
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
                  child: Text(_sending
                      ? 'جارٍ الإرسال…'
                      : _block
                          ? 'إرسال البلاغ وحظر المستخدم'
                          : 'إرسال البلاغ'))
            ],
          )));
}

Future<void> showUserContentReportDialog(BuildContext context, String uid,
    {required String targetPath}) async {
  if (uid.isEmpty || uid == FirebaseAuth.instance.currentUser?.uid) return;
  await showContentReportDialog(context,
      targetId: targetPath,
      title: 'الإبلاغ عن محتوى المستخدم',
      targetUid: uid,
      targetPath: targetPath);
}
