import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/office_model.dart';
import '../models/office_statistics_model.dart';
import '../services/office_service.dart';
import '../services/office_statistics_service.dart';
import 'edit/edit_office_screen.dart';
import 'followers/office_followers_screen.dart';
import 'office_profile_screen.dart';
import 'properties/office_properties_screen.dart';
import 'reviews/office_reviews_screen.dart';
import 'statistics/office_statistics_screen.dart';
import 'subscription/office_subscription_screen.dart';

/// لوحة تحكم صاحب المكتب.
/// تستمد المكتب حصراً من حساب المستخدم الحالي.
class OfficeDashboard extends StatelessWidget {
  const OfficeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _OfficeDashboardMessage(
        icon: Icons.lock_outline_rounded,
        title: 'تسجيل الدخول مطلوب',
        message: 'يرجى تسجيل الدخول للوصول إلى لوحة المكتب',
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<OfficeModel?>(
        stream: OfficeService.myOfficeStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _DashboardLoading();
          }

          if (snapshot.hasError) {
            return const _OfficeDashboardMessage(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل المكتب',
              message: 'حدثت مشكلة أثناء تحميل بيانات المكتب. حاول مرة أخرى',
            );
          }

          final office = snapshot.data;

          if (office == null) {
            return const _OfficeDashboardMessage(
              icon: Icons.business_outlined,
              title: 'لا يوجد مكتب',
              message: 'لا يوجد مكتب مرتبط بحسابك حتى الآن',
            );
          }

          if (office.ownerId != user.uid) {
            return const _OfficeDashboardMessage(
              icon: Icons.lock_outline_rounded,
              title: 'الوصول غير متاح',
              message: 'ليس لديك صلاحية الوصول إلى هذا المكتب',
            );
          }

          return _OfficeDashboardBody(
            office: office,
            ownerUid: user.uid,
          );
        },
      ),
    );
  }
}

class _OfficeDashboardBody extends StatelessWidget {
  const _OfficeDashboardBody({
    required this.office,
    required this.ownerUid,
  });

