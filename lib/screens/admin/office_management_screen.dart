import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'office_details_admin_screen.dart';
import 'office_requests_management_screen.dart';
import 'office_subscriptions_management_screen.dart';

/// لوحة الإدارة الرئيسية للمكاتب.
///
/// الوظائف الأساسية:
/// - عرض جميع المكاتب.
/// - البحث عن مكتب.
/// - تصفية المكاتب حسب الحالة.
/// - معرفة حالة الاشتراك.
/// - فتح تفاصيل المكتب.
/// - تفعيل / تعطيل المكتب.
/// - حذف المكتب.
/// - الانتقال إلى طلبات المكاتب.
/// - الانتقال إلى إدارة الاشتراكات.
/// - الانتقال إلى إدارة التقييمات.
///
/// ملاحظة:
/// هذا الملف لا يعتمد على أي ملف قديم من نظام المكاتب.
/// كل منطق الصفحة موجود هنا حاليًا، وسيتم لاحقًا فصل
/// الخدمات وربط الصلاحيات بشكل أعمق بعد اكتمال الهيكل.
class OfficeManagementScreen extends StatefulWidget {
  const OfficeManagementScreen({
    super.key,
  });

  @override
  State<OfficeManagementScreen> createState() => _OfficeManagementScreenState();
}

