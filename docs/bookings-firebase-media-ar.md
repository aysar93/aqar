# وسائط الحجوزات على Firebase Storage

العمل على feature/bookings فقط، من HEAD a7c10278a6022c5b1000d34bab5c16ba844393b9، بعد فحص af32548 وa7c1027. لا تراجع عن وظائف الحجوزات أو إصلاحات إثبات الملكية والمدفوعات والمراجعة المستقلة. Cloudinary للعقارات وبنرات الصفحة الرئيسية وR2 للريلز محفوظان.

## دورة الوسائط الجديدة

- provider=firebase وschemaVersion=3. المسار `booking_media_v3/{venueId}/{ownerUid}/{mediaId}.jpg|mp4`؛ للبنرات الخارجية venueId=banners، وللبنرات المرتبطة بمكان venueId=الوجهة. المعرف والحصة والمالك والمسار يولّدها الخادم. أسماء callables القديمة reviewBookingExternalMedia/removeBookingExternalMedia/cleanupBookingExternalMedia مستمرة للتوافق، لكن لا تستدعي مزودًا خارجيًا للملفات الجديدة.
- uploadBookingImage: حساب فعّال غير مجهول وصلاحية مالك المكان أو الإدارة للبنر، JPEG/PNG بحد 10MiB، فك كامل بـsharp مع حد 40 مليون بكسل، إعادة JPEG بجودة 80 وأبعاد حتى 2560 دون تكبير أو بيانات EXIF. ضغط Flutter السابق مستمر. حفظ بشرط ifGenerationMatch=0 دون رابط تنزيل دائم. إنشاء سجل uploading قبل الحفظ يجعل فشل الحفظ أو الإنهاء قابلًا للتنظيف.
- reserveBookingVideo ثم رفع Storage SDK إلى المسار المحجوز فقط ثم finishBookingVideo. حد 50MiB وvideo/mp4 وحجم مطابق للحجز وتوقيع ftyp. قواعد Storage ترفض الرفع دون حجز أو بعد انتهاء الحجز/انتقال الملكية أو استبدال ملف موجود. الخادم يتحقق مجددًا من الحجم الفعلي والنوع والملكية والحساب، ويزيل firebaseStorageDownloadTokens قبل pending. فحص MP4 هنا فحص حاوية؛ اختبار codec وتشغيل Android/iOS مطلوب.
- الصور تقرأ عبر SDK getData، والفيديو عبر Firebase Storage REST (وعنوان Storage المحلي في نسخة المحاكيات) مع ترويسة Firebase ID token وRange. لا يستخدم v3 getDownloadURL. الصور في بنرات الحجوزات وسلايدرها وفي لوحة الإدارة تستخدم المسار نفسه.
- القراءة قبل الموافقة للمالك الحالي والإدارة فقط؛ العامة بعد الموافقة، مع مكان نشط وملكية مطابقة ومالك غير محظور. البنر العام يتطلب بنرًا نشطًا مرتبطًا بالوسيط. الحذف والاستبدال من العملاء ممنوعان.
- الحصة ذرية: 30 حجزًا غير محذوف للمكان، 100 ملف و500MiB يوميًا للحساب؛ الموافقة لا تتجاوز 20 وسيطًا منشورًا. مراجعة المكان مستقلة عن مالكه. حفظ البنر إداري ويسجل التدقيق كما قبل.
- التنظيف كل ساعة: انتهاء uploading/pending بعد 24 ساعة، أو الرفض/الإزالة/استبدال البنر، ينقل إلى delete_pending. يفحص مراجع الأماكن والبنرات والعقارات والريلز والسجلات الأخرى، ثم يتحقق من المسار والجيل قبل الحذف. إعادة المحاولة بتراجع زمني وحد 50 عنصرًا وميزانية زمنية. الملفات التي فشل رفعها أو إنهاؤها مرتبطة بحجز منذ البداية؛ لا يجري حذف شامل لحاويات أخرى.

## الوسائط القديمة والتكامل المتقاعد

