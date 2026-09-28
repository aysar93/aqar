import 'dart:async';
import 'package:aqar/widgets/home/keep_alive_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Refresh retains last layout while waiting for replacement data',
      (tester) async {
    final first = StreamController<int>.broadcast();
    final refreshed = StreamController<int>.broadcast();
    addTearDown(first.close);
    addTearDown(refreshed.close);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Widget page(Stream<int> stream) => MaterialApp(
            home: Scaffold(
                body: ListView(
          controller: controller,
          children: [
            KeepAliveSection(
                child: StreamBuilder<int>(
                    stream: stream,
                    builder: (_, snapshot) => snapshot.hasData
                        ? SizedBox(
                            height: 400, child: Text('data ${snapshot.data}'))
                        : const SizedBox.shrink())),
            for (var i = 0; i < 8; i++)
              SizedBox(height: 400, child: Text('item $i')),
          ],
        )));
    await tester.pumpWidget(page(first.stream));
    first.add(1);
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final offset = controller.offset;
    await tester.pumpWidget(page(refreshed.stream));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('data 1'), findsOneWidget);
    expect(controller.offset, offset);
    refreshed.add(2);
    await tester.pumpAndSettle();
    expect(controller.offset, offset);
    expect(find.text('data 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Kept section receives live removals without resubscribing; idle offset and return route stay stable',
      (tester) async {
    final source = StreamController<int>.broadcast();
    addTearDown(source.close);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
            body: ListView(
          controller: controller,
          children: [
            KeepAliveSection(
                child: StreamBuilder<int>(
                    stream: source.stream,
                    builder: (_, snapshot) =>
                        snapshot.data == null || snapshot.data == 0
                            ? const SizedBox.shrink()
                            : SizedBox(
                                height: 400,
                                child: Text('live ${snapshot.data}')))),
            for (var i = 0; i < 8; i++)
              SizedBox(height: 400, child: Text('item $i')),
          ],
        ))));
    source.add(1);
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    final offset = controller.offset;
    source
        .add(2); // Background update while the section is outside the viewport.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(controller.offset, offset);
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('details'))));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(controller.offset, offset);
    source.add(0); // Removal is delivered even while kept off-screen.
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 1100));
    await tester.pumpAndSettle();
    expect(find.text('live 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Previously loaded home section survives leaving the viewport',
      (tester) async {
    var subscriptions = 0;
    final source = Stream<int>.multi((controller) {
      subscriptions++;
      final timer =
          Timer(const Duration(milliseconds: 30), () => controller.add(1));
      controller.onCancel = timer.cancel;
    }, isBroadcast: true);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      KeepAliveSection(
          child: StreamBuilder<int>(
              stream: source,
              builder: (_, snapshot) => snapshot.hasData
                  ? const SizedBox(height: 400, child: Text('loaded section'))
                  : const SizedBox.shrink())),
      for (var i = 0; i < 8; i++)
        SizedBox(height: 400, child: Text('section $i')),
    ]))));
    await tester.pump(const Duration(milliseconds: 50));
    expect(subscriptions, 1);
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1400));
    await tester.pumpAndSettle();
    expect(subscriptions, 1,
        reason:
            'Scrolling must not reload an already loaded section at zero height');
    for (final speed in [
      const Duration(seconds: 1),
      const Duration(milliseconds: 120)
    ]) {
      await tester.timedDrag(
          find.byType(ListView), const Offset(0, -1400), speed);
      await tester.pumpAndSettle();
      await tester.timedDrag(
          find.byType(ListView), const Offset(0, 1400), speed);
      await tester.pumpAndSettle();
      expect(subscriptions, 1);
    }
    expect(tester.takeException(), isNull);
  });
}
