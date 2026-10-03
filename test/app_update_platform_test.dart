import 'package:aqar/app_updates/app_update_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppUpdateModel update({String iosUrl = ''}) => AppUpdateModel(
        id: 'release',
        version: '1.0.5',
        buildNumber: 20,
        title: 'Update',
        description: 'New release',
        storeUrl: ' https://play.google.com/store/apps/details?id=com.aqar ',
        iosStoreUrl: iosUrl,
        isMandatory: false,
        isActive: true,
        features: const [],
      );

  test('routes each mobile platform to its own store', () {
    final release = update(iosUrl: ' https://apps.apple.com/app/id123456 ');
    expect(release.storeUrlForPlatform(TargetPlatform.iOS),
        'https://apps.apple.com/app/id123456');
    expect(release.storeUrlForPlatform(TargetPlatform.android),
        'https://play.google.com/store/apps/details?id=com.aqar');
  });

  test('legacy Android releases do not send iOS users to Google Play', () {
    final release = update();
    expect(release.storeUrlForPlatform(TargetPlatform.iOS), isEmpty);
    expect(release.storeUrlForPlatform(TargetPlatform.android), isNotEmpty);
  });

  test('saves both store links without changing the legacy Android field', () {
    final map = update(iosUrl: ' https://apps.apple.com/app/id123456 ').toMap();
    expect(map['storeUrl'],
        'https://play.google.com/store/apps/details?id=com.aqar');
    expect(map['iosStoreUrl'], 'https://apps.apple.com/app/id123456');
  });

  test('device routing follows the running platform', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final release = update(iosUrl: 'https://apps.apple.com/app/id123456');
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(release.deviceStoreUrl, release.iosStoreUrl);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(release.deviceStoreUrl, release.storeUrl.trim());
  });
}
