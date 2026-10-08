import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

const bookingStatuses = {
  'requested': 'بانتظار المالك',
  'held': 'حجز مؤقت — بانتظار العربون',
  'payment_review': 'الإيصال قيد مراجعة الإدارة',
  'confirmed': 'حجز مؤكد',
  'rejected': 'مرفوض',
  'cancelled': 'ملغي',
  'expired': 'انتهت المهلة',
  'payment_rejected': 'إيصال مرفوض'
};
Future<Map<String, dynamic>> bookingCall(
    String name, Map<String, dynamic> data) async {
  final result =
      await FirebaseFunctions.instance.httpsCallable(name).call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

Future<void> bookingRun(
    BuildContext context, Future<void> Function() task) async {
  try {
    await task();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is FirebaseFunctionsException
              ? e.message ?? 'تعذر تنفيذ العملية'
              : 'تعذر تنفيذ العملية، حاول مجدداً')));
    }
  }
}

class BookingScreen extends StatefulWidget {
  final bool admin;
  const BookingScreen({super.key, this.admin = false});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('سجل الدخول للوصول إلى الحجوزات')));
    }
    Query<Map<String, dynamic>> query;
    if (tab == 0) {
      query = FirebaseFirestore.instance.collection('booking_venues');
      if (!widget.admin) query = query.where('active', isEqualTo: true);
    } else if (tab == 3) {
      query = FirebaseFirestore.instance.collection('booking_reports');
    } else {
      query = FirebaseFirestore.instance.collection('bookings');
      if (!widget.admin) {
        query =
            query.where(tab == 1 ? 'customerId' : 'ownerId', isEqualTo: uid);
      }
    }
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            appBar: AppBar(
                title: Text(widget.admin ? 'إدارة الحجوزات' : 'الحجوزات'),
                actions: widget.admin
                    ? [
                        IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: 'إضافة مكان',
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BookingVenueEditor()))),
                        IconButton(
                            icon: const Icon(Icons.settings),
                            tooltip: 'إعدادات الحجوزات',
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const BookingSettingsScreen())))
                      ]
                    : null),
            body: Column(children: [
              Wrap(spacing: 8, children: [
                for (final entry in {
                  0: 'الأماكن',
                  1: widget.admin ? 'جميع الحجوزات' : 'حجوزاتي',
                  if (!widget.admin) 2: 'لوحة المالك',
                  if (widget.admin) 3: 'البلاغات'
                }.entries)
                  ChoiceChip(
                      label: Text(entry.value),
                      selected: tab == entry.key,
                      onSelected: (_) => setState(() => tab = entry.key))
              ]),
              Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: query.snapshots(),
                      builder: (context, s) {
                        if (s.hasError) {
                          return const Center(
                              child: Text('تعذر تحميل البيانات'));
                        }
                        if (!s.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (s.data!.docs.isEmpty) {
                          return const Center(
                              child: Text('لا توجد بيانات بعد'));
                        }
                        return ListView(
                            children: s.data!.docs.map((doc) {
                          final d = doc.data();
                          return Card(
                              child: ListTile(
                                  title: Text('${d['name'] ?? d['venueName']}'),
                                  subtitle: Text(tab == 0
                                      ? '${d['location']}\nالسعر: ${d['price']} د.ع — العربون: ${d['deposit']} د.ع'
                                      : tab == 3
                                          ? '${d['userName']}: ${d['reason']} — ${d['status']}'
                                          : '${d['customerName']} — ${bookingStatuses[d['status']] ?? d['status']}'),
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => tab == 0
                                              ? (widget.admin
                                                  ? BookingVenueEditor(
                                                      venueId: doc.id, data: d)
                                                  : BookingRequestScreen(
                                                      venueId: doc.id,
                                                      venue: d))
                                              : BookingDetailsScreen(
                                                  bookingId: (tab == 3
                                                          ? d['bookingId']
                                                          : doc.id)
                                                      .toString()))),
                                  trailing: tab == 3 && d['status'] == 'open'
                                      ? IconButton(
                                          icon: const Icon(Icons.check),
                                          onPressed: () => bookingRun(
                                              context,
                                              () => doc.reference.update(
                                                  {'status': 'resolved'})))
                                      : null));
                        }).toList());
                      }))
            ])));
  }
}

