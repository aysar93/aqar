# تجهيز Firebase FCM في بيئة منفصلة

التاريخ: 13 أكتوبر 2026 — بتوقيت بغداد.

بدأ العمل من `migration/fcm-firestore-2026-10-13` عند commit
`7f4f8d8d5c1601194a2e6daf226beecd4d6a310a`، على فرع
`staging/fcm-isolated-2026-10-13`.

لم يُنشأ مشروع سحابي ولم تُنشر Functions أو قواعد. لم يُستخدم مشروع
`aqar-9f3f9` لتنفيذ أوامر Firebase؛ ولم يُدمج main أو يُعطل OneSignal أو يُغير Vercel الإنتاجي.

## ما تم تجهيزه

- `firebase.fcm-emulators.json`: Auth وFirestore وFunctions على localhost ومعرّف `demo-aqar`.
- مدخل Functions مستقل في `functions/staging/index.js`، يرفض التشغيل خارج المحاكي والمشروع الوهمي. يُحمّل وظائف FCM الثلاث فقط؛ لا يحمل وظائف التطبيق القديمة أو اتصالاتها الخارجية.
- `tools/run_fcm_emulators.cjs`: تشغيل الاختبار دون تعديل manifest الأصلي؛ يحذف متغيرات اعتماد CLI الصريحة من بيئة العملية ولا ينفذ نشرًا.
- مسار الإرسال في Functions لا يتصل بخدمة FCM عند `FUNCTIONS_EMULATOR=true`؛ يسجل معرّفًا يبدأ بـ `emulator-mock:`. الاختبارات الأخرى تستبدل Messaging بمحاكاة تسمح بفحص الرسائل والأخطاء.
- `lib/main_fcm_staging.dart`: واجهة اختبار مستقلة لتسجيل الجهاز وفصله وعرض بيانات الرسائل. لا تشغّل واجهات التطبيق الأصلية أو OneSignal أو خدمة Vercel. تتحقق من الإعدادات قبل Firebase initialization. تتعامل مع token refresh، ورسائل المقدمة والضغط والفتح من حالة الإغلاق. ليست بديلًا عن اختبار تنقل التطبيق الكامل.
- Android: عند `FCM_STAGING_BUILD=true` يستخدم `com.andalus.aqar.staging`، ويرفض الملف الإنتاجي ولا يقرأ مفتاح توقيع الإنتاج، ويستخدم توقيع debug. المسار العادي يحتفظ بمعرّفه وتوقيعه الأصليين.
- أدوات مقارنة إعدادات Dart بالملفات الأصلية للمشروع التجريبي على Android وiOS؛ وأداة iOS تنتج ملفات مقترحة في work دون استبدال مشروع Xcode الأصلي تلقائيًا.
- حزمة سحابية منفصلة قابلة للمراجعة بواسطة `tools/prepare_fcm_staging.cjs`. تتضمن وظائف FCM فقط، والقواعد والفهارس، وNode 22، ومشروعًا يبدأ بـ `aqar-fcm-test-`، وراية `FCM_MIGRATION_ENABLED=false`. لا تنشر الأداة ولا تسجل الدخول.
- Workflow مستقل لاختبارات Flutter والمحاكيات، بلا اعتماد سحابي وبصلاحية `contents: read`. اختبارات القواعد المتشاركة في قاعدة واحدة تُشغّل بـ `--test-concurrency=1` حتى لا تمسح بيانات بعضها.

## نتائج التحقق المحلية

