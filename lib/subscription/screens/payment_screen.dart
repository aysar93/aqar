import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../../services/cloudinary_service.dart';
import '../models/subscription_package_model.dart';
import '../../office/models/office_subscription_model.dart';
import '../../office/services/office_subscription_service.dart';

class PaymentScreen extends StatefulWidget {
  final String officeId;
  final String ownerUid;
  final SubscriptionPackageModel package;
  final OfficeSubscriptionModel? currentSubscription;

  const PaymentScreen({
    super.key,
    required this.officeId,
    required this.ownerUid,
    required this.package,
    this.currentSubscription,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final OfficeSubscriptionService _service = OfficeSubscriptionService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _transactionController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();

  String _paymentMethod = 'qicard';

  File? _receiptFile;

  bool _processing = false;
  bool _uploadingReceipt = false;

  static const String _qiCardName = 'AYSAR ABDULKAREEM SALEH';

  static const String _qiCardNumber = '7066135323';

  @override
  void dispose() {
    _transactionController.dispose();
    _notesController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  bool get _requiresReceipt {
    return _paymentMethod == 'qicard';
  }

  Future<void> _pickReceipt({
    required ImageSource source,
  }) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked == null) {
        return;
      }

      setState(() {
        _receiptFile = File(picked.path);
      });
    } catch (e) {
      _showMessage(
        'تعذر اختيار صورة الإيصال',
        isError: true,
      );
    }
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                ),
                title: const Text(
                  'التقاط صورة بالكاميرا',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickReceipt(
                    source: ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                ),
                title: const Text(
                  'اختيار من المعرض',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickReceipt(
                    source: ImageSource.gallery,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyQiCardNumber() async {
    await Clipboard.setData(
      const ClipboardData(
        text: _qiCardNumber,
      ),
    );

    if (!mounted) {
      return;
    }

    _showMessage(
      'تم نسخ رقم الحساب',
    );
  }

  Future<void> _submitPayment() async {
    if (_processing) {
      return;
    }

    if (_requiresReceipt && _receiptFile == null) {
      _showMessage(
        'يرجى رفع صورة إيصال التحويل أولًا',
        isError: true,
      );
      return;
    }

    if (_paymentMethod == 'qicard' &&
        _transactionController.text.trim().isEmpty) {
      _showMessage(
        'يرجى إدخال رقم العملية إن وجد',
        isError: true,
      );
      return;
    }

    if (_paymentMethod == 'manual' &&
        _contactPhoneController.text.trim().isEmpty) {
      _showMessage(
        'يرجى إدخال رقم الهاتف للتواصل معك',
        isError: true,
      );
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      String? receiptUrl;

      if (_receiptFile != null) {
        setState(() {
          _uploadingReceipt = true;
        });

        receiptUrl = await uploadToCloudinary(
          _receiptFile!,
        );

        setState(() {
          _uploadingReceipt = false;
        });

        if (receiptUrl == null || receiptUrl.trim().isEmpty) {
          throw Exception(
            'تعذر رفع صورة الإيصال',
          );
        }
      }

      final subscriptionId = await _service.createSubscriptionRequest(
        officeId: widget.officeId,
        ownerId: widget.ownerUid,
        packageId: widget.package.id,
        packageName: widget.package.name,
        durationDays: widget.package.durationDays,
        price: widget.package.price,
        currency: widget.package.currency,
        maxProperties: widget.package.maxProperties ?? 0,
        maxFeaturedProperties: widget.package.maxFeaturedProperties ?? 0,
        canFeatureProperties: widget.package.featuredPropertiesEnabled,
        canAppearInFeaturedOffices: widget.package.featuredOfficeEnabled,
        canUseAdvancedStatistics: widget.package.statisticsEnabled,
      );

      final paymentId = await _service.createPaymentRequest(
        officeId: widget.officeId,
        ownerUid: widget.ownerUid,
        subscriptionId: subscriptionId,
        package: widget.package,
        paymentMethod: _paymentMethod,
        transactionId: _transactionController.text.trim().isEmpty
            ? null
            : _transactionController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        receiptUrl: receiptUrl,
        contactPhone: _paymentMethod == 'manual'
            ? _contactPhoneController.text.trim()
            : null,
      );

      if (!mounted) {
        return;
      }

      await _showSuccessDialog(
        paymentId,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'تعذر إرسال طلب الدفع. حاول مرة أخرى',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _uploadingReceipt = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog(
    String paymentId,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            size: 58,
          ),
          title: const Text(
            'تم إرسال طلب الدفع',
          ),
          content: Text(
            'تم استلام طلبك بنجاح.\n\n'
            'رقم الطلب:\n$paymentId\n\n'
            'سيتم مراجعة عملية الدفع من الإدارة، '
            'وبعد اعتمادها سيتم تفعيل الاشتراك',
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                child: const Text(
                  'تم',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الدفع والاشتراك',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),
          children: [
            _buildPackageCard(),
            const SizedBox(height: 16),
            _buildPaymentMethods(),
            const SizedBox(height: 16),
            _buildPaymentInstructions(),
            const SizedBox(height: 16),
            if (_paymentMethod == 'qicard') ...[
              _buildTransactionField(),
              const SizedBox(height: 16),
              _buildReceiptSection(),
              const SizedBox(height: 16),
            ],
            _buildNotesField(),
            const SizedBox(height: 22),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الباقة المختارة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.package.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.package.price.toStringAsFixed(0)} '
                        '${widget.package.currency} • '
                        '${widget.package.durationDays} يوم',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'طريقة الدفع',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            RadioListTile<String>(
              value: 'qicard',
              groupValue: _paymentMethod,
              onChanged: _processing
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _paymentMethod = value;
                      });
                    },
              title: const Text(
                'QiCard / خدمات كي',
              ),
              subtitle: const Text(
                'تحويل إلى الحساب ثم رفع صورة الإيصال',
              ),
              secondary: const Icon(
                Icons.account_balance_wallet_outlined,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            RadioListTile<String>(
              value: 'zaincash',
              groupValue: _paymentMethod,
              onChanged: null,
              title: const Text(
                'ZainCash',
              ),
              subtitle: const Text(
                'قريبًا',
              ),
              secondary: const Icon(
                Icons.phone_android_outlined,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            RadioListTile<String>(
              value: 'manual',
              groupValue: _paymentMethod,
              onChanged: _processing
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _paymentMethod = value;
                      });
                    },
              title: const Text(
                'تسليم يدوي',
              ),
              subtitle: const Text(
                'التواصل مع الإدارة لإتمام الدفع يدويًا',
              ),
              secondary: const Icon(
                Icons.handshake_outlined,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInstructions() {
    if (_paymentMethod == 'manual') {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'التسليم اليدوي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'اختر هذا الخيار إذا كنت تريد إتمام الدفع '
                'بالتسليم اليدوي. سيتم إرسال طلبك إلى الإدارة '
                'لمتابعة عملية الدفع وتأكيدها',
              ),
              const SizedBox(height: 16),
              _buildManualPhoneField(),
            ],
          ),
        ),
      );
    }

    if (_paymentMethod == 'zaincash') {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                ),
                SizedBox(width: 10),
                Text(
                  'بيانات التحويل',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCopyRow(
              title: 'اسم صاحب الحساب',
              value: _qiCardName,
              copyValue: _qiCardName,
            ),
            const SizedBox(height: 12),
            _buildCopyRow(
              title: 'رقم الحساب / التحويل',
              value: _qiCardNumber,
              copyValue: _qiCardNumber,
              isNumber: true,
            ),
            const SizedBox(height: 14),
            const Text(
              'حوّل مبلغ الاشتراك إلى الحساب أعلاه '
              'عن طريق تطبيق خدمات كي، ثم احتفظ بصورة الإيصال '
              'وارفعها أدناه',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyRow({
    required String title,
    required String value,
    required String copyValue,
    bool isNumber = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  textDirection: isNumber ? TextDirection.ltr : null,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'نسخ',
            onPressed: _copyQiCardNumber,
            icon: const Icon(
              Icons.copy_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualPhoneField() {
    return TextField(
      controller: _contactPhoneController,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
      ],
      decoration: InputDecoration(
        labelText: 'رقم الهاتف للتواصل',
        hintText: 'مثال: 07xxxxxxxxx',
        prefixIcon: const Icon(Icons.phone_outlined),
        helperText: 'سيظهر هذا الرقم للإدارة عند مراجعة طلب الدفع ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildTransactionField() {
    return TextField(
      controller: _transactionController,
      keyboardType: TextInputType.text,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: 'رقم العملية / المرجع',
        hintText: 'أدخل رقم العملية إن وجد',
        prefixIcon: const Icon(
          Icons.receipt_long_outlined,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildReceiptSection() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إيصال التحويل',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ارفع صورة واضحة لإيصال الدفع حتى تتمكن الإدارة من مراجعته',
            ),
            const SizedBox(height: 14),
            if (_receiptFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  _receiptFile!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            if (_receiptFile != null) const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _processing ? null : _showImageSourceSheet,
                icon: Icon(
                  _receiptFile == null
                      ? Icons.upload_file_rounded
                      : Icons.change_circle_outlined,
                ),
                label: Text(
                  _receiptFile == null
                      ? 'رفع صورة الإيصال'
                      : 'تغيير صورة الإيصال',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'ملاحظات',
        hintText: 'ملاحظات إضافية للإدارة (اختياري)',
        prefixIcon: const Padding(
          padding: EdgeInsets.only(
            bottom: 42,
          ),
          child: Icon(
            Icons.notes_outlined,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isManual = _paymentMethod == 'manual';

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: _processing ? null : _submitPayment,
        icon: _processing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.send_rounded,
              ),
        label: Text(
          _uploadingReceipt
              ? 'جاري رفع الإيصال...'
              : isManual
                  ? 'إرسال طلب التسليم اليدوي'
                  : 'إرسال طلب الدفع',
        ),
      ),
    );
  }
}
