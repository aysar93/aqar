import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aqar/widgets/navigation/custom_bottom_bar.dart';
import 'package:aqar/widgets/navigation/add_property_button.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Comprehensive RTL Layout & Visual Tests', () {
    testWidgets('1. CustomBottomBar renders strictly Right-to-Left (الرئيسية -> الحجوزات)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repaintKey = GlobalKey();
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, fontFamily: 'Cairo', brightness: Brightness.dark),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              bottomNavigationBar: RepaintBoundary(
                key: repaintKey,
                child: CustomBottomBar(
                  currentIndex: selectedIndex,
                  onTap: (i) => selectedIndex = i,
                  onAddTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final homeRect = tester.getRect(find.text('الرئيسية'));
      final favRect = tester.getRect(find.text('المفضلة'));
      final addRect = tester.getRect(find.byType(AddPropertyButton));
      final reelsRect = tester.getRect(find.text('الريلز'));
      final bookingsRect = tester.getRect(find.text('الحجوزات'));

      // Check strictly descending X coordinates: Right (high X) to Left (low X)
      expect(homeRect.center.dx, greaterThan(favRect.center.dx),
          reason: 'الرئيسية (Tab 0) must be to the right of المفضلة');
      expect(favRect.center.dx, greaterThan(addRect.center.dx),
          reason: 'المفضلة (Tab 1) must be to the right of أعلن');
      expect(addRect.center.dx, greaterThan(reelsRect.center.dx),
          reason: 'أعلن (Tab 2) must be to the right of الريلز');
      expect(reelsRect.center.dx, greaterThan(bookingsRect.center.dx),
          reason: 'الريلز (Tab 3) must be to the right of الحجوزات (Tab 4)');

      print('CustomBottomBar RTL Positions Verified:');
      print('  الرئيسية: ${homeRect.center.dx} > المفضلة: ${favRect.center.dx} > أعلن: ${addRect.center.dx} > الريلز: ${reelsRect.center.dx} > الحجوزات: ${bookingsRect.center.dx}');
    });

    test('2. Codebase RTL Static Invariants Check', () async {
      // Check horizontal_properties_section.dart
      final hPropFile = File('lib/widgets/home/horizontal_properties_section.dart');
      final hPropContent = await hPropFile.readAsString();
      expect(hPropContent.contains('reverse: true'), isFalse,
          reason: 'HorizontalPropertiesSection PageView must NOT have reverse: true');
      expect(hPropContent.contains('Alignment.centerRight'), isTrue,
          reason: 'HorizontalPropertiesSection indicator must align to centerRight');

      // Check property_requests_section.dart
      final reqFile = File('lib/widgets/home/property_requests/property_requests_section.dart');
      final reqContent = await reqFile.readAsString();
      expect(reqContent.contains('reverse: true'), isFalse,
          reason: 'PropertyRequestsSection PageView must NOT have reverse: true');

      // Check property_details.dart
      final detailsFile = File('lib/screens/property_details.dart');
      final detailsContent = await detailsFile.readAsString();
      expect(detailsContent.contains('textDirection: TextDirection.rtl'), isTrue,
          reason: 'PropertyDetailsScreen must be wrapped in Directionality RTL');
      expect(detailsContent.contains('Icons.arrow_forward_ios_rounded'), isTrue,
          reason: 'PropertyDetailsScreen back button must point forward in RTL');

      // Check booking_account_screen.dart
      final accountFile = File('lib/bookings/booking_account_screen.dart');
      final accountContent = await accountFile.readAsString();
      expect(accountContent.contains('userProvider.name'), isTrue,
          reason: 'BookingAccountScreen must use UserProvider.name');
      expect(accountContent.contains('Icons.camera_alt_rounded'), isTrue,
          reason: 'BookingAccountScreen avatar must show camera edit badge');
      expect(accountContent.contains('الملف الشخصي'), isTrue,
          reason: 'BookingAccountScreen options must include profile editor');

      // Check media fallback in services
      final mediaLocFile = File('lib/services/media_location.dart');
      final mediaLocContent = await mediaLocFile.readAsString();
      expect(mediaLocContent.contains("defaultValue: 'aqar-9f3f9-media-canary'"), isTrue,
          reason: 'MediaLocation must provide fallback bucket defaultValue');

      final mediaStoreFile = File('lib/services/media_store.dart');
      final mediaStoreContent = await mediaStoreFile.readAsString();
      expect(mediaStoreContent.contains('https://us-central1-aqar-9f3f9.cloudfunctions.net/uploadMedia'), isTrue,
          reason: 'MediaStore must provide fallback upload URL defaultValue');

      // Check Safe Area fix in booking_widgets.dart and booking_discovery_design.dart
      final bwFile = File('lib/bookings/booking_widgets.dart');
      final bwContent = await bwFile.readAsString();
      expect(bwContent.contains('removeTop: true'), isFalse,
          reason: 'BookingScaffold must NOT strip viewPadding with removeTop: true');

      final bddFile = File('lib/bookings/booking_discovery_design.dart');
      final bddContent = await bddFile.readAsString();
      expect(bddContent.contains('rawTopInset > 0'), isTrue,
          reason: 'BookingGoldenHeaderContainer must compute safe top inset');

      // Check codemagic.yaml
      final cmFile = File('codemagic.yaml');
      final cmContent = await cmFile.readAsString();
      expect(cmContent.contains('--dart-define-from-file=config/media.production.json'), isTrue,
          reason: 'codemagic.yaml must include media configuration define');

      print('All 7 Codebase RTL & Media Invariants Verified Successfully!');
    });
  });
}
