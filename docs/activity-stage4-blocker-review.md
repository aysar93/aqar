# STAGE 4 BLOCKER REVIEW — 2026-10-03

فحص وإصلاحات محلية واختبارات فقط. لا Functions/Rules Deploy ولا --force ولا Commit/Push. لا تعديل إداري يدوي لبيانات Production. تشغيل نسخة التشخيص على الهاتف ينفذ النشاط والجلسات المعتادة للتطبيق.

## القرار

| البند | النتيجة |
|---|---|
| retry:true | REQUIRED ضمن تصميم RTDB Admin ACL الحالي |
| Function affected | syncPresenceAdminRole |
| Recommended action | KEEP، لا موافقة نشر مستنتجة |
| --force required after fix | YES لقبول failure policy عند النشر غير التفاعلي؛ لم يُستخدم |
| Retry cost risk | MEDIUM؛ HIGH في خطأ دائم |
| Period analytics error | firebase_database/unknown: java.lang.Exception: Invalid token in path عند .info/serverTimeOffset.get() |
| Index related | NO |
| Rules related | NO |
| Local code bug | YES |
| Fix applied locally | YES، وقت SDK وIdempotency ACL وLogging |
| Tests | PASS |

## الوظيفتان وRetry

### authorizePresenceDashboard

Callable v2، maxInstances=3 وtimeout=30s. لا retry:true، ولا إعادة استدعاء تلقائي من العميل بعد الفشل. PresenceService نجاحه محفوظ UID + TTL عشر دقائق بساعة monotonic. الطلبات المتزامنة تتشارك Future واحدة. build/period/resume لا تستدعي الوظيفة. فشل الطلب يُعرض، وزر retry يعيد الطلب يدويًا. دخول الصفحة من جديد قد يولد محاولة جديدة إذا لم يوجد نجاح مخزن؛ ليست حلقة Retry.

تقرأ users/UID الحالية Server-side، ثم معاملة صغيرة تحت admins/UID. غير المصادق والـanonymous يُرفضان قبل I/O. الحساب الموجود غير المصرح له قد يكتب denial ACL ثم يعيد permission-denied، وهذا مقصود لمنع بقاء صلاحية قديمة. فشل backend يعود للعميل ولا يُجدول Retry من الخادم. قراءات ومعاملات SDK الداخلية تحت التنافس/انقطاع الشبكة ليست استدعاءات Callable جديدة من التطبيق.

### syncPresenceAdminRole

Firestore onDocumentWritten v2 على users/{uid}، وحدها تحمل retry:true. كل كتابة users تسلّم حدثًا، لكن تغيير بيانات مستخدم عادي أو تعديل profile/login/token دون تغير isAdmin/isBlocked يخرج قبل أي Firestore get أو RTDB transaction. منح/سحب دور أو تغيير حظر مشرف أو حذفه يقرأ الحالة الحالية ويحدّث ACL.

سبب الاحتفاظ: RTDB Rules تعتمد على ACL مستقلة ولا تقرأ Firestore. مع retry:false، حدث سحب الدور الفاشل يمكن أن يُسقط ويترك ACL=true؛ Callable المستقبلية للمشرف المسحوب ليست ضمانًا لتصحيحه لأنه يستطيع استخدام ACL القديمة دون استدعائها. maxInstances لا يصلح هذا الخلل. حذف Retry يتطلب قبول best-effort revocation أو تصميمًا بديلًا مثل lease/verification، وهو خارج هذا الإصلاح المحدود.

Retry يحسن التعافي من الفشل المؤقت ولا يضمن السحب الفوري أو التعافي من خطأ دائم. نافذة الجيل الثاني الجديدة 24 ساعة مع exponential backoff؛ 7 أيام المذكورة في رسالة CLI تخص التحذير العام/الجيل الأول. بعد انتهاء النافذة يلزم تدخل تشغيلي. المرجع: https://firebase.google.com/docs/functions/retries . لا Timer أو retry loop صُمم في العميل.

## Idempotency: قبل/بعد

