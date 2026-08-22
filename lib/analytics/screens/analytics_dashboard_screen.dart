import 'package:flutter/material.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';
import '../services/app_activity_service.dart';
import '../widgets/analytics_widgets.dart';
import 'activity_users_screen.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});
  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final _service = AnalyticsService();
  AnalyticsPeriod _period = AnalyticsPeriod.last24Hours;
  late Future<(AnalyticsSummary, List<ChartPoint>)> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _data = Future.wait([_service.summary(_period), _service.chart(_period)])
          .then((v) => (v[0] as AnalyticsSummary, v[1] as List<ChartPoint>));
  void _select(AnalyticsPeriod value) => setState(() {
        _period = value;
        _load();
      });
  String _duration(int seconds) =>
      seconds < 60 ? '$seconds ث' : '${seconds ~/ 60} د';

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0F172A),
        appBar: AppBar(
            backgroundColor: const Color(0xff0F172A),
            title: const Text('إحصائيات النشاط'),
            actions: [
              IconButton(
                  onPressed: () => setState(_load),
                  icon: const Icon(Icons.refresh))
            ]),
        body: RefreshIndicator(
            onRefresh: () async => setState(_load),
            child: ListView(padding: const EdgeInsets.all(18), children: [
              const Text('نظرة عامة',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              PeriodSelector(value: _period, onChanged: _select),
              const SizedBox(height: 18),
              StreamBuilder<int>(
                  stream: AppActivityService.instance.presence.onlineCount(),
                  builder: (_, s) => AnalyticsStatCard(
                      title: 'متصل الآن',
                      value: '${s.data ?? 0}',
                      icon: Icons.online_prediction,
                      color: Colors.green)),
              const SizedBox(height: 12),
              FutureBuilder<(AnalyticsSummary, List<ChartPoint>)>(
                  future: _data,
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return _ErrorCard(onRetry: () => setState(_load));
                    if (!snapshot.hasData)
                      return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()));
                    final summary = snapshot.data!.$1;
                    final chart = snapshot.data!.$2;
                    return Column(children: [
                      GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 175,
                          children: [
                            AnalyticsStatCard(
                                title: 'الجلسات',
                                value: '${summary.sessions}',
                                icon: Icons.phone_android,
                                color: Colors.orange),
                            AnalyticsStatCard(
                                title: 'زوار فريدون',
                                value: '${summary.uniqueUsers}',
                                icon: Icons.groups,
                                color: Colors.blue),
                            AnalyticsStatCard(
                                title: 'جلسات المسجلين',
                                value: '${summary.registeredUsers}',
                                icon: Icons.verified_user,
                                color: Colors.teal),
                            AnalyticsStatCard(
                                title: 'جلسات الزوار',
                                value: '${summary.guests}',
                                icon: Icons.person_outline,
                                color: Colors.purple),
                            AnalyticsStatCard(
                                title: 'متوسط الجلسة',
                                value:
                                    _duration(summary.averageDurationSeconds),
                                icon: Icons.timer,
                                color: const Color(0xffD4AF37)),
                            AnalyticsStatCard(
                                title: 'نشطون 24 ساعة',
                                value: 'عرض القائمة',
                                icon: Icons.history,
                                color: Colors.cyan,
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ActivityUsersScreen()))),
                          ]),
                      const SizedBox(height: 20),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: const Color(0xff1E293B),
                              borderRadius: BorderRadius.circular(18)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('حركة الزيارات',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                VisitsBars(points: chart)
                              ]))
                    ]);
                  })
            ])),
      ));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
      color: const Color(0xff1E293B),
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Text(
                'تعذر تحميل الإحصائيات. تحقق من صلاحيات Firebase والفهارس.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
            TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة'))
          ])));
}
