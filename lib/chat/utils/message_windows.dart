import 'package:cloud_firestore/cloud_firestore.dart';

/// Merge live head and disjoint live history windows. Replacing a window drops
/// deleted messages, and overlapping boundary documents appear exactly once.
List<QueryDocumentSnapshot> mergeMessageWindows(
    List<QueryDocumentSnapshot> head,
    Iterable<List<QueryDocumentSnapshot>> older) {
  final docs = <String, QueryDocumentSnapshot>{};
  for (final page in older) {
    for (final doc in page) {
      docs[doc.id] = doc;
    }
  }
  for (final doc in head) {
    docs[doc.id] = doc;
  }
  return docs.values.toList()
    ..sort((a, b) {
      final x = (a.data() as Map)['createdAt'],
          y = (b.data() as Map)['createdAt'];
      if (x is Timestamp && y is Timestamp) {
        final order = x.compareTo(y);
        if (order != 0) return order;
      }
      return a.id.compareTo(b.id);
    });
}
