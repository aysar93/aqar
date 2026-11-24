import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'booking_access_guard.dart';
import 'booking_experience.dart';
import 'booking_decision_ui.dart';
import 'booking_services_ui.dart';
import 'booking_operations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../screens/login_screen.dart';
import 'booking_filters.dart';
import 'booking_screen.dart';
import 'booking_widgets.dart';

class BookingPublishedReviews extends StatefulWidget {
  const BookingPublishedReviews({super.key, required this.venueId, this.load});
  final String venueId;
  final Future<Map<String, dynamic>> Function()? load;
  @override
  State<BookingPublishedReviews> createState() => _PublishedReviewsState();
}

class _PublishedReviewsState extends State<BookingPublishedReviews> {
  late final reviews = widget.load?.call() ??
      bookingCall('getPublishedBookingReviews', {'venueId': widget.venueId});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: reviews,
      builder: (context, s) {
        if (s.hasError) return const Text('تعذر تحميل التقييمات');
        if (!s.hasData) return const LinearProgressIndicator();
        final count = (s.data?['count'] as num?)?.toInt() ?? 0;
        final avg = (s.data?['average'] as num?)?.toDouble() ?? 0.0;
        return ExpansionTile(
            title: Text(count == 0
                ? 'لا توجد تقييمات منشورة بعد'
                : 'تقييمات حجوزات مكتملة: $count — ${avg.toStringAsFixed(1)} / 5'),
            children: [
              if (count == 0)
                const ListTile(title: Text('لا توجد تقييمات منشورة بعد')),
              for (final r in (s.data?['reviews'] as List? ?? []))
                BookingReviewCard(
                    rating: r['rating'],
                    comment: '${r['comment'] ?? ''}',
                    verified: true)
            ]);
      });
}

class BookingManualCheckInDialog extends StatefulWidget {
  const BookingManualCheckInDialog({
    super.key,
    required this.bookingId,
    this.call,
  });

  final String bookingId;
  final Future<dynamic> Function(String, Map<String, dynamic>)? call;

  @override
  State<BookingManualCheckInDialog> createState() =>
      _BookingManualCheckInDialogState();
}