| الاختبار | النتيجة | ما يثبته |
|---|---|---|
| سياسة رسائل FCM | 4 ناجحة | الهوية، payload، بيانات الوجهات، وAPNs/Android collapse |
| Functions المباشرة + قواعد Firestore | 23 ناجحة | عدة أجهزة، التدوير، تبديل الحساب، فصل الجهاز، التفضيلات، منع التكرار، التعامل مع الأخطاء، صلاحيات الإشعارات وقواعد العقارات المميزة |
| Auth + callable HTTP + Firestore trigger عبر المحاكيات | 1 ناجح | رفض طلب بلا هوية، تسجيل مستخدم Auth وهمي، استدعاء الدوال الحقيقية في المحاكي، تشغيل trigger، تسليم وهمي وفصل الجهاز |
| توافق إعدادات Android | 2 ناجحة | قبول إعداد متطابق ورفض الإنتاج أو عدم تطابق المشروع أو المرسل أو التطبيق |
| Flutter: push migration وtoken sync | 9 ناجحة | الحفاظ على النقل القديم افتراضيًا، حالات الفشل وتبديل الحساب وانتظار APNs |
| تحليل ملف staging الجديد | سليم | لا ملاحظات في الملف الجديد |

الإجمالي: **39 اختبارًا ناجحًا في هذه الجولة**. هذا عدد الاختبارات المنفذة هنا، وليس إعادة إعلان رقم الجولة السابقة.

شُغّل تحليل عام للمستودع وظهرت ملاحظات lint في ملفات خارج النطاق الجديد؛ لذلك لا يُوصف المستودع كله بأنه خالٍ من الملاحظات. تحقق الملف الجديد نجح بشكل مستقل.

فشلت محاولة أولى لاختبار Functions بسبب مهلة اكتشاف 10 ثوانٍ؛ رُفعت إلى 60 ثانية ونجح التشغيل. وفشلت محاولة تشغيل مجموعتي قواعد بالتوازي بسبب مشاركتهما قاعدة `demo-aqar` ومسح البيانات؛ أصلح التشغيل التسلسلي المشكلة. تعثر Flutter أيضًا بسبب امتلاء C، ثم نجحت إعادة الاختبار باستخدام TEMP على `D:\CodexScratch\fcm-isolated-2026-10-13`.

البيئة المحلية: Node 26.7.0، Firebase CLI 15.28.1، Java 21. استخدم محاكي Functions إصدار Node المضيف 26 مع تحذير اختلاف runtime؛ الحزمة وCI معدان لـ Node 22. يجب نجاح CI تحت Node 22 قبل الاعتماد على توافق runtime السحابي. نتيجة CI البعيد مستقلة عن هذه النتائج المحلية ولا يُفترض نجاحها لمجرد إعداد الملف.

أبلغ `npm ci` عن 23 تنبيه اعتماديات في functions (منها critical واحد)، و5 high في أدوات قواعد الاختبار. لم تُنفّذ ترقيات تلقائية قد تكسر المشروع. مراجعة الاعتماديات مطلوبة قبل نشر الحزمة السحابية، مع فصل اعتماديات التشغيل عن التطوير.

## تشغيل محلي قابل للتكرار

من جذر الفرع وباستخدام Node 22 وJava 21:

```text
npm ci --prefix functions
npm ci --prefix test/firestore
node --test functions/push_policy.test.js tools/validate_fcm_staging.test.cjs
node tools/run_fcm_emulators.cjs
firebase emulators:exec --project demo-aqar --config firebase.push-test.json --only firestore "node --test --test-concurrency=1 functions/push_functions.integration.test.js test/firestore/featured_properties.test.cjs"
flutter analyze --no-pub lib/main_fcm_staging.dart
flutter test --no-pub test/push_migration_test.dart test/push_token_sync_test.dart
```

