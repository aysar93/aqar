import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

List<DateTime> bookingShiftDates(DateTime date, Map<String, dynamic> shift) {
  final minute = shift['checkInMinute'] as int;
  final duration = ((shift['checkOutMinute'] as int) - minute + 1440) % 1440;
  final start = DateTime.utc(date.year, date.month, date.day)
      .add(Duration(minutes: minute - 180));
  return [start, start.add(Duration(minutes: duration == 0 ? 1440 : duration))];
}

String bookingTime(dynamic minute) =>
    '${((minute as int) ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
int? bookingMinute(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
  return h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60
      ? h * 60 + m
      : null;
}

String bookingCancellationText(dynamic p) => p == null
    ? 'سياسة الاسترداد غير محددة لهذا الحجز القديم؛ يلزم اعتمادها قبل الإلغاء المالي.'
    : 'استرداد كامل العربون عند إلغاء الزبون قبل الدخول بـ ${p['freeCancellationHours']} ساعة أو أكثر، وبعدها استرداد ${p['lateRefundPercent']}٪. إلغاء المالك أو الإدارة قبل الدخول يعيد كامل العربون. لا يتاح الإلغاء بعد الدخول. الاسترداد بتحويل يدوي يراجعه موظف مالي.';

const bookingStatuses = {
  'requested': 'بانتظار المالك',
  'held': 'حجز مؤقت — بانتظار العربون',
  'payment_review': 'الإيصال قيد مراجعة الإدارة',
  'confirmed': 'حجز مؤكد',
  'cancel_requested': 'إلغاء بانتظار مراجعة الإيصال',
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
  bool finance = false;
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.doc('users/$uid').get().then((s) {
        if (mounted) {
          setState(
              () => finance = s.data()?['canReviewBookingPayments'] == true);
        }
      });
    }
  }

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
      if (tab == 4) {
        query = query.where('status',
            whereIn: ['payment_review', 'cancel_requested', 'cancelled']);
      } else if (!widget.admin) {
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
                  if (widget.admin) 3: 'البلاغات',
                  if (finance) 4: 'المراجعة المالية'
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
  String? shiftId;
  int get total {
    final v = widget.venue;
    if (v['pricingMode'] == 'hourly' && start != null && end != null) {
      return ((end!.difference(start!).inMinutes / 60) *
              (v['hourlyPrice'] as num))
          .round();
    }
    if (v['pricingMode'] == 'shifts' && shiftId != null) {
      return (v['shifts'] as List)
          .firstWhere((s) => s['id'] == shiftId)['price'] as int;
    }
    return v['price'] as int;
  }

  void setShiftDate(DateTime date) {
    final shift =
        (widget.venue['shifts'] as List).firstWhere((s) => s['id'] == shiftId);
    final dates =
        bookingShiftDates(date, Map<String, dynamic>.from(shift as Map));
    start = dates[0];
    end = dates[1];
  }

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
              'المالك: ${v['ownerName']}\nالموقع: ${v['location']}\nالسعر المحدد: $total د.ع\nالعربون: ${v['deposit']} د.ع\nالمتبقي بعد اعتماد العربون: ${total - (v['deposit'] as num)} د.ع\n\nالشروط: ${v['terms']}'),
          if (v['pricingMode'] == 'hourly')
            Text('سعر الساعة: ${v['hourlyPrice']} د.ع — اختر ساعات كاملة'),
          if (v['pricingMode'] == 'shifts') ...[
            DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: shiftId,
                decoration:
                    const InputDecoration(labelText: 'الشفت (توقيت بغداد)'),
                items: [
                  for (final shift in v['shifts'] as List)
                    DropdownMenuItem(
                        value: shift['id'] as String,
                        child: Text(
                            '${shift['name']} — ${bookingTime(shift['checkInMinute'])} إلى ${bookingTime(shift['checkOutMinute'])} — ${shift['price']} د.ع',
                            overflow: TextOverflow.ellipsis))
                ],
                onChanged: (value) => setState(() {
                      shiftId = value;
                      start = null;
                      end = null;
                      accepted = false;
                    })),
            TextButton(
                onPressed: shiftId == null
                    ? null
                    : () async {
                        final date = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)));
                        if (mounted && date != null) {
                          setState(() {
                            setShiftDate(date);
                            accepted = false;
                          });
                        }
                      },
                child: const Text('اختر تاريخ دخول الشفت')),
            if (start != null)
              Text(
                  'الدخول: ${start!.add(const Duration(hours: 3)).toString().replaceAll("Z", "")}\nالخروج: ${end!.add(const Duration(hours: 3)).toString().replaceAll("Z", "")} — توقيت بغداد'),
          ] else ...[
            TextButton(
                onPressed: () async {
                  final d = await pick();
                  if (mounted && d != null) {
                    setState(() {
                      start = d;
                      accepted = false;
                    });
                  }
                },
                child: Text('البداية: ${start ?? "اختر"}')),
            TextButton(
                onPressed: () async {
                  final d = await pick();
                  if (mounted && d != null) {
                    setState(() {
                      end = d;
                      accepted = false;
                    });
                  }
                },
                child: Text('النهاية: ${end ?? "اختر"}')),
          ],
          Text(bookingCancellationText(v['cancellationPolicy'])),
          TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'ملاحظات')),
          CheckboxListTile(
              value: accepted,
              onChanged: (v) => setState(() => accepted = v ?? false),
              title: const Text('أوافق على السعر والشروط وسياسة الإلغاء')),
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
                          'price': total,
                          'shiftId': shiftId,
                          'cancellationPolicy': v['cancellationPolicy'],
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
  bool busy = false, admin = false, finance = false;
  String method = 'qicard';
  final transaction = TextEditingController(),
      reason = TextEditingController(),
      refundReference = TextEditingController();
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.doc('users/$uid').get().then((s) {
        if (mounted) {
          setState(() {
            admin = s.data()?['isAdmin'] == true;
            finance = s.data()?['canReviewBookingPayments'] == true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    refundReference.dispose();
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
              Text(bookingCancellationText(b['cancellationPolicy'])),
              if (b['pricing'] != null)
                Text(
                    'التسعير: ${b['pricing']['name'] ?? b['pricing']['mode']}'),
              if (b['refundDue'] != null)
                Text(
                    'الاسترداد المستحق: ${b['refundDue']} د.ع — المعاد: ${b['refunded'] ?? 0} — الحالة: ${b['refundStatus'] == 'settled' ? 'تمت التسوية' : b['refundStatus'] == 'pending' ? 'بانتظار التسوية المالية' : 'لا يوجد مبلغ مستحق'}'),
              if (b['reviewedBy'] != null)
                Text('مراجع العربون: ${b['reviewedBy']}'),
              if (b['cancelledBy'] != null)
                Text(
                    'ألغاه: ${b['cancelledBy']} — السبب: ${b['cancellationReason'] ?? b['reason']}'),
              if (b['refundReference'] != null)
                Text(
                    'مرجع الاسترداد: ${b['refundReference']}\nالمراجع: ${b['refundSettledBy']}\nوقت التسوية: ${DateTime.fromMillisecondsSinceEpoch(b['refundSettledAt'])}'),
              if (finance &&
                  !owner &&
                  !customer &&
                  b['refundStatus'] == 'pending') ...[
                TextField(
                    controller: refundReference,
                    decoration: const InputDecoration(
                        labelText:
                            'مرجع تحويل الاسترداد بعد إعادة المبلغ فعلياً')),
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => act('settleRefund',
                            {'refundReference': refundReference.text}),
                    child: const Text('تسجيل إعادة المبلغ يدوياً')),
              ],
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
                FutureBuilder<Map<String, dynamic>>(
                    future: bookingCall('getBookingPaymentAccounts', {}),
                    builder: (context, snapshot) {
                      final c = snapshot.data?[method] as Map?;
                      return Text(c?['enabled'] == true
                          ? 'حوّل العربون يدوياً إلى: ${c?['account']}'
                          : 'لا يتوفر حساب تحويل موثّق لهذه الطريقة');
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
                                  await FlutterImageCompress.compressWithList(
                                      await image.readAsBytes(),
                                      format: CompressFormat.jpeg,
                                      quality: 85),
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
              if (finance &&
                  !owner &&
                  !customer &&
                  ['payment_review', 'cancel_requested']
                      .contains(b['status'])) ...[
                button(
                    b['status'] == 'cancel_requested'
                        ? 'اعتماد المبلغ وفتح تسوية الاسترداد'
                        : 'اعتماد العربون وتأكيد الحجز',
                    'confirmPayment'),
                button('رفض الإيصال', 'rejectPayment')
              ],
              if ((owner || customer || admin) &&
                  ['requested', 'held', 'confirmed', 'payment_review']
                      .contains(b['status']))
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
      'terms',
      'hourlyPrice',
      'freeCancellationHours',
      'lateRefundPercent'
    ])
      k: TextEditingController(
          text: (['freeCancellationHours', 'lateRefundPercent'].contains(k)
                      ? (widget.data['cancellationPolicy'] as Map? ?? {})[k]
                      : widget.data[k])
                  ?.toString() ??
              '')
  };
  late String pricingMode = widget.data['pricingMode'] ?? 'fixed';
  late final List<Map<String, TextEditingController>> shifts = [
    for (final shift in (widget.data['shifts'] as List? ?? []))
      {
        for (final key in [
          'id',
          'name',
          'checkInMinute',
          'checkOutMinute',
          'price'
        ])
          key: TextEditingController(
              text: ['checkInMinute', 'checkOutMinute'].contains(key)
                  ? bookingTime(shift[key])
                  : '${shift[key]}')
      }
  ];
  late String category = widget.data['category'] ?? 'chalet';
  late bool active = widget.data['active'] ?? false;
  bool busy = false;
  @override
  void dispose() {
    for (final shift in shifts) {
      for (final c in shift.values) {
        c.dispose();
      }
    }
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
        for (final e in fields.entries.where((e) =>
            e.key != 'ownerId' &&
            (e.key != 'price' || pricingMode == 'fixed') &&
            (e.key != 'hourlyPrice' || pricingMode == 'hourly')))
          TextField(
              controller: e.value,
              decoration: InputDecoration(
                  labelText: const {
                'name': 'اسم المكان',
                'ownerId': 'معرف حساب المالك للتحقق من الحساب',
                'location': 'الموقع',
                'price': 'السعر الثابت لكل حجز بالدينار',
                'deposit': 'العربون بالدينار',
                'terms': 'شروط المكان',
                'hourlyPrice':
                    'سعر الساعة بالدينار (عند اختيار التسعير بالساعة)',
                'freeCancellationHours':
                    'عدد ساعات الإلغاء قبل الدخول لاسترداد كامل العربون',
                'lateRefundPercent':
                    'نسبة استرداد العربون بعد الموعد أعلاه (0–100)'
              }[e.key]),
              maxLines: e.key == 'terms' ? 4 : 1),
        DropdownButtonFormField<String>(
            initialValue: pricingMode,
            decoration: const InputDecoration(labelText: 'نوع التسعير'),
            items: const [
              DropdownMenuItem(value: 'fixed', child: Text('سعر ثابت')),
              DropdownMenuItem(value: 'shifts', child: Text('شفتات')),
              DropdownMenuItem(value: 'hourly', child: Text('بالساعة'))
            ],
            onChanged: (v) => setState(() => pricingMode = v!)),
        if (pricingMode == 'shifts') ...[
          const Text(
              'أوقات الشفتات بتوقيت بغداد. الخروج قبل الدخول أو مساوياً له يعني اليوم التالي.'),
          for (final shift in shifts)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      for (final key in [
                        'name',
                        'checkInMinute',
                        'checkOutMinute',
                        'price'
                      ])
                        TextField(
                            controller: shift[key],
                            decoration: InputDecoration(
                                labelText: {
                              'name': 'اسم الشفت',
                              'checkInMinute': 'الدخول HH:mm',
                              'checkOutMinute': 'الخروج HH:mm',
                              'price': 'السعر بالدينار'
                            }[key])),
                      TextButton(
                          onPressed: () => setState(() {
                                shifts.remove(shift);
                                for (final c in shift.values) {
                                  c.dispose();
                                }
                              }),
                          child: const Text('حذف الشفت')),
                    ]))),
          TextButton(
              onPressed: shifts.length >= 12
                  ? null
                  : () => setState(() => shifts.add({
                        for (final key in [
                          'id',
                          'name',
                          'checkInMinute',
                          'checkOutMinute',
                          'price'
                        ])
                          key: TextEditingController(
                              text: key == 'id'
                                  ? 'shift_${DateTime.now().microsecondsSinceEpoch}'
                                  : '')
                      })),
              child: const Text('إضافة شفت')),
        ],
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
                          e.key: [
                            'price',
                            'deposit',
                            'hourlyPrice',
                            'freeCancellationHours',
                            'lateRefundPercent'
                          ].contains(e.key)
                              ? int.tryParse(e.value.text)
                              : e.value.text,
                        'pricingMode': pricingMode,
                        'shifts': [
                          for (final shift in shifts)
                            {
                              for (final entry in shift.entries)
                                entry.key: ['checkInMinute', 'checkOutMinute']
                                        .contains(entry.key)
                                    ? bookingMinute(entry.value.text)
                                    : entry.key == 'price'
                                        ? int.tryParse(entry.value.text)
                                        : entry.value.text
                            }
                        ],
                        'cancellationPolicy': {
                          'freeCancellationHours': int.tryParse(
                              fields['freeCancellationHours']!.text),
                          'lateRefundPercent':
                              int.tryParse(fields['lateRefundPercent']!.text)
                        },
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
    FirebaseFirestore.instance.doc('settings/bookings').get().then((s) async {
      final d = s.data() ?? {};
      hold.text = '${d['holdMinutes'] ?? 120}';
      final accounts = await bookingCall('getBookingPaymentAccounts', {});
      if (!mounted) return;
      qi.text = accounts['qicard']['account'] ?? '';
      zain.text = accounts['zaincash']['enabled'] == true
          ? accounts['zaincash']['account']
          : 'لا يوجد رقم موثّق في الاشتراكات';
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
            readOnly: true,
            decoration: const InputDecoration(labelText: 'اسم ورقم حساب كي')),
        TextField(
            controller: zain,
            readOnly: true,
            decoration:
                const InputDecoration(labelText: 'اسم ورقم حساب زين كاش')),
        const Text(
            'حسابات التحويل مشتركة مع اشتراكات المكاتب. لا يُفعّل زين كاش دون حساب موثّق. الإلغاء بواسطة المالك أو الإدارة يعيد كامل العربون. التسوية اليدوية تحتاج مرجع تحويل.'),
        FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance.collection('users').get(),
            builder: (context, snapshot) => Column(children: [
                  const Text(
                      'صلاحية مراجعة مدفوعات الحجوزات (مستقلة عن الإدارة)'),
                  for (final user in snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    SwitchListTile(
                        title: Text('${user.data()['name'] ?? user.id}'),
                        value: user.data()['canReviewBookingPayments'] == true,
                        onChanged: busy
                            ? null
                            : (enabled) => bookingRun(context, () async {
                                  await bookingCall('setBookingPaymentReviewer',
                                      {'userId': user.id, 'enabled': enabled});
                                  if (mounted) setState(() {});
                                })),
                ])),
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
                            .set({'holdMinutes': minutes}));
                    if (mounted) setState(() => busy = false);
                  },
            child: const Text('حفظ'))
      ]));
}
