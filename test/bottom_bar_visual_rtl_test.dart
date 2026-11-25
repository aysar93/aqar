import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aqar/widgets/navigation/custom_bottom_bar.dart';
import 'package:aqar/widgets/navigation/add_property_button.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('RTL Bottom Bar renders exactly 5 items in correct RTL order and saves screenshot',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repaintKey = GlobalKey();
    int selectedIndex = 4; // Bookings selected

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Cairo',
          brightness: Brightness.dark,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: const Center(
              child: Text('عقارات الانبار — تجربة الحجوزات الموحدة'),
            ),
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

    // 1. Verify existence of the 5 required items
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('المفضلة'), findsOneWidget);
    expect(find.byType(AddPropertyButton), findsOneWidget);
    expect(find.text('الريلز'), findsOneWidget);
    expect(find.text('الحجوزات'), findsOneWidget);

    // Verify Chat and Chalets are NOT in the bottom bar
    expect(find.text('الدردشة'), findsNothing);
    expect(find.text('الشاليهات'), findsNothing);

    // 2. Geometric Coordinates Verification (Right-to-Left order: الرئيسية -> المفضلة -> أعلن -> الريلز -> الحجوزات)
    final homeRect = tester.getRect(find.text('الرئيسية'));
    final favRect = tester.getRect(find.text('المفضلة'));
    final addRect = tester.getRect(find.byType(AddPropertyButton));
    final reelsRect = tester.getRect(find.text('الريلز'));
    final bookingsRect = tester.getRect(find.text('الحجوزات'));

    print('Geometric X coordinates (RTL screen width: ${tester.view.physicalSize.width / tester.view.devicePixelRatio}):');
    print('  1. الرئيسية (Rightmost): center X = ${homeRect.center.dx}');
    print('  2. المفضلة (2nd from right): center X = ${favRect.center.dx}');
    print('  3. أعلن (Center button): center X = ${addRect.center.dx}');
    print('  4. الريلز (2nd from left): center X = ${reelsRect.center.dx}');
    print('  5. الحجوزات (Leftmost): center X = ${bookingsRect.center.dx}');

    // Assert strictly descending X coordinates from Right to Left
    expect(homeRect.center.dx, greaterThan(favRect.center.dx),
        reason: 'الرئيسية must be to the right of المفضلة in RTL');
    expect(favRect.center.dx, greaterThan(addRect.center.dx),
        reason: 'المفضلة must be to the right of أعلن in RTL');
    expect(addRect.center.dx, greaterThan(reelsRect.center.dx),
        reason: 'أعلن must be to the right of الريلز in RTL');
    expect(reelsRect.center.dx, greaterThan(bookingsRect.center.dx),
        reason: 'الريلز must be to the right of الحجوزات in RTL');

    // 3. Export real visual image of the bottom bar
    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final outputFile = File('C:/Users/AL-NOOR/.gemini/antigravity/brain/110efef9-b0d8-4732-b69f-01014ab4fb7f/screen_bottom_bar_rtl.png');
      await outputFile.writeAsBytes(pngBytes);
      print('Successfully exported visual RTL bottom bar image to: \${outputFile.path} (size: \${pngBytes.length} bytes)');
    });
  });
}
