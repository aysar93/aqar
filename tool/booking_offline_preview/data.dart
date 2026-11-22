// Diagnostic-only facades for existing typed widget seams; no SDK objects or calls.
// ignore_for_file: subtype_of_sealed_class
// Diagnostic fixtures only. Not imported by any production entry point.
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aqar/bookings/booking_request_intent_store.dart';

class LocalMeta implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('Local metadata only');
}

class LocalDocument
    implements
        DocumentSnapshot<Map<String, dynamic>>,
        QueryDocumentSnapshot<Map<String, dynamic>> {
  LocalDocument(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => Map.of(value);
  @override
  bool get exists => true;
  @override
  SnapshotMetadata get metadata => LocalMeta();
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('Local document only: ${i.memberName}');
}

class LocalRecords implements QuerySnapshot<Map<String, dynamic>> {
  LocalRecords(List<Map<String, dynamic>> values)
      : docs = [for (final v in values) LocalDocument(v['id'] as String, v)];
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  SnapshotMetadata get metadata => LocalMeta();
  @override
  int get size => docs.length;
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('Local records only');
}

class LocalIntents implements BookingRequestIntentStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String uid, String venue) async =>
      values['$uid/$venue'];
  @override
  Future<void> save(String uid, String venue, Map<String, dynamic> p) async {
    values['$uid/$venue'] = Map.of(p);
  }

  @override
  Future<void> clear(String uid, String venue, String id) async {
    if (values['$uid/$venue']?['requestId'] == id) values.remove('$uid/$venue');
  }
}

const localAccounts = <String, dynamic>{
  'qicard': {'number': '0000000000000000 — معاينة فقط'},
  'zaincash': {'number': '00000000000 — غير قابل للدفع'}
};

