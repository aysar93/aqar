import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/widgets/navigation/custom_bottom_bar.dart';

void main() {
  testWidgets(
      'bottom bar has exactly 5 items and bookings tab at index 4',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? destination;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar: CustomBottomBar(
                currentIndex: 4,
                onTap: (i) => destination = i,
                onAddTap: () {}))));
    expect(find.text('الحجوزات'), findsOneWidget);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('المفضلة'), findsOneWidget);
    expect(find.text('الريلز'), findsOneWidget);
    expect(find.text('الشاليهات'), findsNothing);
    expect(find.text('الدردشة'), findsNothing);

    await tester.tap(find.text('الحجوزات'));
    expect(destination, 4);
    await tester.tap(find.text('الريلز'));
    expect(destination, 3);
    await tester.tap(find.text('المفضلة'));
    expect(destination, 1);
    await tester.tap(find.text('الرئيسية'));
    expect(destination, 0);
    expect(tester.takeException(), isNull);
  });
}