class _BookingManualCheckInDialogState
    extends State<BookingManualCheckInDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final raw = _codeController.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال أو لصق رمز التحقق للمتابعة');
      return;
    }

    final parts = raw.split(':');
    if (parts.length != 3 || parts[0] != 'aqar-booking') {
      setState(() =>
          _errorMessage = 'صيغة الرمز غير صالحة. يجب أن يبدأ بـ aqar-booking:');
      return;
    }

    if (parts[1] != widget.bookingId) {
      setState(() =>
          _errorMessage = 'هذا الرمز يخص حجزاً آخر؛ يرجى فتح الحجز الصحيح');
      return;
    }

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(parts[2])) {
      setState(() => _errorMessage = 'رمز التحقق غير مكتمل أو تالف');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final caller = widget.call ?? bookingCall;
      await caller('verifyBookingCheckInCode', {
        'code': raw,
        'bookingId': widget.bookingId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل وصول الحجز بنجاح'),
          backgroundColor: Color(0xFF0F172A),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e is FirebaseFunctionsException) {
          if (e.code == 'failed-precondition' &&
              e.details is Map &&
              e.details['reason'] == 'already-checked-in') {
            _errorMessage =
                'تم تسجيل الوصول مسبقاً، ولا يمكن استخدام هذا الرمز مرة أخرى';
          } else if (e.message != null &&
              e.message!.isNotEmpty &&
              !e.message!.contains('Exception')) {
            _errorMessage = e.message;
          } else {
            _errorMessage =
                'تعذر اعتماد الرمز. تحقق من الموعد وصلاحية الرمز واتصال الإنترنت.';
          }
        } else {
          _errorMessage =
              'تعذر اعتماد الرمز. تحقق من الموعد وصلاحية الرمز واتصال الإنترنت.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.pin_outlined, color: Color(0xFFC5A16B)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'إدخال رمز التحقق يدوياً',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'الصق أو اكتب رمز الوصول (QR Code) الذي يقدمه المستأجر عند تسجيل الوصول.',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              enabled: !_busy,
              maxLines: 2,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'aqar-booking:${widget.bookingId}:...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                labelText: 'رمز التحقق',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_outlined),
                  tooltip: 'لصق من الحافظة',
                  onPressed: _busy
                      ? null
                      : () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null && mounted) {
                            setState(() {
                              _codeController.text = data!.text!.trim();
                              _errorMessage = null;
                            });
                          }
                        },
                ),
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                            color: Colors.red.shade900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC5A16B),
            foregroundColor: Colors.black,
          ),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black),
                )
              : const Text('تحقق من الرمز',
                  style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class BookingScannerScreen extends StatefulWidget {
  const BookingScannerScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<BookingScannerScreen> createState() => _ScannerState();
}

class _ScannerState extends State<BookingScannerScreen> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> openManualEntry() async {
    await controller.stop();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => BookingManualCheckInDialog(
        bookingId: widget.bookingId,
        call: bookingCall,
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      try {
        await controller.start();
      } catch (_) {}
    }
  }

  Future<void> verify(String code) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await controller.stop();
      if (!code.startsWith('aqar-booking:${widget.bookingId}:'))
        throw StateError('رمز لحجز آخر؛ افتح الحجز الصحيح');
      await bookingCall('verifyBookingCheckInCode',
          {'code': code, 'bookingId': widget.bookingId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تحقق الخادم وسجل الوصول')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        setState(() => error = e is FirebaseFunctionsException &&
                e.code == 'failed-precondition' &&
                e.details is Map &&
                e.details['reason'] == 'already-checked-in'
            ? 'تم تسجيل الوصول مسبقًا، ولا يمكن استخدام هذا الرمز مرة أخرى'
            : 'تعذر اعتماد الرمز. تحقق من الموعد وصلاحية الرمز واتصال الإنترنت.');
    }
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(
        title: const Text('مسح رمز وصول الحجز'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.pin_outlined),
            label: const Text('إدخال يدوي'),
            onPressed: busy ? null : openManualEntry,
          ),
        ],
      ),
      body: BookingScannerPanel(
          busy: busy,
          error: error,
          camera: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                for (final b in capture.barcodes) {
                  if (b.rawValue != null) {
                    verify(b.rawValue!);
                    break;
                  }
                }
              },
              errorBuilder: (context, error) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'تعذر فتح الكاميرا؛ اسمح باستخدامها من إعدادات الهاتف أو استخدم الإدخال اليدوي للرمز.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.pin_outlined),
                        label: const Text('إدخال رمز التحقق يدوياً'),
                        onPressed: busy ? null : openManualEntry,
                      ),
                    ],
                  ))),
          onRetry: error == null
              ? null
              : () async {
                  setState(() {
                    busy = false;
                    error = null;
                  });
                  try {
                    await controller.start();
                  } catch (_) {
                    if (mounted)
                      setState(() => error =
                          'تعذر إعادة فتح الكاميرا. راجع الإذن وحاول مجددًا.');
                  }
                }));
}

class BookingSupportScreen extends StatefulWidget {
  const BookingSupportScreen({super.key, this.bookingId, this.admin = false});
  final String? bookingId;
  final bool admin;
  @override
  State<BookingSupportScreen> createState() => _SupportState();
}

class _SupportState extends State<BookingSupportScreen> {
  final subject = TextEditingController(), message = TextEditingController();
  final requestId = '${DateTime.now().microsecondsSinceEpoch}';
  bool busy = false;
  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> respond(String id, String status) async {
    final value = await showDialog<String>(
        context: context, builder: (_) => const BookingSupportResponseDialog());
    if (value != null && mounted) {
      await bookingRun(context, () async {
        await bookingCall('updateBookingSupportTicket',
            {'ticketId': id, 'status': status, 'response': value});
      });
    }
  }

  Future<void> addReply(String id) async {
    final value = await showDialog<String>(
        context: context, builder: (_) => const BookingSupportResponseDialog());
    if (value != null && mounted) {
      await bookingRun(context, () async {
        await bookingCall(
            'addBookingSupportMessage', {'ticketId': id, 'message': value});
      });
    }
  }

