import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/widgets/navigation/custom_bottom_bar.dart';

void main() {
  testWidgets(
      'booking tab preserves chat and reels destinations on narrow screens',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? destination;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar: CustomBottomBar(
                currentIndex: 5,
                onTap: (i) => destination = i,
                onAddTap: () {}))));
    expect(find.text('الشاليهات'), findsOneWidget);
    await tester.tap(find.text('الشاليهات'));
    expect(destination, 5);
    await tester.tap(find.text('الدردشة'));
    expect(destination, 4);
    await tester.tap(find.text('الريلز'));
    expect(destination, 3);
    expect(tester.takeException(), isNull);
  });
}