  final OfficeModel office;
  final String ownerUid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'لوحة تحكم المكتب',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<OfficeStatisticsModel>(
        stream: OfficeStatisticsService().watchStatistics(office.id),
        builder: (context, snapshot) {
          final statistics = snapshot.data;

          final propertiesCount =
              statistics?.totalProperties ?? office.propertiesCount;
          final viewsCount = statistics?.totalViews ?? 0;
          final followersCount =
              statistics?.followersCount ?? office.followersCount;
          final reviewsCount = statistics?.reviewsCount ?? 0;
          final averageRating = statistics?.averageRating ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(
                const Duration(milliseconds: 350),
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              children: [
                _DashboardHeader(
                  office: office,
                ),
                const SizedBox(height: 14),
                _PreviewOfficeButton(
                  onTap: () => _open(
                    context,
                    OfficeProfileScreen(
                      officeId: office.id,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionHeader(
                  title: 'أداء المكتب',
                  subtitle: 'ملخص سريع لأهم مؤشرات مكتبك',
                  icon: Icons.insights_rounded,
                ),
                const SizedBox(height: 10),
                _StatisticsGrid(
                  children: [
                    _MetricCard(
                      icon: Icons.home_work_rounded,
                      label: 'إجمالي العقارات',
                      value: '$propertiesCount',
                      accent: colorScheme.primary,
                    ),
                    _MetricCard(
                      icon: Icons.visibility_rounded,
                      label: 'إجمالي المشاهدات',
                      value: '$viewsCount',
                      accent: Colors.blue,
                    ),
                    _MetricCard(
                      icon: Icons.people_alt_rounded,
                      label: 'المتابعون',
                      value: '$followersCount',
                      accent: Colors.teal,
                    ),
                    _MetricCard(
                      icon: Icons.star_rounded,
                      label: 'التقييمات',
                      value: averageRating > 0
                          ? averageRating.toStringAsFixed(1)
                          : '0',
                      extra: '$reviewsCount تقييم',
                      accent: Colors.amber.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'إدارة المكتب',
                  subtitle: 'جميع أدوات الإدارة في مكان واحد',
                  icon: Icons.dashboard_customize_rounded,
                ),
                const SizedBox(height: 10),
                _ManagementGrid(
                  children: [
                    _DashboardAction(
                      icon: Icons.edit_rounded,
                      label: 'تعديل البيانات',
                      subtitle: 'تحديث معلومات المكتب',
                      accent: Colors.indigo,
                      onTap: () => _open(
                        context,
                        EditOfficeScreen(
                          officeId: office.id,
                          ownerUid: ownerUid,
                        ),
                      ),
                    ),
                    _DashboardAction(
                      icon: Icons.home_work_rounded,
                      label: 'عقارات المكتب',
                      subtitle: 'إدارة عقارات المكتب وتمييزها',
                      accent: colorScheme.primary,
                      onTap: () => _open(
                        context,
                        OfficePropertiesScreen(
                          officeId: office.id,
                          ownerUid: ownerUid,
                        ),
                      ),
                    ),
                    _DashboardAction(
                      icon: Icons.people_alt_rounded,
                      label: 'المتابعون',
                      subtitle: 'عرض وإدارة متابعي المكتب',
                      accent: Colors.teal,
                      onTap: () => _open(
                        context,
                        OfficeFollowersScreen(
                          officeId: office.id,
                          ownerUid: ownerUid,
                        ),
                      ),
                    ),
                    _DashboardAction(
                      icon: Icons.rate_review_rounded,
                      label: 'المراجعات والتقييمات',
                      subtitle: 'متابعة تقييمات العملاء',
                      accent: Colors.amber.shade700,
                      onTap: () => _open(
                        context,
                        OfficeReviewsScreen(
                          officeId: office.id,
                          ownerUid: ownerUid,
                        ),
                      ),
                    ),
                    _DashboardAction(
                      icon: Icons.analytics_rounded,
                      label: 'الإحصائيات',
                      subtitle: 'المشاهدات والنقرات والأداء',
                      accent: Colors.blue,
                      featured: true,
                      onTap: () => _open(
                        context,
                        OfficeStatisticsScreen(
                          officeId: office.id,
                          ownerUid: ownerUid,
                        ),
                      ),
                    ),
                    _DashboardAction(
                      icon: Icons.workspace_premium_rounded,
                      label: 'الاشتراك والباقة',
                      subtitle: 'الباقة والمزايا والاستخدام',
                      accent: Colors.deepPurple,
                      onTap: () => _open(
                        context,
                        OfficeSubscriptionScreen(
                          officeId: office.id,
                          ownerUid: ownerUid,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.office,
  });

  final OfficeModel office;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = office.status == 'active'
        ? Colors.green
        : office.status == 'rejected'
            ? Colors.red
            : Colors.orange;

    final statusText = office.status == 'active'
        ? 'المكتب منشور'
        : office.status == 'rejected'
            ? 'المكتب مرفوض'
            : 'قيد المراجعة';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            colorScheme.primary.withValues(alpha: 0.20),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
          ],
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  Icons.business_rounded,
                  size: 25,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      office.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'إدارة مكتبك العقاري',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                office.isVerified
                    ? Icons.verified_rounded
                    : Icons.business_rounded,
                color: office.isVerified ? Colors.blue : colorScheme.primary,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: statusText,
                icon: office.status == 'active'
                    ? Icons.check_circle_rounded
                    : Icons.pending_rounded,
                color: statusColor,
              ),
              _StatusChip(
                label: office.isVerified ? 'مكتب موثّق' : 'غير موثّق',
                icon: office.isVerified
                    ? Icons.verified_rounded
                    : Icons.info_outline_rounded,
                color: office.isVerified ? Colors.blue : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewOfficeButton extends StatelessWidget {
  const _PreviewOfficeButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                colorScheme.primary.withValues(alpha: 0.16),
                colorScheme.primary.withValues(alpha: 0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.visibility_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'معاينة المكتب',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'عرض صفحة المكتب كما تظهر للمستخدمين',
                      softWrap: true,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: colorScheme.primary,
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatisticsGrid extends StatelessWidget {
  const _StatisticsGrid({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: children.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 104,
      ),
      itemBuilder: (_, index) => children[index],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.extra = '',
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String extra;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.50),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    softWrap: true,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                  ),
                  if (extra.isNotEmpty)
                    Text(
                      extra,
                      softWrap: true,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.2,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagementGrid extends StatelessWidget {
  const _ManagementGrid({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.featured = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: featured
                  ? accent.withValues(alpha: 0.32)
                  : colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      softWrap: true,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      softWrap: true,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 14),
              const Text('جاري تحميل لوحة المكتب...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficeDashboardMessage extends StatelessWidget {
  const _OfficeDashboardMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withValues(alpha: 0.11),
                    ),
                    child: Icon(
                      icon,
                      size: 34,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
