# مراجعة ما قبل النشر — 2026-10-03

> تحديث المراجعة النهائية: [FINAL DEPLOY AUDIT](activity-final-deploy-audit.md) يثبت Production baseline ويحدّث Call counts إلى Cache نجاح 10 دقائق، ونتائج Flutter إلى 28 اختبارًا. هذه النسخة تحتوي تفاصيل المرحلة السابقة؛ التقرير النهائي هو المرجع للنشر والرجوع.

الحكم يخص الملفات المحلية واختبارات مشروع demo-aqar فقط. لم يُنفّذ Build أو Commit أو Push أو Deploy أو تعديل بيانات Production. لا نفترض أن قواعد Production تطابق أي Git revision؛ لم تُسترجع القواعد المنشورة في هذه المراجعة.

## النص الفعلي والـDiff

- [Diff كامل لملفات Firebase ضمن نطاق الإحصائيات وملف القواعد المشترك](activity-firebase-predeploy.diff): مقارنة الأب السابق لـ0b7f286 بالملفات الحالية، وليس مقارنة بالقواعد المنشورة في Production.
- [Diff إصلاحات هذه المراجعة وحدها](activity-predeploy-review-fixes.diff).
- النص الحالي كاملًا: [Firestore Rules](../firestore.rules)، [RTDB Rules](../database.rules.json)، [Indexes](../firestore.indexes.json)، [وظائف ACL](../functions/analytics_presence_access.js)، [ربط Functions](../functions/index.js).

يحتوي الـDiff الكامل أيضًا تعديلات الدردشة التي كانت موجودة أصلًا في commit المشترك، بما فيها استيراد chat_functions. لا تُنسب إلى إصلاح Activity ولا إلى هذه المراجعة. النشر الكامل لـfirestore.rules ينشر تلك التعديلات أيضًا؛ يجب اعتمادها بصورة مستقلة قبل اعتماد ملف القواعد الكامل. لم أعدّل قواعد الدردشة هنا. تغيير Functions الخاص بهذه المهمة هو استيراد analytics_presence_access ووظيفتاه فقط؛ لا تنشر Functions كلها لمجرد وجودها في الملف.

## ما هو ACL write؟

ACL = Access Control List: سجل صلاحية صغير في RTDB تحت admins/UID. لا يغيّر Firebase Auth ولا يجعل مستخدمًا مشرفًا في Firestore. المصدر الموثوق هو users/UID.isAdmin، ويُرفض الحساب إن كان isBlocked=true.

السجل الحالي:

```json
{ "presenceDashboard": true, "version": 1, "checkedAt": "عدد صحيح: وقت قراءة Firestore الخادمي بالميكروثانية" }
```

عند السحب/الحظر/الحذف، presenceDashboard=false مع الاحتفاظ بوقت التحقق. checkedAt فعليًا رقم، وليس النص التوضيحي في المثال. لا تمنح قيمة true قديمة وحدها الصلاحية. العميل لا يقرأ أو يكتب admins؛ Admin SDK وحده يصون السجل. هذا SDK ذو صلاحيات خادمية يتجاوز Rules، لذا التفويض داخل الوظيفة ضروري.

«ACL write» أصبح معاملة RTDB صغيرة: قراءة السجل ثم كتابة قرار إن لم يكن أقدم من القرار المحفوظ. قد تتكرر محاولة المعاملة عند التزامن؛ ليس من الدقة وصفها بأنها Write فقط. لكل استدعاء هناك قراءة Firestore واحدة، وليس قراءة users كاملة، ودون Firestore writes جديدة.

## وظيفتا صلاحية المشرف

1. authorizePresenceDashboard: Callable v2. يرفض request.auth المفقود أو anonymous، يستعمل request.auth.uid فقط، ويتجاهل data.uid/data.isAdmin. يقرأ المستخدم من Firestore بواسطة Admin SDK، ويُصون ACL ثم يعيد authorized أو permission-denied. فتح عداد جديد يستدعيه مرة، لا مع كل build.
2. syncPresenceAdminRole: Trigger v2 على users/{uid} عند الكتابة، retry=true. إذا لم يكن الحساب مشرفًا قبل/بعد الحدث، أو لم تتغير isAdmin/isBlocked، يعود دون Database I/O. عند تغير صلاحية مشرف أو حظره/حذفه يقرأ الوثيقة الحالية ويصون ACL. تعديل أي users document يستدعي Trigger حتى إن عاد بلا I/O؛ هذا استهلاك Functions حقيقي.

