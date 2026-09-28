# App Review 1.2 — عقارات الأنبار

الإصدار المعدّ للإرسال: **1.0.3 (16)**. تُختبر هذه النسخة على iPhone فعلي وتُرفع إلى App Store Connect قبل إرسال الرد أدناه. نجاح فحص GitHub غير الموقّع لا ينتج IPA موقّعًا ولا يرفع التطبيق إلى Apple.

## التغييرات

- موافقة غير محددة مسبقًا على EULA عند إنشاء حساب جديد بالهاتف أو عبر Apple وGoogle وFacebook. تُحفظ الموافقة في `users/{uid}/consents/2026-09-27` مع توقيت الخادم. لا تُطلب الموافقة عند تشغيل التطبيق أو تسجيل الدخول لحساب قائم.
- سياسة صريحة بعدم التسامح مع المحتوى المسيء والمستخدمين المسيئين، مع إزالة المخالفات وإيقاف الحسابات ومراجعة البلاغات خلال 24 ساعة.
- الإبقاء على بلاغات العقارات والمكاتب الحالية وقواعدها الخاصة؛ اختبارات محاكي تثبت حفظها وخصوصيتها ومنع التلاعب بهوية المبلّغ أو نتيجة المراجعة.
- حظر شخصي من تفاصيل العقار والمكتب والطلب والتعليقات والردود والتقييمات. يُحفظ الحظر والبلاغ الإداري معًا في عملية ذرية. تختفي مواد الناشر من القوائم والتفاصيل والمفضلة والخريطة والريلز المرتبطة. صفحة «المستخدمون المحظورون» تسمح بإلغاء الحظر دون حذف البلاغ.
- فلتر نصي عربي/إنجليزي في التطبيق وقواعد Firestore، مع مراجعة البلاغات بعد النشر. تبقى المكاتب الموثقة قادرة على النشر المباشر، وتُنشر التقييمات والتعليقات والردود مباشرةً. تُتحقق ملكية المكتب وتوثيقه من قاعدة البيانات لمنع انتحال صفة مكتب موثق. الفلتر النصي ليس فحصًا آليًا للصور؛ تُراجع الصور والمخالفات غير المكتشفة عند الإبلاغ عنها.
- الإدارة تستطيع مراجعة المحتوى وحذفه وحظر صاحبه من شاشة البلاغات. «بلاغات المستخدمين والحظر» تعرض البلاغات الجديدة والمتأخرة،. مراجعة العقارات والمكاتب والطلبات تستمر من صفحات الإدارة الحالية.
- الحظر الإداري يمنع النشر والتعديل، مع إنهاء الجلسة المفتوحة ومنع إعادة الدخول. لا يستطيع المستخدم فك الحظر عن نفسه أو حذف ملفه لإعادة إنشائه دون حظر.
- التواصل عبر الهاتف وواتساب **+9647838081677** ظاهر في الشروط وشاشة «تواصل معنا» قبل الدخول وبعده.

## تشغيل المراجعة

يجب أن تراجع الإدارة الطابور يوميًا وخلال 24 ساعة من كل بلاغ. الوعد المنشور يحتاج فريقًا ينفذه؛ لا تقوم البرمجيات وحدها بالتحقق من الصور أو اتخاذ قرارات الإساءة. افتح المحتوى، وافحص الصور والنصوص، ثم احذف المخالف وأوقف صاحبه عند اللزوم وسجل نتيجة المراجعة. إغلاق البلاغ وحده لا يحذف المحتوى.

قواعد Firestore الجديدة لازمة لتشغيل الموافقات والحظر. لا تغيّر المشروع `aqar-9f3f9` أو قاعدة `(default)` أو إعدادات مزودي الدخول. لا تتغير سياسة النشر الحالية: المكاتب الموثقة والتعليقات والردود والتقييمات تنشر مباشرةً، مع منع المحتوى النصي المخالف وإيقاف الحسابات المحظورة.

## تسجيل فيديو iPhone