  Future<void> attachEvidence(String id) async {
    final value = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => BookingSupportEvidenceDialog(ticketId: id));
    if (value != null && mounted) {
      await bookingRun(context, () async {
        await bookingCall('attachBookingDisputeEvidence', {
          'ticketId': id,
          ...value,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفع وإرفاق الدليل بنجاح')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return BookingScaffold(
        appBar: AppBar(title: const Text('دعم الحجوزات')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.support_agent_rounded,
                    size: 64, color: bookingGold),
                const SizedBox(height: 16),
                const Text(
                  'سجل الدخول لعرض تذاكر الدعم أو فتح تذكرة جديدة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('تسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('booking_support');
    if (!widget.admin) {
      query = query.where('userId', isEqualTo: currentUser.uid);
    }
    return BookingScaffold(
        appBar: AppBar(title: const Text('دعم الحجوزات')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (widget.bookingId != null)
            BookingSupportForm(
                subject: subject,
                message: message,
                busy: busy,
                onSubmit: () async {
                  if (busy) return;
                  setState(() => busy = true);
                  final nav = Navigator.of(context);
                  await bookingRun(context, () async {
                    await bookingCall('openBookingSupportTicket', {
                      'bookingId': widget.bookingId,
                      'requestId': requestId,
                      'subject': subject.text,
                      'message': message.text
                    });
                    if (mounted) nav.pop();
                  });
                  if (mounted) setState(() => busy = false);
                }),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(includeMetadataChanges: true),
              builder: (context, s) => BookingVerifiedGate(
                    hasData: s.hasData,
                    hasError: s.hasError,
                    error: s.error,
                    isFromCache: s.data?.metadata.isFromCache ?? false,
                    hasPendingWrites:
                        s.data?.metadata.hasPendingWrites ?? false,
                    onRetry: () => setState(() {}),
                    child: Builder(builder: (_) {
                      final docs = s.data!.docs.toList()
                        ..sort((a, b) => ((b.data()['updatedAt'] as Timestamp?)
                                    ?.millisecondsSinceEpoch ??
                                0)
                            .compareTo((a.data()['updatedAt'] as Timestamp?)
                                    ?.millisecondsSinceEpoch ??
                                0));
                      if (docs.isEmpty) {
                        return const Text(
                            'لا توجد تذاكر. افتح تفاصيل الحجز لطلب الدعم.');
                      }
                      return Column(children: [
                        for (final d in docs)
                          BookingSupportTicket(data: d.data(), actions: [
                            if (d.data()['status'] != 'resolved' &&
                                d.data()['status'] != 'closed') ...[
                              TextButton.icon(
                                  icon: const Icon(Icons.reply),
                                  onPressed: () => addReply(d.id),
                                  label: const Text('إضافة رد')),
                              TextButton.icon(
                                  icon: const Icon(Icons.attach_file),
                                  onPressed: () => attachEvidence(d.id),
                                  label: const Text('إرفاق دليل')),
                            ],
                            if (widget.admin &&
                                d.data()['status'] != 'resolved' &&
                                d.data()['status'] != 'closed') ...[
                              TextButton(
                                  onPressed: () => respond(d.id, 'in_progress'),
                                  child: const Text('تولي التذكرة والرد')),
                              TextButton(
                                  onPressed: () => respond(d.id, 'resolved'),
                                  child: const Text('حل وإغلاق')),
                            ]
                          ])
                      ]);
                    }),
                  ))
        ]));
  }
}

class BookingSupportResponseDialog extends StatefulWidget {
  const BookingSupportResponseDialog({super.key});

  @override
  State<BookingSupportResponseDialog> createState() =>
      _BookingSupportResponseDialogState();
}

class _BookingSupportResponseDialogState
    extends State<BookingSupportResponseDialog> {
  final response = TextEditingController();

  @override
  void dispose() {
    response.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('رد الدعم'),
          content:
              TextField(controller: response, maxLength: 2000, maxLines: 4),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, response.text),
                child: const Text('إرسال'))
          ]);
}

