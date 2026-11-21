import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/bookings_preview_main.dart';

void main() {
  testWidgets('render seven real Flutter preview screens with Arabic font',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('SplashTajawal');
    font.addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
    font.addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (var page = 0; page < 7; page++) {
      await tester.pumpWidget(MaterialApp(
          key: ValueKey(page),
          home: RepaintBoundary(
              key: const ValueKey('capture'),
              child: BookingPreviewPage(initialPage: page))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('BOOKING_CAPTURE_UI'))
        await expectLater(find.byKey(const ValueKey('capture')),
            matchesGoldenFile('preview_captures/screen-$page.png'));
    }
  });
}
