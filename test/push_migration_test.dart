import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/services/push_migration.dart';
import 'package:aqar/services/push_device_service.dart';

void main() {
  test('normal builds preserve legacy transport without Firebase calls', () async {
    expect(PushMigration.enabled, isFalse);
    expect(PushMigration.fields, isEmpty);
    await PushDeviceService.register('unused-token', 'unused-user');
    await PushDeviceService.detach();
  });
}
