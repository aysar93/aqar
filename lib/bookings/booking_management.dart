import 'booking_extras.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'booking_screen.dart';
import 'booking_widgets.dart';

class BookingReviewInbox extends StatelessWidget {
  const BookingReviewInbox({super.key});
  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('مراجعة تقييمات الحجوزات')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('booking_reviews')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, s) {
            if (s.hasError)
              return const Center(child: Text('تعذر تحميل التقييمات'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            return ListView(children: [
              for (final d in s.data!.docs)
                Card(
                    child: Column(children: [
                  ListTile(
                      title: Text('${d.data()['rating']} / 5'),
                      subtitle: Text('${d.data()['comment']}')),
                  for (final approved in [true, false])
                    TextButton(
                        onPressed: () => bookingRun(context, () async {
                              await bookingCall('moderateBookingReview',
                                  {'reviewId': d.id, 'approved': approved});
                            }),
                        child: Text(approved ? 'نشر التقييم' : 'رفض التقييم')),
                ]))
            ]);
          }));
}

class BookingChatScreen extends StatefulWidget {
  const BookingChatScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  final message = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('محادثة الحجز')),
      body: Column(children: [
        Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('booking_messages/${widget.bookingId}/messages')
                    .orderBy('createdAt')
                    .snapshots(),
                builder: (context, s) {
                  if (s.hasError)
                    return const Center(
                        child: Text('المحادثة لأطراف الحجز فقط'));
                  if (!s.hasData)
                    return const Center(child: CircularProgressIndicator());
                  return ListView(children: [
                    for (final d in s.data!.docs)
                      ListTile(
                          title: Text('${d.data()['message']}'),
                          subtitle: Text(d.data()['senderId'] ==
                                  FirebaseAuth.instance.currentUser?.uid
                              ? 'أنت'
                              : 'الطرف الآخر'))
                  ]);
                })),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: message,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                              hintText: 'اكتب رسالة دون روابط خارجية'))),
                  IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              await bookingRun(context, () async {
                                await bookingCall('sendBookingMessage', {
                                  'bookingId': widget.bookingId,
                                  'requestId':
                                      '${DateTime.now().microsecondsSinceEpoch}',
                                  'message': message.text
                                });
                                message.clear();
                              });
                              if (mounted) setState(() => busy = false);
                            })
                ]))),
      ]));
}

class BookingMediaInbox extends StatelessWidget {
  const BookingMediaInbox({super.key});
  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('مراجعة صور وفيديوهات الأماكن')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('booking_media_reviews')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, s) {
            if (s.hasError)
              return const Center(child: Text('تعذر تحميل الملفات'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            return ListView(padding: const EdgeInsets.all(16), children: [
              for (final d in s.data!.docs)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          Text('المكان ${d.data()['venueId']}'),
                          BookingMediaGallery(paths: [d.data()['path']]),
                          for (final approved in [true, false])
                            TextButton(
                                onPressed: () => bookingRun(context, () async {
                                      await bookingCall(d.data()['schemaVersion'] == 2 ? 'reviewBookingExternalMedia' : 'reviewBookingMedia', {
                                        'mediaId': d.id,
                                        'approved': approved
                                      });
                                    }),
                                child: Text(approved
                                    ? 'اعتماد وعرض الملف'
                                    : 'رفض الملف')),
                        ])))
            ]);
          }));
}

