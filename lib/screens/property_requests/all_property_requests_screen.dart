import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'property_request_details_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AllPropertyRequestsScreen extends StatefulWidget {
  const AllPropertyRequestsScreen({super.key});

  @override
  State<AllPropertyRequestsScreen> createState() =>
      _AllPropertyRequestsScreenState();
}

class _AllPropertyRequestsScreenState extends State<AllPropertyRequestsScreen> {
  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);
  static const Color _card = Color(0xff1E293B);

  String selectedType = 'الكل';
  final TextEditingController searchController = TextEditingController();

  String search = "";
  bool _isAdmin = false;

  final List<String> filters = const [
    'الكل',
    'شراء',
    'إيجار',
  ];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _isAdmin = false;
          });
        }
        return;
      }

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      setState(() {
        _isAdmin = document.data()?['isAdmin'] == true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isAdmin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.white,
          title: const Text(
            "مطلوب على عقارات الانبار",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: searchController,
                onChanged: (value) {
                  setState(() {
                    search = value.toLowerCase().trim();
                  });
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: "ابحث برقم الطلب، نوع العقار، المدينة أو المنطقة",
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xffD4AF37),
                  ),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            searchController.clear();
                            setState(() {
                              search = "";
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xff1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xffD4AF37),
                    ),
                  ),
                ),
              ),
            ),
            _filters(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('property_requests')
                    .where(
                      'status',
                      isEqualTo: 'approved',
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _gold,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _emptyState(
                      icon: Icons.error_outline_rounded,
                      title: "تعذر تحميل الطلبات",
                      subtitle: "حدث خطأ أثناء تحميل طلبات العقارات",
                    );
                  }

                  final docs = snapshot.data?.docs.toList() ?? [];

                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;

                    final bData = b.data() as Map<String, dynamic>;

                    final aTime = aData['createdAt'] as Timestamp?;

                    final bTime = bData['createdAt'] as Timestamp?;

                    if (aTime == null && bTime == null) {
                      return 0;
                    }

                    if (aTime == null) {
                      return 1;
                    }

                    if (bTime == null) {
                      return -1;
                    }

                    return bTime.compareTo(aTime);
                  });

                  final filtered = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final requestType = (data["requestType"] ?? "").toString();

                    final propertyType =
                        (data["propertyType"] ?? "").toString().toLowerCase();

                    final city = (data["city"] ?? "").toString().toLowerCase();

                    final district =
                        (data["district"] ?? "").toString().toLowerCase();

                    final matchesType =
                        selectedType == "الكل" || requestType == selectedType;

                    final matchesSearch = search.isEmpty ||
                        propertyType.contains(search) ||
                        city.contains(search) ||
                        district.contains(search);

                    return matchesType && matchesSearch;
                  }).toList();

                  if (docs.isEmpty) {
                    return _emptyState(
                      icon: Icons.manage_search_rounded,
                      title: "لا توجد طلبات منشورة حالياً",
                      subtitle:
                          "ستظهر هنا طلبات العقارات بعد موافقة الإدارة عليها",
                    );
                  }

                  if (filtered.isEmpty) {
                    return _emptyState(
                      icon: Icons.filter_alt_off_rounded,
                      title: "لا توجد طلبات ضمن هذا القسم",
                      subtitle: "جرّب اختيار نوع طلب آخر",
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      30,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];

                      final data = doc.data() as Map<String, dynamic>;

                      return _requestCard(
                        requestId: doc.id,
                        data: data,
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

  Widget _filters() {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filters[index];
          final selected = selectedType == item;

          return InkWell(
            onTap: () {
              setState(() {
                selectedType = item;
              });
            },
            borderRadius: BorderRadius.circular(30),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected ? _gold : _card,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? _gold : Colors.white10,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                item,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _requestCard({
    required String requestId,
    required Map<String, dynamic> data,
  }) {
    final requestType = _text(data['requestType']);

    final propertyType = _text(
      data['propertyType'],
      fallback: 'عقار',
    );

    final city = _text(data['city']);
    final district = _text(data['district']);

    final location = [
      city,
      district,
    ].where((value) => value.isNotEmpty).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _gold.withValues(alpha: .18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PropertyRequestDetailsScreen(
                  requestId: requestId,
                  data: data,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _gold.withValues(
                          alpha: .10,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _propertyIcon(
                          propertyType,
                        ),
                        color: _gold,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title(
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
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: _gold,
                                  size: 15,
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _typeBadge(requestType),
                        if (_isAdmin) ...[
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            tooltip: 'إدارة الطلب',
                            color: const Color(0xff1E293B),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white60,
                              size: 22,
                            ),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _confirmDeleteRequest(
                                  requestId: requestId,
                                  data: data,
                                );
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
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Divider(
                  color: Colors.white10,
                  height: 1,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _smallInfo(
                        icon: Icons.square_foot_rounded,
                        title: "المساحة",
                        value: _range(
                          data['minArea'],
                          data['maxArea'],
                          suffix: "م²",
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _smallInfo(
                        icon: Icons.account_balance_wallet_rounded,
                        title: "الميزانية",
                        value: _range(
                          data['minPrice'],
                          data['maxPrice'],
                          suffix: "د.ع",
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "عرض التفاصيل",
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _gold,
                      size: 12,
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

  Future<void> _confirmDeleteRequest({
    required String requestId,
    required Map<String, dynamic> data,
  }) async {
    final propertyType = _text(
      data['propertyType'],
      fallback: 'العقار',
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _card,
            title: const Text(
              'حذف الطلب',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'هل أنت متأكد من حذف طلب $propertyType نهائيًا؟\n\n'
              'سيختفي الطلب من قسم مطلوب على عقارات الانبار، '
              'ولا يمكن التراجع عن الحذف',
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

  Widget _smallInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: _gold,
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String requestType) {
    final label = requestType.isEmpty ? "طلب" : requestType;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _gold.withValues(alpha: .22),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _gold,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: 30,
      ),
      children: [
        const SizedBox(height: 100),
        Icon(
          icon,
          size: 88,
          color: Colors.white.withValues(alpha: .12),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  String _title(
    String requestType,
    String propertyType,
  ) {
    if (requestType == 'شراء') {
      return "مطلوب $propertyType للشراء";
    }

    if (requestType == 'إيجار') {
      return "مطلوب $propertyType للإيجار";
    }

    return "مطلوب $propertyType";
  }

  String _range(
    dynamic minValue,
    dynamic maxValue, {
    required String suffix,
  }) {
    final min = _toDouble(minValue);
    final max = _toDouble(maxValue);

    if (min == null && max == null) {
      return "غير محدد";
    }

    if (min != null && max != null) {
      if (min == max) {
        return "${_formatNumber(min)} $suffix";
      }

      return "${_formatNumber(min)} - "
          "${_formatNumber(max)} $suffix";
    }

    if (min != null) {
      return "من ${_formatNumber(min)} $suffix";
    }

    return "حتى ${_formatNumber(max!)} $suffix";
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString().replaceAll(',', ''),
    );
  }

  String _formatNumber(double value) {
    final rounded = value.round();

    final digits = rounded.toString().split('').reversed.toList();

    final result = <String>[];

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) {
        result.add(',');
      }

      result.add(digits[i]);
    }

    return result.reversed.join();
  }

  String _text(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  IconData _propertyIcon(
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
