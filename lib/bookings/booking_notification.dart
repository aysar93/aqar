String? bookingNotificationId(Map<String, dynamic> payload) {
  final nested = payload['data'];
  final type = payload['type'] ?? (nested is Map ? nested['type'] : null);
  final id =
      payload['bookingId'] ?? (nested is Map ? nested['bookingId'] : null);
  if (type != 'booking' || id is! String) return null;
  final value = id.trim();
  return value.isNotEmpty && value.length <= 128 && !value.contains('/')
      ? value
      : null;
}
