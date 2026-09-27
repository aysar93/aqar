import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> reviewSafetyTarget(BuildContext context, String path,
    {String targetUid = ''}) async {
  await showDialog<void>(
      context: context,
      builder: (_) => _SafetyReview(path: path, uid: targetUid));
}

class _SafetyReview extends StatefulWidget {
  const _SafetyReview({required this.path, required this.uid});
  final String path, uid;
  @override
  State<_SafetyReview> createState() => _SafetyReviewState();
}

class _SafetyReviewState extends State<_SafetyReview> {
  Map<String, dynamic>? data;
  String uid = '', message = '';
  bool loading = true, busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = widget.path.isEmpty
          ? null
          : await FirebaseFirestore.instance.doc(widget.path).get();
      if (!mounted) return;
      setState(() {
        data = snapshot?.data();
        uid = widget.uid.isNotEmpty
            ? widget.uid
            : (data?['userId'] ??
                    data?['publisherUid'] ??
                    data?['ownerId'] ??
                    '')
                .toString();
        loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          message = 'تعذر تحميل المحتوى';
        });
    }
  }

  Future<void> _act(bool block) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(
                    block ? 'إيقاف حساب المستخدم؟' : 'حذف المحتوى نهائياً؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأكيد'))
                ]));
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      if (block) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isBlocked': true,
          'blockedAt': FieldValue.serverTimestamp(),
          'blockedBy': FirebaseAuth.instance.currentUser!.uid,
        });
      } else {
        await FirebaseFirestore.instance.doc(widget.path).delete();
      }
      if (mounted)
        setState(() {
          message = block ? 'تم إيقاف الحساب ومنعه من النشر' : 'تم حذف المحتوى';
          if (!block) data = null;
        });
    } catch (_) {
      if (mounted)
        setState(
            () => message = 'تعذر تنفيذ الإجراء. تحقق من الصلاحيات والاتصال.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('المحتوى والمستخدم المبلّغ عنهما'),
        content: SizedBox(
            width: 500,
            child: loading
                ? const LinearProgressIndicator()
                : SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        SelectableText(
                            'المستخدم: $uid\nالمسار: ${widget.path}'),
                        if (data == null)
                          const Text(
                              'المحتوى محذوف أو غير متوفر؛ يبقى البلاغ محفوظاً.'),
                        if (data != null)
                          SelectableText(data!.entries
                              .where((e) => [
                                    'title',
                                    'name',
                                    'description',
                                    'text',
                                    'comment',
                                    'ownerReply',
                                    'status'
                                  ].contains(e.key))
                              .map((e) => '${e.key}: ${e.value}')
                              .join('\n\n')),
                        if (data?['images'] is List)
                          ...((data!['images'] as List)
                              .whereType<String>()
                              .take(12)
                              .map((url) => Image.network(url,
                                  height: 140,
                                  errorBuilder: (_, __, ___) =>
                                      const Text('تعذر تحميل الصورة')))),
                        Text(message),
                      ]))),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('إغلاق')),
          TextButton(
              onPressed: busy || data == null ? null : () => _act(false),
              child: const Text('حذف المحتوى')),
          FilledButton(
              onPressed: busy ||
                      uid.isEmpty ||
                      uid == FirebaseAuth.instance.currentUser?.uid
                  ? null
                  : () => _act(true),
              child: const Text('حظر المستخدم من التطبيق')),
        ],
      );
}

class SafetyReviewScreen extends StatelessWidget {
  const SafetyReviewScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('بلاغات المستخدمين والحظر')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('user_reports')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(
                  child:
                      Text('تعذر تحميل البلاغات. تحقق من الاتصال والصلاحيات.'));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.docs.isEmpty)
              return const Center(child: Text('لا توجد بلاغات'));
            return ListView(
                children: snapshot.data!.docs.map((doc) {
              final d = doc.data();
              final created = (d['createdAt'] as Timestamp?)?.toDate();
              final overdue = d['status'] == 'pending' &&
                  created != null &&
                  DateTime.now().difference(created).inHours >= 24;
              return Card(
                  child: ListTile(
                title: Text('${d['reason']} • ${d['status']}'),
                subtitle: Text(
                    '${d['targetUid']}\n${d['targetPath']}\n${d['details']}\n${created ?? ''}${overdue ? '\nمتأخر: تجب المعالجة خلال 24 ساعة' : ''}'),
                onTap: () => reviewSafetyTarget(context, d['targetPath'] ?? '',
                    targetUid: d['targetUid'] ?? ''),
                trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      try {
                        await doc.reference.update({
                          'status': value,
                          'reviewedBy': FirebaseAuth.instance.currentUser!.uid,
                          'updatedAt': FieldValue.serverTimestamp()
                        });
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تعذر حفظ حالة البلاغ')));
                      }
                    },
                    itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'in_review', child: Text('قيد المراجعة')),
                          PopupMenuItem(
                              value: 'resolved', child: Text('تمت المعالجة')),
                          PopupMenuItem(
                              value: 'dismissed',
                              child: Text('إغلاق دون إجراء'))
                        ]),
              ));
            }).toList());
          },
        ),
      );
}
