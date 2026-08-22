import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_property_request_details_screen.dart';

class AdminPropertyRequestsScreen extends StatefulWidget {
  const AdminPropertyRequestsScreen({
    super.key,
  });

  @override
  State<AdminPropertyRequestsScreen> createState() =>
      _AdminPropertyRequestsScreenState();
}

class _AdminPropertyRequestsScreenState
    extends State<AdminPropertyRequestsScreen> {
  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);

  bool _loadingAdmin = true;
  bool _isAdmin = false;
  String _selectedStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  // ==================================================
  // التحقق من صلاحية الأدمن
  // ==================================================

  Future<void> _checkAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _loadingAdmin = false;
          });
        }

        return;
      }

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _isAdmin = document.data()?['isAdmin'] == true;
        _loadingAdmin = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAdmin = false;
        _loadingAdmin = false;
      });
    }
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
          elevation: 0,
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: Colors.white,
          title: const Text(
            'غير مصرح',
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'هذه الصفحة مخصصة للإدارة فقط',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: Colors.white,
          title: const Text(
            'طلبات العقارات',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            _buildStatusTabs(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('property_requests')
                    .where(
                      'status',
                      isEqualTo: _selectedStatus,
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _gold,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildMessage(
                      icon: Icons.error_outline_rounded,
                      title: 'تعذر تحميل الطلبات',
                      subtitle: 'حدث خطأ أثناء تحميل طلبات العقارات',
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    if (_selectedStatus == 'approved') {
                      return _buildMessage(
                        icon: Icons.public_off_rounded,
                        title: 'لا توجد طلبات منشورة',
                        subtitle: 'لا توجد طلبات عقارات منشورة حاليًا',
                      );
                    }

                    if (_selectedStatus == 'rejected') {
                      return _buildMessage(
                        icon: Icons.cancel_outlined,
                        title: 'لا توجد طلبات مرفوضة',
                        subtitle: 'لا توجد طلبات عقارات مرفوضة حاليًا',
                      );
                    }

                    return _buildMessage(
                      icon: Icons.task_alt_rounded,
                      title: 'لا توجد طلبات معلقة',
                      subtitle: 'لا توجد طلبات عقارات بانتظار المراجعة حاليًا',
                    );
                  }

                  final docs = snapshot.data!.docs.toList();

                  // ترتيب الأحدث أولاً بدون الحاجة إلى
                  // Firestore composite index.
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;

                    final bData = b.data() as Map<String, dynamic>;

                    final aTimestamp = aData['createdAt'] as Timestamp?;

                    final bTimestamp = bData['createdAt'] as Timestamp?;

                    if (aTimestamp == null && bTimestamp == null) {
                      return 0;
                    }

                    if (aTimestamp == null) {
                      return 1;
                    }

                    if (bTimestamp == null) {
                      return -1;
                    }

                    return bTimestamp.compareTo(
                      aTimestamp,
                    );
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      30,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];

                      final data = doc.data() as Map<String, dynamic>;

                      return _RequestCard(
                        requestId: doc.id,
                        data: data,
                        status: _selectedStatus,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminPropertyRequestDetailsScreen(
                                requestId: doc.id,
                                initialData: data,
                              ),
                            ),
                          );
                        },
                        onDelete: () {
                          _confirmDeleteRequest(
                            requestId: doc.id,
                            data: data,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: _statusTab(
              status: 'pending',
              label: 'قيد المراجعة',
              icon: Icons.hourglass_top_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statusTab(
              status: 'approved',
              label: 'المنشورة',
              icon: Icons.public_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statusTab(
              status: 'rejected',
              label: 'المرفوضة',
              icon: Icons.cancel_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusTab({
    required String status,
    required String label,
    required IconData icon,
  }) {
    final bool selected = _selectedStatus == status;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('property_requests')
          .where(
            'status',
            isEqualTo: status,
          )
          .snapshots(),
      builder: (context, snapshot) {
        final int count = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (selected) return;

            setState(() {
              _selectedStatus = status;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 180,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? _gold.withValues(alpha: 0.14)
                  : const Color(0xff1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    selected ? _gold.withValues(alpha: 0.55) : Colors.white10,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: selected ? _gold : Colors.white54,
                  size: 20,
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected ? _gold : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 22,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? _gold.withValues(
                                  alpha: 0.20,
                                )
                              : Colors.white.withValues(
                                  alpha: 0.07,
                                ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          count.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? _gold : Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteRequest({
    required String requestId,
    required Map<String, dynamic> data,
  }) async {
    final propertyType = (data['propertyType'] ?? 'العقار').toString().trim();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xff1E293B),
            title: const Text(
              'حذف الطلب',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'هل أنت متأكد من حذف طلب $propertyType نهائيًا؟\n\n'
              'لا يمكن التراجع عن الحذف',
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
                    color: Colors.white70,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text(
                  'حذف',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('property_requests')
          .doc(requestId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حذف الطلب بنجاح',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر حذف الطلب: $e',
          ),
        ),
      );
    }
  }
  // ==================================================
  // حالة فارغة / خطأ
  // ==================================================

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _gold.withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _gold.withValues(
                    alpha: 0.16,
                  ),
                ),
              ),
              child: Icon(
                icon,
                color: _gold,
                size: 43,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// بطاقة الطلب
// ==================================================

class _RequestCard extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> data;
  final String status;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RequestCard({
    required this.requestId,
    required this.data,
    required this.status,
    required this.onTap,
    required this.onDelete,
  });

  static const Color _gold = Color.fromARGB(255, 34, 32, 25);
  static const Color _card = Color(0xff1E293B);

  @override
  Widget build(BuildContext context) {
    final requestType = (data['requestType'] ?? '').toString().trim();

    final propertyType = (data['propertyType'] ?? '').toString().trim();

    final city = (data['city'] ?? '').toString().trim();

    final district = (data['district'] ?? '').toString().trim();

    final minPrice = _asDouble(
      data['minPrice'],
    );

    final maxPrice = _asDouble(
      data['maxPrice'],
    );

    final minArea = _asDouble(
      data['minArea'],
    );

    final maxArea = _asDouble(
      data['maxArea'],
    );

    final createdAt = data['createdAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(
          22,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            22,
          ),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                22,
              ),
              border: Border.all(
                color: _gold.withValues(
                  alpha: 0.14,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ======================================
                // النوع والحالة
                // ======================================

                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _gold.withValues(
                          alpha: 0.11,
                        ),
                        borderRadius: BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: Icon(
                        _propertyIcon(
                          propertyType,
                        ),
                        color: _gold,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _requestTitle(
                              requestType,
                              propertyType,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _locationText(
                              city,
                              district,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusBadge(
                      status: status,
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      tooltip: 'إدارة الطلب',
                      color: const Color(0xff1E293B),
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white60,
                      ),
                      onSelected: (value) {
                        if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) {
                        return const [
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'حذف الطلب',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const Divider(
                  height: 1,
                  color: Colors.white10,
                ),

                const SizedBox(height: 15),

                // ======================================
                // الميزانية
                // ======================================

                _InfoRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'الميزانية',
                  value: _rangeText(
                    minPrice,
                    maxPrice,
                    suffix: 'د.ع',
                  ),
                ),

                const SizedBox(height: 11),

                // ======================================
                // المساحة
                // ======================================

                _InfoRow(
                  icon: Icons.square_foot_rounded,
                  title: 'المساحة',
                  value: _rangeText(
                    minArea,
                    maxArea,
                    suffix: 'م²',
                  ),
                ),

                if (createdAt != null) ...[
                  const SizedBox(height: 11),
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    title: 'تاريخ الطلب',
                    value: _dateText(
                      createdAt.toDate(),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'معرّف الطلب: ${_shortId(requestId)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'عرض التفاصيل',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _gold,
                          size: 13,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================================================
  // الأدوات
  // ==================================================

  static double? _asDouble(dynamic value) {
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

  static String _locationText(
    String city,
    String district,
  ) {
    if (city.isNotEmpty && district.isNotEmpty) {
      return '$city • $district';
    }

    if (city.isNotEmpty) {
      return city;
    }

    if (district.isNotEmpty) {
      return district;
    }

    return 'الموقع غير محدد';
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
    final integerValue = value.round();

    final text = integerValue.toString();

    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(text[i]);
    }

    return buffer.toString();
  }

  static String _dateText(
    DateTime date,
  ) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '${date.year}/$month/$day';
  }

  static String _shortId(
    String id,
  ) {
    if (id.length <= 8) {
      return id;
    }

    return id.substring(0, 8);
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    switch (status) {
      case 'approved':
        label = 'منشور';
        color = const Color(0xff22C55E);
        break;

      case 'rejected':
        label = 'مرفوض';
        color = const Color(0xffEF4444);
        break;

      case 'pending':
      default:
        label = 'قيد المراجعة';
        color = const Color(0xffF59E0B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
// ==================================================
// سطر معلومات
// ==================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  static const Color _gold = Color(0xffD4AF37);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: _gold,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          '$title:',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