class BookingRequestScreen extends StatefulWidget {
  final String venueId;
  final Map<String, dynamic> venue;
  const BookingRequestScreen(
      {super.key, required this.venueId, required this.venue});
  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  DateTime? start, end;
  bool accepted = false, busy = false;
  final notes = TextEditingController();
  late final requestId = '${DateTime.now().microsecondsSinceEpoch}';
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<DateTime?> pick() async {
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) return null;
    final time =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    return time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.venue;
    return Scaffold(
        appBar: AppBar(title: Text('${v['name']}')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(
              'المالك: ${v['ownerName']}\nالموقع: ${v['location']}\nالسعر لكل حجز: ${v['price']} د.ع\nالعربون: ${v['deposit']} د.ع\nالمتبقي بعد اعتماد العربون: ${(v['price'] as num) - (v['deposit'] as num)} د.ع\n\nالشروط: ${v['terms']}'),
          TextButton(
              onPressed: () async {
                final d = await pick();
                if (mounted && d != null) setState(() => start = d);
              },
              child: Text('البداية: ${start ?? "اختر"}')),
          TextButton(
              onPressed: () async {
                final d = await pick();
                if (mounted && d != null) setState(() => end = d);
              },
              child: Text('النهاية: ${end ?? "اختر"}')),
          TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'ملاحظات')),
          CheckboxListTile(
              value: accepted,
              onChanged: (v) => setState(() => accepted = v ?? false),
              title: const Text('أوافق على السعر والشروط')),
          FilledButton(
              onPressed: busy || !accepted || start == null || end == null
                  ? null
                  : () async {
                      setState(() => busy = true);
                      await bookingRun(context, () async {
                        final r = await bookingCall('requestBooking', {
                          'venueId': widget.venueId,
                          'requestId': requestId,
                          'start': start!.millisecondsSinceEpoch,
                          'end': end!.millisecondsSinceEpoch,
                          'acceptedTerms': v['terms'],
                          'price': v['price'],
                          'deposit': v['deposit'],
                          'notes': notes.text
                        });
                        if (context.mounted) {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => BookingDetailsScreen(
                                      bookingId: r['id'])));
                        }
                      });
                      if (mounted) setState(() => busy = false);
                    },
              child: const Text('طلب الحجز'))
        ]));
  }
}

