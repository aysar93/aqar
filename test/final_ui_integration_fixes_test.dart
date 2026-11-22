import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/widgets/navigation/custom_bottom_bar.dart';
import 'package:aqar/bookings/booking_venue_details.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Final UI Integration Fixes Verification', () {
    testWidgets('Issue 3: Drawer opens from the right (Start in RTL, drawer property used)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              drawer: const Drawer(child: Text('القائمة الجانبية')),
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify that Scaffold.drawer is set (not endDrawer)
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNotNull);
      expect(scaffold.endDrawer, isNull);

      // Open drawer
      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      // In RTL, the drawer is positioned on the RIGHT side of the screen
      final drawerFinder = find.byType(Drawer);
      expect(drawerFinder, findsOneWidget);
      final drawerTopRight = tester.getTopRight(drawerFinder);
      expect(drawerTopRight.dx, equals(800.0)); // In RTL, right edge touches screen edge 800.0
    });

    testWidgets('Issue 4: MainShell bottom bar is hidden on Bookings tab (index 4)', (tester) async {
      int currentIndex = 4;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (ctx, setState) => Scaffold(
              body: Container(),
              bottomNavigationBar: currentIndex == 4
                  ? null
                  : CustomBottomBar(
                      currentIndex: currentIndex,
                      onTap: (_) {},
                      onAddTap: () {},
                    ),
            ),
          ),
        ),
      );

      // When tab is 4 (Bookings), MainShell's CustomBottomBar is null so Bookings has its own bottom bar
      expect(find.byType(CustomBottomBar), findsNothing);
    });

    testWidgets('Issue 5: BookingVenueDetails two-way tab synchronization with external ValueNotifier', (tester) async {
      final selectedNotifier = ValueNotifier<int>(0);
      final scrollController = ScrollController();

      final fakeVenue = <String, dynamic>{
        'name': 'شاليه الأندلس',
        'city': 'الرمادي',
        'district': 'الحبانية',
        'price': 250000,
        'images': <String>[],
        'amenities': <String>['pool', 'wifi'],
        'description': 'شاليه فخم مع مسبح خاص',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (ctx) => Column(
                  children: [
                    BookingVenueDetails.buildTabBarWidget(
                      context: ctx,
                      selectedNotifier: selectedNotifier,
                      onTabTap: (i) => selectedNotifier.value = i,
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          BookingVenueDetails(
                            showTabBar: false,
                            selectedNotifier: selectedNotifier,
                            scrollController: scrollController,
                            venue: fakeVenue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial tab is 0 (التفاصيل)
      expect(selectedNotifier.value, equals(0));

      // Tap on Tab 1 (الأسعار) in TabBar
      await tester.tap(find.text('الأسعار').first);
      await tester.pumpAndSettle();
      expect(selectedNotifier.value, equals(1));

      // Tap on Tab 3 (المزايا) in TabBar
      await tester.tap(find.text('المزايا').first);
      await tester.pumpAndSettle();
      expect(selectedNotifier.value, equals(3));

      // Clean up
      selectedNotifier.dispose();
      scrollController.dispose();
    });
  });
}