class BookingSupportEvidenceDialog extends StatefulWidget {
  final String ticketId;
  const BookingSupportEvidenceDialog({super.key, required this.ticketId});

  @override
  State<BookingSupportEvidenceDialog> createState() =>
      _BookingSupportEvidenceDialogState();
}

class _BookingSupportEvidenceDialogState
    extends State<BookingSupportEvidenceDialog> {
  final noteCtrl = TextEditingController();
  XFile? _pickedFile;
  Uint8List? _fileBytes;
  String? _fileName;
  String? _fileType;
  int _fileSize = 0;
  bool _isUploading = false;
  String? _error;

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        setState(() {
          _error = 'حجم الملف يتجاوز الحد الأقصى (10 ميغابايت)';
          _pickedFile = null;
          _fileBytes = null;
        });
        return;
      }
      final name = picked.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.\s]'), '_');
      String mime = 'image/jpeg';
      final lowerName = name.toLowerCase();
      if (lowerName.endsWith('.png')) {
        mime = 'image/png';
      } else if (lowerName.endsWith('.webp')) {
        mime = 'image/webp';
      }

      setState(() {
        _pickedFile = picked;
        _fileBytes = bytes;
        _fileName = name;
        _fileSize = bytes.length;
        _fileType = mime;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'تعذر اختيار الملف: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) &&
          file.path != null &&
          file.path!.isNotEmpty) {
        try {
          final ioFile = io.File(file.path!);
          if (await ioFile.exists()) {
            bytes = await ioFile.readAsBytes();
          }
        } catch (_) {}
      }
      if (bytes == null || bytes.isEmpty) {
        setState(() => _error = 'تعذر قراءة محتوى ملف PDF');
        return;
      }
      if (bytes.length > 10 * 1024 * 1024) {
        setState(() {
          _error = 'حجم الملف يتجاوز الحد الأقصى (10 ميغابايت)';
          _pickedFile = null;
          _fileBytes = null;
        });
        return;
      }
      final name = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.\s]'), '_');
      if (!name.toLowerCase().endsWith('.pdf')) {
        setState(() => _error = 'يجب اختيار ملف PDF بصيغة صحيحة');
        return;
      }

      setState(() {
        _pickedFile = XFile.fromData(bytes!, name: name);
        _fileBytes = bytes;
        _fileName = name;
        _fileSize = bytes.length;
        _fileType = 'application/pdf';
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'تعذر اختيار ملف PDF: $e');
    }
  }

  Future<void> _uploadAndSubmit() async {
    if (_fileBytes == null || _fileName == null || _fileType == null) return;
    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('يجب تسجيل الدخول أولاً');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = '${timestamp}_$_fileName';
      final storagePath =
          'booking_dispute_evidence/${widget.ticketId}/${user.uid}/$safeName';

      final storageRef = FirebaseStorage.instance.ref(storagePath);
      await storageRef.putData(
          _fileBytes!, SettableMetadata(contentType: _fileType));

      if (!mounted) return;
      // Zero-Token Architecture:
      // We deliberately do NOT call getDownloadURL() to prevent public bearer token generation.
      // Access is strictly mediated via Firebase Storage SDK using authenticated session.
      Navigator.pop(context, {
        'fileName': _fileName,
        'fileUrl': '',
        'storagePath': storagePath,
        'fileType': _fileType,
        'fileSize': _fileSize,
        'note': noteCtrl.text.trim(),
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _error = 'فشل الرفع: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('إرفاق دليل حقيقي للنزاع'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Text(
                    _error!,
                    style:
                        const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_pickedFile == null) ...[
                const Text(
                    'اختر ملف الدليل من جهازك (صور JPEG/PNG/WEBP أو مستندات PDF حتى 10 ميغابايت):',
                    style: TextStyle(fontSize: 13, fontFamily: 'Cairo')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('المعرض'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('الكاميرا'),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF'),
                        onPressed: _pickDocument,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.insert_drive_file,
                              color: Color(0xFF3B82F6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fileName ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: _isUploading
                                ? null
                                : () => setState(() {
                                      _pickedFile = null;
                                      _fileBytes = null;
                                    }),
                          ),
                        ],
                      ),
                      Text(
                        'الحجم: ${(_fileSize / 1024).toStringAsFixed(1)} كيلوبايت | النوع: $_fileType',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة توضيحية حول الدليل (اختياري)',
                  ),
                ),
              ],
              if (_isUploading) ...[
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('جارٍ رفع الملف والتحقق من التخزين...',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          if (_pickedFile != null)
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadAndSubmit,
              child: const Text('رفع وإرفاق الدليل'),
            ),
        ],
      );
}