class BookingProofInbox extends StatelessWidget {
  const BookingProofInbox({super.key});
  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('مراجعة إثبات الملكية')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('booking_ownership_proofs')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, s) {
            if (s.hasError)
              return const Center(child: Text('تعذر تحميل الوثائق'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            return ListView(children: [
              for (final d in s.data!.docs)
                Card(
                    child: Column(children: [
                  ListTile(
                      title: Text('المكان ${d.id}'),
                      subtitle: Text('المالك ${d.data()['ownerId']}')),
                  TextButton(
                      onPressed: () => bookingRun(context, () async {
                            final bytes = await FirebaseStorage.instance
                                .ref(d.data()['path'])
                                .getData(10 * 1024 * 1024);
                            if (context.mounted && bytes != null)
                              await showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                      child: InteractiveViewer(
                                          child: Image.memory(bytes))));
                          }),
                      child: const Text('عرض الإثبات الخاص')),
                  for (final approved in [true, false])
                    TextButton(
                        onPressed: () => bookingRun(context, () async {
                              await bookingCall('reviewBookingOwnershipProof', {
                                'venueId': d.id,
                                'approved': approved,
                                'reason': approved
                                    ? 'تم تدقيق إثبات الملكية'
                                    : 'الوثيقة غير كافية؛ يرجى إعادة التقديم'
                              });
                            }),
                        child: Text(approved
                            ? 'اعتماد الوثيقة'
                            : 'رفض وطلب إعادة التقديم')),
                ]))
            ]);
          }));
}

class BookingOwnerTools extends StatefulWidget {
  const BookingOwnerTools(
      {super.key, required this.venueId, this.ownerControls = true});
  final bool ownerControls;
  final String venueId;
  @override
  State<BookingOwnerTools> createState() => _BookingOwnerToolsState();
}

class _BookingOwnerToolsState extends State<BookingOwnerTools> {
  final owner = TextEditingController(), reason = TextEditingController();
  final staff = TextEditingController();
  final discount = TextEditingController();
  final scopes = <String>{};
  DateTime? start, end;
  bool busy = false;
  @override
  void dispose() {
    staff.dispose();
    discount.dispose();
    owner.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> pick(bool first) async {
    final d = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null && mounted)
      setState(() {
        final value =
            DateTime.utc(d.year, d.month, d.day, t.hour - 3, t.minute);
        if (first) {
          start = value;
        } else {
          end = value;
        }
      });
  }

