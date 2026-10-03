# تقرير إصلاح إحصائيات النشاط — عقارات الانبار

> تحديث المراجعة النهائية: [FINAL DEPLOY AUDIT](activity-final-deploy-audit.md) يثبت Production baseline ويحدّث Call counts إلى Cache نجاح 10 دقائق، ونتائج Flutter إلى 28 اختبارًا. هذه النسخة تحتوي تفاصيل المرحلة السابقة؛ التقرير النهائي هو المرجع للنشر والرجوع.

التاريخ: 2026-10-03، بعد مراجعة ما قبل النشر. الحالة: تنفيذ محلي واختبارات؛ دون نشر قواعد أو Functions أو فهارس أو تعديل بيانات الإنتاج من هذه المهمة.

## النتيجة

تم تطوير `user_activity` و`app_sessions` و`presence` الموجودة. بقي الحقل `user_activity.lastSeen` كما هو. لا توجد Collections موازية، ولا Guest Tracking جديد.

تقرأ القائمة المستخدمين المسجلين على الخادم بصفحات من 30. Presence يحسب UID مرة واحدة، مهما تعددت اتصالاته. تحديث النشاط يعتمد أحداث الدخول/foreground مع مهلة محلية 10 دقائق، بلا heartbeat أو Timer دوري أو Read للتحقق من المهلة.

## الملفات والتغيير المختصر لكل ملف

