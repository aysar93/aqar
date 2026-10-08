import 'package:aqar/services/notification_route_coordinator.dart';
import 'package:aqar/widgets/navigation/home_preserving_tab_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Home survives tabs, account rebuilds and a pushed route on iOS',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      var index = 0;
      var homeStarts = 0;
      var reelsStarts = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          navigatorKey: navigator,
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Scaffold(
                body: HomePreservingTabBody(
                  currentIndex: index,
                  pages: [
                    _ScrollablePage(onStart: () => homeStarts++),
                    const Text('favorites'),
                    const SizedBox(),
                    _ScrollablePage(onStart: () => reelsStarts++),
                    const Text('chat'),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      final state = tester.state<_ScrollablePageState>(
        find.byType(_ScrollablePage),
      );
      final offset = state.controller.offset;
      expect(offset, greaterThan(0));
      expect(reelsStarts, 0);
      for (final tab in [1, 3, 4, 0]) {
        rebuild(() => index = tab);
        await tester.pumpAndSettle();
      }
      expect(homeStarts, 1);
      expect(reelsStarts, 1);
      expect(state.controller.offset, offset);
      rebuild(() {});
      await tester.pump();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('notifications')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(state.controller.offset, offset);
      expect(homeStarts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cold push waits for shell and back keeps the same Home state', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final routes = NotificationRouteCoordinator(navigator);
    var opens = 0;
    var homeStarts = 0;
    var homeSelected = false;
    Future<void> openNotifications(BuildContext context) async {
      opens++;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('notifications')),
            body: const Text('notification list'),
          ),
        ),
      );
    }

    await routes.open(openNotifications);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('splash')),
      ),
    );
    await tester.pumpAndSettle();
    expect(opens, 0);
    Route<dynamic>? shellRoute;
    navigator.currentState!.pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            shellRoute = ModalRoute.of(context)!;
            routes.attach(shellRoute!, () => homeSelected = true);
          });
          return Scaffold(body: _ScrollablePage(onStart: () => homeStarts++));
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(homeSelected, isTrue);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(homeStarts, 1);
    expect(find.byType(ListView), findsOneWidget);

    // A push while another route is open must still return to Home.
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('other page')),
      ),
    );
    await tester.pumpAndSettle();
    await routes.open(openNotifications);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('other page'), findsNothing);
    expect(homeStarts, 1);
    routes.detach(shellRoute!);
    await routes.open(openNotifications);
    expect(opens, 2, reason: 'Do not navigate after the shell is disposed');
    expect(tester.takeException(), isNull);
  });
}

class _ScrollablePage extends StatefulWidget {
  const _ScrollablePage({required this.onStart});
  final VoidCallback onStart;
  @override
  State<_ScrollablePage> createState() => _ScrollablePageState();
}

class _ScrollablePageState extends State<_ScrollablePage> {
  final controller = ScrollController();
  @override
  void initState() {
    super.initState();
    widget.onStart();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        controller: controller,
        primary: false,
        children: [
          for (var i = 0; i < 30; i++)
            SizedBox(height: 150, child: Text('row $i')),
        ],
      );
}
