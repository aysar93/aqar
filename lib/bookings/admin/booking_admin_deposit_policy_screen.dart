import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'booking_admin_theme.dart';

class BookingAdminDepositPolicyScreen extends StatefulWidget {
  const BookingAdminDepositPolicyScreen({super.key});

  @override
  State<BookingAdminDepositPolicyScreen> createState() => _BookingAdminDepositPolicyScreenState();
}

class _BookingAdminDepositPolicyScreenState extends State<BookingAdminDepositPolicyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chaletCtrl = TextEditingController();
  final _farmCtrl = TextEditingController();
  final _hallCtrl = TextEditingController();
  final _numberFormat = NumberFormat('#,###');

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _successMessage;
  Map<String, dynamic> _initialData = {};
  List<Map<String, dynamic>> _auditHistory = [];

  static const int minDeposit = 10000;
  static const int maxDeposit = 10000000;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  @override
  void dispose() {
    _chaletCtrl.dispose();
    _farmCtrl.dispose();
    _hallCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPolicy() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await FirebaseFirestore.instance.doc('settings/booking_categories').get();
      if (doc.exists && doc.data() != null) {
        _initialData = doc.data()!;
        final chaletVal = _extractDeposit(_initialData['chalet']);
        final farmVal = _extractDeposit(_initialData['farm']);
        final hallVal = _extractDeposit(_initialData['hall']);

        _chaletCtrl.text = (chaletVal ?? 50000).toString();
        _farmCtrl.text = (farmVal ?? 50000).toString();
        _hallCtrl.text = (hallVal ?? 100000).toString();

        if (_initialData['history'] is List) {
          _auditHistory = (_initialData['history'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
              .reversed
              .toList();
        }
      } else {
        _chaletCtrl.text = '50000';
        _farmCtrl.text = '50000';
        _hallCtrl.text = '100000';
      }
    } catch (e) {
      _error = 'تعذر تحميل سياسة العربون: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _extractDeposit(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    if (val is Map) {
      final dep = val['deposit'];
      if (dep is num) return dep.toInt();
      if (dep is String) return int.tryParse(dep);
    }
    return null;
  }

  String? _validateDeposit(String? value, String categoryName) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال مبلغ عربون $categoryName';
    }
    final clean = value.replaceAll(',', '').trim();
    final parsed = int.tryParse(clean);
    if (parsed == null) {
      return 'المبلغ يجب أن يكون رقماً صحيحاً';
    }
    if (parsed < minDeposit) {
      return 'الحد الأدنى للعربون هو ${_numberFormat.format(minDeposit)} د.ع';
    }
    if (parsed > maxDeposit) {
      return 'الحد الأقصى للعربون هو ${_numberFormat.format(maxDeposit)} د.ع';
    }
    return null;
  }

  Future<void> _savePolicy() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'يجب تسجيل الدخول كمسؤول لحفظ الإعدادات');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final chaletDep = int.parse(_chaletCtrl.text.replaceAll(',', '').trim());
      final farmDep = int.parse(_farmCtrl.text.replaceAll(',', '').trim());
      final hallDep = int.parse(_hallCtrl.text.replaceAll(',', '').trim());

      final beforeSnapshot = {
        'chalet': _extractDeposit(_initialData['chalet']) ?? 50000,
        'farm': _extractDeposit(_initialData['farm']) ?? 50000,
        'hall': _extractDeposit(_initialData['hall']) ?? 100000,
      };

      final afterSnapshot = {
        'chalet': chaletDep,
        'farm': farmDep,
        'hall': hallDep,
      };

      final auditEntry = {
        'action': 'update_deposit_policy',
        'actorUid': uid,
        'timestamp': DateTime.now().toIso8601String(),
        'before': beforeSnapshot,
        'after': afterSnapshot,
      };

      final updatedDoc = {
        'chalet': {'name': 'شاليه', 'deposit': chaletDep},
        'farm': {'name': 'مزرعة', 'deposit': farmDep},
        'hall': {'name': 'قاعة', 'deposit': hallDep},
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
        'history': FieldValue.arrayUnion([auditEntry]),
      };

      await FirebaseFirestore.instance.doc('settings/booking_categories').set(
            updatedDoc,
            SetOptions(merge: true),
          );

      _initialData = {
        ..._initialData,
        'chalet': {'name': 'شاليه', 'deposit': chaletDep},
        'farm': {'name': 'مزرعة', 'deposit': farmDep},
        'hall': {'name': 'قاعة', 'deposit': hallDep},
      };

      setState(() {
        _successMessage = 'تم حفظ وتطبيق سياسة العربون المركزية بنجاح.';
        _auditHistory.insert(0, auditEntry);
      });
    } catch (e) {
      setState(() => _error = 'فشل حفظ سياسة العربون: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BookingAdminTheme.bg(context),
      appBar: AppBar(
        title: const Text('سياسة العربون المركزية للفئات'),
        backgroundColor: BookingAdminTheme.header(context),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loading || _saving ? null : _loadPolicy,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: BookingAdminTheme.gold))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildNoticeCard(),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    _buildErrorBanner(_error!),
                    const SizedBox(height: 16),
                  ],
                  if (_successMessage != null) ...[
                    _buildSuccessBanner(_successMessage!),
                    const SizedBox(height: 16),
                  ],
                  _buildCategoryInputCard(
                    title: 'شاليهات (Chalet)',
                    category: 'chalet',
                    icon: Icons.pool_outlined,
                    controller: _chaletCtrl,
                    subtitle: 'العربون الافتراضي للشاليهات السكنية والترفيهية',
                  ),
                  const SizedBox(height: 14),
                  _buildCategoryInputCard(
                    title: 'مزارع وبساتين (Farm)',
                    category: 'farm',
                    icon: Icons.nature_people_outlined,
                    controller: _farmCtrl,
                    subtitle: 'العربون الافتراضي للمزارع والاستراحات الريفية',
                  ),
                  const SizedBox(height: 14),
                  _buildCategoryInputCard(
                    title: 'قاعات ومناسبات (Hall)',
                    category: 'hall',
                    icon: Icons.celebration_outlined,
                    controller: _hallCtrl,
                    subtitle: 'العربون الافتراضي لقاعات الأعراس والفعاليات',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _savePolicy,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        _saving ? 'جاري حفظ التغييرات...' : 'حفظ وتثبيت سياسة العربون',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BookingAdminTheme.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildAuditHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'تحدد هذه الإعدادات مبالغ العربون الافتراضية لكل فئة (شاليه، مزرعة، قاعة). يُطبق العربون الافتراضي على الأماكن التي لم يقم مالكها بتحديد عربون خاص. لا يتم التعديل على الحجوزات القائمة أو الأماكن التي تم حجزها مسبقاً حفاظاً على سلامة السجلات المالية.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF1E40AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryInputCard({
    required String title,
    required String category,
    required IconData icon,
    required TextEditingController controller,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BookingAdminTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BookingAdminTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BookingAdminTheme.goldSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: BookingAdminTheme.gold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: BookingAdminTheme.textMute(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            validator: (v) => _validateDeposit(v, title),
            decoration: InputDecoration(
              labelText: 'مبلغ العربون المطلوب',
              suffixText: 'د.ع',
              prefixIcon: const Icon(Icons.payments_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditHistorySection() {
    if (_auditHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.history_rounded, size: 20, color: Color(0xFF64748B)),
            SizedBox(width: 8),
            Text(
              'سجل تغييرات سياسة العربون',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _auditHistory.length > 5 ? 5 : _auditHistory.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = _auditHistory[index];
            final after = entry['after'] as Map<String, dynamic>? ?? {};
            final dateStr = entry['timestamp']?.toString() ?? '';
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تحديث بواسطة: ${(entry['actorUid'] ?? '').toString().substring(0, 8)}...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        dateStr.length >= 16 ? dateStr.substring(0, 16) : dateStr,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'شاليه: ${_numberFormat.format(after['chalet'] ?? 0)} د.ع | مزرعة: ${_numberFormat.format(after['farm'] ?? 0)} د.ع | قاعة: ${_numberFormat.format(after['hall'] ?? 0)} د.ع',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFF166534), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
