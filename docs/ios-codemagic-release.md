# تجهيز نسخة iPhone عبر Codemagic

## مراجعة قبل الاشتراك في Apple Developer

شغّل workflow باسم `iPhone Review - No Apple Account`. لا يحتاج هذا المسار إلى
حساب Apple أو شهادات توقيع، ويؤكد أن المشروع والاختبارات ونسخة iOS Simulator
تُبنى على جهاز macOS. الناتج `Runner-simulator.zip` مخصص لمحاكي iPhone على Mac؛
لا يمكن تثبيته على iPhone حقيقي ولا رفعه إلى TestFlight.

المشروع مهيأ لبناء IPA موقّع ورفعه إلى TestFlight من خلال workflow باسم
`ios-app-store` في `codemagic.yaml`.

## المتطلبات في Apple

1. عضوية Apple Developer فعالة.
2. App ID صريح بالمعرّف `com.andalus.aqar` مع تفعيل Push Notifications.
3. سجل تطبيق في App Store Connect بالمعرّف نفسه.
4. مفتاح App Store Connect API بصلاحية **App Manager**، مع الاحتفاظ بملف `.p8`؛
   يمكن تنزيله مرة واحدة فقط.

## متغيرات Codemagic

من **Application settings > Environment variables** أنشئ المجموعتين التاليتين.
اجعل القيم الحساسة Secret.

### `appstore_credentials`

- `APP_STORE_CONNECT_PRIVATE_KEY`: المحتوى الكامل لملف `.p8`.
- `APP_STORE_CONNECT_KEY_IDENTIFIER`: قيمة Key ID.
- `APP_STORE_CONNECT_ISSUER_ID`: قيمة Issuer ID.
- `CERTIFICATE_PRIVATE_KEY`: مفتاح RSA خاص بصيغة PEM تستخدمه Codemagic لإنشاء
  أو جلب شهادة Apple Distribution.

يمكن إنشاء `CERTIFICATE_PRIVATE_KEY` على macOS أو Linux هكذا:

```sh
ssh-keygen -t rsa -b 2048 -m PEM -f codemagic_distribution_key -q -N ""
```

ارفع محتوى الملف `codemagic_distribution_key` فقط، ولا تضف المفتاح إلى Git.

### `ios_config`

- `BUNDLE_ID`: القيمة `com.andalus.aqar`.
- `APP_STORE_APPLE_ID`: المعرّف الرقمي من App Store Connect > App Information >
  Apple ID، وليس Bundle ID.

## تشغيل البناء

1. اربط المستودع بتطبيق Codemagic واختر إعداد `codemagic.yaml`.
2. شغّل workflow المسمى **iPhone - App Store Connect**.
3. يتحقق البناء من الاختبارات، وينشئ/يجلب شهادة التوزيع وملف provisioning، ثم
   يزيد build number اعتماداً على آخر نسخة في App Store Connect.
4. عند النجاح يرفع ملف IPA إلى TestFlight. لا يرسل النسخة إلى App Store Review
   تلقائياً؛ افحصها في TestFlight وأكمل بيانات المتجر والخصوصية ولقطات الشاشة، ثم
   أرسلها للمراجعة من App Store Connect.

## ملاحظات توقيع مهمة

- ملف `ios/Runner/Runner.entitlements` يحتوي على `aps-environment`. عند توقيع
  نسخة App Store تستبدل Apple/Codemagic القيمة الفعلية ضمن ملف التوقيع إلى
  production؛ يجب أن يكون Push Notifications مفعلاً للـ App ID والـ profile.
- معرّف الحزمة في Xcode وFirebase وCodemagic متطابق: `com.andalus.aqar`.
- لا تخزن ملفات `.p8` أو مفاتيح PEM أو شهادات `.p12` داخل المستودع.
