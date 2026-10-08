import 'dart:convert';
import 'package:flutter/services.dart';

class SubscriptionPaymentAccounts {
  static Future<Map<String, dynamic>> load() async =>
      Map<String, dynamic>.from(jsonDecode(await rootBundle
          .loadString('functions/subscription_payment_accounts.json')) as Map);
}
