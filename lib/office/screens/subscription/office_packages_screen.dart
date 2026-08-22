import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/office_subscription_service.dart';
import '../../../subscription/models/subscription_package_model.dart';
import '../../../subscription/screens/payment_screen.dart';

/// شاشة باقات اشتراك المكتب.
///
/// صاحب المكتب يختار الباقة ويرسل طلب اشتراك فقط.
/// لا يتم تفعيل الاشتراك من هذه الشاشة.
/// بعد الإرسال يبقى الطلب pending حتى تتم مراجعته
/// وتفعيله من الإدارة.
class OfficePackagesScreen extends StatefulWidget {
  final String officeId;
  final String ownerUid;

  const OfficePackagesScreen({
    super.key,
    required this.officeId,
    required this.ownerUid,
  });

  @override
  State<OfficePackagesScreen> createState() => _OfficePackagesScreenState();
}

class _OfficePackagesScreenState extends State<OfficePackagesScreen> {
  final OfficeSubscriptionService _subscriptionService =
      OfficeSubscriptionService();

  String? _selectedPackageId;
  bool _isLoading = false;

  final List<_OfficePackage> _packages = [
    const _OfficePackage(
      id: 'basic',
      name: 'الباقة الأساسية',
      description: 'مناسبة للمكاتب التي تريد إنشاء حضور احترافي على منصة عقار',
      price: 25000,
      durationDays: 30,
      isPopular: false,
      maxProperties: 25,
      maxFeaturedProperties: 3,
      canFeatureProperties: false,
      canAppearInFeaturedOffices: false,
      canUseAdvancedStatistics: false,
      features: [
        'صفحة مكتب احترافية',
        'إضافة حتى 25 عقارًا',
        'حتى 3 عقارات مميزة',
        'ظهور عقارات المكتب في المنصة',
        'استقبال المتابعين',
        'التقييمات',
        'إحصائيات أساسية',
      ],
    ),
    const _OfficePackage(
      id: 'professional',
      name: 'الباقة الاحترافية',
      description: 'مناسبة للمكاتب النشطة التي تريد ظهورًا أفضل وإمكانيات أوسع',
      price: 50000,
      durationDays: 90,
      isPopular: true,
      maxProperties: 60,
      maxFeaturedProperties: 7,
      canFeatureProperties: true,
      canAppearInFeaturedOffices: true,
      canUseAdvancedStatistics: true,
      features: [
        'جميع مزايا الباقة الأساسية',
        'إضافة حتى 60 عقارًا',
        'حتى 7 عقارات مميزة',
        'إمكانية تمييز العقارات',
        'إحصائيات متقدمة',
        'ظهور أفضل للمكتب',
        'دعم أولوية',
      ],
    ),
    const _OfficePackage(
      id: 'premium',
      name: 'الباقة المميزة',
      description: 'الخيار المتقدم للمكاتب التي تريد أقصى استفادة من المنصة',
      price: 100000,
      durationDays: 180,
      isPopular: false,
      maxProperties: 150,
      maxFeaturedProperties: 15,
      canFeatureProperties: true,
      canAppearInFeaturedOffices: true,
      canUseAdvancedStatistics: true,
      features: [
        'جميع مزايا الباقة الاحترافية',
        'إضافة حتى 150 عقارًا',
        'حتى 15 عقارًا مميزًا',
        'مزايا ظهور متقدمة',
        'إحصائيات موسعة',
        'مزايا تسويقية إضافية',
        'أولوية في الدعم',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.ownerUid;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('باقات المكتب'),
          centerTitle: true,
        ),
        body: !isOwner
            ? const _PermissionMessage(
                'ليس لديك صلاحية لطلب اشتراك لهذا المكتب',
              )
            : RefreshIndicator(
                onRefresh: _reloadPackages,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 35),
                  children: [
                    _buildIntro(),
                    const SizedBox(height: 20),
                    ..._packages.map(
                      (package) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildPackageCard(package),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildImportantNotice(),
                    const SizedBox(height: 20),
                    _buildContinueButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر الباقة المناسبة لمكتبك',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'اختر مدة ومزايا الاشتراك التي تناسب نشاط مكتبك العقاري',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildPackageCard(_OfficePackage package) {
    final selected = _selectedPackageId == package.id;

    return InkWell(
      borderRadius: BorderRadius.circular(25),
      onTap: _isLoading
          ? null
          : () {
              setState(() {
                _selectedPackageId = package.id;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPackageHeader(package, selected),
            const SizedBox(height: 16),
            Text(
              package.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            _buildPrice(package),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 14),
            _buildFeatures(package),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageHeader(
    _OfficePackage package,
    bool selected,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  package.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (package.isPopular) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                  ),
                  child: Text(
                    'الأكثر طلبًا',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
              width: 2,
            ),
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: 17,
                  color: Theme.of(context).colorScheme.onPrimary,
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildPrice(_OfficePackage package) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _formatPrice(package.price),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(width: 7),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            'د.ع',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
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
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.55),
          ),
          child: Text(
            _durationText(package.durationDays),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
  }

  String _durationText(int days) {
    if (days == 30) {
      return '30 يوم';
    }

    if (days == 90) {
      return '3 أشهر';
    }

    if (days == 180) {
      return '6 أشهر';
    }

    if (days == 365) {
      return 'سنة';
    }

    return '$days يوم';
  }

  Widget _buildFeatures(_OfficePackage package) {
    return Column(
      children: package.features
          .map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildImportantNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'بعد إرسال الطلب تتم مراجعته من الإدارة. تبدأ مدة الاشتراك من تاريخ التفعيل الفعلي، ولا يستطيع صاحب المكتب تفعيل الاشتراك بنفسه',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    final hasSelection = _selectedPackageId != null;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: hasSelection && !_isLoading ? _continue : null,
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                hasSelection ? 'متابعة للدفع' : 'اختر باقة أولًا',
              ),
      ),
    );
  }

  Future<void> _continue() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid != widget.ownerUid) {
      _showMessage('ليس لديك صلاحية لطلب اشتراك لهذا المكتب.');
      return;
    }

    final selectedId = _selectedPackageId;

    if (selectedId == null) {
      _showMessage('اختر باقة أولًا.');
      return;
    }

    final officePackage = _packages.firstWhere(
      (item) => item.id == selectedId,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      final pendingExists =
          await _subscriptionService.hasPendingSubscriptionRequest(
        officeId: widget.officeId,
        ownerId: currentUser.uid,
      );

      if (pendingExists) {
        if (!mounted) {
          return;
        }

        _showMessage(
          'يوجد طلب اشتراك قيد المراجعة لهذا المكتب بالفعل',
        );
        return;
      }

      final package = _toSubscriptionPackage(officePackage);

      if (!mounted) {
        return;
      }

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            officeId: widget.officeId,
            ownerUid: widget.ownerUid,
            package: package,
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message?.isNotEmpty == true
            ? error.message!
            : 'تعذر التحقق من حالة طلب الاشتراك',
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('حدث خطأ غير متوقع. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  SubscriptionPackageModel _toSubscriptionPackage(
    _OfficePackage package,
  ) {
    return SubscriptionPackageModel(
      id: package.id,
      name: package.name,
      description: package.description,
      price: package.price,
      currency: 'IQD',
      durationDays: package.durationDays,
      isActive: true,
      isFeatured: package.isPopular,
      sortOrder: 0,
      maxProperties: package.maxProperties,
      maxFeaturedProperties: package.maxFeaturedProperties,
      maxImagesPerProperty: null,
      features: package.features,
      statisticsEnabled: package.canUseAdvancedStatistics,
      officeProfileEnabled: true,
      featuredPropertiesEnabled: package.canFeatureProperties,
      featuredOfficeEnabled: package.canAppearInFeaturedOffices,
      verifiedBadgeEnabled: false,
      createdAt: null,
      updatedAt: null,
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
  }

  Future<void> _reloadPackages() async {
    // الباقات الحالية معرفة داخل الشاشة.
    // عند نقلها لاحقًا إلى Firestore يمكن استبدال هذه الدالة
    // بجلب الباقات من مجموعة subscription_packages.
    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );
  }
}

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _OfficePackage {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationDays;
  final bool isPopular;
  final List<String> features;

  final int maxProperties;
  final int maxFeaturedProperties;
  final bool canFeatureProperties;
  final bool canAppearInFeaturedOffices;
  final bool canUseAdvancedStatistics;

  const _OfficePackage({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    required this.isPopular,
    required this.features,
    required this.maxProperties,
    required this.maxFeaturedProperties,
    required this.canFeatureProperties,
    required this.canAppearInFeaturedOffices,
    required this.canUseAdvancedStatistics,
  });
}
