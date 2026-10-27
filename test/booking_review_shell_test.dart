import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/booking_ui_review_main.dart';

void main() {
  testWidgets(
      'diagnostic follows system brightness and avoids duplicate top inset',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 24);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPadding);
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      t.platformDispatcher.platformBrightnessTestValue = brightness;
      await t.pumpWidget(bookingUiReviewShell(
          home: const Scaffold(body: Text('اختبار محلي دون Firebase'))));
      await t.pumpAndSettle();
      expect(
          Theme.of(t.element(find.text('اختبار محلي دون Firebase'))).brightness,
          brightness);
      expect(
          MediaQuery.paddingOf(t.element(find.text('اختبار محلي دون Firebase')))
              .top,
          0);
      expect(t.takeException(), isNull);
    }
  });
}
