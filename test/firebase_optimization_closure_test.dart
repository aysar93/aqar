import 'package:aqar/core/data/paged_query.dart';
import 'package:aqar/core/data/property_catalog_query.dart';
import 'package:aqar/core/data/property_text_search.dart';
import 'package:aqar/office/services/office_detail_queries.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'firebase_read_optimization_test.dart' show Store, flush;

Store source() {
  final store = Store();
  for (var i = 0; i < 65; i++) {
    store.data['properties/p${i.toString().padLeft(3, '0')}'] = {
      'status': i == 64 ? 'pending' : 'approved',
      'officeId': i < 60 ? 'office-a' : 'office-b',
      'propertyType': i.isEven ? 'بيت' : 'أرض',
      'adType': i.isEven ? 'بيع' : 'إيجار',
      'isFeatured': i.isEven,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch((i ~/ 2) * 1000),
      'price': i ~/ 2,
      'views': 100 - i,
      'title': i == 58 ? 'بيت للإيجار في الرمادي' : 'عقار',
      'description': i == 58 ? 'قرب الحوز ٢٠٠ متر' : '',
    };
  }
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final sort in ['الأحدث', 'الأعلى سعراً', 'الأقل سعراً']) {
    test('$sort: complete ordered cursor traversal including equal-value ties',
        () async {
      final store = source();
      final plan = PropertyCatalogQuery(sort: sort);
      expect(plan.bounded, isTrue);
      final query = plan.pageQuery(store);
      final all = await query.get();
      final page = PagedQueryController(query);
      page.start();
      await flush();
      expect(page.documents.length, 20);
      while (page.hasMore) {
        await page.loadMore();
      }
      final ids = page.documents.map((d) => d.id).toList();
      expect(ids, all.docs.map((d) => d.id).toList());
      expect(ids.toSet().length, 64);
      expect(store.limits.every((n) => n == 20), isTrue);
      page.dispose();
    });
  }
  test(
      'text search finds record outside first page, with Arabic AND normalization',
      () async {
    final store = source();
    const plan =
        PropertyCatalogQuery(search: 'للايجار الحوز 200', sort: 'الأقل سعراً');
    expect(plan.bounded, isFalse);
    final initial = await const PropertyCatalogQuery(sort: 'الأقل سعراً')
        .pageQuery(store)
        .limit(20)
        .get();
    expect(initial.docs.any((d) => d.id == 'p058'), isFalse);
    final candidates = await plan.candidates(store).get();
    final results = candidates.docs
        .where((d) => PropertyTextSearch.matches(plan.search, d.id, d.data()));
    expect(results.map((d) => d.id), ['p058']);
    expect(
        PropertyTextSearch.matches(
            'الحوز بغداد', 'p058', store.data['properties/p058']!),
        isFalse);
  });
  test('combined structured filters narrow the complete search candidate set',
      () async {
    final store = source();
    const plan = PropertyCatalogQuery(
        officeId: 'office-a',
        category: 'بيت',
        adType: 'بيع',
        featured: true,
        search: 'الحوز');
    final docs = (await plan.candidates(store).get()).docs;
    expect(docs.length, 30);
    expect(docs.any((d) => d.id == 'p058'), isTrue);
    expect(
        docs.every((d) =>
            d.data()['officeId'] == 'office-a' &&
            d.data()['status'] == 'approved' &&
            d.data()['isFeatured'] == true),
        isTrue);
  });
  test(
      'office approved properties: first/second/third pages have no gaps or duplicates',
      () async {
    final store = source();
    final page =
        PagedQueryController(OfficeDetailQueries.properties(store, 'office-a'));
    page.start();
    await flush();
    expect(page.documents.length, 20);
    await page.loadMore();
    expect(page.documents.length, 40);
    await page.loadMore();
    expect(page.documents.length, 60);
    expect(page.documents.map((d) => d.id).toSet().length, 60);
    expect(
        page.documents.every((d) =>
            d.data()['officeId'] == 'office-a' &&
            d.data()['status'] == 'approved'),
        isTrue);
    await page.refresh();
    await flush();
    expect(page.documents.length, 20);
    page.dispose();
  });
  test(
      'review cursor retains legacy missing status and traverses beyond hidden first page',
      () async {
    final store = Store();
    for (var i = 0; i < 45; i++) {
      store.data['office_reviews/r${i.toString().padLeft(3, '0')}'] = {
        'officeId': 'office-a',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(i),
        if (i != 0) 'status': i > 24 ? 'hidden' : 'published',
      };
    }
    final page =
        PagedQueryController(OfficeDetailQueries.reviews(store, 'office-a'));
    page.start();
    await flush();
    expect(page.documents.length, 20);
    expect(page.hasMore, isTrue);
    await page.loadMore();
    await page.loadMore();
    expect(page.documents.length, 45);
    expect(page.documents.map((d) => d.id).toSet().length, 45);
    expect(page.documents.any((d) => !d.data().containsKey('status')), isTrue);
    page.dispose();
  });
  test(
      'mode sorting takes precedence and structured combinations are paginated',
      () {
    expect(
        const PropertyCatalogQuery(mode: 'views', sort: 'الأقل سعراً')
            .orderField,
        'views');
    expect(
        const PropertyCatalogQuery(mode: 'latest', sort: 'الأقل سعراً')
            .orderField,
        'createdAt');
    expect(const PropertyCatalogQuery(officeId: 'office-a').bounded, isTrue);
    expect(
        const PropertyCatalogQuery(category: 'بيت', sort: 'الأعلى سعراً')
            .bounded,
        isTrue);
  });
}
