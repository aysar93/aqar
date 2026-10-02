import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';
import '../services/app_activity_service.dart';
import '../widgets/analytics_widgets.dart';
import 'activity_users_screen.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({
    super.key,
    this.service,
    this.onlineCounts,
    this.serverNow,
  });
  final AnalyticsService? service;
  final Stream<int> Function()? onlineCounts;
  final Future<DateTime> Function()? serverNow;

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  late final AnalyticsService _service;
  AnalyticsPeriod _period = AnalyticsPeriod.last24Hours;
  late Future<(AnalyticsSummary, List<ChartPoint>)> _data;
  Stream<int>? _onlineStream;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AnalyticsService();
    _onlineStream = _onlineCounts();
    _data = _load();
  }

  Stream<int> _onlineCounts() =>
      widget.onlineCounts?.call() ??
      AppActivityService.instance.presence.onlineCount();

  Future<(AnalyticsSummary, List<ChartPoint>)> _load() async {
    final period = _period;
    final now = await (widget.serverNow?.call() ??
        AppActivityService.instance.presence.serverNow());
    _service.setServerNow(now);
    final values =
        await Future.wait([_service.summary(period), _service.chart(period)]);
    return (values[0] as AnalyticsSummary, values[1] as List<ChartPoint>);
  }

  Future<void> _refresh() async {
    final data = _load();
    setState(() => _data = data);
    try {
      await data;
    } catch (_) {
      // FutureBuilder displays the failure; refresh must not throw to the UI.
    }
  }

  Future<void> _openActiveUsers() async {
    // The covered dashboard does not need a live counter.
    setState(() => _onlineStream = null);
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const ActivityUsersScreen(),
      ));
    } finally {
      if (mounted) setState(() => _onlineStream = _onlineCounts());
    }
  }

  String _duration(int seconds) =>
      seconds < 60 ? '$seconds ث' : '${seconds ~/ 60} د ${seconds % 60} ث';

  Widget _onlineCard() => StreamBuilder<int>(
        stream: _onlineStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Material(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: AppTheme.primaryColor, size: 22),
                    const SizedBox(height: 10),
                    const Text('تعذر تحميل الاتصال',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                    TextButton(
                      onPressed: () =>
                          setState(() => _onlineStream = _onlineCounts()),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }
          return AnalyticsStatCard(
            title: 'متصل الآن',
            value: snapshot.hasData ? '${snapshot.data}' : '—',
            icon: Icons.online_prediction_rounded,
            subtitle:
                snapshot.hasData ? 'حسابات فريدة متصلة' : 'جارٍ تحميل الاتصال…',
          );
        },
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text('إحصائيات النشاط'),
            actions: [
              IconButton(
                tooltip: 'تحديث الإحصائيات',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Text('متابعة استخدام التطبيق',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 16),
                PeriodSelector(
                  value: _period,
                  onChanged: (value) => setState(() {
                    _period = value;
                    _data = _load();
                  }),
                ),
                const SizedBox(height: 16),
                FutureBuilder<(AnalyticsSummary, List<ChartPoint>)>(
                  future: _data,
                  builder: (context, snapshot) {
                    final summary = snapshot.hasData &&
                            snapshot.connectionState == ConnectionState.done
                        ? snapshot.data!.$1
                        : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                            builder: (context, constraints) => GridView.count(
                                  crossAxisCount:
                                      constraints.maxWidth >= 700 ? 4 : 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: 158,
                                  children: [
                                    _onlineCard(),
                                    AnalyticsStatCard(
                                      title: 'الجلسات',
                                      value: summary == null
                                          ? '—'
                                          : '${summary.sessions}',
                                      icon: Icons.layers_outlined,
                                      subtitle: 'بدأت خلال الفترة',
                                    ),
                                    AnalyticsStatCard(
                                      title: 'مستخدمون مسجلون',
                                      value: summary == null
                                          ? '—'
                                          : '${summary.registeredUniqueUsers}',
                                      icon: Icons.people_outline_rounded,
                                      subtitle: 'حسابات فريدة ذات جلسات',
                                    ),
                                    AnalyticsStatCard(
                                      title: 'متوسط الجلسة',
                                      value: summary == null ||
                                              summary.completedSessions == 0
                                          ? '—'
                                          : _duration(
                                              summary.averageDurationSeconds),
                                      icon: Icons.timer_outlined,
                                      subtitle: 'الجلسات المكتملة فقط',
                                    ),
                                  ],
                                )),
                        if (snapshot.hasError) ...[
                          const SizedBox(height: 12),
                          AnalyticsStatCard(
                            title: 'تعذر تحميل إحصائيات الفترة',
                            value: 'إعادة المحاولة',
                            icon: Icons.refresh_rounded,
                            onTap: _refresh,
                          ),
                        ] else if (summary == null) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(minHeight: 2),
                        ] else ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(16)),
                            child: Row(children: [
                              const Icon(Icons.account_circle_outlined,
                                  color: AppTheme.primaryColor, size: 22),
                              const SizedBox(width: 12),
                              const Expanded(
                                  child: Text('جلسات المسجلين',
                                      style:
                                          TextStyle(color: AppTheme.textGrey))),
                              Text('${summary.registeredUsers}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(16)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('حركة الجلسات',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                  VisitsBars(points: snapshot.data!.$2),
                                ]),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Material(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            onTap: _openActiveUsers,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            leading: const Icon(Icons.history_rounded,
                                color: AppTheme.primaryColor),
                            title: const Text('نشطون آخر 24 ساعة',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                            subtitle: const Text('عرض قائمة المستخدمين',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                            trailing: const Icon(Icons.chevron_left_rounded,
                                color: AppTheme.primaryColor),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'بيانات الزوار غير المسجلين غير مكتملة حاليًا؛ لا تشمل هذه المؤشرات جميع زوار التطبيق.',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 11, height: 1.7),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
}