class _OfficeManagementScreenState extends State<OfficeManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  OfficeFilter _filter = OfficeFilter.all;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(
        _onSearchChanged,
      )
      ..dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  CollectionReference<Map<String, dynamic>> get _officesCollection =>
      _firestore.collection('offices');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة المكاتب',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSection(
              context,
              colorScheme,
            ),
            _buildFilterBar(
              context,
              colorScheme,
            ),
            Expanded(
              child: _buildOfficesList(
                context,
                colorScheme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // القسم العلوي
  // ═════════════════════════════════════════════

  Widget _buildTopSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        8,
      ),
      child: Column(
        children: [
          _buildSearchField(
            context,
            colorScheme,
          ),
          const SizedBox(height: 14),
          _buildStatistics(
            context,
            colorScheme,
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // البحث
  // ═════════════════════════════════════════════

  Widget _buildSearchField(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return TextField(
      controller: _searchController,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        hintText: 'ابحث باسم المكتب أو البريد أو المدينة',
        prefixIcon: const Icon(
          Icons.search_rounded,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _searchController.clear();
                },
                icon: const Icon(
                  Icons.clear_rounded,
                ),
              )
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
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
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // الإحصائيات
  // ═════════════════════════════════════════════

  Widget _buildStatistics(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _officesCollection.snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return _buildStatisticsError(
            context,
          );
        }

        if (!snapshot.hasData) {
          return _buildStatisticsLoading(
            colorScheme,
          );
        }

        final docs = snapshot.data!.docs;

        final total = docs.length;

        final active = docs.where(
          (doc) {
            return _isOfficeActive(
              doc.data(),
            );
          },
        ).length;

        final expired = docs.where(
          (doc) {
            return _getSubscriptionStatus(
                  doc.data(),
                ) ==
                'expired';
          },
        ).length;

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'المكاتب',
                value: total.toString(),
                icon: Icons.business_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                context,
                title: 'نشطة',
                value: active.toString(),
                icon: Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                context,
                title: 'منتهية',
                value: expired.toString(),
                icon: Icons.timer_off_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('officeRequests')
                    .where(
                      'status',
                      isEqualTo: 'pending',
                    )
                    .snapshots(),
                builder: (context, requestSnapshot) {
                  final pendingRequests = requestSnapshot.hasData
                      ? requestSnapshot.data!.docs.length
                      : 0;

                  return _buildStatCard(
                    context,
                    title: 'طلبات',
                    value: pendingRequests.toString(),
                    icon: Icons.pending_actions_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const OfficeRequestsManagementScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsLoading(
    ColorScheme colorScheme,
  ) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsError(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'تعذر تحميل إحصائيات المكاتب',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // الفلاتر
  // ═════════════════════════════════════════════

  Widget _buildFilterBar(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          _buildFilterChip(
            context,
            label: 'الكل',
            filter: OfficeFilter.all,
          ),
          _buildFilterChip(
            context,
            label: 'نشطة',
            filter: OfficeFilter.active,
          ),
          _buildFilterChip(
            context,
            label: 'بانتظار الموافقة',
            filter: OfficeFilter.pending,
          ),
          _buildFilterChip(
            context,
            label: 'منتهية',
            filter: OfficeFilter.expired,
          ),
          _buildFilterChip(
            context,
            label: 'معطلة',
            filter: OfficeFilter.disabled,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required OfficeFilter filter,
  }) {
    final selected = _filter == filter;

    return Padding(
      padding: const EdgeInsets.only(
        left: 8,
      ),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) {
          setState(() {
            _filter = filter;
          });
        },
      ),
    );
  }

  // ═════════════════════════════════════════════
  // قائمة المكاتب
  // ═════════════════════════════════════════════

  Widget _buildOfficesList(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _officesCollection
          .orderBy(
            'createdAt',
            descending: true,
          )
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return _buildListError(
            context,
            snapshot.error,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final filtered = docs.where(
          (doc) {
            return _matchesSearch(
                  doc.data(),
                ) &&
                _matchesFilter(
                  doc.data(),
                );
          },
        ).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            context,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _firestore.collection('offices').limit(1).get(
                  const GetOptions(
                    source: Source.server,
                  ),
                );
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24,
            ),
            itemCount: filtered.length,
            separatorBuilder: (
              context,
              index,
            ) =>
                const SizedBox(height: 12),
            itemBuilder: (
              context,
              index,
            ) {
              final doc = filtered[index];

              return _buildOfficeCard(
                context,
                doc,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildListError(
    BuildContext context,
    Object? error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'حدث خطأ أثناء تحميل المكاتب',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
  ) {
    final hasSearch = _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch ? Icons.search_off_rounded : Icons.business_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'لا توجد مكاتب مطابقة للبحث.'
                  : 'لا توجد مكاتب حاليًا',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // بطاقة المكتب
  // ═════════════════════════════════════════════

  Widget _buildOfficeCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final officeName = _readString(
      data['name'],
      fallback: 'مكتب عقاري',
    );

    final ownerName = _readString(
      data['ownerName'],
      fallback: 'غير محدد',
    );

    final email = _readString(
      data['email'],
    );

    final phone = _readString(
      data['phone'],
    );

    final city = _readString(
      data['city'],
    );

    final imageUrl = _readString(
      data['imageUrl'],
    );

    final officeStatus = _getOfficeStatus(
      data,
    );

    final subscriptionStatus = _getSubscriptionStatus(
      data,
    );

    final isVerified = data['isVerified'] == true;

    final followerCount = _readInt(
      data['followerCount'],
    );

    final propertyCount = _readInt(
      data['propertyCount'],
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openOfficeDetails(
            context,
            doc.id,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOfficeAvatar(
                    context,
                    imageUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                officeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (isVerified)
                              const Padding(
                                padding: EdgeInsets.only(
                                  right: 5,
                                ),
                                child: Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        Text(
                          'المالك: $ownerName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (city.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 4,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 15,
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                Expanded(
                                  child: Text(
                                    city,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<OfficeAction>(
                    onSelected: (action) {
                      _handleOfficeAction(
                        context,
                        action,
                        doc,
                      );
                    },
                    itemBuilder: (context) {
                      final isFeatured = doc.data()?['isFeatured'] == true;
                      return [
                        const PopupMenuItem(
                          value: OfficeAction.details,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.visibility_outlined,
                            ),
                            title: Text(
                              'عرض التفاصيل',
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: OfficeAction.subscription,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.workspace_premium_outlined,
                            ),
                            title: Text(
                              'إدارة الاشتراك',
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: OfficeAction.toggleStatus,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.power_settings_new_rounded,
                            ),
                            title: Text(
                              'تغيير الحالة',
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: OfficeAction.toggleFeatured,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isFeatured
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                            ),
                            title: Text(
                              isFeatured
                                  ? 'إلغاء تمييز المكتب'
                                  : 'تمييز المكتب',
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: OfficeAction.delete,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.delete_outline_rounded,
                            ),
                            title: Text(
                              'حذف المكتب',
                            ),
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildOfficeStatusRow(
                context,
                officeStatus: officeStatus,
                subscriptionStatus: subscriptionStatus,
              ),
              const SizedBox(height: 12),
              _buildOfficeMetrics(
                context,
                followerCount: followerCount,
                propertyCount: propertyCount,
              ),
              if (email.isNotEmpty || phone.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildContactRow(
                  context,
                  email: email,
                  phone: phone,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeAvatar(
    BuildContext context,
    String imageUrl,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (imageUrl.isEmpty) {
      return Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.business_rounded,
          color: colorScheme.onPrimaryContainer,
          size: 30,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        imageUrl,
        width: 66,
        height: 66,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return Container(
            width: 66,
            height: 66,
            color: colorScheme.primaryContainer,
            child: Icon(
              Icons.business_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════
  // حالة المكتب والاشتراك
  // ═════════════════════════════════════════════

  Widget _buildOfficeStatusRow(
    BuildContext context, {
    required String officeStatus,
    required String subscriptionStatus,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusBadge(
            context,
            label: _officeStatusLabel(
              officeStatus,
            ),
            color: _officeStatusColor(
              context,
              officeStatus,
            ),
            icon: _officeStatusIcon(
              officeStatus,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusBadge(
            context,
            label: _subscriptionStatusLabel(
              subscriptionStatus,
            ),
            color: _subscriptionStatusColor(
              context,
              subscriptionStatus,
            ),
            icon: _subscriptionStatusIcon(
              subscriptionStatus,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // الإحصائيات الصغيرة
  // ═════════════════════════════════════════════

  Widget _buildOfficeMetrics(
    BuildContext context, {
    required int followerCount,
    required int propertyCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _buildMetric(
            context,
            icon: Icons.home_work_outlined,
            label: 'العقارات',
            value: propertyCount.toString(),
          ),
        ),
        Container(
          width: 1,
          height: 24,
          color: colorScheme.outlineVariant,
        ),
        Expanded(
          child: _buildMetric(
            context,
            icon: Icons.people_outline_rounded,
            label: 'المتابعون',
            value: followerCount.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 5),
        Text(
          '$value $label',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow(
    BuildContext context, {
    required String email,
    required String phone,
  }) {
    return Row(
      children: [
        if (email.isNotEmpty)
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.email_outlined,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (email.isNotEmpty && phone.isNotEmpty) const SizedBox(width: 8),
        if (phone.isNotEmpty)
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // البحث والفلاتر
  // ═════════════════════════════════════════════

  bool _matchesSearch(
    Map<String, dynamic> data,
  ) {
    if (_searchQuery.isEmpty) {
      return true;
    }

    final values = [
      data['name'],
      data['officeName'],
      data['ownerName'],
      data['email'],
      data['phone'],
      data['city'],
      data['areaName'],
      data['ownerUid'],
    ];

    return values.any(
      (value) {
        return value?.toString().toLowerCase().contains(_searchQuery) == true;
      },
    );
  }

  bool _matchesFilter(
    Map<String, dynamic> data,
  ) {
    switch (_filter) {
      case OfficeFilter.all:
        return true;

      case OfficeFilter.active:
        return _isOfficeActive(data);

      case OfficeFilter.pending:
        return _getOfficeStatus(data) == 'pending';

      case OfficeFilter.expired:
        return _getSubscriptionStatus(
              data,
            ) ==
            'expired';

      case OfficeFilter.disabled:
        return !_isOfficeActive(data);
    }
  }

  // ═════════════════════════════════════════════
  // إجراءات المكتب
  // ═════════════════════════════════════════════

  Future<void> _handleOfficeAction(
    BuildContext context,
    OfficeAction action,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    switch (action) {
      case OfficeAction.details:
        _openOfficeDetails(
          context,
          doc.id,
        );
        break;

      case OfficeAction.subscription:
        _openOfficeSubscription(
          context,
          doc.id,
        );
        break;

      case OfficeAction.toggleStatus:
        await _toggleOfficeStatus(
          context,
          doc,
        );
        break;

      case OfficeAction.toggleFeatured:
        await _toggleOfficeFeatured(doc);
        break;

      case OfficeAction.delete:
        await _deleteOffice(
          context,
          doc,
        );
        break;
    }
  }

  void _openOfficeSubscription(
    BuildContext context,
    String officeId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficeSubscriptionsManagementScreen(
          officeId: officeId,
        ),
      ),
    );
  }

  Future<void> _toggleOfficeStatus(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    final currentlyActive = _isOfficeActive(data);

    final newStatus = currentlyActive ? 'disabled' : 'active';

    await _firestore.collection('offices').doc(doc.id).update({
      'status': newStatus,
      'isActive': newStatus == 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    _showMessage(
      context,
      currentlyActive ? 'تم تعطيل المكتب.' : 'تم تفعيل المكتب',
    );
  }

  Future<void> _toggleOfficeFeatured(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();

    if (data == null) return;

    final currentlyFeatured = data['isFeatured'] == true;

    try {
      await _firestore.collection('offices').doc(doc.id).update({
        'isFeatured': !currentlyFeatured,
        'featuredUntil': !currentlyFeatured
            ? Timestamp.fromDate(
                DateTime.now().add(const Duration(days: 30)),
              )
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentlyFeatured
                ? 'تم تمييز المكتب لمدة 30 يومًا ⭐'
                : 'تم إلغاء تمييز المكتب',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحديث تمييز المكتب: $e'),
        ),
      );
    }
  }

  Future<void> _deleteOffice(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    final officeName = _readString(
      data['name'],
      fallback: 'هذا المكتب',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (
        context,
      ) {
        return AlertDialog(
          title: const Text(
            'حذف المكتب؟',
          ),
          content: Text(
            'هل أنت متأكد من حذف "$officeName"؟\n\n'
            'هذا الإجراء لا ينبغي تنفيذه إلا بعد التأكد '
            'من عدم الحاجة إلى بيانات المكتب',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _firestore.collection('offices').doc(doc.id).delete();

    if (!mounted) return;

    _showMessage(
      context,
      'تم حذف المكتب',
    );
  }

  // ═════════════════════════════════════════════
  // الانتقال للتفاصيل
  // ═════════════════════════════════════════════

  void _openOfficeDetails(
    BuildContext context,
    String officeId,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficeDetailsAdminScreen(
          officeId: officeId,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // حالات المكتب
  // ═════════════════════════════════════════════

  String _getOfficeStatus(
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

  bool _isOfficeActive(
    Map<String, dynamic> data,
  ) {
    final status = _getOfficeStatus(data);

    return status == 'active' && data['isActive'] != false;
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

  String _officeStatusLabel(
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

  Color _officeStatusColor(
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

  IconData _officeStatusIcon(
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

  // ═════════════════════════════════════════════
  // حالات الاشتراك
  // ═════════════════════════════════════════════

  String _subscriptionStatusLabel(
    String status,
  ) {
    switch (status) {
      case 'active':
        return 'اشتراك نشط';

      case 'expired':
        return 'الاشتراك منتهي';

      case 'pending':
        return 'اشتراك قيد المعالجة';

      case 'cancelled':
        return 'اشتراك ملغى';

      case 'none':
        return 'بدون اشتراك';

      default:
        return 'اشتراك غير محدد';
    }
  }

  Color _subscriptionStatusColor(
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

  IconData _subscriptionStatusIcon(
    String status,
  ) {
    switch (status) {
      case 'active':
        return Icons.workspace_premium_rounded;

      case 'expired':
        return Icons.timer_off_rounded;

      case 'pending':
        return Icons.hourglass_top_rounded;

      case 'cancelled':
        return Icons.cancel_outlined;

      default:
        return Icons.remove_circle_outline;
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

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

// ═════════════════════════════════════════════
// Filters
// ═════════════════════════════════════════════

enum OfficeFilter {
  all,
  active,
  pending,
  expired,
  disabled,
}

// ═════════════════════════════════════════════
// Actions
// ═════════════════════════════════════════════

enum OfficeAction {
  details,
  subscription,
  toggleStatus,
  toggleFeatured,
  delete,
}