class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailsScreen({super.key, required this.bookingId});
  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  bool busy = false, admin = false;
  String method = 'qicard';
  final transaction = TextEditingController(), reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.doc('users/$uid').get().then((s) {
        if (mounted) setState(() => admin = s.data()?['isAdmin'] == true);
      });
    }
  }

  @override
  void dispose() {
    transaction.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> act(String action,
      [Map<String, dynamic> extra = const {}]) async {
    setState(() => busy = true);
    await bookingRun(context, () async {
      await bookingCall('actOnBooking', {
        'bookingId': widget.bookingId,
        'action': action,
        'reason': reason.text,
        ...extra
      });
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الحجز')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .doc('bookings/${widget.bookingId}')
              .snapshots(),
          builder: (context, s) {
            if (s.hasError) {
              return const Center(child: Text('لا تملك صلاحية عرض هذا الحجز'));
            }
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final b = s.data!.data();
            if (b == null) return const Center(child: Text('الحجز غير موجود'));
            final uid = FirebaseAuth.instance.currentUser?.uid,
                owner = uid == b['ownerId'],
                customer = uid == b['customerId'];
            final held = b['status'] == 'held' &&
                (b['holdUntil'] as num) > DateTime.now().millisecondsSinceEpoch;
            Widget button(String label, String action) => FilledButton(
                onPressed: busy ? null : () => act(action), child: Text(label));
            return ListView(padding: const EdgeInsets.all(20), children: [
              Text(
                  '${b['venueName']}\nالنوع: ${b['category']}\nالموقع: ${b['location']}\nالزبون: ${b['customerName']} — ${b['customerPhone']}\nالمالك: ${b['ownerName']} — ${b['ownerPhone']}\nالبداية: ${DateTime.fromMillisecondsSinceEpoch(b['start'])}\nالنهاية: ${DateTime.fromMillisecondsSinceEpoch(b['end'])}\nالإجمالي: ${b['total']} د.ع\nالعربون: ${b['deposit']} د.ع\nالمدفوع المعتمد: ${b['paid']} د.ع\nالمتبقي: ${b['remaining']} د.ع\nالحالة: ${bookingStatuses[b['status']]}\nالشروط: ${b['terms']}\nملاحظات: ${b['notes']}\n${b['reason'] ?? ""}\n${b['holdUntil'] == null ? "" : "مهلة الدفع: ${DateTime.fromMillisecondsSinceEpoch(b['holdUntil'])}"}\nطريقة الدفع: ${b['paymentMethod'] ?? "—"}\nرقم التحويل: ${b['transactionNumber'] ?? "—"}\nحساب التحويل: ${b['paymentAccount'] ?? "—"}'),
              if (b['receiptPath'] != null)
                TextButton(
                    onPressed: () => bookingRun(context, () async {
                          final bytes = await FirebaseStorage.instance
                              .ref(b['receiptPath'])
                              .getData(10 * 1024 * 1024);
                          if (context.mounted && bytes != null) {
                            showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                    child: InteractiveViewer(
                                        child: Image.memory(bytes))));
                          }
                        }),
                    child: const Text('عرض الإيصال')),
              TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                      labelText: 'سبب الرفض أو الإلغاء أو البلاغ')),
              if (owner && b['status'] == 'requested') ...[
                button('موافقة وحجز مؤقت', 'approve'),
                button('رفض الطلب', 'reject')
              ],
              if (customer && held) ...[
                DropdownButton<String>(
                    value: method,
                    items: const [
                      DropdownMenuItem(value: 'qicard', child: Text('كي')),
                      DropdownMenuItem(
                          value: 'zaincash', child: Text('زين كاش'))
                    ],
                    onChanged: (v) => setState(() => method = v!)),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .doc('settings/bookings')
                        .snapshots(),
                    builder: (context, s) {
                      final c = s.data?.data()?[method] as Map?;
                      return Text(c?['enabled'] == true
                          ? 'حوّل العربون يدوياً إلى: ${c?['account']}\n${c?['instructions'] ?? ""}'
                          : 'طريقة الدفع غير مهيأة لدى الإدارة');
                    }),
                TextField(
                    controller: transaction,
                    decoration:
                        const InputDecoration(labelText: 'رقم التحويل')),
                FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            await bookingRun(context, () async {
                              final image = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1600,
                                  imageQuality: 85);
                              if (image == null) return;
                              final path =
                                  'booking_receipts/${widget.bookingId}/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
                              await FirebaseStorage.instance.ref(path).putData(
                                  await image.readAsBytes(),
                                  SettableMetadata(contentType: 'image/jpeg'));
                              await bookingCall('actOnBooking', {
                                'bookingId': widget.bookingId,
                                'action': 'submitPayment',
                                'method': method,
                                'transactionNumber': transaction.text,
                                'receiptPath': path
                              });
                            });
                            if (mounted) setState(() => busy = false);
                          },
                    child: const Text('رفع إيصال وإرسال للمراجعة'))
              ],
              if (admin && b['status'] == 'payment_review') ...[
                button('اعتماد العربون وتأكيد الحجز', 'confirmPayment'),
                button('رفض الإيصال', 'rejectPayment')
              ],
              if ((owner || customer || admin) &&
                  ['requested', 'held'].contains(b['status']))
                button('إلغاء الحجز', 'cancel'),
              if (owner || customer)
                OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => bookingRun(context, () async {
                              await bookingCall('reportBooking', {
                                'bookingId': widget.bookingId,
                                'reason': reason.text
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('تم إرسال البلاغ')));
                              }
                            }),
                    child: const Text('إرسال بلاغ للإدارة')),
            ]);
          }));
}

class BookingVenueEditor extends StatefulWidget {
  final String? venueId;
  final Map<String, dynamic> data;
  const BookingVenueEditor({super.key, this.venueId, this.data = const {}});
  @override
  State<BookingVenueEditor> createState() => _BookingVenueEditorState();
}