class PreviewData {
  final changes = StreamController<void>.broadcast();
  final intents = LocalIntents();
  final requests = <String, String>{};
  final messages = <Map<String, dynamic>>[
    {
      'id': 'message-1',
      'senderId': 'preview-owner',
      'message': 'أهلًا بك، هذه محادثة محلية للاختبار فقط.'
    }
  ];
  late final List<Map<String, dynamic>> venues = List.generate(10, (i) {
    final kind = ['chalet', 'hall', 'farm'][i % 3],
        label = ['شاليه', 'قاعة', 'مزرعة'][i % 3];
    final assets = ['house', 'building', 'farm'];
    final paths = i == 8
        ? <String>[]
        : [
            'asset://assets/images/defaults/${assets[i % 3]}.png',
            if (i % 2 == 0) 'asset://assets/images/defaults/apartment.png'
          ];
    final price = 150000 + i * 25000;
    return <String, dynamic>{
      'id': 'preview-venue-${i + 1}',
      'active': true,
      'name': '$label المعاينة ${i + 1}',
      'category': kind,
      'ownerId': 'preview-owner',
      'ownerName': 'مالك اصطناعي ${i + 1}',
      'location': 'منطقة اختبار محلية ${i + 1} · الأنبار',
      'description': kind == 'hall'
          ? 'قاعة اصطناعية ${i + 1} للمناسبات، بمساحة جلوس وتنظيم داخلي.'
          : kind == 'farm'
              ? 'مزرعة اصطناعية ${i + 1} بمساحات خضراء وجلسات خارجية.'
              : 'شاليه اصطناعي ${i + 1} للاستراحة العائلية، مع مساحات داخلية وخارجية.',
      'mediaPaths': paths,
      'guestType': kind == 'hall' ? 'both' : 'families',
      'area': 400 + i * 50,
      'areaUnit': 'm2',
      'bathrooms': 2 + i % 3,
      'capacity': kind == 'hall' ? 150 + i * 10 : 12 + i * 2,
      'bedrooms': kind == 'chalet' ? 3 : 0,
      'amenities': kind == 'hall'
          ? ['parking', 'airConditioning', 'accessible']
          : kind == 'farm'
              ? ['parking', 'playground', 'kitchen']
              : ['pool', 'wifi', 'kitchen'],
      'price': price,
      'deposit': price ~/ 5,
      'terms': kind == 'hall'
          ? 'شروط معاينة القاعة ${i + 1}: احترام السعة وتنظيم أوقات المناسبة.'
          : 'شروط معاينة المكان ${i + 1}: الحفاظ على المرافق واحترام موعد الخروج.',
      'pricingMode': i == 7
          ? 'hourly'
          : i == 9
              ? 'daily'
              : 'shifts',
      'hourlyPrice': 25000,
      'shifts': [
        {
          'id': 'day',
          'name': 'الفترة الصباحية',
          'price': price,
          'checkInMinute': 540,
          'checkOutMinute': 1080
        },
        {
          'id': 'evening',
          'name': 'الفترة المسائية',
          'price': price + 25000,
          'checkInMinute': 1140,
          'checkOutMinute': 1380
        }
      ],
      'cancellationPolicy': {
        'freeCancellationHours': 24,
        'lateRefundPercent': 25
      }
    };
  });
  late final List<Map<String, dynamic>> bookings = List.generate(8, (i) {
    final v = venues[i];
    final day = DateTime.now().add(Duration(days: 5 + i));
    final start = DateTime.utc(day.year, day.month, day.day, 6);
    return <String, dynamic>{
      'id': 'preview-booking-${i + 1}',
      'venueId': v['id'],
      'venueName': v['name'],
      'category': v['category'],
      'customerId': 'preview-customer',
      'ownerId': 'preview-owner',
      'customerName': 'عميل اصطناعي ${i + 1}',
      'ownerName': v['ownerName'],
      'status': [
        'requested',
        'held',
        'payment_review',
        'confirmed',
        'completed',
        'cancelled',
        'rejected',
        'expired'
      ][i],
      'start': start.millisecondsSinceEpoch,
      'end': start.add(const Duration(hours: 9)).millisecondsSinceEpoch,
      'holdUntil':
          DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch,
      'paid': i == 3 || i == 4 ? v['deposit'] : 0,
      'remaining':
          (v['price'] as int) - (i == 3 || i == 4 ? v['deposit'] as int : 0),
      'refunded': 0,
      'refundStatus': 'none',
      'total': v['price'],
      'deposit': v['deposit'],
      'terms': v['terms'],
      'location': v['location'],
      'notes': 'حجز معاينة محلي ${i + 1}',
      'version': 1,
      'cancellationPolicy': v['cancellationPolicy'],
      'ownerSettlementStatus': 'settled',
      if (i == 2) 'receiptPath': 'offline-receipt'
    };
  });
  Map<String, dynamic> venue(String id) =>
      venues.firstWhere((v) => v['id'] == id);
  Map<String, dynamic> booking(String id) =>
      bookings.firstWhere((b) => b['id'] == id);
  Stream<QuerySnapshot<Map<String, dynamic>>> records(int tab,
          {bool empty = false, bool unavailable = false}) =>
      Stream.multi((c) {
        if (unavailable) {
          c.addError(StateError('Offline synthetic unavailable state'));
          c.close();
          return;
        }
        List<Map<String, dynamic>> values() => empty
            ? []
            : tab == 0 || tab == 5
                ? venues
                : tab == 3
                    ? []
                    : bookings;
        c.add(LocalRecords(values()));
        final sub = changes.stream
            .listen((_) => c.add(LocalRecords(values())), onError: c.addError);
        c.onCancel = sub.cancel;
      }, isBroadcast: true);
  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String id) =>
      Stream.multi((c) {
        c.add(LocalDocument(id, booking(id)));
        final sub = changes.stream.listen(
            (_) => c.add(LocalDocument(id, booking(id))),
            onError: c.addError);
        c.onCancel = sub.cancel;
      }, isBroadcast: true);

  void changed() => changes.add(null);
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> p) async {
    if (name == 'getPublishedBookingReviews')
      return {'count': 0, 'average': 0, 'reviews': []};
    if (name == 'getBookingAvailability') {
      final m =
          DateTime.fromMillisecondsSinceEpoch(p['start'] as int, isUtc: true)
              .add(const Duration(hours: 3));
      return {
        'slots': [
          for (final day in [5, 13, 18])
            {
              'start':
                  DateTime.utc(m.year, m.month, day, 6).millisecondsSinceEpoch,
              'end':
                  DateTime.utc(m.year, m.month, day, 15).millisecondsSinceEpoch,
              'state': day == 5
                  ? 'confirmed'
                  : day == 13
                      ? 'pending'
                      : 'unavailable'
            }
        ]
      };
    }
    if (name == 'requestBooking') {
      final key = p['requestId'] as String;
      if (requests.containsKey(key)) return {'id': requests[key]};
      final v = venue(p['venueId'] as String);
      final id = 'preview-request-${requests.length + 1}';
      requests[key] = id;
      bookings.add({
        'id': id,
        ...p,
        'venueName': v['name'],
        'category': v['category'],
        'customerId': 'preview-customer',
        'ownerId': 'preview-owner',
        'customerName': 'عميل معاينة',
        'ownerName': v['ownerName'],
        'paid': 0,
        'remaining': p['price'],
        'total': p['price'],
        'status': 'requested',
        'version': 1
      });
      changed();
      return {'id': id};
    }
    if (name == 'actOnBooking') {
      final b = booking(p['bookingId'] as String);
      final a = p['action'];
      b['status'] = a == 'approve'
          ? 'held'
          : a == 'reject'
              ? 'rejected'
              : a == 'confirmPayment'
                  ? 'confirmed'
                  : a == 'rejectPayment'
                      ? 'payment_rejected'
                      : a == 'cancel'
                          ? 'cancelled'
                          : a == 'complete'
                              ? 'completed'
                              : b['status'];
      if (a == 'confirmPayment') {
        b['paid'] = b['deposit'];
        b['remaining'] = (b['total'] as int) - (b['deposit'] as int);
      }
      b['version'] = (b['version'] as int) + 1;
      changed();
      return {'ok': true};
    }
    if (name == 'sendBookingMessage') {
      messages.add({
        'id': 'message-${messages.length + 1}',
        'senderId': 'preview-customer',
        'message': p['message']
      });
      changed();
      return {'ok': true};
    }
    if (['reportBooking', 'reviewCompletedBooking', 'verifyBookingCheckInCode']
        .contains(name)) return {'ok': true};
    if (name == 'issueBookingCheckInCode')
      return {
        'code': 'OFFLINE-PREVIEW-ONLY',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch
      };
    throw StateError('هذه العملية خارج نطاق المحاكاة المحلية: $name');
  }
}