كل وظيفة لها maxInstances=3 وtimeoutSeconds=30. المنطقة الافتراضية us-central1، متوافقة مع FirebaseFunctions.instance الحالي. RTDB في asia-southeast1؛ لا ننقل المنطقة من طرف واحد، وتوجد كلفة/زمن نقل بين المناطق ينبغي مراقبتهما. لا يوجد App Check في التطبيق ولا enforceAppCheck في الوظيفتين. لا أفعّله دون تجهيز التطبيق لأن ذلك يكسر الاستدعاءات. maxInstances يحد التوسع المتزامن، وليس ميزانية أو Rate Limit أو منع إساءة الاستخدام.

syncPresenceAdminForTest مساعد غير enumerable، لذلك Object.assign في index.js لا يصدره كوظيفة أو endpoint. afterRead ليس مدخل Callable؛ يُستخدم لاختبار التداخل الحتمي فقط.

## مشكلة أُصلحت محليًا

قراءة دور أحدث من Firestore لا تكفي وحدها: قد تقرأ عملية A دور admin، ثم عملية B تقرأ سحبه وتكتب المنع، ثم تُكمل A كتابة منح قديم. أُضيف checkedAt من DocumentSnapshot.readTime الخادمي ومعاملة تقارن الزمن. لا يستطيع قرار أقدم تجاوز قرار أحدث، وفي التعادل تكون الأولوية للمنع. الاحتفاظ بسجل المنع يمنع إعادة إنشاء ACL بواسطة منح متأخر. لا توجد Migration أو مسح مستخدمين؛ السجل الصغير يُصان عند الاستدعاء/حدث الدور.

ما زال Trigger غير متزامن مع تعديل Firestore: توجد نافذة بين تغيير الدور وتطبيق السحب في RTDB. الإصلاح يمنع إحياء صلاحية بعد سحب أحدث مُثبت، ولا يدعي إلغاء الصلاحية ذريًا بين القاعدتين. إذا كانت الإزالة اللحظية الذرية شرطًا، يلزم تصميم صلاحيات مختلف، ويُوقف النشر حتى اعتماده.

## إثبات الصلاحيات

| محاولة مستخدم عادي | حاجز الخادم | نتيجة المحاكي |
|---|---|---|
| إنشاء ملفه isAdmin=true | users create يتطلب false وUID المالك | 403 |
| تحديث isAdmin أو تعديل دور مستخدم آخر | قائمة affectedKeys لصاحب الحساب تستبعد isAdmin؛ تعديل الدور يتطلب isAdmin الحالية | 403 |
| ترقية نفسه مع Activity في Batch | نفس قواعد users تُطبق على الكتابة ضمن Batch | 403 |
| إضافة نفسه/تعديل/حذف admins أو ACL مشرف آخر | .write=false، ولا توجد سماحية من أب | permission_denied |
| قراءة presence من الأب، أو Query كغير مشرف | ACL versioned خادمي + Query connections محددة | permission_denied |
| قراءة/كتابة Connection تحت UID آخر | auth.uid==$uid عند الورقة | permission_denied |
| onDisconnect لحذف اتصال UID آخر | تحقق قواعد عند تسجيل الإجراء | permission_denied |
| اسم اتصال 65 حرفًا أو قيمة متداخلة | طول <=64 وقيمة رقمية ==now | permission_denied |
| تزوير data.uid أو data.isAdmin للـCallable | لا تُستخدم Request data للتفويض | permission-denied |
| Callable بحساب مشرف محظور أو بلا Auth | قراءة الدور/الحظر الخادمية وفحص Auth | permission-denied / unauthenticated |
| قراءة user_activity أو app_sessions لغير مشرف | allow read: isAdmin() | 403 |
| كتابة Activity لغيره أو تغيير userId | معرّف الوثيقة ==auth.uid وبيانات userId ==auth.uid | 403 |
| إنشاء/إنهاء Session لغيره | visitorId وuserId ==auth.uid؛ المالك الحالي والتوقيت ثابتان | 403 |

