/// Check before rendering a snapshot: Firestore may emit another session's
/// cached document before the server rejects the new account's listener.
bool bookingCanDisplayDetails({
  required String? uid,
  required Map<String, dynamic> booking,
  bool admin = false,
  bool finance = false,
  String? privilegedUid,
}) =>
    uid != null &&
    (uid == booking['customerId'] ||
        uid == booking['ownerId'] ||
        (uid == privilegedUid && (admin || finance)));
