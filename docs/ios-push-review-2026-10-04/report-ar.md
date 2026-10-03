# مراجعة الإشعارات الخارجية على الآيفون

التاريخ: 2026-10-04 بتوقيت بغداد. مراجعة للقراءة فقط؛ لم تتغير إعدادات أو ملفات التطبيق، ولم تُرسل إشعارات.

## النتيجة

تطبيق OneSignal الذي يهيئه التطبيق غير مُعد حاليًا للإرسال إلى Apple APNs. لا يمكن اعتبار إشعارات الآيفون جاهزة قبل ضبط ذلك واختبار نسخة موقعة على جهاز فعلي.

## الفحص المباشر

تمت قراءة إعدادات تطبيق OneSignal باستخدام بيانات الاتصال الموجودة محليًا دون طباعة المفاتيح أو حفظها. استجاب API بحالة 200، ومعرّف التطبيق يطابق الموجود في FCMService.

حقول إعداد Apple موجودة في الاستجابة لكنها فارغة: apns_bundle_id، apns_env، apns_p8، apns_certificates، apns_team_id، apns_key_id. لا يوجد مفتاح p8 أو شهادة APNs مضبوطة لتطبيق OneSignal المحدد.

## ما هو موجود في الكود

- Firebase مهيأ لنظام iOS، ومعرّف الحزمة com.andalus.aqar يطابق Xcode.
- Runner.entitlements يتضمن aps-environment، وإعداد التوقيع يشير إليه.
- Info.plist يحتوي على remote-notification في Background Modes.
- كود التطبيق يطلب إذن الإشعارات ويسجل معرّف اشتراك OneSignal ويستقبل النقر على الإشعارات.
- الخادم المحلي D:/Projects/notification_server/server.js يرسل عبر OneSignal إلى oneSignalId المخزن للمستخدم. لا يمكن اعتبار وجود المصدر المحلي إثباتًا لمطابقته لكل إعدادات خادم Vercel المنشور.

## نقاط الكود التي تحتاج معالجة

1. saveTokens يحصل أولًا على FCM Token ثم يحفظ OneSignal ID في كتلة try واحدة. عند فشل الحصول على FCM Token، لا يصل إلى حفظ OneSignal ID في تلك المحاولة. مراقب OneSignal قد يحفظه لاحقًا عند تغير الاشتراك، لكنه لا يزيل هذه المشكلة في مسار تسجيل الدخول.
2. لا يوجد انتظار أو تحقق من APNs Token قبل getToken على iOS، بينما وثائق Firebase تطلب جاهزية APNs قبل استدعاءات رموز FCM.
3. مسار استقبال FCM أثناء فتح التطبيق يسجل الرسالة فقط دون ضبط setForegroundNotificationPresentationOptions. مسار OneSignal الموجود يطلب عرض الإشعار صراحةً.
4. المشروع لا يتضمن Notification Service Extension أو App Group لـ OneSignal. هذا لا يثبت فشل كل إشعار نصي، لكنه يجعل إعداد ميزات OneSignal الكاملة مثل المرفقات وتأكيد التسليم غير مكتمل.

## المطلوب لتفعيل الآيفون

- إعداد Apple iOS في OneSignal لنفس تطبيق OneSignal المستخدم في الكود.
- إضافة مفتاح APNs .p8 مع Key ID وTeam ID وربطه بمعرّف الحزمة com.andalus.aqar، أو شهادة APNs صالحة.
- التأكد من تفعيل Push Notifications لمعرّف التطبيق وملف التوقيع في حساب Apple.
- فصل حفظ معرّف OneSignal عن أي فشل في الحصول على FCM Token، والتعامل مع جاهزية APNs.
- اختبار نسخة TestFlight/App Store على آيفون مع الإذن ممنوحًا، في حالات التطبيق المفتوح والخلفية والمغلق، ثم التأكد من وجهة النقر.

لم تُفحص النسخة الموقعة IPA ولم يُجر اختبار تسليم على جهاز. قيمة development في ملف المصدر وحدها ليست دليلًا على خلل نسخة App Store؛ يلزم فحص صلاحيات النسخة الموقعة وملف provisioning.

## مصادر رسمية

- OneSignal Flutter setup: https://documentation.onesignal.com/docs/en/flutter-sdk-setup
- OneSignal View an app API: https://documentation.onesignal.com/reference/view-an-app
- Firebase FCM Flutter setup: https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- Firebase FCM receiving messages: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages

الأدلة غير الحساسة محفوظة في onesignal-platform-metadata.json داخل هذا المجلد.