  Future<void> run(String name, Map<String, dynamic> data) async {
    setState(() => busy = true);
    await bookingRun(context, () async {
      await bookingCall(name, data);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حفظ الطلب')));
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('جدول المكان ونقل الملكية')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('إغلاق موعد أو تسجيل حجز خارجي دون بيانات العملاء'),
        TextButton(
            onPressed: busy ? null : () => pick(true),
            child: Text(
                'البداية بتوقيت بغداد: ${start?.add(const Duration(hours: 3)) ?? "اختر"}')),
        TextButton(
            onPressed: busy ? null : () => pick(false),
            child: Text(
                'النهاية بتوقيت بغداد: ${end?.add(const Duration(hours: 3)) ?? "اختر"}')),
        TextField(
            controller: reason,
            decoration:
                const InputDecoration(labelText: 'سبب الإغلاق أو نقل الملكية')),
        FilledButton(
            onPressed: busy || start == null || end == null
                ? null
                : () => run('saveBookingClosure', {
                      'venueId': widget.venueId,
                      'requestId': '${DateTime.now().microsecondsSinceEpoch}',
                      'start': start!.millisecondsSinceEpoch,
                      'end': end!.millisecondsSinceEpoch,
                      'reason': reason.text
                    }),
            child: const Text('حفظ موعد غير متاح')),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('booking_closures')
                .where('venueId', isEqualTo: widget.venueId)
                .where('active', isEqualTo: true)
                .snapshots(),
            builder: (context, s) {
              if (s.hasError)
                return const Text('لا تتوفر صلاحية قراءة الإغلاقات');
              return Column(children: [
                for (final d in s.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  ListTile(
                      title: Text('${d.data()['reason']}'),
                      subtitle: Text(
                          '${DateTime.fromMillisecondsSinceEpoch(d.data()['start'], isUtc: true).add(const Duration(hours: 3))} — بغداد'),
                      trailing: TextButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  'reopenBookingClosure', {'closureId': d.id}),
                          child: const Text('إعادة الإتاحة')))
              ]);
            }),
        if (widget.ownerControls) ...[
          const Divider(height: 32),
          TextField(
              controller: discount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'خصم مؤقت 0–50٪ لمدة 7 أيام')),
          FilledButton(
              onPressed: busy
                  ? null
                  : () => run('saveBookingOffer', {
                        'venueId': widget.venueId,
                        'percent': int.tryParse(discount.text),
                        'until': DateTime.now()
                            .add(const Duration(days: 7))
                            .millisecondsSinceEpoch
                      }),
              child: const Text('حفظ العرض — الصفر يلغي الخصم')),
          const Divider(height: 32),
          const Text('صلاحيات الموظفين — لا تشمل المالية'),
          TextField(
              controller: staff,
              decoration: const InputDecoration(labelText: 'UID حساب الموظف'),
              textDirection: TextDirection.ltr),
          for (final entry in const {
            'calendar': 'إدارة الإغلاقات',
            'bookings': 'قبول ورفض الطلبات',
            'checkin': 'تسجيل الوصول والانتهاء'
          }.entries)
            CheckboxListTile(
                value: scopes.contains(entry.key),
                title: Text(entry.value),
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                          if (v == true) {
                            scopes.add(entry.key);
                          } else {
                            scopes.remove(entry.key);
                          }
                        })),
          FilledButton(
              onPressed: busy
                  ? null
                  : () => run('setBookingVenueStaff', {
                        'venueId': widget.venueId,
                        'userId': staff.text.trim(),
                        'scopes': scopes.toList()
                      }),
              child:
                  const Text('حفظ الصلاحيات — إلغاء جميع الاختيارات يسحبها')),
          const Divider(height: 32),
          const Text(
              'نقل الملكية يحتاج قبول المالك الجديد وموافقة إدارة مستقلة وتسوية الحجوزات القائمة.'),
          TextField(
              controller: owner,
              decoration: const InputDecoration(labelText: 'UID المالك الجديد'),
              textDirection: TextDirection.ltr),
          FilledButton(
              onPressed: busy
                  ? null
                  : () => run('requestBookingOwnershipTransfer', {
                        'venueId': widget.venueId,
                        'newOwnerId': owner.text.trim(),
                        'requestId': '${DateTime.now().microsecondsSinceEpoch}',
                        'reason': reason.text
                      }),
              child: const Text('تقديم طلب نقل ملكية')),
        ],
      ]));
}

class BookingStaffScreen extends StatefulWidget {
  const BookingStaffScreen(
      {super.key, required this.venueId, required this.scopes});
  final String venueId;
  final List<String> scopes;
  @override
  State<BookingStaffScreen> createState() => _BookingStaffScreenState();
}

