import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPaymentAccounts {
  static Map<String, dynamic> parse(Map<String, dynamic>? data) {
    final methods = data?['methods'] as Map? ?? {};
    return Map<String, dynamic>.fromEntries(methods.entries.where((e) {
      final c = e.value as Map;
      final number = c['number'];
      return ['qicard', 'zaincash'].contains(e.key) &&
          c['enabled'] == true &&
          number is String &&
          (e.key == 'qicard'
                  ? RegExp(r'^[0-9]{10,16}$')
                  : RegExp(r'^07[0-9]{9}$'))
              .hasMatch(number);
    }).map((e) =>
        MapEntry(e.key as String, Map<String, dynamic>.from(e.value as Map))));
  }

  static Stream<Map<String, dynamic>> watch() => FirebaseFirestore.instance
      .doc('payment_accounts/shared')
      .snapshots()
      .map((s) => parse(s.data()));
  static Future<Map<String, dynamic>> load() async =>
      parse((await FirebaseFirestore.instance
              .doc('payment_accounts/shared')
              .get(const GetOptions(source: Source.server)))
          .data());
}