| الملف | التغيير |
|---|---|
| lib/analytics/services/app_activity_service.dart | متابعة Auth مستمرة واحدة، انتظار اكتمال الدخول، طابور انتقالات، تنظيف قبل الخروج، منع الخروج المتزامن المكرر، وحفظ حدود pause/resume السريعة. |
| lib/analytics/services/visit_tracking_service.dart | حجز Session ID مرة واحدة، فصل الجلسة قبل إنهائها، إعادة محاولة إنشاء مرفوضة، الاحتفاظ بمعرّف الكتابة غير المؤكدة، lastSeen بوقت الخادم مع throttle محلي، ومدة بساعة monotonic. |
| lib/analytics/services/presence_service.dart | connections صغيرة لكل UID، تسجيل onDisconnect قبل النشر، حماية من الكتابات المتأخرة، إعادة اتصال وإلغاء الاشتراكات، عدّ UID الفريد باستعلام مفهرس، وقراءة serverTimeOffset عند طلب وقت النافذة. |
| lib/analytics/services/analytics_service.dart | Query مسجلين بحد 30 وCursor، Cache ملفات 5 دقائق مع جلب دفعات، حد أعلى زمني للجلسات، Cache الجلسات 15 ثانية، وعدد المسجلين الفريدين والجلسات المكتملة. |
| lib/analytics/models/analytics_models.dart | ActivityPage مع cursor/hasMore، Provider كمعلومة، اعتماد معرّف وثيقة النشاط كـUID، ومؤشرات الملخص الإضافية. |
| lib/analytics/screens/analytics_dashboard_screen.dart | تصميم رسمي، Stream ثابت، حالات تحميل/نجاح/خطأ، إيقاف عداد الصفحة عند تغطيتها بقائمة النشطين، وإخفاء مؤشرات الزوار المضللة. |
| lib/analytics/screens/activity_users_screen.dart | قائمة RTL موحّدة، Pagination وزر 30 إضافية، تحديث يدوي، عرض منصة/Provider، وإلغاء Badge «مسجل». لا Listener على القائمة. |
| lib/analytics/widgets/analytics_widgets.dart | بطاقات أصغر، كحلي وذهبي واحد، Segmented Control موحّد، ورسوم جلسات بنفس الهوية. |
| lib/main.dart | بدء متابعة Auth فورًا بعد الواجهة، بصورة مستقلة عن انتظار خدمات الإشعارات؛ إزالة انتظار أول مستخدم لمرة واحدة. |
| lib/screens/login_screen.dart | تعليق Activity أثناء المصادقة والموافقة وتجهيز الحساب، ثم استئنافها؛ ربط حالات الخروج بالتنظيف. |
| lib/screens/register_screen.dart | تعليق واستئناف التتبع حول تجهيز التسجيل الموجود. |
| lib/screens/otp_screen.dart | نفس ربط النشاط حول مسار OTP الموجود، مع حماية mounted بعد الانتظار. |
| lib/services/user_service.dart | تنظيف التتبع قبل إخراج الحساب الموقوف، دون تغيير تسجيل الدخول. |
| lib/services/password_auth_service.dart | تنظيف التتبع قبل إخراج الحساب الموقوف، دون تعديل بيانات الاعتماد أو مسار Phone/Email. |
| lib/widgets/app_drawer.dart | خروج من خلال تنظيف Activity/Presence أولًا. |
| lib/screens/profile_screen.dart | نفس التنظيف قبل الخروج. |
| lib/screens/main_shell.dart | نفس التنظيف في خروج الحساب الموقوف. |
| lib/screens/onboarding/splash_screen.dart | نفس التنظيف في AuthGate. |
| lib/screens/settings_screen.dart | إيقاف التتبع قبل حذف الحساب الموجود، واستعادة الحالة بعد اكتمال العملية أو فشلها. |
| database.rules.json | ACL خادمي للمشرف، قراءة استعلام connections فقط، كتابة/قراءة اتصال المستخدم نفسه، فهرس connections، والتحقق من timestamp وحجم المفتاح. |
| firestore.rules | Validators مشتركة للإنشاء والتحديث في النشاط والجلسات؛ منع تزوير UID/guest/وقت النشاط/وقت نهاية الجلسة، دون فتح writes للزوار. التعديلات السابقة الأخرى محفوظة. |
| firestore.indexes.json | Composite: user_activity: isGuest ASC + lastSeen DESC. |
| functions/analytics_presence_access.js | authorizePresenceDashboard للتحقق من صلاحية المشرف الحالي؛ syncPresenceAdminRole لصيانة ACL عند تغيير الدور/الحظر/الحذف. |
| functions/index.js | سطر ربط الوظائف الجديدة فقط؛ أبقيت ربط وتغييرات الدردشة السابقة. |
| firebase.analytics-test.json | إعداد محاكيات معزول لمشروع demo-aqar، Firestore 8185 وRTDB 9195. |
| test/analytics/activity_tracking_test.dart | UID/Auth/Logout، تزامن lifecycle، مهلة النشاط، أخطاء الكتابة، مصفوفة المنصة/Provider، وعدّ UID الفريد. |
| test/analytics/presence_lifecycle_test.dart | ترتيب onDisconnect، إعادة الاتصال، عدم تراكم listeners، الكتابات المتأخرة وإعادة محاولة النشر المرفوض. |
| test/analytics/analytics_queries_test.dart | limit/filter/cursor، Batch profiles والـCache، مشاركة استعلام الجلسات ودقة معاني الملخص. |
| test/analytics/analytics_ui_test.dart | Layout/RTL، حالات العداد، التخلص من الاشتراك، Pagination، وصور الواجهة. |
| test/firestore_activity_rules_test.py | اختبارات قواعد النشاط والجلسات ومصفوفة Providers والمنصات، مع اختبارات قواعد تقارير سابقة كتحقق Regression. |
| functions/analytics_presence_access.integration.test.js | صلاحيات فعلية على المحاكيات، ACL bootstrap/revoke، استبعاد legacy، اتصالان UID واحد، onDisconnect، ومصفوفة Providers. |
| test/goldens/activity_dashboard.png | معاينة Flutter فعلية ببيانات مثال، وليست بيانات إنتاج. |
| test/goldens/activity_users.png | معاينة قائمة Flutter ببيانات مثال. |
| docs/activity-security-audit.json | مراجعة أمنية محددة لنطاق هذه المهمة. |
| docs/activity-analytics-repair.md | هذا التقرير. |

لم تتغير ملفات Google/Apple/Facebook SDK أو طريقة مصادقتها. لم أغيّر dependencies أو ملفات المنصات. التغييرات السابقة غير المرتبطة بقيت محفوظة.

