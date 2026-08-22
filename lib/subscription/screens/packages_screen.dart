import 'package:flutter/material.dart';

import '../models/subscription_package_model.dart';
import '../../office/models/office_subscription_model.dart';
import '../../office/services/office_subscription_service.dart';
import 'payment_screen.dart';

/// شاشة باقات اشتراك المكاتب.
///
/// تعرض الباقات التي فعلتها الإدارة فقط.
/// صاحب المكتب يستطيع اختيار الباقة المناسبة له.
///
/// لاحقًا سنربط زر الاختيار بنظام طلب الاشتراك
/// والدفع واعتماد الإدارة.
class PackagesScreen extends StatefulWidget {
  final String officeId;
  final String ownerUid;

  final OfficeSubscriptionModel? currentSubscription;

  const PackagesScreen({
    super.key,
    required this.officeId,
    required this.ownerUid,
    this.currentSubscription,
  });

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final OfficeSubscriptionService _service = OfficeSubscriptionService();

  String? _selectedPackageId;
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'باقات الاشتراك',
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<SubscriptionPackageModel>>(
        stream: _service.watchActivePackages(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildError();
          }

          final packages = snapshot.data ?? [];

          if (packages.isEmpty) {
            return _buildEmpty();
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                32,
              ),
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                ...packages.map(
                  _buildPackageCard,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════
  // رأس الصفحة
  // ═════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 46,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'اختر الباقة المناسبة لمكتبك',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'استفد من مزايا المكتب والعقارات والإحصائيات حسب الباقة التي تختارها',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // بطاقة الباقة
  // ═════════════════════════════════════════════

  Widget _buildPackageCard(
    SubscriptionPackageModel package,
  ) {
    final isCurrent = widget.currentSubscription?.packageId == package.id;

    final isSelected = _selectedPackageId == package.id;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected || isCurrent
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor.withValues(alpha: 0.5),
            width: isSelected || isCurrent ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPackageHeader(
                package,
                isCurrent,
              ),
              const SizedBox(height: 16),
              _buildPrice(
                package,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _buildPackageLimits(
                package,
              ),
              const SizedBox(height: 14),
              _buildFeatures(
                package,
              ),
              const SizedBox(height: 18),
              _buildSelectButton(
                package,
                isCurrent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageHeader(
    SubscriptionPackageModel package,
    bool isCurrent,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      package.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (package.isFeatured) ...[
                    const SizedBox(width: 8),
                    _buildSmallBadge(
                      icon: Icons.star_rounded,
                      text: 'مميزة',
                    ),
                  ],
                ],
              ),
              if (package.description.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  package.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (isCurrent)
          _buildSmallBadge(
            icon: Icons.check_circle_rounded,
            text: 'الحالية',
          ),
      ],
    );
  }

  Widget _buildSmallBadge({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // السعر
  // ═════════════════════════════════════════════

  Widget _buildPrice(
    SubscriptionPackageModel package,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          package.price.toStringAsFixed(0),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(width: 7),
        Padding(
          padding: const EdgeInsets.only(
            bottom: 4,
          ),
          child: Text(
            package.currency,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${package.durationDays} يوم',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // الحدود
  // ═════════════════════════════════════════════

  Widget _buildPackageLimits(
    SubscriptionPackageModel package,
  ) {
    return Column(
      children: [
        _buildLimitRow(
          icon: Icons.home_work_outlined,
          title: 'العقارات',
          value: package.maxProperties == null
              ? 'غير محدود'
              : '${package.maxProperties}',
        ),
        const SizedBox(height: 9),
        _buildLimitRow(
          icon: Icons.star_border_rounded,
          title: 'العقارات المميزة',
          value: package.maxFeaturedProperties == null
              ? package.featuredPropertiesEnabled
                  ? 'غير محدود'
                  : 'غير متاح'
              : '${package.maxFeaturedProperties}',
        ),
        const SizedBox(height: 9),
        _buildLimitRow(
          icon: Icons.photo_library_outlined,
          title: 'الصور لكل عقار',
          value: package.maxImagesPerProperty == null
              ? 'غير محدود'
              : '${package.maxImagesPerProperty}',
        ),
      ],
    );
  }

  Widget _buildLimitRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // المزايا
  // ═════════════════════════════════════════════

  Widget _buildFeatures(
    SubscriptionPackageModel package,
  ) {
    final features = <String>[
      ...package.features,
    ];

    if (package.statisticsEnabled) {
      features.add(
        'إحصائيات المكتب',
      );
    }

    if (package.officeProfileEnabled) {
      features.add(
        'صفحة مكتب متكاملة',
      );
    }

    if (package.featuredPropertiesEnabled) {
      features.add(
        'إمكانية إبراز العقارات',
      );
    }

    if (package.featuredOfficeEnabled) {
      features.add(
        'إظهار المكتب ضمن المكاتب المميزة',
      );
    }

    if (package.verifiedBadgeEnabled) {
      features.add(
        'دعم شارة التوثيق',
      );
    }

    if (features.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مزايا الباقة',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        ...features.map(
          (feature) => Padding(
            padding: const EdgeInsets.only(
              bottom: 7,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // زر اختيار الباقة
  // ═════════════════════════════════════════════

  Widget _buildSelectButton(
    SubscriptionPackageModel package,
    bool isCurrent,
  ) {
    final isSelected = _selectedPackageId == package.id;

    return SizedBox(
      width: double.infinity,
      child: isSelected
          ? FilledButton.icon(
              onPressed: _processing
                  ? null
                  : () => _confirmPackage(
                        package,
                      ),
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_forward_rounded,
                    ),
              label: Text(
                isCurrent ? 'تجديد بهذه الباقة' : 'متابعة بهذه الباقة',
              ),
            )
          : OutlinedButton(
              onPressed: _processing
                  ? null
                  : () {
                      setState(() {
                        _selectedPackageId = package.id;
                      });
                    },
              child: Text(
                isCurrent ? 'اختيار الباقة الحالية' : 'اختيار الباقة',
              ),
            ),
    );
  }

  // ═════════════════════════════════════════════
  // تأكيد الاختيار
  // ═════════════════════════════════════════════

  Future<void> _confirmPackage(
    SubscriptionPackageModel package,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'تأكيد الباقة',
          ),
          content: Text(
            'هل تريد المتابعة مع باقة "${package.name}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                false,
              ),
              child: const Text(
                'إلغاء',
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                true,
              ),
              child: const Text(
                'متابعة للدفع',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          officeId: widget.officeId,
          ownerUid: widget.ownerUid,
          package: package,
          currentSubscription: widget.currentSubscription,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  // ═════════════════════════════════════════════
  // حالات الصفحة
  // ═════════════════════════════════════════════

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد باقات متاحة حاليًا',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم عرض الباقات هنا عندما تقوم الإدارة بتفعيلها',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 58,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            const Text(
              'تعذر تحميل الباقات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تأكد من الاتصال بقاعدة البيانات ثم حاول مرة أخرى',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
