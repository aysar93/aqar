import 'package:flutter/foundation.dart';

class AppStoreLinks {
  static const appStore =
      'https://apps.apple.com/iq/app/%D8%B9%D9%82%D8%A7%D8%B1%D8%A7%D8%AA-%D8%A7%D9%84%D8%A7%D9%86%D8%A8%D8%A7%D8%B1/id6815804115?l=ar';
  static const googlePlay =
      'https://play.google.com/store/apps/details?id=com.andalus.aqar';

  static Uri ratingUri(TargetPlatform platform) => Uri.parse(
        platform == TargetPlatform.iOS
            ? appStore
            : '$googlePlay&showAllReviews=true',
      );

  static const shareMessage =
      "حمّل تطبيق عقارات الانبار واستعرض أفضل العقارات بسهولة.\n\nApp Store:\nhttps://apps.apple.com/iq/app/%D8%B9%D9%82%D8%A7%D8%B1%D8%A7%D8%AA-%D8%A7%D9%84%D8%A7%D9%86%D8%A8%D8%A7%D8%B1/id6815804115?l=ar\n\nGoogle Play:\nhttps://play.google.com/store/apps/details?id=com.andalus.aqar";
}