class _BookingVenueEditorState extends State<BookingVenueEditor> {
  late final fields = {
    for (final k in [
      'name',
      'ownerId',
      'location',
      'price',
      'deposit',
      'terms'
    ])
      k: TextEditingController(text: widget.data[k]?.toString() ?? '')
  };
  late String category = widget.data['category'] ?? 'chalet';
  late bool active = widget.data['active'] ?? false;
  bool busy = false;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('إعداد مكان للحجز')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').get(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('تعذر تحميل حسابات الملاك');
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final users = snapshot.data!.docs
                .where((u) => u.data()['isBlocked'] != true)
                .toList();
            return DropdownButtonFormField<String>(
              initialValue: users.any((u) => u.id == fields['ownerId']!.text)
                  ? fields['ownerId']!.text
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'حساب المالك'),
              items: users
                  .map((u) => DropdownMenuItem(
                      value: u.id,
                      child: Text(
                          '${u.data()['name'] ?? u.data()['displayName'] ?? "حساب بلا اسم"} — ${u.data()['phone'] ?? ""}',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: widget.venueId != null
                  ? null
                  : (v) => fields['ownerId']!.text = v ?? '',
            );
          },
        ),
        for (final e in fields.entries.where((e) => e.key != 'ownerId'))
          TextField(
              controller: e.value,
              decoration: InputDecoration(
                  labelText: const {
                'name': 'اسم المكان',
                'ownerId': 'معرف حساب المالك للتحقق من الحساب',
                'location': 'الموقع',
                'price': 'السعر لكل حجز بالدينار',
                'deposit': 'العربون بالدينار',
                'terms': 'الشروط وسياسة الإلغاء'
              }[e.key]),
              maxLines: e.key == 'terms' ? 4 : 1),
        DropdownButton<String>(
            value: category,
            items: [
              for (final e in {
                'chalet': 'شاليه',
                'farm': 'مزرعة',
                'hall': 'قاعة',
                'other': 'أخرى'
              }.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value))
            ],
            onChanged: (v) => setState(() => category = v!)),
        SwitchListTile(
            title: const Text('متاح للحجز'),
            value: active,
            onChanged: (v) => setState(() => active = v)),
        FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    await bookingRun(context, () async {
                      await bookingCall('saveBookingVenue', {
                        'id': widget.venueId,
                        for (final e in fields.entries)
                          e.key: ['price', 'deposit'].contains(e.key)
                              ? int.tryParse(e.value.text)
                              : e.value.text,
                        'category': category,
                        'active': active
                      });
                      if (context.mounted) Navigator.pop(context);
                    });
                    if (mounted) setState(() => busy = false);
                  },
            child: const Text('حفظ'))
      ]));
}

class BookingSettingsScreen extends StatefulWidget {
  const BookingSettingsScreen({super.key});
  @override
  State<BookingSettingsScreen> createState() => _BookingSettingsScreenState();
}

class _BookingSettingsScreenState extends State<BookingSettingsScreen> {
  final hold = TextEditingController(text: '120'),
      qi = TextEditingController(),
      zain = TextEditingController();
  bool loaded = false, busy = false;
  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.doc('settings/bookings').get().then((s) {
      final d = s.data() ?? {};
      hold.text = '${d['holdMinutes'] ?? 120}';
      qi.text = d['qicard']?['account'] ?? '';
      zain.text = d['zaincash']?['account'] ?? '';
      if (mounted) setState(() => loaded = true);
    });
  }

  @override
  void dispose() {
    hold.dispose();
    qi.dispose();
    zain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('إعدادات الحجوزات')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(
            controller: hold,
            decoration: const InputDecoration(
                labelText: 'مدة الحجز المؤقت بالدقائق (5–10080)')),
        TextField(
            controller: qi,
            decoration: const InputDecoration(labelText: 'اسم ورقم حساب كي')),
        TextField(
            controller: zain,
            decoration:
                const InputDecoration(labelText: 'اسم ورقم حساب زين كاش')),
        const Text(
            'ترك حساب التحويل فارغاً يعطل طريقة الدفع. الإيصال مطلوب لكلا الطريقتين.'),
        FilledButton(
            onPressed: !loaded || busy
                ? null
                : () async {
                    final minutes = int.tryParse(hold.text);
                    if (minutes == null || minutes < 5 || minutes > 10080) {
                      return;
                    }
                    setState(() => busy = true);
                    await bookingRun(
                        context,
                        () => FirebaseFirestore.instance
                                .doc('settings/bookings')
                                .set({
                              'holdMinutes': minutes,
                              'qicard': {
                                'enabled': qi.text.trim().isNotEmpty,
                                'account': qi.text.trim()
                              },
                              'zaincash': {
                                'enabled': zain.text.trim().isNotEmpty,
                                'account': zain.text.trim()
                              }
                            }));
                    if (mounted) setState(() => busy = false);
                  },
            child: const Text('حفظ'))
      ]));
}
