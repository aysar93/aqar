import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../office/models/office_subscription_model.dart';
import '../../office/services/office_subscription_service.dart';

class OfficeSubscriptionsManagementScreen extends StatefulWidget {
  const OfficeSubscriptionsManagementScreen({
    super.key,
    this.officeId,
  });

  final String? officeId;

  @override
  State<OfficeSubscriptionsManagementScreen> createState() =>
      _OfficeSubscriptionsManagementScreenState();
}

class _OfficeSubscriptionsManagementScreenState
    extends State<OfficeSubscriptionsManagementScreen> {
  final OfficeSubscriptionService _service = OfficeSubscriptionService();
  final TextEditingController _searchController = TextEditingController();

  String _filter = 'all';
  String _searchQuery = '';
  String _sort = 'newest';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<OfficeSubscriptionAdminItem>> _subscriptionsStream() =>
      _service.watchAdminSubscriptions(officeId: widget.officeId);

  List<OfficeSubscriptionAdminItem> _filtered(
    List<OfficeSubscriptionAdminItem> items,
  ) {
    final result = items.where((item) {
      final subscription = item.subscription;
      final matchesFilter = _filter == 'all' || subscription.status == _filter;

      if (!matchesFilter) {
        return false;
      }

      if (_searchQuery.isEmpty) {
        return true;
      }

      return item.searchableText.contains(_searchQuery);
    }).toList();

    int compare(OfficeSubscriptionAdminItem a, OfficeSubscriptionAdminItem b) {
      final left = a.subscription;
      final right = b.subscription;
      switch (_sort) {
        case 'oldest':
          return _effectiveDate(left).compareTo(_effectiveDate(right));
        case 'priceHigh':
          return right.price.compareTo(left.price);
        case 'priceLow':
          return left.price.compareTo(right.price);
        case 'office':
          return a.officeName.compareTo(b.officeName);
        default:
          return _effectiveDate(right).compareTo(_effectiveDate(left));
      }
    }

    result.sort(compare);
    return result;
  }

  DateTime _effectiveDate(OfficeSubscriptionModel item) =>
      item.updatedAt ??
      item.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اشتراكات المكاتب'),
          centerTitle: true,
        ),
        body: StreamBuilder<List<OfficeSubscriptionAdminItem>>(
          stream: _subscriptionsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ErrorState(
                message: 'تعذر تحميل اشتراكات المكاتب',
                onRetry: () => setState(() {}),
              );
            }

            final allItems = snapshot.data ?? const [];
            final items = _filtered(allItems);

            return Column(children: [
              Expanded(
                  child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildDashboard(allItems)),
                  SliverToBoxAdapter(child: _buildSearchAndSort()),
                  SliverToBoxAdapter(child: _buildFilters(allItems)),
                  if (items.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(message: 'لا توجد اشتراكات مطابقة'),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.crossAxisExtent >= 1050
                              ? 3
                              : constraints.crossAxisExtent >= 680
                                  ? 2
                                  : 1;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 390,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildSubscriptionCard(items[index]),
                              childCount: items.length,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              )),
            ]);
          },
        ),
      ),
    );
  }

  Widget _buildSearchAndSort() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: LayoutBuilder(builder: (context, constraints) {
        final search = TextField(
          controller: _searchController,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'ابحث باسم المكتب أو معرّفه أو الباقة أو الاشتراك',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.clear),
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
        final sort = DropdownButtonFormField<String>(
          initialValue: _sort,
          decoration: InputDecoration(
            labelText: 'الترتيب',
            prefixIcon: const Icon(Icons.sort),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          items: const [
            DropdownMenuItem(value: 'newest', child: Text('الأحدث')),
            DropdownMenuItem(value: 'oldest', child: Text('الأقدم')),
            DropdownMenuItem(value: 'priceHigh', child: Text('السعر: الأعلى')),
            DropdownMenuItem(value: 'priceLow', child: Text('السعر: الأقل')),
            DropdownMenuItem(value: 'office', child: Text('اسم المكتب')),
          ],
          onChanged: (value) => setState(() => _sort = value ?? 'newest'),
        );
        if (constraints.maxWidth < 650) {
          return Column(children: [search, const SizedBox(height: 10), sort]);
        }
        return Row(children: [
          Expanded(child: search),
          const SizedBox(width: 12),
          SizedBox(width: 210, child: sort)
        ]);
      }),
    );
  }

  Widget _buildDashboard(List<OfficeSubscriptionAdminItem> items) {
    int count(String status) =>
        items.where((item) => item.subscription.status == status).length;
    final revenue = items
        .where((item) => item.subscription.paymentStatus == 'paid')
        .fold<double>(0, (total, item) => total + item.subscription.price);
    final cards = <_MetricData>[
      _MetricData(
          'إجمالي السجلات', '${items.length}', Icons.receipt_long_outlined),
      _MetricData(
          'قيد المراجعة', '${count('pending')}', Icons.hourglass_top_rounded),
      _MetricData(
          'الاشتراكات الفعّالة', '${count('active')}', Icons.verified_outlined),
      _MetricData('الإيراد المدفوع', revenue.toStringAsFixed(0),
          Icons.payments_outlined),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width >= 900
            ? (width - 36) / 4
            : width >= 520
                ? (width - 12) / 2
                : width;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((item) =>
                  SizedBox(width: itemWidth, child: _MetricCard(data: item)))
              .toList(),
        );
      }),
    );
  }

  Widget _buildFilters(List<OfficeSubscriptionAdminItem> items) {
    final subscriptions = items.map((item) => item.subscription);
    final counts = <String, int>{
      'all': items.length,
      'pending': subscriptions.where((e) => e.status == 'pending').length,
      'active': subscriptions.where((e) => e.status == 'active').length,
      'expired': subscriptions.where((e) => e.status == 'expired').length,
      'cancelled': subscriptions.where((e) => e.status == 'cancelled').length,
      'suspended': subscriptions.where((e) => e.status == 'suspended').length,
    };

    final filters = <String, String>{
      'all': 'الكل',
      'pending': 'قيد المراجعة',
      'active': 'فعّال',
      'expired': 'منتهي',
      'cancelled': 'ملغى',
      'suspended': 'موقوف',
    };

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = filters.keys.elementAt(index);
          final selected = _filter == key;

          return FilterChip(
            selected: selected,
            label: Text('${filters[key]} (${counts[key] ?? 0})'),
            onSelected: (_) {
              setState(() {
                _filter = key;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionCard(OfficeSubscriptionAdminItem item) {
    final subscription = item.subscription;
    final status = _statusInfo(subscription.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(subscription, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OfficeAvatar(
                      name: item.officeName, imageUrl: item.officeImageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              item.officeName.isEmpty
                                  ? 'مكتب غير متاح'
                                  : item.officeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(
                              subscription.packageName.isEmpty
                                  ? 'باقة غير مسماة'
                                  : subscription.packageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ]),
                  ),
                  _StatusChip(
                    label: status.label,
                    icon: status.icon,
                    color: status.color,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(
                icon: Icons.business_outlined,
                title: 'معرّف المكتب',
                value: subscription.officeId,
              ),
              _InfoRow(
                icon: Icons.person_outline,
                title: 'صاحب المكتب',
                value: subscription.ownerId,
              ),
              _InfoRow(
                icon: Icons.payments_outlined,
                title: 'السعر',
                value:
                    '${subscription.price.toStringAsFixed(0)} ${subscription.currency}',
              ),
              _InfoRow(
                icon: Icons.calendar_month_outlined,
                title: 'المدة',
                value: '${subscription.durationDays} يوم',
              ),
              _InfoRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'الدفع',
                value: _paymentLabel(subscription.paymentStatus),
              ),
              if (subscription.createdAt != null)
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  title: 'تاريخ الطلب',
                  value: _date(subscription.createdAt),
                ),
              const SizedBox(height: 8),
              _buildActions(subscription),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(OfficeSubscriptionModel subscription) {
    final actions = <Widget>[];
    switch (subscription.status) {
      case 'pending':
        actions.addAll([
          FilledButton.icon(
              onPressed: () => _confirmActivate(subscription),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('تفعيل')),
          OutlinedButton.icon(
              onPressed: () => _confirmCancel(subscription),
              icon: const Icon(Icons.close),
              label: const Text('رفض')),
        ]);
        break;

      case 'active':
        actions.add(OutlinedButton.icon(
            onPressed: () => _confirmSuspend(subscription),
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('إيقاف')));
        break;

      case 'suspended':
        actions.add(FilledButton.icon(
            onPressed: () => _confirmResume(subscription),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('استئناف')));
        break;
    }
    actions.add(IconButton.filledTonal(
      tooltip: 'حذف فعلي',
      onPressed: () => _confirmDelete(subscription),
      icon: const Icon(Icons.delete_forever_outlined),
    ));
    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  Future<void> _confirmDelete(OfficeSubscriptionModel subscription) async {
    final confirmed = await _confirm(
      title: 'حذف الاشتراك نهائيًا',
      message: 'سيُحذف سجل الاشتراك وطلبات الدفع المرتبطة به نهائيًا. '
          'لن يتأثر أي اشتراك أحدث للمكتب. هل تريد المتابعة؟',
      confirmText: 'حذف نهائي',
      isDestructive: true,
    );
    if (confirmed != true) return;
    await _runAction(
      action: () =>
          _service.deleteSubscription(subscriptionId: subscription.id),
      successMessage: 'تم حذف الاشتراك وبيانات الدفع المرتبطة به',
    );
  }

  Future<void> _confirmActivate(
    OfficeSubscriptionModel subscription,
  ) async {
    final confirmed = await _confirm(
      title: 'تفعيل الاشتراك',
      message: 'سيتم تفعيل الباقة "${subscription.packageName}" الآن. '
          'إذا كان للمكتب اشتراك فعّال، ستُضاف مدة الباقة الجديدة إلى '
          'الأيام المتبقية من الاشتراك الحالي',
      confirmText: 'تفعيل',
    );

    if (confirmed != true) {
      return;
    }

    await _runAction(
      action: () => _service.activateSubscription(
        subscriptionId: subscription.id,
      ),
      successMessage: 'تم تفعيل الاشتراك بنجاح',
    );
  }

  Future<void> _confirmResume(
    OfficeSubscriptionModel subscription,
  ) async {
    final confirmed = await _confirm(
      title: 'إعادة تفعيل الاشتراك',
      message: 'هل تريد إعادة تفعيل اشتراك المكتب؟',
      confirmText: 'إعادة التفعيل',
    );

    if (confirmed != true) {
      return;
    }

    await _runAction(
      action: () => _service.resumeSubscription(
        subscriptionId: subscription.id,
      ),
      successMessage: 'تمت إعادة تفعيل الاشتراك بنجاح',
    );
  }

  Future<void> _confirmCancel(
    OfficeSubscriptionModel subscription,
  ) async {
    final confirmed = await _confirm(
      title: 'رفض طلب الاشتراك',
      message: 'هل تريد رفض هذا الطلب؟',
      confirmText: 'رفض الطلب',
      isDestructive: true,
    );

    if (confirmed != true) {
      return;
    }

    await _runAction(
      action: () => _service.cancelSubscription(
        subscriptionId: subscription.id,
      ),
      successMessage: 'تم رفض طلب الاشتراك',
    );
  }

  Future<void> _confirmSuspend(
    OfficeSubscriptionModel subscription,
  ) async {
    final confirmed = await _confirm(
      title: 'إيقاف الاشتراك',
      message: 'سيتم إيقاف اشتراك المكتب الحالي',
      confirmText: 'إيقاف',
      isDestructive: true,
    );

    if (confirmed != true) {
      return;
    }

    await _runAction(
      action: () => _service.suspendSubscription(
        subscriptionId: subscription.id,
      ),
      successMessage: 'تم إيقاف الاشتراك',
    );
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    try {
      await action();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        error.message?.isNotEmpty == true
            ? error.message!
            : 'تعذر تنفيذ العملية',
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showError('حدث خطأ غير متوقع أثناء تنفيذ العملية.');
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      )
                    : null,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmText),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _getPaymentData(
    String subscriptionId,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('subscription_payments')
        .where('subscriptionId', isEqualTo: subscriptionId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return snapshot.docs.first.data();
  }

  Future<String?> _getReceiptUrl(String subscriptionId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('subscription_payments')
        .where('subscriptionId', isEqualTo: subscriptionId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final data = snapshot.docs.first.data();
    final value = data['receiptUrl']?.toString().trim();

    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _showDetails(
    OfficeSubscriptionModel subscription,
    OfficeSubscriptionAdminItem item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _OfficeAvatar(
                        name: item.officeName,
                        imageUrl: item.officeImageUrl,
                        size: 54),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                      item.officeName.isEmpty
                          ? 'تفاصيل الاشتراك'
                          : item.officeName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ))
                  ]),
                  const SizedBox(height: 18),
                  _DetailRow('اسم المكتب',
                      item.officeName.isEmpty ? 'غير متاح' : item.officeName),
                  _DetailRow('معرّف الاشتراك', subscription.id),
                  _DetailRow('معرّف المكتب', subscription.officeId),
                  _DetailRow('صاحب المكتب', subscription.ownerId),
                  _DetailRow('معرّف الباقة', subscription.packageId),
                  _DetailRow(
                    'المدة',
                    '${subscription.durationDays} يوم',
                  ),
                  _DetailRow(
                    'السعر',
                    '${subscription.price.toStringAsFixed(0)} ${subscription.currency}',
                  ),
                  _DetailRow(
                    'حالة الاشتراك',
                    _statusInfo(subscription.status).label,
                  ),
                  _DetailRow(
                    'حالة الدفع',
                    _paymentLabel(subscription.paymentStatus),
                  ),
                  _DetailRow(
                    'طريقة الدفع',
                    subscription.paymentMethod.isEmpty
                        ? 'غير محددة'
                        : subscription.paymentMethod,
                  ),
                  _DetailRow(
                    'مرجع الدفع',
                    subscription.paymentReference.isEmpty
                        ? 'غير موجود'
                        : subscription.paymentReference,
                  ),
                  _DetailRow(
                    'تاريخ البداية',
                    _date(subscription.startDate),
                  ),
                  _DetailRow(
                    'تاريخ الانتهاء',
                    _date(subscription.endDate),
                  ),
                  _DetailRow(
                    'تجديد تلقائي',
                    subscription.autoRenew ? 'مفعّل' : 'غير مفعّل',
                  ),
                  _DetailRow(
                    'الحد الأقصى للعقارات',
                    subscription.maxProperties <= 0
                        ? 'غير محدد'
                        : '${subscription.maxProperties}',
                  ),
                  _DetailRow(
                    'الحد الأقصى للعقارات المميزة',
                    subscription.maxFeaturedProperties <= 0
                        ? 'غير محدد'
                        : '${subscription.maxFeaturedProperties}',
                  ),
                  _DetailRow(
                    'تمييز العقارات',
                    subscription.canFeatureProperties ? 'مسموح' : 'غير مسموح',
                  ),
                  _DetailRow(
                    'الظهور ضمن المكاتب المميزة',
                    subscription.canAppearInFeaturedOffices
                        ? 'مسموح'
                        : 'غير مسموح',
                  ),
                  _DetailRow(
                    'الإحصائيات المتقدمة',
                    subscription.canUseAdvancedStatistics
                        ? 'مسموح'
                        : 'غير مسموح',
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _getPaymentData(subscription.id),
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      if (data == null) {
                        return const SizedBox.shrink();
                      }

                      final paymentMethod =
                          data['paymentMethod']?.toString().trim() ?? '';
                      final notes = data['notes']?.toString().trim() ?? '';
                      final contactPhone =
                          data['contactPhone']?.toString().trim() ?? '';
                      final transactionId =
                          data['transactionId']?.toString().trim() ?? '';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'بيانات طلب الدفع',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            'طريقة الدفع',
                            paymentMethod == 'manual'
                                ? 'تسليم يدوي'
                                : paymentMethod == 'qicard'
                                    ? 'QiCard / خدمات كي'
                                    : paymentMethod.isEmpty
                                        ? 'غير محددة'
                                        : paymentMethod,
                          ),
                          if (contactPhone.isNotEmpty)
                            _DetailRow('رقم الهاتف', contactPhone),
                          if (transactionId.isNotEmpty)
                            _DetailRow('رقم العملية', transactionId),
                          _DetailRow(
                            'ملاحظات صاحب المكتب',
                            notes.isEmpty ? 'لا توجد ملاحظات' : notes,
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                  FutureBuilder<String?>(
                    future: _getReceiptUrl(subscription.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final receiptUrl = snapshot.data;

                      if (receiptUrl == null || receiptUrl.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'لا توجد صورة إيصال مرفوعة',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showReceipt(receiptUrl),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('مشاهدة إيصال الدفع'),
                          ),
                        ),
                      );
                    },
                  ),
                  if (subscription.status == 'pending')
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _confirmActivate(subscription);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('موافقة وتفعيل'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReceipt(String receiptUrl) async {
    if (receiptUrl.trim().isEmpty) {
      _showError('لا توجد صورة إيصال متاحة.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'إيصال الدفع',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.network(
                      receiptUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (
                        context,
                        child,
                        loadingProgress,
                      ) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return const SizedBox(
                          height: 400,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return const SizedBox(
                          height: 300,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'تعذر تحميل صورة الإيصال',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  String _date(DateTime? date) {
    if (date == null) {
      return 'غير محدد';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _paymentLabel(String value) {
    switch (value) {
      case 'paid':
        return 'مدفوع';
      case 'pending':
        return 'قيد المراجعة';
      case 'failed':
        return 'فشل الدفع';
      case 'refunded':
        return 'مسترد';
      case 'cancelled':
        return 'ملغى';
      default:
        return value.isEmpty ? 'غير محدد' : value;
    }
  }

  _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'active':
        return _StatusInfo(
          'فعّال',
          Icons.check_circle_outline,
          Theme.of(context).colorScheme.primary,
        );
      case 'expired':
        return _StatusInfo(
          'منتهي',
          Icons.event_busy_outlined,
          Theme.of(context).colorScheme.error,
        );
      case 'pending':
        return _StatusInfo(
          'قيد المراجعة',
          Icons.hourglass_top_rounded,
          Theme.of(context).colorScheme.tertiary,
        );
      case 'cancelled':
        return _StatusInfo(
          'ملغى',
          Icons.cancel_outlined,
          Theme.of(context).colorScheme.error,
        );
      case 'suspended':
        return _StatusInfo(
          'موقوف',
          Icons.pause_circle_outline,
          Theme.of(context).colorScheme.secondary,
        );
      default:
        return _StatusInfo(
          status.isEmpty ? 'غير محدد' : status,
          Icons.help_outline,
          Theme.of(context).colorScheme.onSurfaceVariant,
        );
    }
  }
}

class _StatusInfo {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusInfo(this.label, this.icon, this.color);
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});
  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),
    );
  }
}

class _OfficeAvatar extends StatelessWidget {
  const _OfficeAvatar({
    required this.name,
    required this.imageUrl,
    this.size = 48,
  });
  final String name;
  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.business_outlined, size: size * .48);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: imageUrl.isEmpty
            ? fallback
            : Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;

  const _DetailRow(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 58),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