قبل هذا الفحص: checkedAt يعتمد على Firestore readTime؛ إعادة الحدث بعد نجاح الكتابة تعطي readTime أحدث وتكتب ACL مجددًا. كان القرار نفسه آمنًا، لكن السجل ليس ثابتًا والكتابة غير ضرورية.

بعد الإصلاح المحلي:

- المستند الموجود: checkedAt مشتق من updateTime Server-side الثابت لنفس النسخة، وليس وقت قراءة جديد.
- حدث حذف والمستند ما زال غير موجود: يستعمل before.updateTime؛ denial يتغلب على grant عند نفس النسخة. تبقى tombstone؛ لا يُحذف ACL.
- معاملة RTDB تُلغى عند watermark أحدث، أو denial قائم لنفس النسخة مقابل grant، أو version=1 ونسخة وقرار مطابقين. تكرار حدث ناجح بنفس حالة Firestore لا يكتب ACL مجددًا.
- كل تنفيذ يعيد قراءة الحالة الحالية، فلا يعيد تطبيق isAdmin من payload قديم. إذا تغيرت الحالة فعلًا، فالنتيجة الجديدة مقصودة وليست duplicate side effect.
- absent-document Callable بلا deletion event تستعمل readTime Server-side كـfallback؛ استدعاء يدوي متكرر لهذا الاستثناء قد يكرر denial watermark write. لا Retry تلقائي لها ولا مسار طبيعي للمشرف الحالي على مستند محذوف. لا ندّعي أن كل طلب يدوي ضار بلا تكلفة.
- Firestore read ومعاملة RTDB منطقية واحدة ما زالت تتكرران لكل محاولة ذات علاقة. abort يمنع write لكنه ليس وعدًا بانعدام RTDB traffic. SDK قد يعيد transaction تحت التنافس.
- لا invocation loop: المصدر users في Firestore، والوجهة admins في RTDB، دون تحديث users من الوظيفتين.

اختبار المحاكيات يثبت ACL متطابقًا بعد تكرار promotion/deletion، ورفض منح معلق بعد deletion لنفس نسخة المستند. اختبارات revocation والـblocked admin وUID ownership القديمة نجحت أيضًا. هذا الإصلاح يغيّر مصدر watermark محليًا؛ الوظائف غير منشورة ولا يوجد ACL versioned أنشأته في Production، ولا Migration مطلوبة. Snapshot reviewed.analytics_presence_access.js الأصلي لم يُستبدل.

## فرق التكلفة التقريبي

A = عدد محاولات حدث فاشل حتى النجاح/انتهاء النافذة، وليس سقفًا ثابتًا للفاتورة.

| الحالة | retry:false | retry:true |
|---|---|---|
| users write غير متعلق بالدور | invocation واحدة، 0 reads و0 RTDB I/O | نفسها؛ لا خطأ في مسار early return |
| تعديل دور ناجح | invocation واحدة، 1 current-user read، 1 logical transaction، عادة 1 ACL write | نفس الكلفة الطبيعية |
| تكرار تسليم حدث ناجح | تكرار التسليم ممكن أيضًا؛ 1 read وtransaction لكل تسليم، 0 ACL writes إذا نفس النسخة/القرار | نفسه بعد إصلاح Idempotency |
| خطأ مؤقت | محاولة واحدة؛ قد تبقى ACL قديمة | A invocations، وحتى A reads وA logical transactions حسب موضع الفشل؛ write واحدة للتغيير، ثم abort للتكرار الناجح |
| خطأ دائم | محاولة واحدة وحدث قد يُسقط؛ خطر صلاحية stale | A attempts حتى نهاية نافذة Retry، تكلفة HIGH محتملة، وقد تبقى ACL stale إذا لم تتعاف الخدمة |

لا Firestore writes داخل الوظيفتين. maxInstances=3 حد تزامن وليس حد invocations أو تكلفة. إشارات errors/retries ووجود external emergency rules rollback مطلوبة قبل قبول Production. حذف retry ليس تخفيض تكلفة آمنًا في عقد ACL الحالي.

## خطأ إحصائيات الفترة: إثبات فعلي

