import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminPropertyRequestDetailsScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> initialData;

  const AdminPropertyRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.initialData,
  });

  @override
  State<AdminPropertyRequestDetailsScreen> createState() =>
      _AdminPropertyRequestDetailsScreenState();
}

class _AdminPropertyRequestDetailsScreenState
    extends State<AdminPropertyRequestDetailsScreen> {
  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);
  static const Color _card = Color(0xff1E293B);

  bool _loadingAdmin = true;
  bool _isAdmin = false;
  bool _processing = false;

  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();

    _data = Map<String, dynamic>.from(
      widget.initialData,
    );

    _checkAdmin();
  }

  // ==================================================
  // التحقق من الأدمن
  // ==================================================

  Future<void> _checkAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isAdmin = false;
          _loadingAdmin = false;
        });

        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _isAdmin = userDoc.data()?['isAdmin'] == true;
        _loadingAdmin = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isAdmin = false;
        _loadingAdmin = false;
      });
    }
  }

  // ==================================================
  // موافقة / رفض
  // ==================================================

  Future<void> _changeStatus(
    String newStatus,
  ) async {
    if (_processing || !_isAdmin) {
      return;
    }

    final isApprove = newStatus == 'approved';

    final confirmed = await _showConfirmDialog(
      title: isApprove ? 'الموافقة على الطلب' : 'رفض الطلب',
      message: isApprove
          ? 'هل تريد الموافقة على هذا الطلب ونشره للمستخدمين؟'
          : 'هل تريد رفض هذا الطلب؟',
      confirmText: isApprove ? 'موافقة' : 'رفض',
      destructive: !isApprove,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      final requestRef = FirebaseFirestore.instance
          .collection('property_requests')
          .doc(widget.requestId);

      // نقرأ أحدث نسخة قبل التعديل حتى لا نعتمد فقط
      // على البيانات التي وصلت من الشاشة السابقة.
      final requestSnapshot = await requestRef.get();

      if (!requestSnapshot.exists) {
        throw Exception(
          'الطلب غير موجود أو تم حذفه',
        );
      }

      final latestData = requestSnapshot.data()!;

      final currentStatus = (latestData['status'] ?? '').toString();

      if (currentStatus != 'pending') {
        if (!mounted) return;

        setState(() {
          _data = Map<String, dynamic>.from(
            latestData,
          );
          _processing = false;
        });

        _showMessage(
          'تمت معالجة هذا الطلب مسبقًا',
        );

        return;
      }

      await requestRef.update({
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': currentUser?.uid ?? '',
      });

      // إرسال إشعار لصاحب الطلب.
      // فشل إنشاء الإشعار لا يلغي قرار الأدمن.
      await _sendStatusNotification(
        data: latestData,
        approved: isApprove,
      );

      if (!mounted) return;

      setState(() {
        _data = {
          ...latestData,
          'status': newStatus,
        };

        _processing = false;
      });

      _showMessage(
        isApprove ? 'تمت الموافقة على الطلب ونشره' : 'تم رفض الطلب',
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _processing = false;
      });

      _showMessage(
        'تعذر تحديث الطلب: $e',
      );
    }
  }

  // ==================================================
  // إشعار صاحب الطلب
  // ==================================================

  Future<void> _sendStatusNotification({
    required Map<String, dynamic> data,
    required bool approved,
  }) async {
    try {
      final userId = (data['userId'] ?? '').toString();

      if (userId.isEmpty) {
        return;
      }

      final propertyType = (data['propertyType'] ?? 'عقار').toString();

      final requestType = (data['requestType'] ?? '').toString();

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': approved ? 'تمت الموافقة على طلبك' : 'تم رفض طلبك',
        'body': approved
            ? 'تمت الموافقة على طلب $propertyType ${_requestTypeText(requestType)} ونشره.'
            : 'تم رفض طلب $propertyType ${_requestTypeText(requestType)}',
        'type': approved
            ? 'property_request_approved'
            : 'property_request_rejected',
        'requestId': widget.requestId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // لا نلغي الموافقة أو الرفض إذا تعذر
      // إنشاء الإشعار.
    }
  }

  // ==================================================
  // نافذة التأكيد
  // ==================================================

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool destructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            title,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: destructive ? const Color(0xffEF4444) : _gold,
                foregroundColor: destructive ? Colors.white : _background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                confirmText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==================================================
  // رسالة
  // ==================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ==================================================
  // الواجهة
  // ==================================================

  @override
  Widget build(BuildContext context) {
    if (_loadingAdmin) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(
          child: CircularProgressIndicator(
            color: _gold,
          ),
        ),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'غير مصرح',
          ),
        ),
        body: const Center(
          child: Text(
            'هذه الصفحة مخصصة للإدارة فقط',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    final status = (_data['status'] ?? 'pending').toString();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'تفاصيل الطلب',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildLocationSection(),
                      const SizedBox(height: 14),
                      _buildBudgetSection(),
                      const SizedBox(height: 14),
                      _buildRequirementsSection(),
                      const SizedBox(height: 14),
                      _buildContactSection(),
                      if (_text(
                        _data['description'],
                      ).isNotEmpty) ...[
                        const SizedBox(
                          height: 14,
                        ),
                        _buildDescriptionSection(),
                      ],
                      const SizedBox(height: 14),
                      _buildPublisherSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ======================================
              // أزرار الأدمن
              // ======================================

              if (status == 'pending') _buildAdminActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================================================
  // رأس الطلب
  // ==================================================

  Widget _buildHeader() {
    final propertyType = _text(_data['propertyType']);

    final requestType = _text(_data['requestType']);

    final createdAt = _data['createdAt'] as Timestamp?;

    return _SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _gold.withValues(
                    alpha: 0.11,
                  ),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: _gold.withValues(
                      alpha: 0.18,
                    ),
                  ),
                ),
                child: Icon(
                  _propertyIcon(
                    propertyType,
                  ),
                  color: _gold,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _requestTitle(
                        requestType,
                        propertyType,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'أرسل بتاريخ ${_dateTimeText(createdAt.toDate())}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                status: _text(
                  _data['status'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(
            height: 1,
            color: Colors.white10,
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              const Icon(
                Icons.tag_rounded,
                color: _gold,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'معرّف الطلب: ${widget.requestId}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================================================
  // الموقع
  // ==================================================

  Widget _buildLocationSection() {
    return _SectionCard(
      title: 'الموقع المطلوب',
      icon: Icons.location_on_rounded,
      child: Column(
        children: [
          _DetailRow(
            title: 'المدينة',
            value: _display(
              _data['city'],
            ),
          ),
          _DetailRow(
            title: 'المنطقة',
            value: _display(
              _data['district'],
            ),
          ),
          _DetailRow(
            title: 'أقرب نقطة دالة',
            value: _display(
              _data['landmark'],
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ==================================================
  // الميزانية والمساحة
  // ==================================================

  Widget _buildBudgetSection() {
    return _SectionCard(
      title: 'المساحة والميزانية',
      icon: Icons.account_balance_wallet_rounded,
      child: Column(
        children: [
          _DetailRow(
            title: 'المساحة',
            value: _rangeText(
              _asDouble(
                _data['minArea'],
              ),
              _asDouble(
                _data['maxArea'],
              ),
              suffix: 'م²',
            ),
          ),
          _DetailRow(
            title: 'الميزانية',
            value: _rangeText(
              _asDouble(
                _data['minPrice'],
              ),
              _asDouble(
                _data['maxPrice'],
              ),
              suffix: 'د.ع',
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ==================================================
  // المواصفات
  // ==================================================

  Widget _buildRequirementsSection() {
    final items = <MapEntry<String, String>>[];

    void addIfAvailable(
      String title,
      dynamic value,
    ) {
      if (value == null) {
        return;
      }

      final text = value.toString().trim();

      if (text.isEmpty || text == '0') {
        return;
      }

      items.add(
        MapEntry(
          title,
          text,
        ),
      );
    }

    addIfAvailable(
      'عدد الغرف',
      _data['rooms'],
    );

    addIfAvailable(
      'عدد الحمامات',
      _data['bathrooms'],
    );

    addIfAvailable(
      'عدد المجالس',
      _data['livingRooms'],
    );

    addIfAvailable(
      'مواقف السيارات',
      _data['parking'],
    );

    addIfAvailable(
      'أقل عدد طوابق',
      _data['minFloors'],
    );

    addIfAvailable(
      'أعلى عدد طوابق',
      _data['maxFloors'],
    );

    addIfAvailable(
      'الطابق المطلوب',
      _data['apartmentFloor'],
    );

    return _SectionCard(
      title: 'المواصفات المطلوبة',
      icon: Icons.tune_rounded,
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 8,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'لم يتم تحديد مواصفات إضافية',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          : Column(
              children: List.generate(
                items.length,
                (index) {
                  final item = items[index];

                  return _DetailRow(
                    title: item.key,
                    value: item.value,
                    showDivider: index != items.length - 1,
                  );
                },
              ),
            ),
    );
  }

  // ==================================================
  // التواصل
  // ==================================================

  Widget _buildContactSection() {
    return _SectionCard(
      title: 'معلومات التواصل',
      icon: Icons.phone_rounded,
      child: Column(
        children: [
          _DetailRow(
            title: 'رقم الهاتف',
            value: _display(
              _data['phone'],
            ),
          ),
          _DetailRow(
            title: 'واتساب',
            value: _display(
              _data['whatsapp'],
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ==================================================
  // الوصف
  // ==================================================

  Widget _buildDescriptionSection() {
    return _SectionCard(
      title: 'تفاصيل إضافية',
      icon: Icons.notes_rounded,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          _text(
            _data['description'],
          ),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.7,
          ),
        ),
      ),
    );
  }

  // ==================================================
  // بيانات صاحب الطلب
  // ==================================================

  Widget _buildPublisherSection() {
    return _SectionCard(
      title: 'صاحب الطلب',
      icon: Icons.person_rounded,
      child: Column(
        children: [
          _DetailRow(
            title: 'الاسم',
            value: _display(
              _data['publisherName'],
            ),
          ),
          _DetailRow(
            title: 'البريد',
            value: _display(
              _data['publisherEmail'],
            ),
          ),
          _DetailRow(
            title: 'UID',
            value: _display(
              _data['publisherUid'],
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ==================================================
  // أزرار الموافقة والرفض
  // ==================================================

  Widget _buildAdminActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16,
      ),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(
          top: BorderSide(
            color: Colors.white10,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _processing
                    ? null
                    : () {
                        _changeStatus(
                          'rejected',
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xffEF4444),
                  side: const BorderSide(
                    color: Color(0xffEF4444),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.close_rounded,
                ),
                label: const Text(
                  'رفض',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _processing
                    ? null
                    : () {
                        _changeStatus(
                          'approved',
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _background,
                  disabledBackgroundColor: _gold.withValues(
                    alpha: 0.45,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
                icon: _processing
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _background,
                        ),
                      )
                    : const Icon(
                        Icons.check_rounded,
                      ),
                label: Text(
                  _processing ? 'جارٍ التنفيذ...' : 'موافقة ونشر',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // الأدوات
  // ==================================================

  static String _text(
    dynamic value,
  ) {
    return value?.toString().trim() ?? '';
  }

  static String _display(
    dynamic value,
  ) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? 'غير محدد' : text;
  }

  static double? _asDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  static String _rangeText(
    double? min,
    double? max, {
    required String suffix,
  }) {
    if (min == null && max == null) {
      return 'غير محدد';
    }

    if (min != null && max != null) {
      if (min == max) {
        return '${_numberText(min)} $suffix';
      }

      return '${_numberText(min)} - ${_numberText(max)} $suffix';
    }

    if (min != null) {
      return 'من ${_numberText(min)} $suffix';
    }

    return 'حتى ${_numberText(max!)} $suffix';
  }

  static String _numberText(
    double value,
  ) {
    final text = value.round().toString();

    return text.replaceAllMapped(
      RegExp(
        r'(?=(\d{3})+(?!\d))',
      ),
      (_) => ',',
    );
  }

  static String _requestTitle(
    String requestType,
    String propertyType,
  ) {
    final type = propertyType.isEmpty ? 'عقار' : propertyType;

    if (requestType == 'شراء') {
      return 'مطلوب $type للشراء';
    }

    if (requestType == 'إيجار') {
      return 'مطلوب $type للإيجار';
    }

    return 'مطلوب $type';
  }

  static String _requestTypeText(
    String requestType,
  ) {
    if (requestType == 'شراء') {
      return 'للشراء';
    }

    if (requestType == 'إيجار') {
      return 'للإيجار';
    }

    return '';
  }

  static String _dateTimeText(
    DateTime date,
  ) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour.toString().padLeft(2, '0');

    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.year}/$month/$day - $hour:$minute';
  }

  static IconData _propertyIcon(
    String propertyType,
  ) {
    switch (propertyType) {
      case 'بيت':
        return Icons.home_rounded;

      case 'شقة':
        return Icons.apartment_rounded;

      case 'أرض':
        return Icons.landscape_rounded;

      case 'محل':
        return Icons.storefront_rounded;

      case 'عمارة':
        return Icons.location_city_rounded;

      case 'مزرعة':
        return Icons.agriculture_rounded;

      default:
        return Icons.real_estate_agent_rounded;
    }
  }
}

// ==================================================
// بطاقة قسم
// ==================================================

class _SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;

  const _SectionCard({
    this.title,
    this.icon,
    required this.child,
  });

  static const Color _gold = Color(0xffD4AF37);

  static const Color _card = Color(0xff1E293B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.055,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: _gold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
          ],
          child,
        ],
      ),
    );
  }
}

// ==================================================
// سطر بيانات
// ==================================================

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;
  final bool showDivider;

  const _DetailRow({
    required this.title,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            color: Colors.white10,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ==================================================
// حالة الطلب
// ==================================================

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color color;

    switch (status) {
      case 'approved':
        text = 'منشور';
        color = const Color(0xff22C55E);
        break;

      case 'rejected':
        text = 'مرفوض';
        color = const Color(0xffEF4444);
        break;

      default:
        text = 'قيد المراجعة';
        color = const Color(0xffF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.13,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
