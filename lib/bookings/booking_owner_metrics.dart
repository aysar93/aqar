const _maxMoney = 9007199254740991;
int? _sumKnown(Iterable<Map<String, dynamic>> rows, String key) {
  var sum = 0;
  for (final b in rows) {
    final n = b[key];
    if (n is! num ||
        !n.isFinite ||
        n < 0 ||
        n > _maxMoney ||
        n != n.truncateToDouble()) return null;
    sum += n.toInt();
    if (sum > _maxMoney) return null;
  }
  return sum;
}

Map<String, dynamic> bookingOwnerMetrics(List<Map<String, dynamic>> bookings,
    {DateTime? now}) {
  final clock = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final confirmed = bookings.where(
      (b) => ['confirmed', 'arrived', 'completed'].contains(b['status']));
  final expected = bookings.where((b) =>
      ['held', 'payment_review', 'confirmed', 'arrived'].contains(b['status']));
  return {
    'new': bookings.where((b) => b['status'] == 'requested').length,
    'pending': bookings
        .where((b) => ['held', 'payment_review', 'payment_rejected']
            .contains(b['status']))
        .length,
    'confirmed': bookings
        .where((b) => ['confirmed', 'arrived'].contains(b['status']))
        .length,
    'upcoming': bookings
        .where((b) =>
            ['held', 'payment_review', 'confirmed'].contains(b['status']) &&
            b['start'] is num &&
            b['start'] > clock)
        .length,
    'completed': bookings.where((b) => b['status'] == 'completed').length,
    'cancelled': bookings
        .where(
            (b) => ['cancelled', 'rejected', 'expired'].contains(b['status']))
        .length,
    'expected': _sumKnown(expected, 'total'),
    // Gross approved deposits, not net profit or a substitute for the finance ledger.
    'paid': _sumKnown(confirmed, 'paid'),
    'remaining': _sumKnown(confirmed, 'remaining'),
    'recorded': _sumKnown(confirmed, 'total'),
  };
}
