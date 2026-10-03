import 'package:aqar/core/data/paged_query.dart';
import 'package:aqar/core/data/property_catalog_query.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'firebase_read_optimization_test.dart' show Store, flush;

Store fixture() {
  final store = Store();
  for (var i = 0; i < 81; i++) {
    store.data['properties/m${i.toString().padLeft(3, '0')}'] = {
      'status': i == 80 ? 'pending' : 'approved',
      'officeId': i < 65 ? 'office-a' : 'office-b',
      'propertyType': i < 65 ? 'بيت' : 'أرض',
      'adType': i < 65 ? 'للبيع' : 'للإيجار',
      'isFeatured': i < 65,
      'price': i ~/ 3,
      'views': i ~/ 3,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch((i ~/ 3) * 1000),
    };
  }
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (var mask = 0; mask < 16; mask++) {
    for (final sort in [
      'الأحدث',
      'الأقل سعراً',
      'الأعلى سعراً',
      'الأكثر مشاهدة'
    ]) {
      test('structured mask=$mask sort=$sort: all cursor pages and equal ties',
          () async {
        final store = fixture();
        final plan = PropertyCatalogQuery(
          featured: mask & 1 != 0,
          adType: mask & 2 != 0 ? 'للبيع' : 'الكل',
          category: mask & 4 != 0 ? 'بيت' : 'الكل',
          officeId: mask & 8 != 0 ? 'office-a' : null,
          sort: sort,
        );
        expect(plan.bounded, isTrue);
        final query = plan.pageQuery(store);
        final expected = (await query.get()).docs.map((d) => d.id).toList();
        expect(expected.length, greaterThan(40));
        final pages = PagedQueryController(query, pageSize: 20);
        pages.start();
        await flush();
        expect(pages.documents.length, 20);
        await pages.loadMore();
        expect(pages.documents.length, 40);
        await pages.loadMore();
        expect(pages.documents.length, 60);
        while (pages.hasMore) {
          await pages.loadMore();
        }
        final actual = pages.documents.map((d) => d.id).toList();
        expect(actual, expected);
        expect(actual.toSet().length, actual.length);
        expect(actual, isNot(contains('m080')));
        expect(store.limits.every((n) => n == 20), isTrue);
        pages.dispose();
      });
    }
  }
  test('structured filters never turn substring search into loaded-page search',
      () {
    for (var mask = 0; mask < 16; mask++) {
      expect(
          PropertyCatalogQuery(
                  featured: mask & 1 != 0,
                  adType: mask & 2 != 0 ? 'للبيع' : 'الكل',
                  category: mask & 4 != 0 ? 'بيت' : 'الكل',
                  officeId: mask & 8 != 0 ? 'office-a' : null,
                  search: 'الرمادي الحوز')
              .bounded,
          isFalse);
    }
  });
  test('new approved zero-view property remains reachable in views pagination',
      () async {
    final store = fixture();
    store.data['properties/new-zero'] = {
      'status': 'approved',
      'officeId': 'office-a',
      'propertyType': 'بيت',
      'adType': 'للبيع',
      'isFeatured': true,
      'price': 1,
      'views': 0,
      'createdAt': Timestamp.now(),
    };
    final page = PagedQueryController(const PropertyCatalogQuery(
            featured: true,
            officeId: 'office-a',
            adType: 'للبيع',
            category: 'بيت',
            sort: 'الأكثر مشاهدة')
        .pageQuery(store));
    page.start();
    await flush();
    expect(page.documents.any((d) => d.id == 'new-zero'), isFalse);
    while (page.hasMore) {
      await page.loadMore();
    }
    expect(page.documents.where((d) => d.id == 'new-zero').length, 1);
    page.dispose();
  });
}
