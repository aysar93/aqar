import 'dart:async';

import 'package:aqar/analytics/models/analytics_models.dart';
import 'package:aqar/analytics/screens/activity_users_screen.dart';
import 'package:aqar/analytics/screens/analytics_dashboard_screen.dart';
import 'package:aqar/analytics/services/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'analytics_queries_test.dart' show QueryDoc;

class PreviewAnalytics implements AnalyticsService {
  final now = DateTime(2026, 10, 2, 12);
  int pages = 0;
  @override
  void setServerNow(DateTime now) {}
  @override
  void invalidateSessions() {}
  @override
  Future<AnalyticsSummary> summary(AnalyticsPeriod period) async =>
      const AnalyticsSummary(
        sessions: 128,
        uniqueUsers: 74,
        registeredUsers: 128,
        guests: 0,
        averageDurationSeconds: 204,
        registeredUniqueUsers: 74,
        completedSessions: 110,
      );
  @override
  Future<List<ChartPoint>> chart(AnalyticsPeriod period) async => const [
        ChartPoint('08:00', 12),
        ChartPoint('09:00', 18),
        ChartPoint('10:00', 32),
        ChartPoint('11:00', 27),
        ChartPoint('12:00', 39)
      ];
  @override
  Future<ActivityPage> activeLast24Hours(
      {required DateTime windowEnd,
      DocumentSnapshot<Map<String, dynamic>>? after}) async {
    pages++;
    final names = [
      'أحمد محمد',
      'عمر عبد الله',
      'سارة خالد',
      'محمد أحمد',
      'علي حسن',
      'نور علي'
    ];
    final providers = [
      'google.com',
      'apple.com',
      'facebook.com',
      'password',
      'phone'
    ];
    return ActivityPage(
      users: List.generate(
          after == null ? 30 : 5,
          (index) => ActivityUser(
                id: 'uid${after == null ? index : index + 30}',
                userId: 'uid${after == null ? index : index + 30}',
                displayName: names[index % names.length],
                isGuest: false,
                lastSeen: now.subtract(Duration(minutes: 3 + index * 7)),
                platform: index.isEven ? 'android' : 'ios',
                provider: providers[index % providers.length],
              )),
      cursor: QueryDoc('cursor', {}),
      hasMore: after == null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RefreshAnalytics extends PreviewAnalytics {
  bool fresh = false;
  final cursors = <DocumentSnapshot<Map<String, dynamic>>?>[];
  @override
  Future<ActivityPage> activeLast24Hours(
      {required DateTime windowEnd,
      DocumentSnapshot<Map<String, dynamic>>? after}) async {
    cursors.add(after);
    return ActivityPage(users: [
      ActivityUser(
          id: 'A',
          userId: 'A',
          displayName: 'مستخدم الاختبار',
          isGuest: false,
          lastSeen: windowEnd.subtract(
              fresh ? const Duration(seconds: 20) : const Duration(hours: 1)),
          platform: 'ios',
          provider: 'apple.com')
    ], cursor: QueryDoc('cursor', {}), hasMore: after == null);
  }
}

Widget preview(Widget screen) => MaterialApp(
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
            primary: Color(0xffD4AF37), surface: Color(0xff1E293B)),
        scaffoldBackgroundColor: const Color(0xff0F172A),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xff0F172A), centerTitle: true),
        textTheme:
            ThemeData.dark().textTheme.apply(fontFamily: 'SplashTajawal'),
      ),
      home: RepaintBoundary(key: const Key('preview'), child: screen),
    );

void main() {
  setUpAll(() async {
    final loader = FontLoader('SplashTajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('dashboard RTL layout and official palette preview',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = PreviewAnalytics();
    await tester.pumpWidget(preview(AnalyticsDashboardScreen(
      service: data,
      onlineCounts: () => Stream.value(16),
      serverNow: () async => data.now,
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('جلسات الزوار'), findsNothing);
    expect(find.text('زوار فريدون'), findsNothing);
    expect(find.text('جلسات المسجلين'), findsNothing);
    expect(find.text('الجلسات'), findsOneWidget);
    expect(find.text('الحسابات الفريدة'), findsOneWidget);
    expect(find.text('متوسط مدة الجلسة'), findsOneWidget);
    expect(find.textContaining('بيانات الزوار غير المسجلين'), findsNothing);
    expect(Directionality.of(tester.element(find.text('الجلسات'))),
        TextDirection.rtl);
    await expectLater(find.byKey(const Key('preview')),
        matchesGoldenFile('../goldens/activity_dashboard.png'));
  });

  testWidgets('presence loading/error is not zero and subscription is disposed',
      (tester) async {
    final data = PreviewAnalytics();
    var active = 0;
    final stream = StreamController<int>.broadcast(
      onListen: () => active++,
      onCancel: () => active--,
    );
    await tester.pumpWidget(preview(AnalyticsDashboardScreen(
      service: data,
      onlineCounts: () => stream.stream,
      serverNow: () async => data.now,
    )));
    await tester.pumpAndSettle();
    expect(find.text('جارٍ تحميل الاتصال…'), findsOneWidget);
    expect(active, 1);
    stream.addError(StateError('permission denied'));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل الاتصال'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    await tester.tap(find.text('7 أيام'));
    await tester.pumpAndSettle();
    expect(active, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(active, 0);
    await stream.close();
  });

  testWidgets('active-user preview and next page retain registered users',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = PreviewAnalytics();
    await tester.pumpWidget(preview(
        ActivityUsersScreen(service: data, serverNow: () async => data.now)));
    await tester.pumpAndSettle();
    expect(data.pages, 1);
    expect(find.text('مسجل'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const Key('preview')),
        matchesGoldenFile('../goldens/activity_users.png'));
    await tester.scrollUntilVisible(find.text('تحميل 30 مستخدمًا إضافيًا'), 600,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('تحميل 30 مستخدمًا إضافيًا'));
    await tester.pumpAndSettle();
    expect(data.pages, 2);
    expect(find.text('تحميل 30 مستخدمًا إضافيًا'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'explicit refresh reloads first page and timestamp; pagination deduplicates',
      (tester) async {
    final data = RefreshAnalytics();
    var clockReads = 0;
    await tester.pumpWidget(preview(ActivityUsersScreen(
        service: data,
        serverNow: () async {
          clockReads++;
          return data.now;
        })));
    await tester.pumpAndSettle();
    expect(find.text('منذ ساعة'), findsOneWidget);
    await tester.tap(find.text('تحميل 30 مستخدمًا إضافيًا'));
    await tester.pumpAndSettle();
    expect(data.cursors.last, isNotNull);
    expect(find.text('مستخدم الاختبار'), findsOneWidget);
    expect(clockReads, 1);
    data.fresh = true;
    await tester.tap(find.byTooltip('تحديث النشاط'));
    await tester.pumpAndSettle();
    expect(data.cursors.last, isNull);
    expect(clockReads, 2);
    expect(find.text('منذ ساعة'), findsNothing);
    expect(find.text('منذ أقل من دقيقة'), findsOneWidget);
    expect(find.textContaining('البيانات محمّلة حتى'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
