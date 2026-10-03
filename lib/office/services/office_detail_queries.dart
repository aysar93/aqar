import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared definitions used by previews, public lists and owner pagination.
abstract final class OfficeDetailQueries {
  static Query<Map<String, dynamic>> properties(
      FirebaseFirestore db, String officeId,
      {bool approvedOnly = true}) {
    var query =
        db.collection('properties').where('officeId', isEqualTo: officeId);
    if (approvedOnly) query = query.where('status', isEqualTo: 'approved');
    return query.orderBy('createdAt', descending: true);
  }

  static Query<Map<String, dynamic>> reviews(
          FirebaseFirestore db, String officeId) =>
      db
          .collection('office_reviews')
          .where('officeId', isEqualTo: officeId)
          .orderBy('createdAt', descending: true);
}