1. ثبّت النسخة الجديدة من TestFlight على **iPhone فعلي**، وجهّز حسابي مستخدمين A وB وإعلانين معتمدين لـB وتعليقًا معتمدًا له على إعلان مستخدم آخر. استخدم محتوى تجريبيًا غير مسيء، وأعطِ App Review حسابًا تجريبيًا يعمل.
2. سجّل الخروج، ثم ابدأ «تسجيل الشاشة» من مركز التحكم. افتح إنشاء حساب جديد: أظهر نص عدم التسامح ومعلومات التواصل، وأن الموافقة غير محددة وأن محاولة التسجيل تعرض رسالة قبل الموافقة. افتح الشروط ثم وافق وأكمل التسجيل. أظهر أن تسجيل الدخول لحساب قائم يعمل دون مربع موافقة.
3. افتح أحد إعلانات B، واضغط زر الإبلاغ الحالي، واختر السبب ثم أرسل؛ أظهر رسالة نجاح الإرسال.
4. أظهر إعلانات B في القائمة والمفضلة والخريطة إن كان له موقع. افتح الإعلان واضغط زر الإبلاغ، واختر السبب، وفعّل «حظر المستخدم أيضًا» ثم اضغط «إرسال البلاغ وحظر المستخدم». أظهر اختفاء الإعلان المفتوح، ثم ارجع إلى القوائم لإظهار اختفاء باقي إعلاناته وتعليقاته فورًا. أعد فتح التطبيق لإثبات استمرار الحظر.
5. افتح «الإعدادات» ثم «المستخدمون المحظورون» وأظهر الحظر المحفوظ. افتح «تواصل معنا» وأظهر الهاتف وواتساب.
6. في لقطة منفصلة بحساب الإدارة، افتح «بلاغات المحتوى»، وأظهر البلاغ العادي وبلاغ الحظر، ثم افتح محتواهما. على المحتوى التجريبي فقط، أظهر الحذف وحظر المستخدم وتسجيل النتيجة. لا تكشف بيانات مستخدمين حقيقيين أو كلمات مرور في الفيديو.
7. أظهر نشر تعليق أو تقييم سليم مباشرةً، وكذلك إعلان مكتب موثق. جرّب نصًا اختباريًا يتضمن `PORN` لإظهار رفض الفلتر، دون نشر مادة مسيئة فعلية.
8. احتفظ بالتسجيل الأصلي؛ لا تسرّع الخطوات المهمة. ارفق الفيديو في App Store Connect أو أضف رابطًا يمكن لفريق Apple فتحه دون طلب صلاحية. أضف رقم البناء وبيانات حساب المراجعة في App Review Information.

## الرد الجاهز — يُرسل بعد رفع النسخة وتسجيل الفيديو

Hello App Review Team,

We have addressed Guideline 1.2 in Anbar Real Estate, version 1.0.3, build 16.

Users must explicitly accept our EULA when creating a new account, including when completing a new social account. The terms state that objectionable content and abusive users are not tolerated. Existing users can sign in without repeated consent prompts. The full terms remain accessible from the sign-in and registration screens.

We have added Arabic and English objectionable-text filtering in the app and in server-enforced Firestore rules. Verified offices, comments, replies, and reviews retain immediate publication. Users can report objectionable content, including images, and administrators can remove reported content and suspend abusive accounts. Reports are reviewed within 24 hours.

The existing report action is available on property and office pages. Users can block an abusive publisher by opening Report, selecting a reason, enabling the optional block checkbox, and submitting the report. Blocking immediately hides that publisher's content for the blocking user and creates an administrator report. Blocks persist across app restarts and can be managed from Settings > Blocked Users.

Our contact phone and WhatsApp number are clearly available in the terms and Contact Us screen, including before sign-in.

We have attached an iPhone recording demonstrating EULA acceptance, reporting, blocking and immediate content removal, persistent blocks, contact information, and administrator moderation. Review credentials are provided in App Review Information.

Thank you for reviewing the updated build.

## التحقق التقني

```
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test test/content_policy_test.dart test/user_blocks_test.dart test/content_report_test.dart test/reel_model_test.dart test/iraqi_phone_service_test.dart test/services
npx -y firebase-tools@15.31.0 emulators:exec --only firestore --project demo-aqar --config firebase.reports-test.json "python test/firestore_safety_rules_test.py"
flutter build apk --debug
```

يفحص workflow `Safety and iOS build` القواعد والاختبارات ويبني iOS على macOS باستخدام `flutter build ios --release --no-codesign`. التوقيع والرفع إلى TestFlight واختبار الأجهزة الفعلية خطوات إصدار منفصلة. مرجع المتطلبات: https://developer.apple.com/app-store/review/guidelines/#user-generated-content


تحديث واجهة الإبلاغ: افتح زر الإبلاغ، واختر سبب البلاغ، ثم فعّل «حظر المستخدم أيضًا» واضغط «إرسال البلاغ وحظر المستخدم». أصبح خيار الحظر داخل نافذة الإبلاغ للعقارات والمكاتب والتعليقات والردود والتقييمات والطلبات. اترك الخيار غير مفعّل لإرسال بلاغ فقط.