## Auth وSession lifecycle

الخدمة تملك اشتراك authStateChanges واحدًا وWidgetsBindingObserver واحدًا طوال تشغيل التطبيق. لم يعد _started يحبس الحالة بعد أول حساب.

مسارات الدخول الحالية تستدعي beginSignIn قبل بدء المصادقة، وfinishSignIn بعد انتهاء خطواتها. أثناء الإعداد الاجتماعي لا يُنشأ حضور أو نشاط لحساب لم يكتمل تجهيزه. التتبع يعتمد currentUser.uid وكون الحساب غير anonymous، دون تصفية حسب Provider.

كل انتقال متسلسل: تنظيف UID السابق ثم بدء الجديد. مسارات Logout المعروفة تُنهي الجلسة وتحذف اتصال Presence قبل FirebaseAuth.signOut. عملية Logout المتزامنة تُشارك نفس Future.

pause/hidden/detached تنهي الجلسة والاتصال؛ resumed تبدأ جلسة جديدة. بقي تعريف الجلسة الأصلي، بلا مهلة دمج background القصير.

إنشاء الجلسة لا يُكرر معرّفًا أثناء انتظار acknowledgment. الرفض المؤكد يحرر الحالة ويسمح بمحاولة لاحقة. timeout لا يعني أن الكتابة فشلت، لذلك يُحفظ نفس Session ID المعلّق. مرجع الجلسة المنتهية يُفصل محليًا قبل await كي لا يُعاد استخدامه. الجلسة والنشاط لا يمنع أحدهما الآخر من بدء الكتابة.

مهلة انتظار الكتابات تمنع تعليق الانتقالات بلا نهاية عند فقد الشبكة. كتابة نهاية جلسة غير مؤكدة قد تتأخر أو تُرفض بعد انتهاء المصادقة؛ يُسجل الفشل، ولا يُعاد استخدام الجلسة. لا أدّعي أن قتل العملية فجأة يمكن أن ينهي وثيقة Firestore دائمًا.

## Presence والعداد

البنية الجديدة ضمن العقدة القائمة:

```
presence/UID/connections/PUSH_ID = Server Timestamp
```

لا يُخزن ملف المستخدم داخل Presence. كل اتصال فعلي يملك Push ID مستقلًا يتغير عند إعادة الاتصال بالشبكة، حتى لا يحذف تنظيف اتصال قديم الاتصال الجديد. تسجيل onDisconnect.remove يسبق كتابة timestamp. إنهاء جهاز يحذف معرّفات اتصالات هذه النسخة فقط بتحديث واحد؛ يبقى UID Online إن بقي اتصال جهاز آخر.

.info/connected يعيد النشر عند عودة الاتصال. يوجد كذلك Listener صغير لمسار الاتصال الخاص بهذه النسخة، للمحافظة على الاتصال دون heartbeat writes، وفق توصية Firebase الخاصة بحضور Android. ليس Listener لكل مستخدم في لوحة الإدارة.

عداد المشرف يستخدم Listener بيانات واحدًا على:

```
presence.orderByChild('connections').startAt(true)
```

RTDB يرتب maps بعد القيم البدائية، بينما connections المفقودة = null؛ لذلك يستبعد الاستعلام سجلات legacy/offline على الخادم. القواعد تشترط صلاحية المشرف وهذا الاستعلام تحديدًا. يوجد indexOn للـconnections. يُحسب عدد UID التي لديها اتصال رقمي واحد على الأقل، وليس عدد connection records.

