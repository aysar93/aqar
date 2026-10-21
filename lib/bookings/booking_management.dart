import 'booking_experience.dart';
import 'booking_operations.dart';
import 'booking_workspace.dart';
import 'booking_extras.dart';
import 'booking_ledger_access.dart';
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
              .snapshots(includeMetadataChanges: true),
          builder: (context, s) {
            if (s.hasError ||
                (s.hasData &&
                    (s.data!.metadata.isFromCache ||
                        s.data!.metadata.hasPendingWrites))) {
              return const BookingStateView(
                  title: 'يلزم اتصال للتحقق من الصلاحية',
                  detail:
                      'أعد الاتصال ليتم التحقق من الحساب وتحديث البيانات الخاصة بأمان.');
            }
            if (s.hasError)
              return const Center(child: Text('تعذر تحميل التقييمات'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            return ListView(padding: const EdgeInsets.all(20), children: [
              for (final d in s.data!.docs)
                BookingReviewCard(
                    rating: d.data()['rating'],
                    comment: '${d.data()['comment']}',
                    actions: [
                      for (final approved in [true, false])
                        TextButton(
                            onPressed: () => bookingRun(context, () async {
                                  await bookingCall('moderateBookingReview',
                                      {'reviewId': d.id, 'approved': approved});
                                }),
                            child:
                                Text(approved ? 'نشر التقييم' : 'رفض التقييم')),
                    ])
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
                    .snapshots(includeMetadataChanges: true),
                builder: (context, s) {
                  if (s.hasError ||
                      (s.hasData &&
                          (s.data!.metadata.isFromCache ||
                              s.data!.metadata.hasPendingWrites))) {
                    return const Center(
                        child:
                            Text('يلزم اتصال للتحقق من صلاحية عرض البيانات'));
                  }
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
  const BookingMediaInbox({super.key, this.reviews, this.call = bookingCall});
  final Stream<QuerySnapshot<Map<String, dynamic>>>? reviews;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
      call;
  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('مراجعة صور وفيديوهات الأماكن')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: reviews ??
              FirebaseFirestore.instance
                  .collection('booking_media_reviews')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(includeMetadataChanges: true),
          builder: (context, s) {
            if (s.hasError ||
                (s.hasData &&
                    (s.data!.metadata.isFromCache ||
                        s.data!.metadata.hasPendingWrites))) {
              return const BookingStateView(
                  title: 'يلزم اتصال للتحقق من الصلاحية',
                  detail:
                      'أعد الاتصال ليتم التحقق من الحساب وتحديث البيانات الخاصة بأمان.');
            }
            if (s.hasError)
              return const Center(child: Text('تعذر تحميل الملفات'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            if (s.data!.docs.isEmpty)
              return const BookingStateView(
                  title: 'كل الملفات تمت مراجعتها',
                  detail:
                      'ستظهر هنا الصور والفيديوهات الجديدة التي تنتظر قرار الإدارة.');
            return ListView(padding: const EdgeInsets.all(16), children: [
              for (final d in s.data!.docs)
                BookingMediaReviewCard(
                    venueId: '${d.data()['venueId']}',
                    preview: BookingMediaGallery(paths: [d.data()['path']]),
                    onReview: (approved) => bookingRun(context, () async {
                          await call(
                              [2, 3].contains(d.data()['schemaVersion'])
                                  ? 'reviewBookingExternalMedia'
                                  : 'reviewBookingMedia',
                              {'mediaId': d.id, 'approved': approved});
                        }))
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
              .snapshots(includeMetadataChanges: true),
          builder: (context, s) {
            if (s.hasError ||
                (s.hasData &&
                    (s.data!.metadata.isFromCache ||
                        s.data!.metadata.hasPendingWrites))) {
              return const BookingStateView(
                  title: 'يلزم اتصال للتحقق من الصلاحية',
                  detail:
                      'أعد الاتصال ليتم التحقق من الحساب وتحديث البيانات الخاصة بأمان.');
            }
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
    if (busy) return;
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
        BookingSection(
            title: 'إدارة إتاحة المكان',
            subtitle: 'إغلاق موعد أو تسجيل حجز خارجي دون بيانات العملاء',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                      decoration: const InputDecoration(
                          labelText: 'سبب الإغلاق أو نقل الملكية')),
                  FilledButton(
                      onPressed: busy || start == null || end == null
                          ? null
                          : () => run('saveBookingClosure', {
                                'venueId': widget.venueId,
                                'requestId':
                                    '${DateTime.now().microsecondsSinceEpoch}',
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
                          .snapshots(includeMetadataChanges: true),
                      builder: (context, s) {
                        if (s.hasError ||
                            (s.hasData &&
                                (s.data!.metadata.isFromCache ||
                                    s.data!.metadata.hasPendingWrites))) {
                          return const BookingStateView(
                              title: 'يلزم اتصال للتحقق من الصلاحية',
                              detail:
                                  'أعد الاتصال ليتم التحقق من الحساب وتحديث البيانات الخاصة بأمان.');
                        }
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
                                        : () => run('reopenBookingClosure',
                                            {'closureId': d.id}),
                                    child: const Text('إعادة الإتاحة')))
                        ]);
                      }),
                ])),
        if (widget.ownerControls) ...[
          BookingSection(
              title: 'عرض لفترة محدودة',
              subtitle: 'خصم واضح لمدة سبعة أيام؛ لا يغيّر سياسة العربون.',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                  ])),
          const Divider(height: 32),
          BookingStaffPermissions(
              controller: staff,
              scopes: scopes,
              busy: busy,
              onChanged: (key, yes) => setState(() {
                    if (yes) {
                      scopes.add(key);
                    } else {
                      scopes.remove(key);
                    }
                  }),
              onSave: () => run('setBookingVenueStaff', {
                    'venueId': widget.venueId,
                    'userId': staff.text.trim(),
                    'scopes': scopes.toList()
                  })),
          const Divider(height: 32),
          BookingSection(
              title: 'نقل الملكية',
              subtitle:
                  'يحتاج قبول المالك الجديد وموافقة إدارة مستقلة وتسوية الحجوزات القائمة.',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                        controller: owner,
                        decoration: const InputDecoration(
                            labelText: 'UID المالك الجديد'),
                        textDirection: TextDirection.ltr),
                    FilledButton(
                        onPressed: busy
                            ? null
                            : () => run('requestBookingOwnershipTransfer', {
                                  'venueId': widget.venueId,
                                  'newOwnerId': owner.text.trim(),
                                  'requestId':
                                      '${DateTime.now().microsecondsSinceEpoch}',
                                  'reason': reason.text
                                }),
                        child: const Text('تقديم طلب نقل ملكية')),
                  ])),
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
    if (busy) return;
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
                      ['confirmed', 'arrived'].contains(b['status']))
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
            stream: query.snapshots(includeMetadataChanges: true),
            builder: (context, s) {
              if (s.hasError ||
                  (s.hasData &&
                      (s.data!.metadata.isFromCache ||
                          s.data!.metadata.hasPendingWrites))) {
                return const BookingStateView(
                    title: 'يلزم اتصال للتحقق من الصلاحية',
                    detail:
                        'أعد الاتصال ليتم التحقق من الحساب وتحديث البيانات الخاصة بأمان.');
              }
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
      body: BookingLedgerAccess(
          sessions: FirebaseAuth.instance.authStateChanges().map((u) => u?.uid),
          currentUid: () => FirebaseAuth.instance.currentUser?.uid,
          permissions: (uid) => FirebaseFirestore.instance
                  .doc('users/$uid')
                  .snapshots(includeMetadataChanges: true)
                  .map((s) {
                final user = s.data();
                return BookingLedgerPermission(
                    fromCache:
                        s.metadata.isFromCache || s.metadata.hasPendingWrites,
                    allowed: user != null &&
                        user['isBlocked'] != true &&
                        (user['isAdmin'] == true ||
                            user['canReviewBookingPayments'] == true));
              }),
          builder: (context) =>
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('booking_ledger')
                      .snapshots(includeMetadataChanges: true),
                  builder: (context, s) {
                    if (s.hasError ||
                        (s.hasData &&
                            (s.data!.metadata.isFromCache ||
                                s.data!.metadata.hasPendingWrites))) {
                      return const BookingStateView(
                          title: 'يلزم اتصال للتحقق من الصلاحية',
                          detail:
                              'أعد الاتصال ليتم التحقق من الحساب وتحديث البيانات الخاصة بأمان.');
                    }
                    if (s.hasError)
                      return const Center(
                          child: Text('التقرير للإدارة والمالية المخولين فقط'));
                    if (!s.hasData)
                      return const Center(child: CircularProgressIndicator());
                    if (s.data!.metadata.isFromCache ||
                        s.data!.metadata.hasPendingWrites)
                      return const Center(
                          child: Text('اتصل بالإنترنت لتحديث دفتر المالية'));
                    return BookingLedgerContent(
                        entries: s.data!.docs.map((d) => d.data()).toList());
                  })));
}
