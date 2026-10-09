# قبول staging لنظام الحجوزات

الفرع `feature/bookings` فقط. مشروع الإنتاج `aqar-9f3f9` خارج نطاق هذه الخطوات.

## عزل التطبيق

- flavor `bookingsStaging` يستخدم `com.andalus.aqar.bookingstest`، المطابق لتطبيق Android المسجل في مشروع `aqar-bookings-test-20261009` الموجود مسبقًا.
- `lib/bookings_staging_main.dart` يتحقق من flavor ومعرف مشروع Firebase قبل عرض تسجيل الدخول. تشغيل `lib/main.dart` بهذا flavor يوجه إلى staging قبل تهيئة الإنتاج.
- لا توجد كلمة مرور ثابتة أو حسابات المحاكيات في مدخل staging. يلزم حساب اختبار فعلي مع وثيقة مستخدم وصلاحيات خادمية مناسبة في مشروع الاختبار.
- مدخل `bookingsTest` وAPK المحلي يبقيان معزولين عن السحابة، مع تحذير ظاهر؛ لا يصبح APK مستقلًا بمجرد وجود مشروع Firebase فارغ.
- ملفات إعداد Firebase العميلية تعرف المشروع والتطبيق؛ ليست مفاتيح حساب خدمة. لم تضف هذه الجولة مفاتيح إدارة أو توقيع إنتاج.

## حالة المشروع الملاحظة

قراءة مشاريع Firebase أظهرت مشروع الاختبار وتطبيق Android. قراءة Cloud Functions أعادت HTTP 403 مع `SERVICE_DISABLED` واسم الخدمة `cloudfunctions.googleapis.com`. لم أفعّل خدمات أو فوترة ولم أنشر وظائف أو قواعد. قراءة Cloud Billing لمشروع الاختبار أعادت `billingEnabled:false`؛ الفوترة غير مفعّلة. لم تُقرأ تفاصيل حساب دفع ولم يُربط حساب. هذا ليس فحص IAM كاملًا.

[Firebase يوضح أن نشر Cloud Functions يتطلب Blaze](https://firebase.google.com/docs/functions/faq-and-troubleshooting). لا تنفذ ترقية أو ربط حساب دفع دون موافقة المستخدم الصريحة.

## بناء نسخة cloud بعد تهيئة الخدمات وقبولها

```powershell
flutter build apk --debug --flavor bookingsStaging --target lib/bookings_staging_main.dart --target-platform android-arm64
```

لا توزعها كنسخة صالحة قبل نجاح الدخول والوظائف والقواعد والتخزين والفهارس. الشهادة Debug للاختبار فقط. لا تغير إعدادات flavor الإنتاج أو اشتراكات المكاتب.

## اختبار staging المجهز

`functions/booking_staging_smoke.js` يرفض العمل دون اسم المشروع المحدد و`BOOKINGS_STAGING_CONFIRM=synthetic-test-data-only`. يتطلب API key عميل، حساب زبون ومالك اصطناعيين، ومعرف مكان اختباري ثابت السعر وعقده. استعمل متغيرات البيئة في جلسة آمنة أو أسرار CI، ولا تكتب كلمات المرور في الملفات أو سجلات التسليم.

متغيرات الإعداد:

- `BOOKINGS_STAGING_PROJECT`: `aqar-bookings-test-20261009`
- `BOOKINGS_STAGING_CONFIRM`: `synthetic-test-data-only`
- `BOOKINGS_STAGING_API_KEY`
- `BOOKINGS_STAGING_CUSTOMER_EMAIL` / `BOOKINGS_STAGING_CUSTOMER_PASSWORD`
- `BOOKINGS_STAGING_OWNER_EMAIL` / `BOOKINGS_STAGING_OWNER_PASSWORD`
- `BOOKINGS_STAGING_VENUE_ID`
- `BOOKINGS_STAGING_CONTRACT`: JSON بمفاتيح `synthetic:true`, `price`, `deposit`, `terms`, `cancellationPolicy` المطابقة للمكان الاختباري.

تشغيله: `node functions/booking_staging_smoke.js`. يفحص تسجيل Auth السحابي، إرسال الحجز، قبول المالك، استبعاد المكان عند حجز الفترة، إنشاء تذكرة دعم، ثم إلغاء الحجز الاختباري في finally. لا يستورد fixtures محلية إلى السحابة ولا ينشئ دفعات أو يحول أموالًا. قد تبقى تذكرة الدعم للاطلاع والإغلاق الإداري.

## قبول الأجهزة المطلوب قبل الإطلاق

- الزبون والمالك والإدارة والمالية: الحجز، الشفتات، التعارض، موافقات العربون، رفض الإيصال، الإلغاء والاسترداد وتسوية المالك.
- هاتف دون USB أو محاكيات: دخول وتصفح وتحميل الوسائط والتحقق من QR عبر الشبكة.
- Android وiOS: إذن الكاميرا والرفض وإعادة السماح، QR منتهي أو صادر مجددًا أو لحجز آخر، موظف مسح مسحوبة صلاحياته، واستخدام الرمز مرة واحدة.
- FCM/APNs: تطبيق مفتوح وفي الخلفية وبعد الإغلاق، فتح تفاصيل الحجز الصحيح، حساب محظور وإشعارات معطلة، وتبديل الحساب.
- التذكيرات: نشر المجدول والفهارس، عدم تكرار الإشعار، عدم تذكير حجز ملغي؛ الإرسال المتأخر يعاد التحقق منه في الخادم.
- بنرات الحجوزات والخريطة والصور والفيديو على شبكات بطيئة، وعدم تأثيرها في الرئيسية والمكاتب.
- RTL وتكبير الخط ولوحة المفاتيح وشاشات صغيرة ودوران الجهاز.

اختبارات المحاكيات ونجاح البناء لا تحل محل هذه القائمة. هذه الجولة لم تنشر staging ولم تثبت تسليم إشعارات سحابية.