- لا نقل فعلي ولا حذف لبيانات سحابية في هذه المهمة. مسارات booking_media القديمة وbooking_banner_media ما زالت قابلة للعرض وفق قواعدها السابقة. قائمة حذف Firebase القديمة تعمل مع تحقق المرجع والمسار والحالة.
- سجلات schemaVersion=2 وروابطها محفوظة. القراءة القديمة لـR2 مستمرة في Worker عبر BOOKINGS_BUCKET الخاص دون سر Worker أو bridge؛ مسارات الكتابة والحذف /bookings/* أصبحت 410 في مصدر Worker، دون تعديل منطق الريلز. هذا التعطيل لن يسري على Worker المنشور إلا بعد نشر مستقل، ولم ننشره هنا. حُذفت bookingVideoBridge من صادرات Functions الجديدة؛ يجب حذف الوظيفة المنشورة القديمة في نشر مصرح لاحقًا.
- الصور القديمة authenticated في Cloudinary لا يمكن عرضها بلا بيانات وصول المزود. بوابة قراءة فقط في booking_legacy_external_media.js، اختيارية عبر BOOKING_LEGACY_EXTERNAL_READS=true. افتراضيًا غير محملة ولا تُعرّف أسرارًا في مشروع اختبار جديد. إذا كانت ملفات قديمة موجودة فعلًا في المشروع الذي سينشر لاحقًا، يجب الاحتفاظ بالبوابة وأسرار BOOKING_CLOUDINARY_* السابقة حتى نقل تلك الملفات في عملية مستقلة. لا تطلب هذه المهمة أسرارًا ولا تنسخها.
- لا وجود لـfetch أو defineSecret/defineString أو BOOKING_WORKER/BOOKING_CLOUDINARY في مسار الرفع/المراجعة/التنظيف الجديد. الأصول الخارجية المتقاعدة لا تُحذف تلقائيًا؛ يمكن فصل البيانات/الحاوية القديمة بعد جرد ونقل مصرح مستقل. لا تُحذف أسرار المزود العامة لأنها قد تخدم العقارات أو الريلز.

## مشروع الاختبار والتكلفة

المحاكيات demo-aqar على 8185 و9198 لا تحتاج فوترة. للاختبار الحقيقي استخدم مشروع staging المعزول وإعداد Firebase الخاص به، وتأكد من bucket الفعلي في storageBucket وصلاحيات حساب خدمة Functions على ذلك bucket، وربط Storage Rules بـFirestore، ونشر rules وFunctions/indexes معًا ضمن موافقة نشر منفصلة. إعداد Storage الافتراضي وإتاحة Firestore للسياسات يجب اختباره عند النشر.

Firebase يتطلب Blaze لاستخدام Cloud Storage بدءًا من 3 فبراير 2026 وفق [وثائق Firebase](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024). Functions والوظيفة المجدولة تحتاج أيضًا الخدمات والصلاحيات المرتبطة؛ توجد حصص بلا تكلفة لكن ذلك لا يعني عدم إمكان رسوم التخزين/التنزيل/الحوسبة/Cloud Scheduler وبناء الحاويات. راجع [التسعير الرسمي](https://firebase.google.com/pricing). لم تُفحص أو تُعدّل فوترة المشروع ولم يُفعّل أي منتج مدفوع.

قبل اختبار حقيقي مصرح: نشر منسق للعميل وFunctions والقواعد، رفع صورة/MP4، منع القراءة قبل المراجعة ومراجعة مستقلة، منع القديم بعد انتقال الملكية، اختبار رمز تنزيل قديم بعد finish، Range وتشغيل الفيديو على Android/iOS، بنر نشط/غير نشط واستبداله وحذفه وتنظيف الملفات اليتيمة. محاكي Storage لا يزيل downloadTokens الداخلية عند metadata=null؛ الاختبار المحلي يتحقق من إرسال إزالة الرمز، والإثبات الفعلي يحتاج مشروع الاختبار الحقيقي.

## تشغيل الاختبارات محليًا

```
npm ci --prefix functions
npm ci --prefix test/firestore
firebase emulators:exec --project demo-aqar --config firebase.bookings-test.json --only firestore,storage "node test/run_booking_tests.cjs"
node --test functions/booking_policy.test.js functions/booking_media_policy.test.js cloudflare/reels-worker/test/bookings.test.mjs
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
flutter test --no-pub test/booking_test_isolation_test.dart test/booking_staging_isolation_test.dart test/booking_filters_test.dart test/booking_widgets_test.dart test/booking_banners_test.dart test/booking_media_service_test.dart test/payment_accounts_test.dart test/booking_navigation_test.dart test/booking_phase_two_test.dart test/navigation_return_test.dart
```

تبقى CI للتغيير a7c1027 مع اختبارات المحاكيات وFlutter وبناء Android/iOS. لا تعتبر نجاح المحاكيات نشرًا أو نجاح تجربة أجهزة حقيقية.

## نتائج التحقق في 10 أكتوبر 2026

- محاكيات demo-aqar: 14 اختبار Node integration نجحت، و9 اختبارات Python لقواعد Firestore/Storage نجحت؛ تشمل الصور التالفة، الحصص المتزامنة، الملكية والمراجعة المستقلة، البنرات، الفيديو، اليتيم، منع الاستبدال، وحماية المراجع وإعادة محاولة الحذف. اختبار بوابة الصور القديمة محفوظ في ملف مستقل مع محاكاة طلبات Cloudinary.
- Flutter: مجموعة الحجوزات والمدفوعات والتنقل نجحت (25 اختبارًا). بعد إضافة عزل عنوان فيديو المحاكيات أُعيدت مجموعة الوسائط والعزل (10 اختبارات، تشمل الاختبار الجديد). لا يوجد فشل متبقٍّ في الاختبارات التي شُغلت.
- سياسات الحجوزات/الوسائط وWorker للقراءة القديمة/رفض العمليات المتقاعدة: 14 اختبارًا ناجحًا. اختبارات الرفع القديم استُبدلت باختبارات تثبت أنه معطل حتى عند وجود السر السابق.
- التحليل الكامل flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings: exit 0، صفر أخطاء و17 تحذيرًا و201 ملاحظة عامة. بعد تعديل عنوان فيديو المحاكيات أُعيد dart analyze للملفات المتأثرة: صفر أخطاء/تحذيرات و6 ملاحظات أسلوب. git diff --check ناجح.
- npm audit لاعتماديات Functions: صفر ثغرات. sharp مثبت بإصدار محدد 0.35.5 وlockfile محدث؛ هذه مكتبة فك الصور المحلية ولا تحتاج سر خدمة. البيئة المحلية Node 26.7.0؛ إعداد Functions وCI هو Node 24، ولم يُشغّل نشر أو بناء Functions سحابي.
- لم تُشغّل تجربة جهاز فعلية أو بناء APK/iOS في هذه المهمة. CI الموجود سيعمل عند push؛ لا يُعد نجاحه مؤكدًا قبل اكتماله. لم ننشر Firebase/Worker/المتاجر أو نغيّر main أو الفوترة.
