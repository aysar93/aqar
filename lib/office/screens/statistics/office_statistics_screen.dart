import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/office_statistics_model.dart';
import '../../services/office_statistics_service.dart';

class OfficeStatisticsScreen extends StatelessWidget {
  const OfficeStatisticsScreen({
    super.key,
    required this.officeId,
    required this.ownerUid,
  });

  final String officeId;
  final String ownerUid;

  @override
  Widget build(BuildContext context) {
    final isOwner = FirebaseAuth.instance.currentUser?.uid == ownerUid;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'إحصائيات المكتب',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: !isOwner
            ? const _StatisticsMessage(
                icon: Icons.lock_outline_rounded,
                title: 'الوصول غير متاح',
                message: 'ليس لديك صلاحية لعرض الإحصائيات',
              )
            : StreamBuilder<OfficeStatisticsModel>(
                stream: OfficeStatisticsService().watchStatistics(officeId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _StatisticsLoading();
                  }

                  if (snapshot.hasError) {
                    return const _StatisticsMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'تعذر تحميل الإحصائيات',
                      message:
                          'حدثت مشكلة أثناء جلب بيانات المكتب. حاول مرة أخرى',
                    );
                  }

                  final data = snapshot.data;

                  if (data == null) {
                    return const _StatisticsMessage(
                      icon: Icons.analytics_outlined,
                      title: 'لا توجد بيانات بعد',
                      message: 'ستظهر إحصائيات المكتب هنا بعد توفر البيانات',
                    );
                  }

                  return _StatisticsContent(
                    data: data,
                    colorScheme: colorScheme,
                  );
                },
              ),
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({
    required this.data,
    required this.colorScheme,
  });

  final OfficeStatisticsModel data;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final primaryItems = <_Statistic>[
      _Statistic(
        icon: Icons.home_work_rounded,
        label: 'إجمالي العقارات',
        value: data.totalProperties,
        accent: colorScheme.primary,
      ),
      _Statistic(
        icon: Icons.check_circle_rounded,
        label: 'العقارات النشطة',
        value: data.activeProperties,
        accent: Colors.green,
      ),
      _Statistic(
        icon: Icons.pending_actions_rounded,
        label: 'قيد المراجعة',
        value: data.pendingProperties,
        accent: Colors.orange,
      ),
      _Statistic(
        icon: Icons.visibility_rounded,
        label: 'إجمالي المشاهدات',
        value: data.totalViews,
        accent: Colors.blue,
      ),
    ];

    final engagementItems = <_Statistic>[
      _Statistic(
        icon: Icons.people_alt_rounded,
        label: 'المتابعون',
        value: data.followersCount,
        accent: Colors.teal,
      ),
      _Statistic(
        icon: Icons.star_rounded,
        label: 'التقييمات',
        value: data.reviewsCount,
        suffix: ' • ${data.averageRating.toStringAsFixed(1)} ★',
        accent: Colors.amber,
      ),
      _Statistic(
        icon: Icons.phone_rounded,
        label: 'نقرات الهاتف',
        value: data.phoneClicks,
        accent: Colors.indigo,
      ),
      _Statistic(
        icon: Icons.chat_rounded,
        label: 'نقرات واتساب',
        value: data.whatsappClicks,
        accent: Colors.green,
      ),
      _Statistic(
        icon: Icons.location_on_rounded,
        label: 'نقرات الموقع',
        value: data.locationClicks,
        accent: Colors.redAccent,
      ),
      _Statistic(
        icon: Icons.contact_phone_rounded,
        label: 'نقرات التواصل',
        value: data.contactClicks,
        accent: Colors.deepPurple,
      ),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _OverviewHeader(data: data),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(
                title: 'نظرة عامة',
                subtitle: 'أداء العقارات وحركة المشاهدات',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _StatisticCard(item: primaryItems[index]),
                childCount: primaryItems.length,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250,
                mainAxisExtent: 142,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _SectionTitle(
                title: 'تفاعل العملاء',
                subtitle: 'كيف يتفاعل الزوار مع المكتب وبياناته',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _StatisticCard(item: engagementItems[index]),
                childCount: engagementItems.length,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250,
                mainAxisExtent: 142,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.data});

  final OfficeStatisticsModel data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            colorScheme.primary.withValues(alpha: 0.22),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
          ],
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.14),
            ),
            child: Icon(
              Icons.analytics_rounded,
              color: colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أداء مكتبك',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'ملخص سريع لأهم أرقام المكتب والتفاعل مع العقارات',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Icon(
                Icons.star_rounded,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                data.averageRating.toStringAsFixed(1),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 10),
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

class _Statistic {
  const _Statistic({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.suffix = '',
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;
  final String suffix;
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({required this.item});

  final _Statistic item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.accent,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.trending_up_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${item.value}${item.suffix}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsLoading extends StatelessWidget {
  const _StatisticsLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'جاري تحميل الإحصائيات',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StatisticsMessage extends StatelessWidget {
  const _StatisticsMessage({
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
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
    );
  }
}