أضيف Logging محدود في _load يسجل مرحلة الفشل والاستثناء والـstack، ويعيد رمي الخطأ ليبقى ظاهرًا بالواجهة. بُني APK Debug واحد خلال 307.5 ثانية وثُبت adb install -r؛ لا uninstall أو مسح بيانات.

الهاتف OPPO CPH2365 / Android13 / UID المشرف المحفوظ. السجل period-error-before.txt:

    Period analytics failed at server-time (.info/serverTimeOffset):
    [firebase_database/unknown] java.lang.Exception: Invalid token in path

الـstack: MethodChannelQuery.get → Query.get → PresenceService.serverNow → AnalyticsDashboardScreen._load. Failure في RTDB SDK metadata وليس Firestore collection. القراءة .info/serverTimeOffset.get() تستخدم مسار بيانات server؛ Android يرفض token .info في get. المرجع التقني: https://github.com/firebase/firebase-android-sdk/blob/master/firebase-database/src/main/java/com/google/firebase/database/core/Repo.java ، getValue يستخدم serverSyncTree/connection.get بينما .info listeners تستخدم infoSyncTree.

الإصلاح: onValue → فلترة numeric → Stream.timeout(8 seconds) → first. first يلغي الاستماع عند data/error؛ Stream timeout يوصل error ثم يلغي، بدل Future.timeout الذي قد يترك انتظار first القديم حيًا. لا Listener دائم للوقت، لا قراءة users، لا كتابة RTDB أو Firestore لتحديد الوقت. يحافظ على إزاحة وقت الخادم، دون fallback صامت إلى ساعة الهاتف.

اختبر المصدر المصحح عبر Flutter attach + Hot Restart دون Build ثانٍ، ثم فتح الصفحة مرة واحدة: 106 sessions، 41 registered unique users، متوسط 2د16ث، وظهر chart. الصورة dashboard-period-fixed.png وblocker-after-ui.xml. Rules القديمة نفسها نجحت مع Query الحالية؛ لم تُنشر Rules لتجربة الحل. Presence NOT_FOUND بقي منفصلًا لأن الوظيفة غير منشورة.

تنبيه artifact: APK Debug المثبت بُني لأخذ الاستثناء قبل إصلاح الوقت. الاختبار المصحح عبر Hot Restart فقط؛ الإصلاح في المصدر وعلى VM الحالي، وليس في ملف APK المثبت. يلزم Build/تثبيت APK مصحح قبل قبول الجهاز واستئناف النشر، وإلا قد يعود العيب بعد إنهاء العملية. APK Release السابق كذلك لا يتضمن هذا الإصلاح.

## Query والقراءات

الفشل السابق حدث قبل Query Firestore، لذا لم يفشل app_sessions query ولا فهرس user_activity.

الاستعلام التاريخي الموجود لم يتغير:

    collection('app_sessions')
      .where('startedAt', isGreaterThanOrEqualTo: periodStart)
      .where('startedAt', isLessThanOrEqualTo: serverNow)
      .get()

لا orderBy صريح. نطاقان لنفس الحقل، يستخدم فهرسة startedAt المفردة. Production allow read/delete: if isAdmin() للمجموعة؛ لا شرط فترة يمنع الاستعلام. نجاح القراءة على الجهاز يؤكد ذلك دون الاعتماد فقط على النص.

Summary وChart يتشاركان Future/Cache 15 ثانية، أي قراءة documents S للفترة مرة واحدة، وليس مرتين. 106 كانت نتائج 24 ساعة في الاختبار، وليست قيمة دائمة. حدود الفترة الزمنية موجودة لكن عدد sessions غير محدود بـlimit؛ هذه كلفة تاريخية موجودة ومؤجلة للAggregation كما اتفقنا. لا نزيدها باستعلام إضافي. مقارنة بمحاولة كانت تتوقف قبل Firestore، القراءة الناجحة تنفذ بالطبع S reads المقصودة؛ لا ندّعي بقاء صفر reads بعد إصلاح الفشل.