class BookingAvailabilitySearchScreen extends StatefulWidget {
  const BookingAvailabilitySearchScreen({super.key});
  @override
  State<BookingAvailabilitySearchScreen> createState() =>
      _AvailabilitySearchState();
}

class _AvailabilitySearchState extends State<BookingAvailabilitySearchScreen> {
  DateTime? start, end;
  bool busy = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> results = [];
  bool searched = false;
  Future<DateTime?> pick() async {
    final date = await showDatePicker(
        context: context,
        firstDate: bookingBaghdadDate(),
        lastDate: bookingBaghdadDate().add(const Duration(days: 365)),
        initialDate: bookingBaghdadDate().add(const Duration(days: 1)));
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null) return null;
    // Date/time controls represent Baghdad, independent of the phone timezone.
    return DateTime.utc(
        date.year, date.month, date.day, time.hour - 3, time.minute);
  }

  String label(DateTime? value) => value == null
      ? 'لم يحدد'
      : value.add(const Duration(hours: 3)).toString().replaceAll('Z', '');
  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('البحث عن موعد متاح')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        BookingSection(
            title: 'متى تخطط للزيارة؟',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BookingActionReason(
                      reason:
                          'اختر الدخول والخروج بتوقيت بغداد. يؤكد الخادم التوافر مجددًا عند إنشاء الحجز.'),
                  OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final value = await pick();
                              if (value != null && mounted)
                                setState(() {
                                  start = value;
                                  results = [];
                                  searched = false;
                                });
                            },
                      child: Text('الدخول: ${label(start)}')),
                  OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final value = await pick();
                              if (value != null && mounted)
                                setState(() {
                                  end = value;
                                  results = [];
                                  searched = false;
                                });
                            },
                      child: Text('الخروج: ${label(end)}')),
                ])),
        FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (start == null ||
                        end == null ||
                        !start!.isAfter(DateTime.now()) ||
                        !end!.isAfter(start!) ||
                        end!.difference(start!).inDays > 31) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'حدد موعدًا مستقبليًا وخروجًا بعد الدخول خلال 31 يومًا')));
                      return;
                    }
                    if (busy) return;
                    setState(() {
                      busy = true;
                      results = [];
                      searched = false;
                    });
                    await bookingRun(context, () async {
                      final venues = await publicBookingVenuesQuery()
                          .get(const GetOptions(source: Source.server));
                      final eligibleDocs = venues.docs
                          .where(
                              (d) => isPubliclyEligibleBookingVenue(d.data()))
                          .toList();
                      final free = <String>{};
                      for (var offset = 0;
                          offset < eligibleDocs.length;
                          offset += 50) {
                        final ids = eligibleDocs
                            .skip(offset)
                            .take(50)
                            .map((d) => d.id)
                            .toList();
                        final response =
                            await bookingCall('findAvailableBookingVenues', {
                          'venueIds': ids,
                          'start': start!.millisecondsSinceEpoch,
                          'end': end!.millisecondsSinceEpoch
                        });
                        free.addAll(List<String>.from(response['venueIds']));
                      }
                      if (mounted)
                        setState(() {
                          results = venues.docs
                              .where((d) => free.contains(d.id))
                              .toList();
                          searched = true;
                        });
                    });
                    if (mounted) setState(() => busy = false);
                  },
            child: Text(busy ? 'جاري فحص التوافر...' : 'ابحث عن أماكن متاحة')),
        if (searched && results.isEmpty)
          const Text('لا يوجد مكان متاح خلال الفترة المحددة'),
        for (final d in results)
          BookingVenueCard(
              venue: d.data(),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BookingRequestScreen(
                          venueId: d.id, venue: d.data()))))
      ]));
}
