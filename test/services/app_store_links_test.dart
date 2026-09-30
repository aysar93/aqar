import 'package:aqar/services/app_store_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS rating uses the official App Store URL', () {
    expect(AppStoreLinks.ratingUri(TargetPlatform.iOS).toString(),
        'https://apps.apple.com/iq/app/%D8%B9%D9%82%D8%A7%D8%B1%D8%A7%D8%AA-%D8%A7%D9%84%D8%A7%D9%86%D8%A8%D8%A7%D8%B1/id6815804115?l=ar');
  });
  test('Android rating preserves the existing reviews URL', () {
    expect(AppStoreLinks.ratingUri(TargetPlatform.android).toString(),
        'https://play.google.com/store/apps/details?id=com.andalus.aqar&showAllReviews=true');
  });
  test('Sharing includes both links exactly once', () {
    expect(
        AppStoreLinks.shareMessage.split(AppStoreLinks.appStore), hasLength(2));
    expect(AppStoreLinks.shareMessage.split(AppStoreLinks.googlePlay),
        hasLength(2));
    expect(AppStoreLinks.shareMessage, contains('App Store:'));
    expect(AppStoreLinks.shareMessage, contains('Google Play:'));
  });
}