Firestore isAdmin يقرأ وثيقة users الموثوقة في Rules، وليس قيمة Role من الطلب. إنشاء الدور ممنوع للمستخدم والتحديث محصور بمشرف موجود/خادم. لا توجد catch-all تسمح بقراءة/كتابة Analytics؛ match comments/replies العامة لا تنطبق عليها.

تنبيه قائم: دالة isAdmin العامة في Firestore لا تفحص isBlocked، بينما Callable يفحصه. لذلك حساب يحمل isAdmin=true وisBlocked=true يبقى قادرًا على قراءة Analytics في Firestore وفق القواعد الحالية. عالجت قراءة Analytics محليًا بدالة خاصة ترفض المحظور دون تغيير صلاحيات بقية التطبيق. لا تعني هذه المراجعة أن صلاحيات المشرف المحظور في بقية Collections أُعيد تصميمها.

## Presence وconnectionId

- لا توجد .read:true أو .write:true عامة في database.rules.json. الجذر غير المسموح مرفوض افتراضيًا، وقواعد admins صريحة بالرفض.
- كتابة Connections مقتصرة على UID المصادق وغير anonymous. حذف null لا يمرر .validate في RTDB، لكن يظل يحتاج .write؛ لذلك onDisconnect.remove مسموح لصاحب UID فقط.
- قراءة العداد تتطلب admins/UID.presenceDashboard=true، version=1، orderByChild=connections، startAt=true. query.indexOn=connections فقط. لا يسمح للمشرف بقراءة الأب بلا هذا الاستعلام.
- البيانات المقروءة هي عقد UIDs ذات Connections، بما قد تبقى عليها حقول Legacy صغيرة؛ RTDB لا يعمل كـprojection على connections وحدها. العداد لا يحمل Profiles ولا جميع users، لكنه يحمل كل الاتصالات النشطة؛ حجمه ينمو مع عدد Online.
- SDK Push IDs آمنة لمسار Firebase، والقاعدة تقيّد طولها ونوع القيمة. تغيير الاسم لا يتجاوز auth.uid. يحظر SDK مفاتيح Firebase غير الصالحة؛ ومحاولة المسار المتداخل رفضتها القواعد.
- التسجيل الخادمي onDisconnect يسبق set. اختبار جهازين فعليين في RTDB emulator أثبت بقاء اتصال الجهاز الآخر عند فصل الأول، واختبار حذف متعدد المسارات أثبت السماح بحذف IDs الخاصة بـUID نفسه.
- القواعد تفصل UIDs، لا أجهزة الحساب الواحد. عميل خبيث يملك نفس UID يستطيع حذف Connection آخر تحت UID نفسه؛ سلوك التطبيق الصحيح يحذف IDs التي يملكها فقط. لم تُضف هوية مصادقة منفصلة لكل جهاز.
- فحص onDisconnect يتكرر وقت الانقطاع وفق [وثائق Firebase](https://firebase.google.com/docs/database/web/offline-capabilities)؛ تغيير القواعد وقت وجود عمليات مسجلة قد يرفض cleanup قديمًا. راجع خطة الإصدار أدناه.

## Activity وSessions والخدمات

validTrackedSession موحد للإنشاء والتحديث: visitorId/userId المصادق نفسه، isGuest=false، حقول محدودة وأنواع صحيحة، منصة <=32، اسم <=256، مدة صحيحة غير سالبة. الإنشاء startedAt=request.time وendedAt=null ومدة صفر. الإنهاء مرة واحدة، endedAt=request.time، والتغيير محصور endedAt/durationSeconds. لا يمكن تبديل المالك أو وقت البداية.

validUserActivity يتطلب userId المصادق نفسه، isGuest=false، lastSeen=request.time، بيانات عرض صغيرة، وlastSessionId<=128. معرّف الوثيقة UID. إنشاء حقول غير معروفة ممنوع؛ تحديث حقول قديمة غير معروفة ممنوع، لكن يمكن إبقاؤها دون تغيير لحماية التوافق. لا تُتاح writes للزوار.

AppActivityService: اشتراك Auth واحد وطابور انتقالات؛ تنظيف قبل signOut؛ انتظار إكمال sign-in؛ UID جديد لا يرث حالة السابق. PresenceService: معرف لكل اتصال فعلي، onDisconnect لحذف المعرف، تنظيف IDs المملوكة قبل إلغاء Auth، مع guards ضد acknowledgements متأخرة. AnalyticsService: عداد لا يقرر الصلاحية؛ Rules والـCallable يقررانها. Activity 30+Cursor وProfiles دفعة مع Cache؛ تاريخ الجلسات ما زال استعلام كل سجلات الفترة، موثق كمخاطرة نمو.

## Indexes

الجديد الوحيد في Firestore: user_activity، COLLECTION، isGuest ASC + lastSeen DESC. يطابق equality للمسجلين + range/order للوقت. Cursor لا يحتاج فهرسًا مستقلًا؛ ترتيب __name__ الضمني يكسر تعادل timestamps. app_sessions يرشّح حقل startedAt وحده، ولا يبرر Composite إضافيًا. RTDB index الوحيد connections لاستعلام العداد الجديد. لم تُضف indexes للحقول legacy online أو Profiles.

اختبارات المحاكي لا تثبت جاهزية Composite في Production. يلزم انتظار READY قبل إتاحة النسخة الجديدة. الفهارس القديمة في الملف بقيت دون تغيير؛ لا يُوافق على حذف Index أثناء النشر ضمن هذه المهمة.

## توافق النسخ وترتيب النشر

| سيناريو | النتيجة |
|---|---|
| التطبيق الجديد قبل Functions/Rules/Index | Callable غير موجود أو القراءة مرفوضة؛ إنشاء Connections مرفوض بقواعد Legacy؛ Pagination قد تحتاج Index. لا يصدر التطبيق بهذا الترتيب. |
| القواعد الجديدة قبل Functions | Presence المستخدم الجديد ممكن، لكن عداد المشرف بلا ACL موثوقة وصيانة سحب. ترتيب غير معتمد. |
| القواعد الجديدة بعد Functions، قبل التطبيق | payloads التسجيل القديمة المثبتة تعمل عادة؛ لا يتوقف Auth بسبب قواعد Analytics. الأجهزة القديمة وحدها تستطيع كتابة عقدة Legacy ما دامت بلا Connections. العداد الجديد لا يحتسبها. |
| جهاز قديم وجديد على UID نفسه | set/onDisconnect.set القديم على العقدة كاملة يُرفض إذا كانت Connections موجودة، لحماية الجهاز الجديد. update القديمة للحقول لا تحذف Connections. القديمة قد تفقد Presence أو توقف initialization بسبب الرفض. |
| Dashboard قديمة | Query online القديمة لا تُمنح قراءة بواسطة قواعد connections الجديدة. كذلك صيانة ACL تبدل true القديم إلى object، فتؤثر على readers القديمة التي تتوقع true. لا ضمان توافق لوحة الإدارة القديمة. |
| Anonymous/بيانات قديمة شاذة | الكتابات مجهولة المصادقة مرفوضة؛ Session قديمة ذات حقول زائدة/اسم طويل/UID خاطئ قد تُرفض نهايتها. لا يوجد تنظيف Production ضمن المهمة. |

لا يوجد ترتيب نشر لهذه الملفات يضمن جميع وظائف Presence القديمة والجديدة معًا. لا نفتح صلاحيات لتجنب هذا التحذير ولا ننشئ Bridge أو Migration دون قرار مستقل. الترتيب التالي يجهز متطلبات الجديد ويقلل الأعطال، مع قبول صريح لتحذير التوافق وإصدار لوحة المشرف الجديدة ضمن نافذة النشر.

SAFE DEPLOY ORDER:
1. Indexes: إضافة Composite الخاص بـuser_activity فقط وانتظار READY. لا حذف فهارس. اعتماد الاختبارات وهذا التحذير وتغييرات القواعد المسبقة غير المتعلقة بالنشاط شرط قبل الانتقال.
2. Functions: نشر authorizePresenceDashboard وsyncPresenceAdminRole فقط؛ التحقق من التفويض/السحب/الحظر والحذف ببيئة قبول. تفعيل الصيانة يمكن أن يغيّر ACL القديم عند أحداث الأدوار؛ تجهيز لوحة المشرف الجديدة ضروري.
3. Rules: نشر Firestore/RTDB المعتمدة في نافذة إصدار منسقة، والتحقق من القديم والجديد ببيئة قبول أولًا. لا إعادة تفعيل ACL قديم غير موثوق. مراقبة permission_denied وTrigger failures/retries.
4. App update: طرح النسخة الجديدة بعد الجاهزية، مع تحديث أجهزة الإدارة، اختبار Android/iOS، ومراقبة الأرقام والكلفة. توقع نقص Online للأجهزة القديمة حتى تحديثها.

## اختبارات وحدود المراجعة

- Firestore emulator: 11 ناجحًا (5 Analytics/Authority +6 Regression تقارير).
- RTDB/Functions integration: 4 ناجحة، تشمل concurrent grant/revoke جديدًا.
- node --check للوظائف المعدلة وindex.js: ناجح.
- git diff --check: ناجح.
- لم يُنفذ Flutter Build أو Commit/Push أو أي Deploy.
- اختبارات Callable تستدعي handler.run مع contexts محاكية؛ فحص JWT/HTTP الفعلي جزء من Firebase framework ولم يُختبر Endpoint منشور. معاملات Firestore/RTDB وRules اختُبرت فعليًا على المحاكيات.
- App Check غير مستخدم، ولا Rate Limit دائم؛ مستخدم مسجل مسيء يمكنه تكرار Callable وزيادة قراءة Firestore ومعاملات ACL واستدعاءات Functions، وكتابة بياناته own-UID بكثرة. خطر التكلفة MEDIUM. maxInstances ليس سقفًا للفواتير. لا polling أو heartbeat أو N+1 جديد.
- Firebase توصي بتفعيل [App Check للـCallable](https://firebase.google.com/docs/functions/callable)؛ [فرضه](https://firebase.google.com/docs/app-check/cloud-functions) يحتاج تجهيز نسخة التطبيق أولًا، ولا يُنفذ ضمن نشر هذه الملفات دون خطة مستقلة.
- الصلاحية الخادمية وسحبها لاحقًا غير ذريين بين Firestore وRTDB؛ ليست هذه القواعد نظام صلاحيات فورية عبر القاعدتين.
- مراجعة نطاق Activity لا تُثبت أمان/توافق الدردشة وبقية Collections الموجودة في نفس ملف Rules، ولا تطابق قواعد Production المحلية.

PRE-DEPLOY REVIEW:
- Firestore Rules: PASS (نطاق Analytics بعد إصلاح رفض المشرف المحظور؛ صلاحيات باقي التطبيق خارج النطاق).
- RTDB Rules: PASS.
- Indexes: PASS (تصميم محلي؛ جاهزية Production لم تُختبر).
- Functions: PASS (تداخل ACL أُصلح؛ غياب App Check ومخاطر التكلفة موثقة).
- Admin authorization: PASS (تفويض خادمي، مع تأخر محتمل لسحب RTDB).
- Old app compatibility: WARNING.
- Firebase cost risk: MEDIUM.

القرار: جاهز لمراجعة بشرية وقبول مشروط، وليس موافقة على نشر غير منسق. إذا كان المطلوب عدم تأثر أي نسخة قديمة إطلاقًا، فالنشر محجوب حتى اعتماد خطة توافق مستقلة. توقف التنفيذ هنا قبل أي نشر.