المصدر: [ترتيب بيانات RTDB](https://firebase.google.com/docs/database/flutter/lists-of-data)، [حضور Firebase وAndroid](https://firebase.google.com/docs/firestore/solutions/presence).

الـStream ثابت خارج build، ومراقب .info/connected مشترك مع الخدمة ومُلغى عندما يغادر آخر مستهلك. يغلق StreamBuilder اشتراكه عند Dispose؛ وتُوقفه الصفحة أيضًا عند فتح قائمة النشطين فوقها، ثم تعيد اشتراكًا واحدًا عند العودة. يظهر الخطأ مع إعادة المحاولة بدل 0. لم يُضف polling.

فقد الإنترنت المفاجئ ينظفه الخادم عند اكتشاف انقطاع الاتصال؛ لا توجد ضمانة إزالة فورية قبل timeout الشبكة. عند فقد شبكة جهاز المشرف، يتحول العداد إلى Error بدل عرض رقم cache كأنه حي. يشترك العداد وPresence في مراقب .info/connected واحد؛ لا توجد subscription Firebase مكررة لهذا المسار، ولا polling. يعود العرض عند عودة الاتصال.

## صيانة صلاحيات المشرف

لا تستطيع قواعد RTDB قراءة Firestore مباشرةً. بقي المصدر الموثوق users/UID.isAdmin، مع رفض المشرف المحظور.

authorizePresenceDashboard يقرأ وثيقة الحساب الحالية من الخادم، ويكتب داخل admins/UID تأكيدًا خادميًا {presenceDashboard: true, version: 1, checkedAt: SERVER_READ_TIME_MICROS} فقط إذا كان الحساب مشرفًا مسموحًا. قيم true القديمة وحدها لا تمنح القراءة، فلا نفترض أن ACL القديم مصان. خلاف ذلك يُبقي سجل منع presenceDashboard:false مع checkedAt ويعيد permission-denied. العميل لا يستطيع كتابة admins. معاملة RTDB تمنع قراءة خادمية أقدم من تجاوز قرار أحدث؛ وفي تعادل الوقت تكون الأولوية للمنع. سجل المنع الصغير ضروري حتى لا يعيد منح متأخر إنشاء صلاحية مسحوبة.

syncPresenceAdminRole تعمل عند تغيير isAdmin/isBlocked أو حذف حساب مشرف. تقرأ الوثيقة الحالية بدل الاعتماد على حدث قديم، وتحدّث ACL أو تسجل المنع. إنشاء الحسابات العادية وتعديل بياناتها أو حظرها لا ينفذ I/O إضافيًا داخل الوظيفة. وأحداث تعديل الاسم/Token/lastLogin لا تنفّذ I/O إضافيًا أيضًا؛ لكنها تظل استدعاءات trigger. يوجد حد maxInstances=3 وtimeoutSeconds=30 لكل وظيفة؛ ليس حدًا ماليًا أو Rate Limit. App Check غير مفعّل؛ خطر الاستدعاءات المسيئة مصنف MEDIUM في المراجعة.

سحب الصلاحية عبر trigger غير متزامن وله تأخر نشر/تنفيذ محتمل. يجب نشر الوظيفة مع القواعد؛ نشر القواعد وحدها لا يصلح صيانة ACL.

## lastSeen والساعة

lastSeen يُكتب باستخدام FieldValue.serverTimestamp فقط، عند حدث Activity طبيعي.

المهلة 10 دقائق، بناءً على ساعة monotonic محلية وMap لكل UID في عملية التطبيق. لا Read للتحقق من المهلة. طلبان متزامنان يشاركان كتابة معلقة واحدة. كتابة مرفوضة لا تسمّم المهلة؛ يُسمح بمحاولة لاحقة.

المهلة لا تستمر بعد قتل عملية التطبيق؛ cold start يسجل نشاط تشغيل جديدًا. لا تُكتب Activity عند background، أو فتح صفحة، أو حركة مستخدم، أو مرور وقت فقط.

حد نافذة 24 ساعة يستعمل .info/serverTimeOffset مرة عند فتح/تحديث القائمة. هذا تقدير لوقت الخادم، وليس وقت خادم ذريًا؛ دقته تتأثر بزمن الشبكة. وقت lastSeen نفسه وقت خادم فعلي. نافذة pagination ثابتة حتى التحديث اليدوي، وقد تتحرك سجلات النشاط أثناء تصفح صفحات Firebase؛ واجهة القائمة تزيل التكرار حسب UID.

المصدر: [Firebase clock skew](https://firebase.google.com/docs/database/android/offline-capabilities#clock-skew).

## Pagination ومعلومات المستخدم

Query:

```
user_activity
  where isGuest == false
  where lastSeen >= serverAdjustedNow - 24h
  where lastSeen <= windowEnd
  orderBy lastSeen DESC
  limit 30
  startAfterDocument(lastCursor) عند الصفحة التالية
```

الجلب مرة واحدة لكل صفحة، بلا snapshot listener. ملفات users تُجلب بـwhereIn في دفعات من 30، وCache صالح 5 دقائق داخل خدمة الصفحة. فشل الجلب لا يملأ Cache بملفات فارغة. المعايير لا تعتمد على Provider؛ يُعرض فقط كمعلومة موجودة في Profile. password يُعرض Email / Phone لأن المسار الحالي للهاتف يستخدم Password Auth.

## المعاني والتاريخ

«مستخدمون مسجلون» = Unique UID للمسجلين ذوي جلسات بدأت في الفترة. هذا ليس عدادًا مستقلًا لجميع مستخدمي lastSeen خلال الفترة.

«الجلسات» = وثائق جلسات بدأت خلال الفترة.
«جلسات المسجلين» = جلسات isGuest=false.
«متوسط الجلسة» = متوسط مدد الجلسات المكتملة فقط؛ تعرض — إن لم توجد جلسات مكتملة.
«نشطون آخر 24 ساعة» = قائمة سجلات النشاط المسجلة الحديثة، بوقت خادم.

أُخفيت بطاقات جلسات الزوار/زوار فريدون المضللة، وأضيف توضيح بأن البيانات لا تشمل جميع الزوار.

الجلسات التاريخية لا تزال تُحمّل كل الجلسات المطابقة للفترة. لم أُضف limit يقتطع الأرقام أو aggregation جديدة. الملخص والرسم يشتركان باستعلام واحد وCache 15 ثانية، بما في ذلك refresh داخل مدة الـCache. أُضيف حد أعلى startedAt <= وقت الطلب لاستبعاد بيانات مستقبلية. Query واحدة على حقل الوقت لا تحتاج Composite جديدًا.

## تقدير Firebase بعد الإصلاح

الأرقام تخص الإضافة بسبب Activity/Presence فقط. لا تشمل عمليات تسجيل الدخول وFCM الحالية، ولا الحد الأدنى لتسعير Query الفارغة، ولا قراءات وثيقة المشرف التي قد تُحاسب عليها قواعد Firestore، ولا حجم بروتوكول RTDB. S = عدد جلسات الفترة. P = عدد الملفات غير المخزنة في Cache، بحد 30 لكل صفحة.

| EVENT | FIRESTORE READS | FIRESTORE WRITES | RTDB OPERATIONS |
|---|---:|---:|---|
| Cold start بحساب مسجل | 0 | 2: Session + lastSeen | إنشاء اتصال واحد + تسجيل onDisconnect؛ .info وListener مسار الاتصال نفسه |
| Login مكتمل | 0 بسبب Activity | 1 Session + 0/1 Activity حسب مهلة UID | اتصال واحد + تسجيل onDisconnect |
| Logout طبيعي | 0 | 1 لإنهاء الجلسة إن وجدت | حذف اتصال هذه النسخة + إلغاء onDisconnect والاشتراكات |
| Foreground بعد background | 0 | 1 Session + 0/1 Activity | اتصال جديد + تسجيل onDisconnect |
| Background | 0 | 1 إنهاء Session | حذف الاتصال + إلغاء onDisconnect والاشتراكات |
| 30 minutes foreground دون أحداث أو reconnect | 0 | 0 إضافية دورية | لا data writes من التطبيق؛ تبقى مراقبة الاتصال والـSDK transport |
| Open analytics dashboard | S، أو 0 من Cache؛ +1 قراءة خادمية للتحقق من المشرف لكل اشتراك عداد جديد | 0 Firestore | معاملة ACL: قراءة صغيرة + كتابة، وقد تتكرر المحاولة عند التداخل؛ 1 Listener بيانات لحسابات connections فقط، وقراءة offset صغيرة |
| Open active users | حتى 30 Activity + P Profiles، P<=30 | 0 | قراءة offset صغيرة؛ عداد اللوحة موقوف أثناء تغطيتها |
| Load next 30 users | حتى 30 Activity + P Profiles، P<=30 | 0 | 0 إضافية |

في صفحة فيها 30 حسابًا وملفات غير مخزنة: تقريبًا 60 قراءة وثيقة، وQuery واحدة للنشاط + Query واحدة للملفات. صفحة أخيرة فارغة قد تُحاسب بالحد الأدنى لقراءة Query.

كل عودة foreground تُنشئ جلسة، كما في السابق. مجموع دورة background/foreground أصبح 2 Session writes + 0/1 Activity، بدل 4 Firestore writes سابقًا. cold start بقي 2 writes. التطبيق المفتوح 30 دقيقة بقي بلا writes دورية.

Presence reconnect لا يُنشئ جلسة Firestore جديدة ولا يحدث lastSeen تلقائيًا؛ يعيد اتصال RTDB فقط.

تغيير الفلتر يقرأ S للفترة الجديدة كما في السابق؛ لا زيادة في قراءات السجل التاريخي. القراءة الخادمية الإضافية للمشرف ضرورية لتأسيس ACL بأمان، ولا توجد قراءات ملفات فردية لتأسيسه.

## BEFORE / AFTER

| المجال | BEFORE | AFTER |
|---|---|---|
| Auth | أول حساب فقط، دون تنظيف تغيّر UID | اشتراك واحد مستمر، ربط اكتمال الدخول، تنظيف قبل الخروج |
| Online | online flag مشتركة بين الأجهزة، أخطاء تظهر 0 | connections مستقلة، UID فريد، Error/Loading منفصلتان |
| Activity | كتابة عند بداية ونهاية كل جلسة | كتابة مؤهلة عند الحدث فقط، throttle 10 دقائق، بلا background heartbeat |
| قائمة النشطين | حتى 100، تشمل Guest، بلا pagination | 30 لكل صفحة، registered filter على الخادم، Cursor |
| Profiles | Batch حتى 30 وCache غير محدد الصلاحية | Batch نفسه، TTL 5 دقائق، وفشل Query لا يسمم Cache |
| القراءات الأولى للقائمة | حتى 100 + حتى 100 Profile | حتى 30 + حتى 30 Profile |
| التاريخ | جميع جلسات الفترة + Cache 15 ثانية | نفس الحجم/Cache، مع حد أعلى زمني، بلا إعادة قراءة للملخص والرسم |
| Listeners | Stream عداد جديد في build + Listener للقائمة | Stream عداد ثابت واحد أثناء الحاجة؛ لا Listener للقائمة |
| الجلسات | تداخل foreground/background وحالة إنشاء وهمية | انتقالات متسلسلة، فصل الجلسة المنتهية، وفشل قابل للتعافي |
| التصميم | ألوان كثيرة وبطاقات كبيرة | كحلي/ذهبي موحد، RTL، hierarchy وكثافة متناسقة |

لم يخلق الإصلاح polling أو heartbeat writes أو N+1 reads أو قراءة users كاملة أو Query نشطين غير محدود. يوجد ترحيل login indexes قديم في UserService قد يقرأ users كاملة عند دخول المشرف إذا لم يكتمل marker؛ أبقيته خارج نطاق هذه المهمة ولم أعد كتابته.

## نتائج التحقق

- تأكدت بقراءة metadata فقط أن قاعدة Firestore الحالية (default) إصدار STANDARD. لم أقرأ وثائق إنتاج أو أغير بياناتها.
- flutter analyze على المشروع: 170 diagnostics في تلك الجولة؛ أُصلحت الملاحظة المتعلقة بالتعديل الجديد. بقيت ملاحظات المشروع خارج النطاق دون تغييرات.
- flutter analyze --no-pub lib/analytics test/analytics: No issues found.
- flutter test test/analytics --concurrency=1 --no-pub: 26 اختبارًا ناجحًا، تشمل مقارنات صور الواجهة.
- اختبارات Firestore emulator بعد مراجعة ما قبل النشر: 11 اختبارًا ناجحًا، منها 5 اختبارات Activity/Session/Provider/Authority و6 Regression لقواعد التقارير السابقة.
- اختبارات RTDB/Functions emulator بعد المراجعة: 4 اختبارات تكامل ناجحة، تضم صلاحيات/سحب دور/تداخل منح وسحب/تعدد أجهزة/onDisconnect/مصفوفة Providers.
- git diff --check على نطاق التعديل: ناجح.
- لم أشغّل APK/IPA Build: التغيير لا يضيف native dependencies؛ اختبارات Flutter جمعت الكود والشاشات، والتحليل راجع الربط. لا يمكنني التحقق من OAuth الحقيقي أو أجهزة iOS على هذا الجهاز Windows.

مصفوفة Android/iOS اختُبرت بحقوق مصادقة محاكية وMetadata platform مضبوطة؛ ليست اختبار Google/Apple/Facebook OAuth على أجهزة فعلية. يلزم اختبار قبول على Android وiPhone قبل إصدار التطبيق.

## قبل نشر أي شيء — تغييرات تحتاج مراجعتك

1. مراجعة firestore.rules المحلية: تشديد UID/الأنواع/وقت الخادم/إنهاء الجلسة مرة واحدة.
2. مراجعة database.rules.json: connections وصلاحيات قراءة Query محددة للمشرف وفهرس connections. ACL لا تُكتب من العميل.
3. مراجعة ونشر authorizePresenceDashboard وsyncPresenceAdminRole معًا؛ لا تعتمد على admins موجودة وغير مصانة.
4. إنشاء Composite user_activity المذكور وانتظار جاهزيته.
5. تنسيق إصدار التطبيق مع القواعد والوظائف. الكود الجديد لن يعمل كاملًا على Production قبل هذه الأجزاء.

لا توجد Migration جماعية أو حذف legacy. تسمح قواعد RTDB بكتابة العقدة القديمة لصاحبها حين لا تحتوي connections، لكنها تمنع old client من استبدال عقدة تحتوي connections وحذف اتصالات الأجهزة الجديدة. تحديث online/lastSeen القديم وحده لا يمس connections.

العداد الجديد يتجاهل legacy online flags حتى لا يعيد أرقامًا غير موثوقة. الأجهزة التي تستخدم نسخة قديمة لا تنشئ connections لن تُحسب منه؛ يلزم تنسيق rollout وتوقع نقص مؤقت حتى اعتماد النسخة الجديدة. لا أعتبر هذا عدًّا كاملًا لجميع النسخ القديمة والجديدة معًا.

القواعد المحلية Prototype راجعتها واختبرتها على المحاكيات؛ تحتاج مراجعتك واختبار قبول قبل النشر العام. لم أنشرها.

I've set up prototype Security Rules to keep the data in Firestore safe. They are designed to be secure for UID-owned activity/session writes, server timestamps, and admin-only analytics reads. However, you should review and verify them before broadly sharing your app. If you'd like, I can help you harden these rules.

## مراحل لاحقة

- Guest Analytics مستقل دون فتح guest writes في هذا التغيير.
- Historical aggregation عند نمو S؛ لا تجمع Unique Users يوميًا بالجمع البسيط عبر 7/30 يومًا.
- إنهاء الجلسات المقطوعة بالقوة، وتحديد سياسة دمج background القصير.
- تنظيف/تدقيق البيانات التاريخية المكررة أو الناقصة فقط بعد موافقة مستقلة؛ لم أجرِ Migration.
- إبقاء lastSeen دون أحداث قد يجعله أقدم من الاستخدام المستمر؛ هذا نتيجة قرار منع heartbeat، وليس مؤشر انقطاع Presence.
- اختبار قبول OAuth وأجهزة فعلية، ومراجعة rollout للقواعد والوظائف والفهرس.