class _BookingStaffScreenState extends State<BookingStaffScreen> {
  late Future<Map<String, dynamic>> requests = load();
  Future<Map<String, dynamic>> load() =>
      bookingCall('getBookingStaffRequests', {'venueId': widget.venueId});
  bool busy = false;
  Future<void> act(String id, String action) async {
    setState(() => busy = true);
    await bookingRun(context, () async {
      await bookingCall('actOnBooking',
          {'bookingId': id, 'action': action, 'reason': 'قرار موظف مفوض'});
    });
    if (mounted)
      setState(() {
        busy = false;
        requests = load();
      });
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('طلبات الموظف')),
      body: FutureBuilder<Map<String, dynamic>>(
          future: requests,
          builder: (context, s) {
            if (s.hasError)
              return const Center(child: Text('لا تتوفر صلاحية موظف نشطة'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            return ListView(children: [
              if (widget.scopes.contains('calendar'))
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BookingOwnerTools(
                                venueId: widget.venueId,
                                ownerControls: false))),
                    child: const Text('إدارة إغلاق المواعيد')),
              for (final b in s.data!['bookings'] as List)
                Card(
                    child: Column(children: [
                  ListTile(
                      title: Text('${b['venueName']} — ${b['customerName']}'),
                      subtitle: Text(
                          bookingStatuses[b['status']] ?? '${b['status']}')),
                  if (widget.scopes.contains('bookings') &&
                      b['status'] == 'requested')
                    Wrap(children: [
                      TextButton(
                          onPressed:
                              busy ? null : () => act(b['id'], 'approve'),
                          child: const Text('قبول الطلب')),
                      TextButton(
                          onPressed: busy ? null : () => act(b['id'], 'reject'),
                          child: const Text('رفض الطلب'))
                    ]),
                  if (widget.scopes.contains('checkin') &&
                      b['status'] == 'confirmed')
                    TextButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('مسح رمز الوصول'),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    BookingScannerScreen(bookingId: b['id'])))),
                  if (widget.scopes.contains('checkin') &&
                      b['status'] == 'confirmed')
                    TextButton(
                        onPressed: busy ? null : () => act(b['id'], 'arrive'),
                        child: const Text('تسجيل الوصول')),
                  if (widget.scopes.contains('checkin') &&
                      ['confirmed', 'arrived'].contains(b['status']))
                    TextButton(
                        onPressed: busy ? null : () => act(b['id'], 'complete'),
                        child: const Text('تسجيل الانتهاء')),
                ])),
            ]);
          }));
}

class BookingTransferInbox extends StatelessWidget {
  const BookingTransferInbox({super.key, this.admin = false});
  final bool admin;
  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('booking_ownership_transfers');
    if (!admin)
      query = query.where('newOwnerId',
          isEqualTo: FirebaseAuth.instance.currentUser!.uid);
    return BookingScaffold(
        appBar: AppBar(title: const Text('طلبات نقل الملكية')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, s) {
              if (s.hasError)
                return const Center(child: Text('تعذر تحميل الطلبات'));
              if (!s.hasData)
                return const Center(child: CircularProgressIndicator());
              return ListView(children: [
                for (final d in s.data!.docs)
                  ListTile(
                      title: Text('المكان ${d.data()['venueId']}'),
                      subtitle:
                          Text('${d.data()['reason']} — ${d.data()['status']}'),
                      trailing: TextButton(
                          onPressed: () => bookingRun(context, () async {
                                await bookingCall(
                                    'actOnBookingOwnershipTransfer', {
                                  'transferId': d.id,
                                  'action': admin ? 'approve' : 'accept'
                                });
                              }),
                          child: Text(admin ? 'اعتماد النقل' : 'قبول الملكية')))
              ]);
            }));
  }
}

class BookingLedgerScreen extends StatelessWidget {
  const BookingLedgerScreen({super.key});
  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('دفتر مالية الحجوزات')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('booking_ledger')
              .snapshots(),
          builder: (context, s) {
            if (s.hasError)
              return const Center(
                  child: Text('التقرير للإدارة والمالية المخولين فقط'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            int sum(String k) => s.data!.docs.fold(
                0, (total, d) => total + ((d.data()[k] as num?)?.toInt() ?? 0));
            return ListView(padding: const EdgeInsets.all(20), children: [
              const Text(
                  'الحسابات تخص العربون المحصّل يدويًا فقط. المتبقي من ثمن الحجز لا يعد مبلغًا محصّلًا.'),
              Text(
                  'العربون ${sum('depositCollected')} د.ع\nالاستردادات ${sum('refundPaid')} د.ع\nتسويات الملاك ${sum('ownerPaid')} د.ع\nالعمولات ${sum('platformCommission')} د.ع'),
              const Divider(),
              for (final d in s.data!.docs)
                ListTile(
                    title: Text(
                        '${d.data()['bookingId']} — ${d.data()['action']}'),
                    subtitle: Text('مرجع ${d.data()['reference']}')),
            ]);
          }));
}
