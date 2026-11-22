import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

abstract class BookingRequestIntentStore {
  Future<Map<String, dynamic>?> read(String uid, String venue);
  Future<void> save(String uid, String venue, Map<String, dynamic> payload);
  Future<void> clear(String uid, String venue, String requestId);
}

/// Private app storage, partitioned by account and venue. No credentials stored.
class FileBookingRequestIntentStore implements BookingRequestIntentStore {
  final Future<Directory> Function() directory;
  FileBookingRequestIntentStore({Future<Directory> Function()? directory})
      : directory = directory ?? getApplicationSupportDirectory;
  static final Map<String, Future<void>> _locks = {};
  Future<T> _locked<T>(
      String uid, String venue, Future<T> Function(File) action) async {
    final key = sha256.convert(utf8.encode('$uid/$venue')).toString();
    final prior = _locks[key] ?? Future<void>.value();
    final result = prior.then((_) async {
      final folder =
          Directory('${(await directory()).path}/booking_request_intents');
      await folder.create(recursive: true);
      return action(File('${folder.path}/$key.json'));
    });
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _locks[key] = tail;
    try {
      return await result;
    } finally {
      if (identical(_locks[key], tail)) _locks.remove(key);
    }
  }

  Future<Map<String, dynamic>?> _read(File f, String uid, String venue) async {
    if (!await f.exists()) return null;
    final envelope = jsonDecode(await f.readAsString()) as Map;
    final p = Map<String, dynamic>.from(envelope['payload'] as Map);
    if (envelope['uid'] != uid ||
        envelope['venue'] != venue ||
        p['venueId'] != venue ||
        p['requestId'] is! String ||
        !RegExp(r'^[0-9]{1,128}$').hasMatch(p['requestId']) ||
        p['start'] is! int ||
        p['end'] is! int ||
        p['end'] <= p['start']) {
      throw StateError(
          'تعذر التحقق من الطلب المحفوظ؛ راجع حجوزاتك قبل إرسال طلب آخر.');
    }
    return p;
  }

  @override
  Future<Map<String, dynamic>?> read(String uid, String venue) =>
      _locked(uid, venue, (f) => _read(f, uid, venue));
  @override
  Future<void> save(String uid, String venue, Map<String, dynamic> p) =>
      _locked(uid, venue, (f) async {
        final old = await _read(f, uid, venue);
        if (old != null && jsonEncode(old) != jsonEncode(p))
          throw StateError(
              'يوجد طلب غير محسوم لهذا المكان؛ أعد فتحه لاستعادته.');
        final temp = File('${f.path}.pending');
        await temp.writeAsString(
            jsonEncode({'uid': uid, 'venue': venue, 'payload': p}),
            flush: true);
        await temp.rename(f.path);
      });
  @override
  Future<void> clear(String uid, String venue, String requestId) =>
      _locked(uid, venue, (f) async {
        final p = await _read(f, uid, venue);
        if (p != null && p['requestId'] == requestId) await f.delete();
      });
}
