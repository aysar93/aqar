import 'package:cloud_firestore/cloud_firestore.dart';

/// Structured predicates may narrow the COMPLETE text-search candidate set.
/// Text tokens themselves are never inferred as an equality predicate.
class PropertyCatalogQuery {
  const PropertyCatalogQuery(
      {this.officeId,
      this.category = 'الكل',
      this.adType = 'الكل',
      this.featured = false,
      this.search = '',
      this.sort = 'الأحدث',
      this.mode = 'all'});
  final String? officeId;
  final String category, adType, search, sort, mode;
  final bool featured;
  String get orderField => mode == 'views'
      ? 'views'
      : mode == 'latest'
          ? 'createdAt'
          : sort == 'الأكثر مشاهدة'
              ? 'views'
              : sort == 'الأعلى سعراً' || sort == 'الأقل سعراً'
                  ? 'price'
                  : 'createdAt';
  bool get descending => !(orderField == 'price' && sort == 'الأقل سعراً');
  bool get hasOffice => officeId?.trim().isNotEmpty ?? false;
  // All structured predicates are equality filters and can be paginated with
  // the server sort. Only multi-field substring search needs a complete pool.
  bool get bounded => search.trim().isEmpty;
  Query<Map<String, dynamic>> candidates(FirebaseFirestore db) {
    var query =
        db.collection('properties').where('status', isEqualTo: 'approved');
    if (hasOffice) query = query.where('officeId', isEqualTo: officeId!.trim());
    if (category != 'الكل') {
      query = query.where('propertyType', isEqualTo: category);
    }
    if (adType != 'الكل') query = query.where('adType', isEqualTo: adType);
    if (featured) query = query.where('isFeatured', isEqualTo: true);
    return query;
  }

  // Firestore implicitly orders equal values by document name in the same
  // direction. startAfterDocument retains BOTH values, including that tie.
  Query<Map<String, dynamic>> pageQuery(FirebaseFirestore db) =>
      candidates(db).orderBy(orderField, descending: descending);
}
