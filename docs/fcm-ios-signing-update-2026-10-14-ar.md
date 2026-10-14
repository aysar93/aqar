# تحديث توقيع واختبار iOS — 14 أكتوبر 2026

هذا التحديث يحل محل الحالة السابقة التي ذكرت عدم وجود شهادة متاحة أو جهاز مسجل أو IPA موقعة. ما زال تشغيل التطبيق واستقبال الإشعارات الفعليان غير مثبتين.

## ما اكتمل فعليًا

- بموافقة المستخدم أُصدرت شهادة Apple Distribution إضافية T8RL9ANSX6 للفريق H96JUT8PUM، سارية حتى 14 أكتوبر 2027. لم تُلغَ أو تُعدّل الشهادة السابقة. تحقق تطابق مفتاحها الخاص مع الشهادة محليًا.
- رُفع P12 وكلمة مروره وملف Ad Hoc كأسرار مشفرة في GitHub Actions للمستودع aysar93/aqar، بالأسماء FCM_STAGING_P12_BASE64 وFCM_STAGING_P12_PASSWORD وFCM_STAGING_ADHOC_PROFILE_BASE64. لم تُحفظ قيم الأسرار في الكود أو التقارير. يستخدم الرفع تشفير LibSodium وفق [واجهة GitHub الرسمية](https://docs.github.com/en/rest/actions/secrets#create-or-update-a-repository-secret).
- بموافقة المستخدم التُقط معرف iPhone المتصل من بيانات USB ثم تأكد تطابقه عبر جلسة Lockdown موثوقة بعد تثبيت Apple Mobile Device Support الرسمي، بتوقيع Apple صالح. أكدت Apple أن الجهاز iPhone 12 Pro Max، وأُنجز تسجيله. الهاتف يبلّغ iOS 26.6.2. لم يُنشر UDID في المستودع أو التقارير العامة.
- أُنشئ ملف Aqar FCM Staging AdHoc 20261014، معرفه LYPN3NFP6U وUUID يساوي 40e592b5-83a7-49fd-97b1-f87de3c04c77. يجيز الحزمة com.andalus.aqar.staging وشهادة T8RL9ANSX6 والهاتف المسجل وحده. تم التحقق من CMS والبيئة production لـ APNs وغياب صلاحية التصحيح.
- نجح [بناء IPA الموقعة](https://github.com/aysar93/aqar/actions/runs/38596439511) على Mac CI، من المصدر 738165e4726683b520633f61777eada49993f7c1. شُغل عبر workflow Safety and iOS build بالمدخل staging_adhoc=true على فرع staging/fcm-complete-2026-10-14، دون دمج main. يستخدم مسار التوقيع القابل للاستدعاء fcm-ios-adhoc.yml؛ لا يرفع إلى متجر.
- فُك تشفير الأثر محليًا بعد التحقق من HMAC، وفُحصت إعدادات Firebase وInfo.plist واستحقاقات توقيع Mach-O وملف التوقيع داخل IPA. الحزمة صحيحة، Firebase هو aqar-fcm-test-20261014، والمنصة iPhoneOS، وaps-environment=production وget-task-allow=false، والجهاز والشهادة مطابقان.
- ثُبتت IPA على iPhone فعليًا، وأكدت خدمة installation_proxy وجود Aqar FCM staging بالإصدار 1.0.5 والبناء 20. لم تُمس الحزمة الإنتاجية com.andalus.aqar.

SHA256 للنسخة الموقعة: cbec067fa39e8a221dca7e1f8653d19f5509d1b1da819d28f526c75572a7b748.

## حماية الأثر ومعالجة التوافق

ملف IPA يتضمن ملف توقيع يحتوي UDID؛ لذلك لا يُرفع خامًا إلى GitHub. الأثر البالغ نحو 45MB مشفر بـ AES-256-CBC وPBKDF2-SHA256 بعدد 200000 دورة، ومحمٍ بـ HMAC-SHA256 مستقل الاشتقاق، ويُحذف مفتاح Keychain المؤقت وملفات التوقيع وIPA الخام في نهاية CI. النسخة المفكوكة محفوظة محليًا بصلاحية حساب Windows الحالي وSYSTEM فقط.

فشل استيراد P12 في المحاولتين الأوليين بخطأ MAC في Keychain، ثم نجح بعد إعادة تصدير الحاوية بالشهادة والمفتاح وكلمة المرور نفسها، باستخدام PBE-SHA1-3DES وMAC SHA1 مع 100000 دورة للتوافق مع مستورد Apple. كلمة المرور عشوائية 256 بت، واعتماد GitHub مغلف بتشفير LibSodium. لا تعني هذه المعالجة تغيير خوارزمية توقيع التطبيق أو تخفيض تشفير أثر IPA. آخر بناء موقّع نجح، وكذلك CI الاختبارات المعزولة وفحص السلامة على مصدره؛ الإخفاقان السابقان محفوظان في ios-signing-ci-runs.json.

## التحقق من ملفي APNs اللذين وفرهما المستخدم

- AuthKey_L74V23VW58.p8: مفتاح EC P-256 صالح من حيث البنية، ويطابق اسمه Key ID فعالًا في فريق H96JUT8PUM باسم Aqar Anbar APNs. نطاقه Team Scoped (All topics)، وبيئتاه Sandbox وProduction. هذا مفتاح مشترك قائم، وليس أحد المفتاحين الجديدين المقيدين بالتطبيق التجريبي. وافق المستخدم صراحة على ربط الملف المحدد بـ Firebase التجريبي.
- AuthKey_D336L54R3T.p8: بنية EC P-256 صالحة، لكن Key ID لا يظهر ضمن مفاتيح APNs الفعالة في هذا الفريق. لم يُرفع إلى Firebase؛ لا تُفترض صلاحيته للإشعارات أو نوع خدمته من اسم الملف وحده.
- لم يُطبع محتوى أي ملف p8 أو يُرفع إلى GitHub. القيم الخاصة لم تدخل التقارير. مطابقة البنية والاسم مع Apple ليست إثبات مصادقة APNs تشفيريًا؛ الإثبات النهائي يتطلب إرسالًا ناجحًا ووصولًا فعليًا.

## المتبقي عند كتابة التحديث

1. انتهت جلسة Google في المتصفح، وفُتحت صفحة الدخول للمستخدم. يلزم إكمال الدخول ذاتيًا قبل رفع L74V23VW58 إلى خانتَي APNs في المشروع aqar-fcm-test-20261014 فقط. لم يحدث الرفع بعد.
2. فتح التطبيق على الهاتف والتأكد من شاشته. Developer Mode غير مفعّل عند الفحص؛ لم يُغيّر هذا الإعداد. لم يُفترض أن التثبيت يثبت التشغيل.
3. تسجيل حساب اختبار داخل التطبيق، ومنح إذن الإشعارات، ثم التحقق الفعلي من المقدمة والخلفية والإغلاق والنقر والتنقل والتفضيلات وتبديل الحساب. استقبال iPhone ما زال غير مثبت.
4. لا يوجد TestFlight أو نشر متجر. لا يزال الجهاز الثاني Android واختبار الانتشار المختلط والأداء السحابي ومتابعة تنبيهات التبعيات ضمن البنود السابقة غير المكتملة.

الأدلة: ios-signing-certificate-state.json، ios-signing-secrets-state.json، ios-adhoc-profile-state.json، iphone-connection-state.json، ios-signed-ci-progress.json، ios-ipa-verification.json، iphone-staging-installation.json، apns-provided-keys-verification.json، ولقطات Apple المحلية.

فحص لاحق لسجل CI الناجح لم يجد UDID خامًا أو كلمة مرور التوقيع أو P12/profile بصيغة Base64؛ الدليل ios-signing-log-privacy-check.json.

## تحديث ربط APNs بعد تسجيل Google

تم حفظ المفتاح L74V23VW58 للفريق H96JUT8PUM في خانتَي Development وProduction لتطبيق Aqar FCM iOS Staging داخل aqar-fcm-test-20261014، والتحقق من ظهوره في الخانتين في واجهة Firebase. خانة Production لازمة لنسخة Ad Hoc التجريبية؛ لم يتغير مشروع Firebase الإنتاجي. لم يُستخدم D336L54R3T ولم يُرفع أي APNs إلى GitHub. دليل الواجهة المحلي: firebase-apns-L74-configured.png. هذا يحل البند الأول أعلاه؛ لا يثبت استقبال iPhone قبل تجربة الجهاز الفعلية.
