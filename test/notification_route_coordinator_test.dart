import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/services/notification_route_coordinator.dart';

void main() {
  testWidgets('cold tap waits for shell and keeps shell as back route',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    final coordinator = NotificationRouteCoordinator(key);
    Route<dynamic>? shell;
    var homeCalls = 0;
    await coordinator.open((context) async {
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('destination'))));
    });
    await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        home: Builder(
          builder: (context) {
            shell = ModalRoute.of(context);
            return const Scaffold(body: Text('shell'));
          },
        )));
    expect(find.text('destination'), findsNothing);
    coordinator.attach(shell!, () => homeCalls++);
    await tester.pumpAndSettle();
    expect(find.text('destination'), findsOneWidget);
    expect(homeCalls, 1);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('latest startup tap replaces older pending tap', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final coordinator = NotificationRouteCoordinator(key);
    final opened = <int>[];
    await coordinator.open((_) async => opened.add(1));
    await coordinator.open((_) async => opened.add(2));
    Route<dynamic>? route;
    await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        home: Builder(
          builder: (context) {
            route = ModalRoute.of(context);
            return const Scaffold();
          },
        )));
    coordinator.attach(route!, () {});
    await tester.pump();
    expect(opened, [2]);
  });

  testWidgets('detached shell queues taps until next shell attaches',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    final coordinator = NotificationRouteCoordinator(key);
    Route<dynamic>? route;
    await tester.pumpWidget(MaterialApp(
        navigatorKey: key,
        home: Builder(
          builder: (context) {
            route = ModalRoute.of(context);
            return const Scaffold();
          },
        )));
    coordinator.attach(route!, () {});
    coordinator.detach(route!);
    var count = 0;
    await coordinator.open((_) async => count++);
    expect(count, 0);
    coordinator.attach(route!, () {});
    await tester.pump();
    expect(count, 1);
  });
}
