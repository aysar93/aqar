import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// إدارة طلبات إنشاء المكاتب من لوحة الإدارة.
///
/// هذه الصفحة مسؤولة عن:
/// - عرض طلبات المكاتب.
/// - البحث في الطلبات.
/// - تصفية الطلبات حسب الحالة.
/// - فتح تفاصيل الطلب.
/// - قبول الطلب.
/// - رفض الطلب.
/// - حذف الطلب.
///
/// ملاحظة:
/// تم بناء الملف من الصفر ولا يعتمد على ملفات نظام المكاتب القديمة.
class OfficeRequestsManagementScreen extends StatefulWidget {
  const OfficeRequestsManagementScreen({
    super.key,
  });

  @override
  State<OfficeRequestsManagementScreen> createState() =>
      _OfficeRequestsManagementScreenState();
}

class _OfficeRequestsManagementScreenState
    extends State<OfficeRequestsManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  OfficeRequestFilter _filter = OfficeRequestFilter.pending;

  CollectionReference<Map<String, dynamic>> get _requestsCollection =>
      _firestore.collection('officeRequests');

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'طلبات المكاتب',
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
            _buildHeader(
              context,
              colorScheme,
            ),
            _buildFilterBar(context),
            Expanded(
              child: _buildRequestsList(
                context,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Header
  // ═════════════════════════════════════════════

  Widget _buildHeader(
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
          TextField(
            controller: _searchController,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'ابحث باسم المكتب أو المالك أو البريد',
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
          ),
          const SizedBox(height: 12),
          _buildPendingCounter(
            context,
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCounter(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _requestsCollection
          .where(
            'status',
            isEqualTo: 'pending',
          )
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        final count = snapshot.data?.docs.length ?? 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.pending_actions_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'طلبات بانتظار المراجعة',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════
  // Filters
  // ═════════════════════════════════════════════

  Widget _buildFilterBar(
    BuildContext context,
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
            label: 'بانتظار المراجعة',
            filter: OfficeRequestFilter.pending,
          ),
          _buildFilterChip(
            context,
            label: 'مقبولة',
            filter: OfficeRequestFilter.approved,
          ),
          _buildFilterChip(
            context,
            label: 'مرفوضة',
            filter: OfficeRequestFilter.rejected,
          ),
          _buildFilterChip(
            context,
            label: 'الكل',
            filter: OfficeRequestFilter.all,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required OfficeRequestFilter filter,
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
  // Requests list
  // ═════════════════════════════════════════════

  Widget _buildRequestsList(
    BuildContext context,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _buildRequestsQuery().snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return _buildErrorState(
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
            await _requestsCollection.limit(1).get(
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
              return _buildRequestCard(
                context,
                filtered[index],
              );
            },
          ),
        );
      },
    );
  }

  Query<Map<String, dynamic>> _buildRequestsQuery() {
    Query<Map<String, dynamic>> query = _requestsCollection;

    switch (_filter) {
      case OfficeRequestFilter.all:
        return query.orderBy(
          'createdAt',
          descending: true,
        );

      case OfficeRequestFilter.pending:
        return query
            .where(
              'status',
              isEqualTo: 'pending',
            )
            .orderBy(
              'createdAt',
              descending: true,
            );

      case OfficeRequestFilter.approved:
        return query
            .where(
              'status',
              isEqualTo: 'approved',
            )
            .orderBy(
              'createdAt',
              descending: true,
            );

      case OfficeRequestFilter.rejected:
        return query
            .where(
              'status',
              isEqualTo: 'rejected',
            )
            .orderBy(
              'createdAt',
              descending: true,
            );
    }
  }

  // ═════════════════════════════════════════════
  // Request card
  // ═════════════════════════════════════════════

  Widget _buildRequestCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final officeName = _readString(
      data['officeName'] ?? data['name'],
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

    final status = _readString(
      data['status'],
      fallback: 'pending',
    ).toLowerCase();

    final imageUrl = _readString(
      data['imageUrl'],
    );

    final createdAt = _readDate(data['createdAt']);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _showRequestDetails(
            context,
            doc,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequestAvatar(
                    context,
                    imageUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          officeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'صاحب الطلب: $ownerName',
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
                                const SizedBox(width: 4),
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
                  _buildRequestStatusBadge(
                    context,
                    status,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRequestInfo(
                context,
                email: email,
                phone: phone,
                createdAt: createdAt,
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 14),
                _buildRequestActions(
                  context,
                  doc,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestAvatar(
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
          size: 30,
          color: colorScheme.onPrimaryContainer,
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

  Widget _buildRequestStatusBadge(
    BuildContext context,
    String status,
  ) {
    final color = _statusColor(
      context,
      status,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(status),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestInfo(
    BuildContext context, {
    required String email,
    required String phone,
    required DateTime? createdAt,
  }) {
    final items = <Widget>[];

    if (email.isNotEmpty) {
      items.add(
        _buildInfoItem(
          context,
          icon: Icons.email_outlined,
          text: email,
        ),
      );
    }

    if (phone.isNotEmpty) {
      items.add(
        _buildInfoItem(
          context,
          icon: Icons.phone_outlined,
          text: phone,
        ),
      );
    }

    if (createdAt != null) {
      items.add(
        _buildInfoItem(
          context,
          icon: Icons.calendar_today_outlined,
          text: _formatDate(createdAt),
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: items,
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // Actions
  // ═════════════════════════════════════════════

  Widget _buildRequestActions(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              _approveRequest(
                context,
                doc,
              );
            },
            icon: const Icon(
              Icons.check_rounded,
              size: 19,
            ),
            label: const Text(
              'قبول الطلب',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _rejectRequest(
                context,
                doc,
              );
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 19,
            ),
            label: const Text(
              'رفض الطلب',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _approveRequest(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    final officeName = _readString(
      data['officeName'] ?? data['name'],
      fallback: 'المكتب',
    );

    final confirmed = await _showConfirmationDialog(
      context,
      title: 'قبول طلب المكتب؟',
      message: 'سيتم اعتماد طلب "$officeName" كمكتب مقبول',
      confirmText: 'قبول',
    );

    if (confirmed != true) {
      return;
    }

    try {
      final requestRef = _firestore.collection('officeRequests').doc(doc.id);

      // نستخدم نفس ID الخاص بالطلب للمكتب.
      // هذا يمنع إنشاء مكتبين لنفس الطلب.
      final officeRef = _firestore.collection('offices').doc(doc.id);

      await _firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(requestRef);

        if (!requestSnapshot.exists) {
          throw Exception('REQUEST_NOT_FOUND');
        }

        final requestData = requestSnapshot.data() ?? {};

        final currentStatus =
            requestData['status']?.toString().trim().toLowerCase() ?? '';

        // إذا تمت الموافقة سابقًا فلا ننشئ مكتبًا ثانيًا.
        if (currentStatus == 'approved') {
          return;
        }

        // بيانات المكتب القادمة من طلب المستخدم.
        final officeData = <String, dynamic>{
          'ownerId': requestData['ownerId'] ?? '',

          'name': requestData['name'] ?? '',
          'description': requestData['description'] ?? '',

          'logoUrl': requestData['logoUrl'] ?? '',
          'coverImageUrl': requestData['coverImageUrl'] ?? '',
          'galleryImages': requestData['galleryImages'] ?? <String>[],

          'phone': requestData['phone'] ?? '',
          'whatsapp': requestData['whatsapp'] ?? '',
          'email': requestData['email'] ?? '',
          'website': requestData['website'] ?? '',

          'facebook': requestData['facebook'] ?? '',
          'instagram': requestData['instagram'] ?? '',
          'telegram': requestData['telegram'] ?? '',
          'tiktok': requestData['tiktok'] ?? '',
          'youtube': requestData['youtube'] ?? '',

          'city': requestData['city'] ?? '',
          'district': requestData['district'] ?? '',
          'areaName': requestData['areaName'] ?? '',
          'address': requestData['address'] ?? '',

          'latitude': requestData['latitude'] ?? 0,
          'longitude': requestData['longitude'] ?? 0,

          'services': requestData['services'] ?? <String>[],
          'workingHours': requestData['workingHours'] ?? <String, dynamic>{},

          'establishedYear': requestData['establishedYear'],
          'licenseNumber': requestData['licenseNumber'] ?? '',
          'licenseImageUrl': requestData['licenseImageUrl'] ?? '',

          // حالة المكتب بعد الموافقة.
          'status': 'active',

          // الاعتماد الإداري.
          'isVerified': false,
          'verificationStatus': 'not_requested',
          'verificationNote': '',

          'isFeatured': false,
          'featuredUntil': null,

          // الإحصائيات تبدأ من الصفر.
          'propertiesCount': 0,
          'followersCount': 0,
          'viewsCount': 0,
          'reviewsCount': 0,
          'rating': 0,

          // الاشتراك يبدأ بدون اشتراك.
          'subscriptionId': '',
          'subscriptionStatus': 'none',
          'subscriptionStartDate': null,
          'subscriptionEndDate': null,

          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // إنشاء المكتب.
        transaction.set(
          officeRef,
          officeData,
        );

        // تحديث الطلب وربطه بالمكتب الجديد.
        transaction.update(
          requestRef,
          {
            'status': 'approved',
            'officeId': doc.id,
            'approvedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      if (!mounted) return;

      _showMessage(
        context,
        'تم قبول الطلب وإنشاء المكتب بنجاح',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        context,
        'تعذر قبول الطلب وإنشاء المكتب',
        isError: true,
      );
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    final officeName = _readString(
      data['officeName'] ?? data['name'],
      fallback: 'المكتب',
    );

    final reasonController = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'رفض طلب المكتب',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'سيتم رفض طلب "$officeName"',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'سبب الرفض',
                  hintText: 'اكتب سبب الرفض إن وجد',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  reasonController.text.trim(),
                );
              },
              child: const Text('رفض الطلب'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (result == null) {
      return;
    }

    try {
      await _firestore.collection('officeRequests').doc(doc.id).update({
        'status': 'rejected',
        'rejectionReason': result,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage(
        context,
        'تم رفض طلب المكتب',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        context,
        'تعذر رفض الطلب',
        isError: true,
      );
    }
  }

  // ═════════════════════════════════════════════
  // Details
  // ═════════════════════════════════════════════

  Future<void> _showRequestDetails(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();

    final officeName = _readString(
      data['officeName'] ?? data['name'],
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
      fallback: 'لا يوجد وصف',
    );

    final status = _readString(
      data['status'],
      fallback: 'pending',
    );

    final createdAt = _readDate(data['createdAt']);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  officeName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  context,
                  label: 'صاحب المكتب',
                  value: ownerName,
                  icon: Icons.person_outline_rounded,
                ),
                _buildDetailRow(
                  context,
                  label: 'البريد الإلكتروني',
                  value: email,
                  icon: Icons.email_outlined,
                ),
                _buildDetailRow(
                  context,
                  label: 'رقم الهاتف',
                  value: phone,
                  icon: Icons.phone_outlined,
                ),
                _buildDetailRow(
                  context,
                  label: 'المدينة',
                  value: city,
                  icon: Icons.location_city_outlined,
                ),
                _buildDetailRow(
                  context,
                  label: 'العنوان',
                  value: address,
                  icon: Icons.location_on_outlined,
                ),
                if (createdAt != null)
                  _buildDetailRow(
                    context,
                    label: 'تاريخ الطلب',
                    value: _formatDate(createdAt),
                    icon: Icons.calendar_today_outlined,
                  ),
                _buildDetailRow(
                  context,
                  label: 'الحالة',
                  value: _statusLabel(status),
                  icon: _statusIcon(status),
                ),
                const SizedBox(height: 14),
                const Text(
                  'الوصف',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(
                    14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Text(
                    description,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 105,
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

  // ═════════════════════════════════════════════
  // Search
  // ═════════════════════════════════════════════

  bool _matchesSearch(
    Map<String, dynamic> data,
  ) {
    if (_searchQuery.isEmpty) {
      return true;
    }

    final values = [
      data['officeName'],
      data['name'],
      data['ownerName'],
      data['email'],
      data['phone'],
      data['city'],
      data['address'],
      data['ownerUid'],
    ];

    return values.any(
      (value) {
        return value?.toString().toLowerCase().contains(_searchQuery) == true;
      },
    );
  }

  // ═════════════════════════════════════════════
  // Dialog
  // ═════════════════════════════════════════════

  Future<bool?> _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  // ═════════════════════════════════════════════
  // Empty / Error
  // ═════════════════════════════════════════════

  Widget _buildEmptyState(
    BuildContext context,
  ) {
    final isPending = _filter == OfficeRequestFilter.pending;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.task_alt_rounded : Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              isPending
                  ? 'لا توجد طلبات بانتظار المراجعة.'
                  : 'لا توجد طلبات لعرضها',
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

  Widget _buildErrorState(
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
              'تعذر تحميل طلبات المكاتب',
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

  String _formatDate(
    DateTime date,
  ) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    return '$year/$month/$day';
  }

  String _statusLabel(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'بانتظار المراجعة';

      case 'approved':
        return 'مقبول';

      case 'rejected':
        return 'مرفوض';

      case 'cancelled':
        return 'ملغى';

      default:
        return 'غير محدد';
    }
  }

  IconData _statusIcon(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_rounded;

      case 'approved':
        return Icons.check_circle_rounded;

      case 'rejected':
        return Icons.cancel_rounded;

      case 'cancelled':
        return Icons.block_rounded;

      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _statusColor(
    BuildContext context,
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;

      case 'approved':
        return Colors.green;

      case 'rejected':
        return Theme.of(context).colorScheme.error;

      case 'cancelled':
        return Colors.grey;

      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
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
}

// ═════════════════════════════════════════════
// Filter enum
// ═════════════════════════════════════════════

enum OfficeRequestFilter {
  all,
  pending,
  approved,
  rejected,
}
