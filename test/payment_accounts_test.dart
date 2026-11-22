import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/subscription/payment_accounts.dart';

void main() {
  test('only enabled, nonempty, valid accounts reach customers', () {
    expect(SubscriptionPaymentAccounts.parse(null), isEmpty);
    final data = {
      'methods': {
        'qicard': {'enabled': true, 'number': '7066135323'},
        'zaincash': {'enabled': false, 'number': '07701234567'},
      }
    };
    expect(SubscriptionPaymentAccounts.parse(data).keys, ['qicard']);
    data['methods']!['qicard']!['number'] = '';
    expect(SubscriptionPaymentAccounts.parse(data), isEmpty);
    data['methods']!['zaincash']!['enabled'] = true;
    expect(SubscriptionPaymentAccounts.parse(data).keys, ['zaincash']);
    data['methods']!['zaincash']!['number'] = 'bad';
    expect(SubscriptionPaymentAccounts.parse(data), isEmpty);
  });
}
