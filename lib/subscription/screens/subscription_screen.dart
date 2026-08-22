import 'package:flutter/material.dart';

import '../models/subscription_package_model.dart';
import '../../office/models/office_subscription_model.dart';
import '../../office/services/office_subscription_service.dart';
import 'payment_screen.dart';

/// شاشة الاشتراك الخاصة بالمكتب.
///
/// تعرض:
/// - حالة الاشتراك الحالية.
/// - تاريخ البداية والانتهاء.
/// - الأيام المتبقية.
/// - الباقة الحالية.
/// - الباقات المتاحة.
/// - خيار التجديد.
///
/// هذه الشاشة لا تفترض وجود موظفين.
/// الاشتراك مرتبط بصاحب المكتب مباشرة.
class SubscriptionScreen extends StatefulWidget {
  final String officeId;
  final String ownerUid;

  const SubscriptionScreen({
    super.key,
    required this.officeId,
    required this.ownerUid,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final OfficeSubscriptionService _subscriptionService =
      OfficeSubscriptionService();

  OfficeSubscriptionModel? _subscription;
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    setState(() {
      _loading = true;
    });

    try {
      final subscription = await _subscriptionService.getOfficeSubscription(
        widget.officeId,
      );

      if (!mounted) return;

      setState(() {
        _subscription = subscription;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'تعذر تحميل بيانات الاشتراك',
        isError: true,
      );
    }
  }

  String _currentStatus(OfficeSubscriptionModel subscription) {
    if (subscription.status == 'pending') {
      return 'pending';
    }

    if (subscription.status == 'cancelled') {
      return 'cancelled';
    }

    if (subscription.status == 'suspended') {
      return 'suspended';
    }

    if (subscription.status == 'active') {
      if (subscription.endDate == null) {
        return 'active';
      }

      if (!subscription.endDate!.isAfter(DateTime.now())) {
        return 'expired';
      }

      if (subscription.remainingDays <= 7) {
        return 'expiring_soon';
      }

      return 'active';
    }

    return subscription.status;
  }

  String _statusText(OfficeSubscriptionModel? subscription) {
    if (subscription == null) {
      return 'لا يوجد اشتراك';
    }

    switch (_currentStatus(subscription)) {
      case 'active':
        return 'الاشتراك فعال';
      case 'expiring_soon':
        return 'الاشتراك ينتهي قريبًا';
      case 'pending':
        return 'طلب الاشتراك قيد المراجعة';
      case 'expired':
        return 'الاشتراك منتهي';
      case 'suspended':
        return 'الاشتراك موقوف';
      case 'cancelled':
        return 'طلب الاشتراك مرفوض';
      default:
        return 'حالة غير معروفة';
    }
  }

  Color _statusColor(OfficeSubscriptionModel? subscription) {
    if (subscription == null) {
      return Colors.grey;
    }

    switch (_currentStatus(subscription)) {
      case 'active':
        return Colors.green;
      case 'expiring_soon':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'expired':
      case 'cancelled':
        return Colors.red;
      case 'suspended':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(OfficeSubscriptionModel? subscription) {
    if (subscription == null) {
      return Icons.info_outline;
    }

    switch (_currentStatus(subscription)) {
      case 'active':
        return Icons.verified_rounded;
      case 'expiring_soon':
        return Icons.warning_amber_rounded;
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'expired':
        return Icons.event_busy_rounded;
      case 'suspended':
        return Icons.pause_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'غير محدد';
    }

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    return '$year/$month/$day';
  }

  String _formatPrice(
    double price,
    String currency,
  ) {
    final value = price.toStringAsFixed(0);

    return '$value $currency';
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _openPackages() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PackagesPlaceholderScreen(
          officeId: widget.officeId,
          ownerUid: widget.ownerUid,
          currentSubscription: _subscription,
          subscriptionService: _subscriptionService,
        ),
      ),
    );

    await _loadSubscription();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'اشتراك المكتب',
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadSubscription,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCurrentSubscriptionCard(),
                  const SizedBox(height: 20),
                  _buildSubscriptionActions(),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentSubscriptionCard() {
    final subscription = _subscription;

    if (subscription == null) {
      return _buildNoSubscriptionCard();
    }

    final statusColor = _statusColor(subscription);

    final statusText = _statusText(subscription);

    final remainingDays = subscription.remainingDays;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: 0.12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _statusIcon(subscription),
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.packageName.isEmpty
                            ? 'اشتراك المكتب'
                            : subscription.packageName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.play_circle_outline,
              title: 'تاريخ البداية',
              value: _formatDate(
                subscription.startDate,
              ),
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.event_outlined,
              title: 'تاريخ الانتهاء',
              value: _formatDate(
                subscription.endDate,
              ),
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.hourglass_bottom_rounded,
              title: 'المدة المتبقية',
              value: remainingDays == 0 ? 'منتهية' : '$remainingDays يوم',
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.payments_outlined,
              title: 'قيمة الاشتراك',
              value: _formatPrice(
                subscription.price,
                subscription.currency,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSubscriptionCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.card_membership_outlined,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد اشتراك حالي',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'اختر إحدى الباقات المتاحة لتفعيل صفحة مكتبك ومزايا الاشتراك',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _processing ? null : _openPackages,
                icon: const Icon(
                  Icons.workspace_premium_outlined,
                ),
                label: const Text(
                  'عرض الباقات',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionActions() {
    final subscription = _subscription;

    final status = subscription == null ? 'none' : _currentStatus(subscription);

    final isPending = status == 'pending';
    final isExpired = status == 'expired';
    final isUsable = status == 'active' || status == 'expiring_soon';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: (_processing || isPending) ? null : _openPackages,
          icon: const Icon(Icons.workspace_premium_outlined),
          label: Text(
            isPending
                ? 'طلب الاشتراك قيد المراجعة'
                : isExpired
                    ? 'تجديد الاشتراك'
                    : 'عرض الباقات والترقية',
          ),
        ),
        if (isUsable) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _processing ? null : _openPackages,
            icon: const Icon(Icons.autorenew_rounded),
            label: const Text('تجديد أو تغيير الباقة'),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                ),
                const SizedBox(width: 10),
                Text(
                  'معلومات الاشتراك',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'يتم احتساب انتهاء الاشتراك تلقائيًا اعتمادًا على تاريخ الانتهاء المحدد عند إنشاء الاشتراك',
            ),
            const SizedBox(height: 8),
            const Text(
              'عند انتهاء المدة، يتوقف اعتبار الاشتراك فعالًا حتى يتم تجديده',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
        ),
        const SizedBox(width: 12),
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
}

/// شاشة مؤقتة للباقات.
///
/// سيتم لاحقًا استبدالها بملف:
/// subscription/screens/packages_screen.dart
///
/// وضعناها مؤقتًا حتى لا نربط شاشة الاشتراك
/// بملفات لم ننشئها بعد.
class _PackagesPlaceholderScreen extends StatelessWidget {
  final String officeId;
  final String ownerUid;
  final OfficeSubscriptionModel? currentSubscription;
  final OfficeSubscriptionService subscriptionService;

  const _PackagesPlaceholderScreen({
    required this.officeId,
    required this.ownerUid,
    required this.currentSubscription,
    required this.subscriptionService,
  });

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
        stream: subscriptionService.watchActivePackages(),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'تعذر تحميل الباقات',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            );
          }

          final packages = snapshot.data ?? [];

          if (packages.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد باقات متاحة حاليًا',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: packages.length,
            separatorBuilder: (
              context,
              index,
            ) =>
                const SizedBox(height: 12),
            itemBuilder: (
              context,
              index,
            ) {
              final package = packages[index];

              return Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              package.name,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (package.isFeatured)
                            const Icon(
                              Icons.star_rounded,
                            ),
                        ],
                      ),
                      if (package.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          package.description,
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        '${package.price.toStringAsFixed(0)} ${package.currency}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'مدة الاشتراك: ${package.durationDays} يوم',
                      ),
                      const SizedBox(height: 14),
                      if (package.features.isNotEmpty)
                        ...package.features.map(
                          (feature) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: 5,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  Expanded(
                                    child: Text(
                                      feature,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final result =
                                await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => PaymentScreen(
                                  officeId: officeId,
                                  ownerUid: ownerUid,
                                  package: package,
                                  currentSubscription: currentSubscription,
                                ),
                              ),
                            );

                            if (result == true && context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                          child: Text(
                            currentSubscription == null
                                ? 'اختيار الباقة'
                                : 'اختيار / تجديد',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
