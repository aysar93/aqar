import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/office_subscription_model.dart';
import 'office_packages_screen.dart';

class OfficeSubscriptionScreen extends StatelessWidget {
  const OfficeSubscriptionScreen({
    super.key,
    required this.officeId,
    required this.ownerUid,
  });

  final String officeId;
  final String ownerUid;

  @override
  Widget build(BuildContext context) {
    final isOwner = FirebaseAuth.instance.currentUser?.uid == ownerUid;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اشتراك المكتب'),
          centerTitle: true,
        ),
        body: !isOwner
            ? const _SubscriptionMessage(
                'ليس لديك صلاحية لعرض الاشتراك',
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('office_subscriptions')
                    .where('officeId', isEqualTo: officeId)
                    .where('ownerId', isEqualTo: ownerUid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return const _SubscriptionMessage(
                      'تعذر تحميل اشتراكات المكتب',
                    );
                  }

                  final subscriptions = snapshot.data?.docs
                          .map(OfficeSubscriptionModel.fromFirestore)
                          .toList() ??
                      [];

                  if (subscriptions.isEmpty) {
                    return _NoSubscription(
                      officeId: officeId,
                      ownerUid: ownerUid,
                    );
                  }

                  subscriptions.sort((a, b) {
                    final aDate = a.updatedAt ??
                        a.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bDate = b.updatedAt ??
                        b.createdAt ??
                        DateTime.fromMillisecondsSinceEpoch(0);

                    return bDate.compareTo(aDate);
                  });

                  final activeSubscription =
                      _findLatest(subscriptions, 'active');
                  final pendingSubscription =
                      _findLatest(subscriptions, 'pending');
                  final currentSubscription = activeSubscription ??
                      pendingSubscription ??
                      subscriptions.first;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SubscriptionCard(
                        subscription: currentSubscription,
                        title: activeSubscription != null
                            ? 'الاشتراك الحالي'
                            : 'حالة الاشتراك',
                      ),
                      if (pendingSubscription != null &&
                          pendingSubscription.id != activeSubscription?.id) ...[
                        const SizedBox(height: 14),
                        _SubscriptionCard(
                          subscription: pendingSubscription,
                          title: 'طلب اشتراك قيد المراجعة',
                        ),
                      ],
                      const SizedBox(height: 14),
                      _buildActionCard(
                        context,
                        activeSubscription: activeSubscription,
                        pendingSubscription: pendingSubscription,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required OfficeSubscriptionModel? activeSubscription,
    required OfficeSubscriptionModel? pendingSubscription,
  }) {
    final hasPending = pendingSubscription != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              hasPending
                  ? Icons.hourglass_top_rounded
                  : Icons.workspace_premium_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              hasPending
                  ? 'لديك طلب اشتراك قيد المراجعة'
                  : activeSubscription != null
                      ? 'يمكنك اختيار باقة جديدة للتجديد'
                      : 'ابدأ اشتراك مكتبك',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasPending
                  ? 'سيتم تفعيل الطلب بعد مراجعة الإدارة وتأكيد الدفع.'
                  : 'اختر الباقة المناسبة، ثم أرسل طلب الاشتراك ليتم مراجعته من الإدارة',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: hasPending
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OfficePackagesScreen(
                              officeId: officeId,
                              ownerUid: ownerUid,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text(
                  hasPending
                      ? 'بانتظار مراجعة الإدارة'
                      : activeSubscription != null
                          ? 'عرض باقات التجديد'
                          : 'عرض الباقات',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static OfficeSubscriptionModel? _findLatest(
    List<OfficeSubscriptionModel> subscriptions,
    String status,
  ) {
    final matching = subscriptions
        .where((subscription) => subscription.status == status)
        .toList();

    if (matching.isEmpty) {
      return null;
    }

    matching.sort((a, b) {
      final aDate =
          a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return matching.first;
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.subscription,
    required this.title,
  });

  final OfficeSubscriptionModel subscription;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _StatusChip(status: subscription.status),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              subscription.packageName.isEmpty
                  ? 'اشتراك المكتب'
                  : subscription.packageName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            _SubscriptionRow(
              'السعر',
              '${subscription.price.toStringAsFixed(0)} ${subscription.currency}',
            ),
            _SubscriptionRow(
              'حالة الدفع',
              _paymentStatusLabel(subscription.paymentStatus),
            ),
            _SubscriptionRow(
              'تاريخ البداية',
              _date(subscription.startDate),
            ),
            _SubscriptionRow(
              'تاريخ الانتهاء',
              _date(subscription.endDate),
            ),
            if (subscription.status == 'active' &&
                subscription.endDate != null) ...[
              const Divider(height: 22),
              _SubscriptionRow(
                'الأيام المتبقية',
                _remainingDays(subscription.endDate!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _date(DateTime? date) {
    if (date == null) return 'غير محدد';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  static String _remainingDays(DateTime endDate) {
    final difference = endDate.difference(DateTime.now());

    if (difference.isNegative || difference.inDays < 0) {
      return 'منتهي';
    }

    return '${difference.inDays} يوم';
  }

  static String _paymentStatusLabel(String status) {
    return switch (status) {
      'paid' => 'مدفوع',
      'pending' => 'بانتظار الدفع',
      'failed' => 'فشل الدفع',
      'refunded' => 'مسترد',
      'cancelled' => 'ملغى',
      _ => status.isEmpty ? 'غير محدد' : status,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(_statusLabel(status)),
      avatar: Icon(_statusIcon(status), size: 18),
    );
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'active' => 'فعّال',
      'expired' => 'منتهي',
      'pending' => 'قيد المراجعة',
      'cancelled' => 'ملغى',
      'suspended' => 'موقوف',
      _ => status.isEmpty ? 'غير محدد' : status,
    };
  }

  static IconData _statusIcon(String status) {
    return switch (status) {
      'active' => Icons.check_circle_outline,
      'expired' => Icons.event_busy_outlined,
      'pending' => Icons.hourglass_top_outlined,
      'cancelled' => Icons.cancel_outlined,
      'suspended' => Icons.pause_circle_outline,
      _ => Icons.info_outline,
    };
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow(this.title, this.value);

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Flexible(
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSubscription extends StatelessWidget {
  const _NoSubscription({
    required this.officeId,
    required this.ownerUid,
  });

  final String officeId;
  final String ownerUid;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_outlined, size: 58),
            const SizedBox(height: 14),
            const Text(
              'لا يوجد اشتراك أو طلب اشتراك لهذا المكتب',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OfficePackagesScreen(
                      officeId: officeId,
                      ownerUid: ownerUid,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('عرض الباقات'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionMessage extends StatelessWidget {
  const _SubscriptionMessage(this.message);

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