FCM ليس ضمن خدمات Emulator Suite؛ نجاح السجل الوهمي لا يعني أن إشعارًا وصل إلى هاتف.
مرجع: [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)،
[المشاريع الوهمية وعزل الخدمات](https://firebase.google.com/docs/emulator-suite/connect_firestore).

## الخطوة الخارجية الأولى: حساب Firebase ومشروع الاختبار

إن لم يوجد مشروع منفصل، ينشئه المستخدم من حسابه باسم ومعرّف مثل `aqar-fcm-test-<unique>` ويرسل **المعرّف فقط** أولًا. لا يلزم إرسال كلمة مرور أو ملف service-account أو مفتاح خاص في المحادثة.

قبل أي نشر:

1. التحقق من المعرف والمالك وأنه منفصل تمامًا عن `aqar-9f3f9`.
2. موافقة المستخدم على Blaze والفوترة، وحدود التكلفة ومراقبتها؛ النشر السحابي لـ Functions يتطلب Blaze، بينما الاختبارات المحلية لا تتطلبه. [متطلبات Functions](https://firebase.google.com/docs/functions/get-started).
3. اختيار موقع Firestore ومطابقته لخطة Functions قبل إنشاء قاعدة البيانات؛ لم تُنسخ منطقة الإنتاج تلقائيًا إلى مشروع جديد.
4. تفعيل Anonymous Auth لحسابات الواجهة التجريبية فقط، مع بيانات مصطنعة، وعدم استيراد بيانات أو tokens إنتاجية.
5. إنشاء حزمة للمشروع الفعلي: `node tools/prepare_fcm_staging.cjs aqar-fcm-test-<unique>`؛ مراجعة الحزمة والقواعد والفهارس وIAM والاعتماديات. ناتج `aqar-fcm-test-template` المحلي مجرد اختبار أداة، وليس مشروع Firebase موجودًا.
6. موافقة منفصلة على نشر هذه الحزمة في المشروع المحدد فقط. لا يُستخدم firebase.json الرئيسي للنشر التجريبي، ولا تُنفذ أوامر deploy عامة من المستودع.
7. إبقاء `FCM_MIGRATION_ENABLED=false` حتى اكتمال التهيئة؛ ثم موافقة على تفعيلها في مشروع الاختبار بعد مراجعة الأجهزة والحسابات المستخدمة.

## Android

سجل تطبيقًا جديدًا بمعرف `com.andalus.aqar.staging` في المشروع المنفصل. نزّل google-services.json منه، وجهز نسخة عمل محلية مخصصة للبناء؛ لا تحفظ استبدال ملف الإنتاج ضمن commit. انسخ `config/fcm-staging.example.json` إلى ملف `.local.json` واملأ بيانات تطبيق Android الفعلية.

تحقق ثم ابنِ واجهة الاختبار على PowerShell:

```powershell
node tools/validate_fcm_staging.cjs config/fcm-staging.local.json
$env:FCM_STAGING_BUILD = 'true'
flutter build apk --debug --target lib/main_fcm_staging.dart --dart-define-from-file=config/fcm-staging.local.json
```

لم تُنفذ عملية بناء APK في هذه الجولة لغياب تكوين Firebase التجريبي الصحيح. توقيع debug يكفي للاختبار المحلي؛ SHA-1/SHA-256 يؤخذان من **توقيع الاختبار** إن احتاجت خدمات المصادقة المختارة ذلك، ولا نفترض توفر مفتاح توقيع المتجر. جهاز Android يحتاج Google Play services متوافقة، وإذن الإشعارات بحسب الإصدار. [متطلبات FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

## iOS وAPNs

سجل تطبيق iOS منفصلًا بمعرف `com.andalus.aqar.staging`. ملف Dart يجب أن يحمل `STAGING_APP_ID` الخاص بـ iOS؛ لا تستخدم App ID الخاص بـ Android.

```text
python tools/prepare_ios_fcm_staging.py config/fcm-ios.local.json <isolated-GoogleService-Info.plist>
```

الأداة تتحقق من المشروع وbundle وapp ID وsender وAPI key، وتنتج ملفات في work. تُراجع ثم تُستخدم في نسخة بناء محلية منفصلة على Mac؛ لا تُطبّق على مشروع الإنتاج أو مسار Codemagic الخاص بالنشر.

في Xcode: اختر Apple Team المخوّل، وسجل App ID المنفصل وProvisioning profile المناسب، وفعل Push Notifications وBackground Modes/Remote notifications. المشروع الحالي يحتوي `aps-environment=development` و`remote-notification`؛ وجودهما في الملفات لا يثبت توفر الاستحقاق في التوقيع الفعلي. لا تغيّر القيمة يدويًا إلى production لتجاوز مشكلة signing؛ تحقق من الاستحقاقات في الملف الموقع حسب قناة التوزيع.

يتطلب اختبار التسليم حساب Apple Developer مناسبًا ومفتاح APNs `.p8` مع Key ID وTeam ID وإعداد صلاحياته الصحيحة للتطبيق. يرفعه المستخدم في إعدادات Cloud Messaging **للمشروع التجريبي**؛ لا يرسله هنا ولا يضعه في Git. حافظ على method swizzling الذي يتطلبه FlutterFire، وانتظر APNs token قبل FCM token. [إعداد FCM على Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

لم يُبنَ iOS ولم يُختبر Xcode أو التوقيع أو APNs؛ الجهاز الحالي Windows. لا نعتبر iOS Simulator أو اختبار الدوال محليًا دليلاً على وصول الإشعار إلى جهاز iPhone موقع فعليًا.

## اختبارات الأجهزة الفعلية التي ما زالت مطلوبة

| الحالة | قبول متوقع |
|---|---|
| Android وiPhone في المقدمة والخلفية والإغلاق | وصول الإشعار، والضغط يمرر بياناته الصحيحة |
| رفض الإذن ثم منحه | سلوك مفهوم، وعدم الادعاء بالتسجيل/الوصول قبل تحقق الصلاحية |
| حساب واحد على جهازين | وصول مستقل لكل جهاز دون تكرار المحاولة لكل حدث |
| تغيير token وتسجيل الخروج وتبديل الحساب | لا يصل إشعار الحساب السابق إلى جلسة الحساب الجديد |
| تعطيل notificationsEnabled | عدم إرسال إشعارات لاحقة بعد حفظ التفضيل |
| رسالة دردشة متتابعة وتعليق ورد | payload صحيح، ومنع تكرار الحدث، وعدم إرسال تغييرات القراءة |
| انقطاع الشبكة وأخطاء FCM | تسجيل الخطأ؛ النتائج الغامضة تتطلب مراجعة ولا يعاد إرسالها عشوائيًا |
| نسخة التطبيق الكاملة التجريبية لاحقًا | اختبار التنقل الفعلي لكل وجهة؛ واجهة staging الحالية تعرض payload فقط |

يجب تسجيل نوع الجهاز وOS ومعرّف البناء ووقت الحدث ونتيجة العرض/الضغط، دون تخزين tokens كاملة في تقرير عام. اختبارات الأجهزة لم تُنفذ هنا.

## حدود هذه المرحلة والموافقات المتبقية

إنشاء المشروع وتفعيل الفوترة، واختيار الموقع، وتوفير ملفات التطبيقات، وإعداد Apple/APNs والتوقيع، ثم مراجعة واعتماد نشر **المشروع التجريبي المحدد** وتفعيل رايته هي الخطوات الخارجية المتبقية. ربط CI بمشروع سحابي ليس ضمن workflow الحالي؛ إن طُلب لاحقًا يحتاج اعتمادًا منفصلًا وهوية بصلاحيات مقتصرة على مشروع الاختبار.

اختبار كامل لتطبيق العقارات يتطلب لاحقًا عزل تكوين Firebase وكل endpoints الخارجية للتطبيق؛ المدخل الرئيسي لا يزال يحتفظ بإعداداته الأصلية، لذلك لا يُشغّل بـ FCM_MIGRATION=true لهذه المرحلة. استخدم المدخل `main_fcm_staging.dart` فقط بعد إعداد الملفات الأصلية المنفصلة.

أي انتقال إنتاجي أو معالجة توافق النسخ القديمة/Vercel أو تحديث المتاجر يحتاج خطة وموافقة جديدة، وليس نتيجة تلقائية لنجاح المحاكيات.