user_activity/isGuest/lastSeen/fهرس Pagination الجديد ليس في مسار الخطأ أصلًا. لم تُفتح active users أثناء هذا الفحص. لا full users/user_activity reads، ولا N+1 أو polling أو aggregation جديد.

## الاختبارات والتغييرات

- Flutter targeted: 12 PASS (3 SDK-time listener data/error/timeout، cache/no-auto-retry، lifecycle، UI).
- Functions/RTDB على demo-aqar المحلي: 5 PASS، bridge test واحد SKIPPED عمدًا في config الحالي.
- Scoped analyze 3 files: No issues found.
- node --check لكلا ملفي Functions: PASS. git diff --check على النطاق: PASS.
- جهاز Android: exception reproduces قبل الإصلاح، وperiod analytics success بعد Hot Restart؛ لا ادعاء قبول Online أو providers في هذا الفحص.

الملفات المتعلقة بهذه الجولة:

1. functions/analytics_presence_access.js: stable revision، abort identical ACL، deletion revision، تعليق سبب retry.
2. functions/analytics_presence_access.integration.test.js: duplicate promotion/deletion + stale deletion/grant race.
3. lib/analytics/services/presence_service.dart: SDK metadata one-shot stream بدل get.
4. lib/analytics/screens/analytics_dashboard_screen.dart: stage/error/stack logging دون إخفاء Error.
5. test/analytics/presence_lifecycle_test.dart: إلغاء listener نجاح/error/timeout.
6. هذا التقرير وملفات أدلة الهاتف. Git diff الكامل لهذه الملفات قد يضم إصلاحات سابقة غير committed؛ لا يُنسب كل الـdiff إلى الجولة الحالية.

SHA256 المصدر الجديد للوظيفتين: c044cb53cbb410f3bad2589bc225c3a6b185d4c047e59d4fcf9078145fda73e4 . يختلف عمدًا عن snapshot المعتمد السابق؛ يحتاج مراجعة هذا الإصلاح قبل أي نشر.

## خطة استئناف المرحلة 4 — غير منفذة

1. اعتماد إصلاح revision وإصلاح وقت SDK وقرار KEEP retry، وموافقة صريحة منفصلة على --force. لا استخدام له خلال هذا الفحص.
2. تجهيز Build Android واحد يتضمن إصلاح Flutter، بنفس شهادة الاختبار الحالية، وتثبيته -r. اختبار cold launch + period analytics فوق Rules الحالية لإثبات الإصلاح داخل APK، مع حفظ Auth والبيانات. لا طرح عام.
3. إعادة GET للقواعد ومقارنتها بالbaseline، وتأكيد user_activity index READY واحتفاظ الـ12 القديمة. أي drift = STOP.
4. بعد الموافقة على retry فقط، أمر المرحلة 4 المقترح في PowerShell (لا يُنفذ الآن):

    & 'C:/Users/AL-NOOR/AppData/Roaming/npm/firebase.ps1' deploy --project aqar-9f3f9 --config firebase.activity-deploy.json --only 'functions:authorizePresenceDashboard,functions:syncPresenceAdminRole' --non-interactive --force

الخيار --force هنا لقبول failure policy المعتمدة بعد تقييمها، وليس لتجاوز index deletion أو نشر عام. الاختيار only محدد؛ أي خطأ جديد = STOP دون retry تلقائي.

5. اقرأ deployment metadata: ACTIVE/us-central1/nodejs24/maxInstances3/timeout30 للوظيفتين. اختبر admin والnormal authenticated من SDK فعلي، ACL عبر الوظيفة فقط. اختبار unauthenticated لا يُعد بديلًا عن normal authenticated.
6. لا Rules حتى INDEX READY + FUNCTIONS PASS + ADMIN AUTHORIZATION PASS + BASELINE UNCHANGED. راقب Invocation/errors؛ وأبقِ خطة emergency read-disable متاحة مستقلًا عن التطبيق. بعدها فقط مراحل Rules/Presence/Active Users المعتمدة.

توقف. لا Deploy ولا Public release موافق عليه من هذا التقرير.
