import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OfficeDetailsAdminScreen extends StatefulWidget {
  final String officeId;

  const OfficeDetailsAdminScreen({
    super.key,
    required this.officeId,
  });

  @override
  State<OfficeDetailsAdminScreen> createState() =>
      _OfficeDetailsAdminScreenState();
}

class _OfficeDetailsAdminScreenState extends State<OfficeDetailsAdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isUpdating = false;

  DocumentReference<Map<String, dynamic>> get _officeRef =>
      _firestore.collection('offices').doc(widget.officeId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تفاصيل المكتب',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _officeRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError(
              context,
              'حدث خطأ أثناء تحميل بيانات المكتب',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildNotFound(context);
          }

          final data = snapshot.data!.data() ?? {};

          return _buildContent(
            context,
            data,
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final officeName = _readString(
      data['name'] ?? data['officeName'],
      fallback: 'مكتب عقاري',
    );

    final ownerName = _readString(
      data['ownerName'],
      fallback: 'غير محدد',
    );

    final email = _readString(
      data['email'],
      fallback: 'غير متوفر',
    );

    final phone = _readString(
      data['phone'],
      fallback: 'غير متوفر',
    );

    final city = _readString(
      data['city'],
      fallback: 'غير محددة',
    );

    final address = _readString(
      data['address'],
      fallback: 'غير متوفر',
    );

    final description = _readString(
      data['description'],
      fallback: 'لا يوجد وصف للمكتب',
    );

    final imageUrl = _readString(
      data['imageUrl'],
    );

    final status = _getStatus(data);

    final subscriptionStatus = _getSubscriptionStatus(data);

    final isVerified = data['isVerified'] == true;

    final propertyCount = _readInt(data['propertyCount']);

    final followerCount = _readInt(data['followerCount']);

    final createdAt = _readDate(data['createdAt']);

    final updatedAt = _readDate(data['updatedAt']);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32,
        ),
        children: [
          _buildOfficeHeader(
            context,
            officeName: officeName,
            imageUrl: imageUrl,
            isVerified: isVerified,
            status: status,
          ),
          const SizedBox(height: 16),
          _buildActionButtons(
            context,
            data,
            status,
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: 'معلومات المكتب',
            icon: Icons.business_rounded,
            child: Column(
              children: [
                _buildInfoRow(
                  context,
                  icon: Icons.business_outlined,
                  label: 'اسم المكتب',
                  value: officeName,
                ),
                _buildInfoRow(
                  context,
                  icon: Icons.person_outline_rounded,
                  label: 'المالك',
                  value: ownerName,
                ),
                _buildInfoRow(
                  context,
                  icon: Icons.location_city_outlined,
                  label: 'المدينة',
                  value: city,
                ),
                _buildInfoRow(
                  context,
                  icon: Icons.location_on_outlined,
                  label: 'العنوان',
                  value: address,
                ),
                _buildInfoRow(
                  context,
                  icon: Icons.email_outlined,
                  label: 'البريد',
                  value: email,
                ),
                _buildInfoRow(
                  context,
                  icon: Icons.phone_outlined,
                  label: 'الهاتف',
                  value: phone,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSection(
            context,
            title: 'إحصائيات المكتب',
            icon: Icons.analytics_outlined,
            child: Row(
              children: [
                Expanded(
                  child: _buildStat(
                    context,
                    icon: Icons.home_work_outlined,
                    title: 'العقارات',
                    value: propertyCount.toString(),
                  ),
                ),
                Expanded(
                  child: _buildStat(
                    context,
                    icon: Icons.people_outline_rounded,
                    title: 'المتابعون',
                    value: followerCount.toString(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSection(
            context,
            title: 'حالة المكتب',
            icon: Icons.verified_outlined,
            child: Column(
              children: [
                _buildStatusRow(
                  context,
                  label: 'حالة المكتب',
                  value: _statusLabel(status),
                  color: _statusColor(
                    context,
                    status,
                  ),
                ),
                _buildStatusRow(
                  context,
                  label: 'الاشتراك',
                  value: _subscriptionLabel(
                    subscriptionStatus,
                  ),
                  color: _subscriptionColor(
                    context,
                    subscriptionStatus,
                  ),
                ),
                _buildStatusRow(
                  context,
                  label: 'التوثيق',
                  value: isVerified ? 'موثق' : 'غير موثق',
                  color: isVerified ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSection(
            context,
            title: 'الوصف',
            icon: Icons.description_outlined,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                description,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  height: 1.7,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildSection(
            context,
            title: 'تواريخ النظام',
            icon: Icons.history_rounded,
            child: Column(
              children: [
                if (createdAt != null)
                  _buildInfoRow(
                    context,
                    icon: Icons.calendar_today_outlined,
                    label: 'تاريخ الإنشاء',
                    value: _formatDateTime(
                      createdAt,
                    ),
                  ),
                if (updatedAt != null)
                  _buildInfoRow(
                    context,
                    icon: Icons.update_rounded,
                    label: 'آخر تحديث',
                    value: _formatDateTime(
                      updatedAt,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Header
  // ═════════════════════════════════════════════

  Widget _buildOfficeHeader(
    BuildContext context, {
    required String officeName,
    required String imageUrl,
    required bool isVerified,
    required String status,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _buildAvatar(
            context,
            imageUrl,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  officeName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  color: Colors.blue,
                  size: 21,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _buildStatusBadge(
            context,
            status,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    String imageUrl,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (imageUrl.isEmpty) {
      return Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Icon(
          Icons.business_rounded,
          size: 45,
          color: colorScheme.onPrimaryContainer,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Image.network(
        imageUrl,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return Container(
            width: 96,
            height: 96,
            color: colorScheme.primaryContainer,
            child: Icon(
              Icons.business_rounded,
              size: 45,
              color: colorScheme.onPrimaryContainer,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    String status,
  ) {
    final color = _statusColor(
      context,
      status,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(status),
            size: 17,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Actions
  // ═════════════════════════════════════════════

  Widget _buildActionButtons(
    BuildContext context,
    Map<String, dynamic> data,
    String status,
  ) {
    final active = _isActive(data);

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _isUpdating
                ? null
                : () {
                    _toggleOfficeStatus(
                      context,
                      active,
                    );
                  },
            icon: Icon(
              active
                  ? Icons.power_settings_new_rounded
                  : Icons.check_circle_outline_rounded,
            ),
            label: Text(
              active ? 'تعطيل المكتب' : 'تفعيل المكتب',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isUpdating
                ? null
                : () {
                    _toggleVerification(
                      context,
                      data,
                    );
                  },
            icon: Icon(
              data['isVerified'] == true
                  ? Icons.verified_outlined
                  : Icons.verified_rounded,
            ),
            label: Text(
              data['isVerified'] == true ? 'إلغاء التوثيق' : 'توثيق المكتب',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleOfficeStatus(
    BuildContext context,
    bool currentlyActive,
  ) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final newStatus = currentlyActive ? 'disabled' : 'active';

      await _officeRef.update({
        'status': newStatus,
        'isActive': newStatus == 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage(
        context,
        currentlyActive ? 'تم تعطيل المكتب.' : 'تم تفعيل المكتب',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        context,
        'تعذر تحديث حالة المكتب',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _toggleVerification(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final current = data['isVerified'] == true;

    setState(() {
      _isUpdating = true;
    });

    try {
      await _officeRef.update({
        'isVerified': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage(
        context,
        current ? 'تم إلغاء توثيق المكتب.' : 'تم توثيق المكتب',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        context,
        'تعذر تحديث حالة التوثيق',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  // ═════════════════════════════════════════════
  // Sections
  // ═════════════════════════════════════════════

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(
          icon,
          color: colorScheme.primary,
          size: 27,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 11,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Firestore
  // ═════════════════════════════════════════════

  Future<void> _refresh() async {
    await _officeRef.get(
      const GetOptions(
        source: Source.server,
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Status
  // ═════════════════════════════════════════════

  String _getStatus(
    Map<String, dynamic> data,
  ) {
    final status = _readString(
      data['status'],
    ).toLowerCase();

    if (status.isNotEmpty) {
      return status;
    }

    if (data['isActive'] == true) {
      return 'active';
    }

    return 'disabled';
  }

  bool _isActive(
    Map<String, dynamic> data,
  ) {
    return _getStatus(data) == 'active' && data['isActive'] != false;
  }

  String _getSubscriptionStatus(
    Map<String, dynamic> data,
  ) {
    final status = _readString(
      data['subscriptionStatus'],
    ).toLowerCase();

    if (status.isNotEmpty) {
      return status;
    }

    final endDate = _readDate(
      data['subscriptionEndDate'],
    );

    if (endDate != null &&
        endDate.isBefore(
          DateTime.now(),
        )) {
      return 'expired';
    }

    return 'none';
  }

  String _statusLabel(
    String status,
  ) {
    switch (status) {
      case 'active':
        return 'المكتب نشط';

      case 'pending':
        return 'بانتظار الموافقة';

      case 'disabled':
        return 'المكتب معطل';

      case 'suspended':
        return 'موقوف';

      default:
        return 'غير محدد';
    }
  }

  IconData _statusIcon(
    String status,
  ) {
    switch (status) {
      case 'active':
        return Icons.check_circle_rounded;

      case 'pending':
        return Icons.pending_rounded;

      case 'disabled':
        return Icons.block_rounded;

      case 'suspended':
        return Icons.pause_circle_rounded;

      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _statusColor(
    BuildContext context,
    String status,
  ) {
    switch (status) {
      case 'active':
        return Colors.green;

      case 'pending':
        return Colors.orange;

      case 'disabled':
      case 'suspended':
        return Theme.of(context).colorScheme.error;

      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _subscriptionLabel(
    String status,
  ) {
    switch (status) {
      case 'active':
        return 'اشتراك نشط';

      case 'expired':
        return 'منتهي';

      case 'pending':
        return 'قيد المعالجة';

      case 'cancelled':
        return 'ملغى';

      default:
        return 'بدون اشتراك';
    }
  }

  Color _subscriptionColor(
    BuildContext context,
    String status,
  ) {
    switch (status) {
      case 'active':
        return Colors.green;

      case 'expired':
        return Colors.red;

      case 'pending':
        return Colors.orange;

      case 'cancelled':
        return Colors.grey;

      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  // ═════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════

  String _readString(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  int _readInt(
    dynamic value,
  ) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  DateTime? _readDate(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      );
    }

    return null;
  }

  String _formatDateTime(
    DateTime date,
  ) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour.toString().padLeft(2, '0');

    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.year}/$month/$day - $hour:$minute';
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 55,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound(
    BuildContext context,
  ) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'لم يتم العثور على بيانات المكتب',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
