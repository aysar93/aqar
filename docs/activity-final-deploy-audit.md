# FINAL DEPLOY AUDIT — 2026-10-03

الحالة: مراجعة وقراءات GET فقط لموارد Firebase، إصلاحات محلية واختبارات محاكيات. لم يُنفذ Build أو Deploy أو Commit أو Push أو Production writes أو Migration أو حذف Legacy Presence.

مراجع آلية القراءة: [Firebase Rules management API](https://firebase.google.com/docs/rules/manage-deploy)، [RTDB Rules REST](https://firebase.google.com/docs/database/rest/app-management). استُخدمت عمليات GET فقط على موارد المشروع؛ لم تُستخدم create/update/release أو PUT للقواعد.

## Production baseline: KNOWN عند وقت الالتقاط

المشروع aqar-9f3f9، Firestore (default)/STANDARD، RTDB الإقليمية الحالية. استُرجعت القواعد المنشورة مباشرة، وليس من تخمين Git. [metadata](deploy-audit/production-baseline-metadata.json) تحفظ حالات HTTP ونتائج الجرد دون Tokens. استُخدم تسجيل CLI الموجود، ولم تُطبع أو تُحفظ Credentials.

- [Firestore المنشور](deploy-audit/production.firestore.rules)، [release metadata](deploy-audit/production-firestore-release.json): ruleset `44a15ec2-eebf-49b9-ba7f-69e3e0ce8352`، SHA256 `22bb159e076bcc6513662c87ef4e0821bb475cfd6b37eea3b53891542d112b90`. لقطة القراءة بدأت 2026-10-03 00:39 بتوقيت بغداد؛ بقية موارد الجرد جُلبت لاحقًا أثناء المراجعة، وليست لقطة ذرية عبر الخدمات.
- [RTDB المنشور](deploy-audit/production.database.rules.json): قراءة Presence للمشرف من الأب اعتمادًا على admins/UID=true، وفهرس online. هذه التفاصيل ليست في Git baseline القديم.
- [Git baseline قبل Activity](deploy-audit/git-pre-activity.firestore.rules): commit `112e9b9c484a0bd7aa8e459b0be90dc0783653d3`، الأب السابق لـ0b7f286. baseline Git ليس Production rollback.
- [الفهارس المنشورة كاملة](deploy-audit/production.all-indexes.json): 12 Composite، لا فهرس user_activity. [Field overrides](deploy-audit/production.field-overrides.json): صفر. الجرد بصفحة كاملة دون nextPageToken.
- [وظيفتا Analytics المنشورتان في us-central1](deploy-audit/production.analytics-functions.json): لا توجدان في نتيجة API. لا نعمم ذلك على مناطق أخرى؛ العميل يستعمل us-central1 الافتراضية.

قبل أي نشر لاحق يجب إعادة GET وحفظ النتائج في مجلد جديد، ثم مقارنة قواعد/Release/Fهارس هذه اللقطة. إذا تغيّر المصدر لا نستبدله بهذا الملف القديم؛ نوقف النشر ونعيد المقارنة. لا تعِد كتابة snapshots/rollback الحالية.

## عزل A/B/C وما سيُنشر

النتيجة المثبتة برمجيًا، بعد توحيد نهايات الأسطر: prefix Firestore غير المتعلق بالنشاط متطابق تمامًا بين Production والمحلي. استبدال جزء Activity في Production بالجزء المحلي ينتج ملفًا مطابقًا للمحلي. لذلك تغييرات الدردشة السابقة PRESENT في Git، لكنها موجودة فعلًا في Production وليست Delta جديدة عند نشر هذا الملف الآن.

| RULE CHANGE | SOURCE | RELATED TO THIS TASK? | CURRENTLY IN PRODUCTION? | SAFE TO DEPLOY? |
|---|---|---|---|---|
| A: Validators UID/الأنواع/Server time للنشاط والجلسات | إصلاح Activity في 0b7f286 | نعم | لا | نعم بعد شروط الإصدار والاختبارات |
| A: منع anonymous، جلسة تنتهي مرة، نطاق حقول صغير | إصلاح Activity | نعم | لا | نعم؛ تحذير بيانات/نسخ شاذة |
| A: isAnalyticsAdmin يرفض المشرف المحظور | مراجعة ما قبل النشر المحلية | نعم | لا | نعم لنطاق Analytics |
| A: RTDB Connections، onDisconnect own-UID، Query/index connections | إصلاح Presence | نعم | لا | نعم بعد انتقال جهاز الإدارة؛ تحذير النسخ القديمة |
| A: ACL versioned server-only | إصلاح Presence والوظيفتان | نعم | لا | نعم مع نشر وصيانة الوظيفتين |
| B: قواعد chats/messages، acknowledgements، الحذف، صوت/صور/Property payload | تغييرات سابقة في commit مشترك | لا | نعم، متطابقة في الجزء غير المتعلق بالنشاط | لا تغيير جديد في لقطة النشر؛ لا نعيد اعتماد تصميمها أمنيًا هنا |
| C: RTDB parent admin read + online index | Production يختلف عن Git القديم | متعلق بالنظام القديم؛ ليس إضافة هذه المهمة | نعم | يُستبدل بمنطق Connections المعتمد؛ لا ترجع إلى Git القديم عند rollback |
| C: فرق جديد آخر في Firestore المحلي مقابل Production | المقارنة الفعلية | لا | لا يوجد فرق كهذا | NONE ضمن الملف المقارن |
| فهرس isGuest ASC + lastSeen DESC | هذه المهمة | نعم | غير موجود | إضافته فقط ثم انتظار READY |

الأدلة الكاملة: [A: Activity-only diff](deploy-audit/A-activity-only.diff)، [B: التغييرات السابقة](deploy-audit/B-prior-chat-changes.diff)، [Production→local Firestore](deploy-audit/production-to-local.firestore.diff)، [Production→local RTDB](deploy-audit/production-to-local.database.diff).

جهزت [ملف Firestore للنشر المعزول](deploy-audit/deploy.firestore.activity-only.rules) من Production + Activity فقط؛ هو حاليًا مطابق للمحلي. [RTDB candidate](deploy-audit/deploy.database.rules.json) هو القواعد المعتمدة الحالية. [Indexes candidate](deploy-audit/deploy.firestore.indexes.json) يحفظ الفهارس الـ12 القائمة ويضيف المطلوب فقط (13)، ولا يحذف أو يعيد ضبط Field Overrides.

`firebase.activity-deploy.json` في جذر المشروع يشير لهذه الملفات. لا تستخدم `firebase deploy` عامًا؛ قد يشمل Storage وكل Functions وغيرها مما لم تُراجع baseline الخاصة به هنا. لا تستخدم ملف activity-only.indexes.json وحده للنشر: حذف الفهارس الأخرى ممنوع. الاختيار يجب أن يكون target محددًا ومعرف مشروع صريحًا وconfig الجذر المعزول.

## authorizePresenceDashboard: Call Sites والتكلفة

Call Site إنتاجي واحد فقط: PresenceService._ensureDashboardAuthorization. onlineCount يطلبه عند بدء الاستماع، وليس عند مجرد إنشاء Stream. AnalyticsDashboardScreen يملك Stream ثابتًا في initState. توجد ثلاثة أسباب لإنشاء Stream: دخول الصفحة، العودة من قائمة النشطين، زر إعادة محاولة صريح. `_load`، تغيير الفترة، refresh وbuild لا يستدعون Callable. AppActivityService foreground/resume/connect لا يستدعيها.

الوصول الطبيعي للصفحة من AppDrawer.isAdmin → AdminDashboard → AnalyticsDashboard. المستخدم العادي لا يملك زر الإدارة. إخفاء الزر ليس حاجزًا أمنيًا؛ الخادم يرفض أي عميل يتعمد طلب الصلاحية بلا دور.

المشكلة السابقة: العودة من قائمة النشطين أو إعادة فتح Dashboard أعادت طلب Callable دون Cache. أُصلحت بـCache نجاح محلي مدة 10 دقائق، مرتبط بـFirebase UID وبساعة monotonic. لا Timer ولا تجديد آلي. الطلب المتزامن للـUID نفسه يشارك Future واحدة. لا يُخزن الفشل. Logout يبطل Cache؛ UID مختلف لا يستخدمه. permission-denied من RTDB يبطله لإعادة تحقق يدوية. TTL لا يبدل Rules ولا يبقي صلاحية مسحوبة في الخادم.

| الحدث | مستخدم عادي، استخدام طبيعي | مشرف |
|---|---:|---:|
| Cold start إلى الصفحة الرئيسية | 0 | 0 |
| أول فتح Analytics بعد تشغيل العملية | غير متاح طبيعيًا: 0 | 1 |
| Widget rebuild / تغيير الفترة / Refresh | 0 | 0 إضافية |
| Resume مع Dashboard نفسها | 0 | 0 إضافية |
| العودة من قائمة النشطين/إعادة فتح Dashboard ضمن TTL | 0 | 0 إضافية |
| فتح جديد بعد TTL | 0 | 1 عند الحاجة؛ لا renewal دوري |
| بقاء Dashboard مفتوحة ساعة دون إعادة اشتراك | 0 | 0 إضافية، حتى بعد انتهاء TTL |
| Network reconnect | 0 | 0 إضافية ما دام الاشتراك نفسه قائمًا |
| Retry صريح بعد فشل Callable أو رفض صلاحية | 0 | 1 لكل محاولة يدوية؛ لا حلقة retry |
| Retry صريح بعد خطأ شبكة مع Cache نجاح صالح | 0 | 0 إضافية |
| Logout/Login / تغيير UID | 0 | 1 عند أول فتح جديد مؤهل |

Cold start متعمد مباشرة إلى Analytics، إن أضيف مستقبلًا، يعادل أول فتح: 1 للمشرف. التطبيق الحالي لا يستعيد هذه الصفحة تلقائيًا. لا يوجد حد عالمي لعدد المحاولات اليدوية أو الخبيثة؛ لا ندّعي Rate Limit من TTL.

كل Call مؤهل يصل إلى المعالج: 1 Firestore read للتحقق، 0 Firestore writes، معاملة RTDB صغيرة (read + write/abort وقد يعاد التزامن). الطلب بلا Auth/anonymous يرفض قبل I/O. المستخدم العادي الذي يتعمد الطلب مصادقًا يُرفض بعد التحقق ويُسجل المنع؛ لا تعادل إساءة الاستخدام الاستعمال الطبيعي ذي 0 calls.

## syncPresenceAdminRole: Trigger

- document path: users/{uid}.
- event type: onDocumentWritten v2، create/update/delete.
- event subscription يستقبل كل كتابة فعلية على users. لا يمكن الادعاء أنه لا يُستدعى عند تغيير الاسم/Token/lastLogin؛ اختبار الحقول داخل handler يقلل I/O، وليس عدد أحداث Trigger.
- قبل أي Database I/O: إذا لم يكن قبل/بعد الحساب مشرفًا، يعود. ثم يقارن الحالة المؤثرة isAdmin===true وisBlocked===true. إن لم تتغير يعود. جرى تحسين undefined→false في isBlocked بحيث لا يعد تغييرًا للصلاحية.
- ordinary create/profile/lastLogin/Token/ban/delete: استدعاء Trigger واحد، صفر Firestore reads/writes داخل handler، صفر RTDB operations.
- profile/Token للمشرف دون تغير الصلاحية: نفس الاستدعاء، صفر I/O.
- promotion/demotion/ban/unban/admin deletion: استدعاء واحد عادة، 1 Firestore read للحالة الحالية، 0 Firestore writes، معاملة RTDB واحدة عادة.
- retry=true: أحداث فاشلة قد تتكرر بواسطة المنصة؛ لا يوجد عدد محاولات ثابت داخل الكود. maxInstances=3 وtimeout=30 ثانية يحدان التوسع/زمن المحاولة، ولا يمنعان الفاتورة أو إعادة تسليم الأحداث. راقب أخطاء الوظيفة، ولا تترك retry failures مستمرة.

## Admin ACL lifecycle

G = {presenceDashboard:true,version:1,checkedAt:وقت خادمي}؛ D = نفس البنية مع false. الجدول يصف تنفيذ المعالج المكتمل، لا ضمان زمن فوري عبر قاعدتين.

| الحالة | Firestore state | RTDB ACL state | Callable result | Presence read | متى تتغير/تُسحب؟ |
|---|---|---|---|---|---|
| مستخدم أصبح Admin | isAdmin=true وغير محظور | G بعد Trigger أو Callable | authorized | نعم بعد G والقواعد الجديدة | عند اكتمال أول تحديث مؤهل |
| سحب isAdmin | false | D بعد المعالج | permission-denied إن تحقق حديثًا | لا بعد D؛ قد يبقى قبل المعالج | اكتمال Trigger أو Callable حديث |
| Admin محظور | true + isBlocked=true | D | permission-denied | لا بعد D؛ Firestore Analytics يرفض فورًا مع قواعدها الجديدة | عند مزامنة D في RTDB |
| حذف وثيقة المستخدم | وثيقة users غير موجودة | D | permission-denied إذا بقي token Auth صالحًا | لا بعد D | Trigger الحذف/Callable |
| فتح Dashboard قبل Trigger | أحدث وثيقة admin أو nonadmin | Callable يجهز G أو D | حسب أحدث قراءة خادمية | يوافق ACL الذي طبق حديثًا | لا يلزم انتظار Trigger لأول bootstrap |
| Callable وTrigger متقاربان | دور قد يتغير أثناء التنفيذ | أكبر checkedAt ينتصر؛ تعادل: المنع | بحسب قراءة المعالج؛ grant قد يرجع authorized ثم Rules ترفض إن سُحب أحدث | القرار الفعلي في RTDB | stale grant لا يتجاوز D أحدث مكتمل |

حذف Firebase Auth وحده دون حذف users document لا يولد Trigger users. لا يقوم Admin SDK بمراجعة token revocation/disabled على كل طلب؛ request.auth هو هوية يتحقق منها إطار Callable. إدارة حذف الحساب يجب أن تشمل ملفه/سحب دوره، كما يفعل مسار التطبيق. إبطال Tokens وسحب صلاحيات عبر القاعدتين ليسا ذريين. لا يخفي Cache هذه الحدود.

## Legacy Presence: SAFE للتخزين، WARNING للنسخ القديمة

UID له {online:true,...} ثم يدخل التطبيق الجديد: يكتب child connections/PUSH_ID بتوقيت خادم، دون استبدال UID node؛ تبقى الحقول القديمة. إنها إضافة تدريجية ضمن نفس العقدة وليست Migration جماعية.

عند فصل آخر Connection تختفي connections. قد يبقى online:true قديمًا للأبد؛ الاستعلام الجديد يستبعد UID إذا connections مفقودة، لذلك لا يرفع العداد. لا Cleanup مطلوب للإصدار. يمكن لاحقًا مراجعة حذف الحقول القديمة لتقليل التخزين، بموافقة مستقلة، دون حذف اتصالات فعالة.

عميل قديم يستعمل set/onDisconnect.set كامل UID قد يُرفض عند وجود Connections جديدة، لحماية الجهاز الجديد. update القديم للحقول لا يحذف Connections. النسخة القديمة لا تساهم في العداد الجديد. هذه حدود التوافق، لا مبرر لمسح Legacy.

## Index readiness

Production inventory الحالية: فهرس user_activity المطلوب ABSENT. Index status: NEEDS ACTION. ملف candidate يحفظ كل الموجود ويضيف المطلوب فقط؛ لا يبدأ استعمال القائمة الجديدة قبل رؤية الفهرس نفسه READY بقراءة API/Console، وليس بمجرد نجاح بدء إنشائه. READY يجب أن يطابق COLLECTION + isGuest ASC + lastSeen DESC (و__name__ الضمني). أخطاء Query لا تُحل بتخفيف Rules أو إزالة pagination.

لا يوجد gate داخل نسخة التطبيق الموزعة ينتظر Index READY تلقائيًا. الضمان هنا هو منع طرح/فتح هذه الصفحة في Production حتى يتحقق الشرط؛ جهاز الإدارة يُثبّت مسبقًا لكن لا يستخدم القائمة قبل READY.

## Admin device transition: لم يُثبت فعليًا بعد

لم أبنِ أو أثبت نسخة على جهازك، لذلك لا أؤكد نجاح جهاز الإدارة الحالي. التحضير المسبق شرط نشر لا ادعاء مكتمل. البناء/التثبيت التاليان خطوات مستقبلية تحتاج الموافقة، لا أعمال نُفذت الآن.

1. بعد الموافقة: بناء واحد من المصدر المراجع، واحتفاظ بنسخة تثبيت الإدارة السابقة، وتجهيز نسخة جديدة لنفس التطبيق. اختبار الجهاز على بيئة قبول قبل Production قدر الإمكان.
2. تثبيت النسخة الجديدة على جهاز الإدارة قبل Rules (ومفضل قبل Functions)؛ التحقق من فتح التطبيق والوصول للوحة والـUI. قد يظهر خطأ متوقع للعداد حتى تجهيز Backend؛ لا تعتبره اختبار Online ناجحًا، ولا تفتح قائمة النشطين قبل READY.
3. الاحتفاظ بمدخل Firebase Console/CLI خارجي يعمل مستقلًا عن التطبيق. القراءات الحالية أثبتت وصول CLI للقواعد؛ تحقق من صلاحية النشر/الرجوع عند موعده دون افتراض أن read permission تعني write permission.
4. تجهيز Index ثم Functions ثم Rules. إغلاق النسخة القديمة على جهاز الإدارة حتى لا تعيد set Legacy أثناء الاختبار. لا تصدر التطبيق للعموم حتى ينجح اختبار الجهاز نفسه بعد Rules.
5. بعد Rules مباشرة: فتح Analytics من الجديد، Callable واحدة، Online دون permission_denied، تعداد UID واحد، دخول جهاز ثانٍ بنفس UID لا يضاعفه، إغلاق أحدهما يبقيه Online، الصفحة الأولى 30 وLoad More، background/logout/reconnect، وخطأ الشبكة يظهر Error.

## EXACT DEPLOY PLAN — مقترح فقط، لم يُنفذ

1. اعتماد نتائج هذا التقرير وSnapshot baseline، وتحذير Legacy، وخطر التكلفة MEDIUM. إعادة مقارنة Production عند موعد التنفيذ؛ أي drift يوقف النشر. اعتماد الوصول الخارجي وخطة الرجوع ونسخة التطبيق السابقة.
2. بناء واحد وتثبيت نسخة جهاز الإدارة الجديدة واختبار فتحها قبل Rules. لا طرح عام ولا استعمال Active Query بعد. مراجعة المصدر والملفات/hash في هذا المجلد؛ لا استبدال firebase.json العام.
3. إضافة الفهرس وحده عبر config الجذر firebase.activity-deploy.json وtarget firestore:indexes ومعرف aqar-9f3f9. candidate يشمل 12 قائمة +1 جديدة؛ رفض أي طلب deletion. انتظار READY والتأكد منه بقراءة مستقلة.
4. نشر target الوظيفتين authorizePresenceDashboard وsyncPresenceAdminRole فقط من نفس config ومعرف المشروع. لا all-functions. فحص runtime وregion وAuth errors وTrigger. التحقق بحساب الإدارة من أن الدور الموثوق يجهز ACL؛ لا تعديل ACL يدوي ولا users scan.
5. نشر firestore:rules,database فقط من config المعزول، في نافذة متفق عليها. ملف Firestore يضيف Activity إلى baseline المنشور فقط؛ RTDB يغيّر العقدة القائمة دون بيانات. لا Storage Deploy ولا Data Migration.
6. اختبار جهاز الإدارة الجديد فورًا بالأحداث السابقة، وإثبات 0 calls على مستخدم عادي وعدم call عند rebuild/resume، ومراقبة Functions invocations/errors وRTDB downloads. فشل أي شرط يوقف الطرح وينقلنا لRollback المحدد، لا Retry تلقائي دائم.
7. طرح التطبيق تدريجيًا للعموم بعد القبول، ومراقبة نقص Online المتوقع للنسخ القديمة. لا حذف Legacy. مراجعة budgets/alerts التشغيلية بموافقة منفصلة؛ maxInstances لا يكفي للتحكم بالفاتورة.

## ROLLBACK PLAN — ملفات حقيقية محفوظة، دون تنفيذ

- [rollback.firestore.rules](deploy-audit/rollback.firestore.rules): النص المنشور فعلًا، يحفظ الدردشة السابقة؛ لا تستخدم Git baseline القديم.
- [rollback.database.rules.json](deploy-audit/rollback.database.rules.json): قواعد RTDB المنشورة قبل الإصدار. يحفظ parent read وonline index، لكنه يتوقع ACL boolean.
- [rollback.firestore.indexes.json](deploy-audit/rollback.firestore.indexes.json): metadata فهارس البداية؛ لا تستعمله لحذف الجديد أثناء Incident. أَبقِ الفهارس القائمة والجديد إن لم يسبب مشكلة.
- [reviewed.analytics_presence_access.js](deploy-audit/reviewed.analytics_presence_access.js): نسخة Functions المراجعة على المحاكيات، ليست إصدارًا سبق إثباته على Production. الوظيفتان لا توجدان في baseline؛ الرجوع لحالتهما الأصلية يعني إيقاف/إزالة الوظيفتين بعد تأمين القراءة، لا استعادة إصدار منشور سابق.
- [rollback.database.admin-bridge.rules.json](deploy-audit/rollback.database.admin-bridge.rules.json): fallback اختياري، لا للنشر الأساسي. يحافظ على Connections وحماية UID وACL versioned، ويسمح للمشرف الموثق فقط باستعلام online==true القديم إضافة للاستعلام الجديد، مع الفهرسين. لا يقبل admins/UID=true القديمة غير الموثقة. قد يعرض العداد القديم بيانات Legacy غير دقيقة؛ ليست مساواة كاملة بالنظام الجديد. يتطلب نشرًا صريحًا إذا احتجنا الرجوع لجهاز الإدارة القديم، ولا يحتاج Data Migration.
- [emergency.database.no-dashboard.rules.json](deploy-audit/emergency.database.no-dashboard.rules.json): يوقف قراءة العداد من الأب، ويبقي صلاحيات الاتصال الصغير لصاحبه. يستخدم قبل إيقاف صيانة ACL، حتى لا يبقى دور مسحوب قادرًا على قراءة Presence بسبب ACL قديمة.

| حادث بعد النشر | أول إجراء | الرجوع المحدد | ما لا نفعله |
|---|---|---|---|
| Presence permission_denied | وقف الطرح وتحديد المسار: اتصال أم Query أم ACL | تحقق من نشر Functions/config الصحيح؛ إعادة candidate المراجع إن نُشر ملف خاطئ. إن لزم downgrade: أغلق الجديد على جهاز الإدارة واستخدم Bridge المراجع مع ACL الموثقة، لا مجرد RTDB Git قديم | لا read:true ولا حذف Presence |
| Online لا يعمل | وقف الطرح؛ افحص Callable وACL/network دون loop | إعادة Functions المراجعة أو Bridge إن احتجنا لوحة قديمة، مع إبقاء Trigger. الأصل boolean قد لا يقرأ ACL object؛ استعادة snapshot وحدها لا تضمن استعادة العداد القديم | لا تزوير ACL ولا عرض Error كصفر |
| Active users Query تفشل | تحديد missing-index أم permission | missing-index: منع استخدام القائمة حتى READY، وإبقاء الفهرس؛ permission regression: استعادة rollback.firestore.rules الحقيقية، مع بقاء المنصة/Query الجديدة إذا كانت صالحة | لا full collection fallback ولا حذف Index |
| Functions أخطاء | وقف الطرح؛ افحص deployment/logs وretry | إعادة نسخة Functions المراجعة، مع الإقرار أنها ليست runtime baseline مجرّبة. عند تعذر الإصلاح: emergency no-dashboard ثم تعطيل Endpoint/Trigger بصورة صريحة | لا توقف Trigger وتبقي read ACL فعالة |
| ارتفاع invocations | وقف الطرح والاستدعاءات من التطبيق؛ تمييز Callable من Trigger | Callable مسيء: منع الوصول للEndpoint/إيقافه، لا تكتفِ بثلاث instances. Trigger مسيء/أخطاء متكررة: emergency no-dashboard أولًا، ثم وقف subscription/الوظيفة بعد قرار صريح؛ يحفظ users/Presence كما هي | لا حذف users أو Legacy لتقليل أحداث، ولا تعطيل صيانة مع بقاء قراءة Admin |

Rollback كامل إلى ملفات Production السابقة يحتاج أيضًا downgrade التطبيق. بيانات ACL التي تحولها الوظائف إلى object لا تعود boolean بمجرد Rules rollback؛ لذلك جهزت Bridge آمنًا للقراءة القديمة، بدل وعد بأن استعادة قواعد فقط تعيد العداد. يجب أن يكون جهاز الإدارة قد جهز ACL عبر النسخة الجديدة والـCallable قبل downgrade إلى القديم؛ إن لم يحصل ذلك، استخدم Console الخارجي ولا تفتح القراءة غير الموثقة. لا نفترض أن هذه الخطوة وحدها تصلح metrics Legacy.

عند الرجوع الكامل/إيقاف الوظائف: ضَمِن رفض قراءة Presence الإدارية أولًا، أوقف الطرح/الصفحة، ثم أوقف Functions. لا حذف ACL أو Connections. تغيير Rules قد يؤثر على onDisconnect مسجل سابقًا؛ النسخة الجديدة تُنظف اتصالها قبل الخروج حيث يمكن، وخلاف ذلك لا ننفذ cleanup جماعيًا أثناء Incident.

## التكلفة والحكم

الاستخدام الطبيعي للـCallable أصبح قليلًا ومحددًا بالحدث/TTL، لكن Cost risk يبقى MEDIUM: App Check/Rate Limit الدائم غير موجودين، Trigger يصل لكل كتابة users وإن كان I/O صفرًا، retries ممكنة، التاريخ يقرأ S، والعداد يحمّل جميع UIDs المتصلة. لا polling أو heartbeat أو N+1 أو users full scan جديد. التخفيض لا يبرر ادعاء سقف تكلفة.

اختبارات: Flutter 28 ناجحًا، Scoped analyze نظيف، Exact candidate emulator: 11 Firestore و4 RTDB/Functions ناجحة، واختبار Bridge إضافي مستقل. Production device/OAuth/Index READY لم تُختبر لأن مرحلة التنفيذ غير مأذونة الآن.

FINAL DEPLOY AUDIT:
- Production rules baseline: KNOWN (GET snapshot؛ يعاد التحقق وقت التنفيذ).
- Unrelated rules changes: PRESENT في التاريخ/المحلي، لكنها موجودة بالفعل في Production؛ فرق جديد خارج Activity في Firestore: NONE.
- authorizePresenceDashboard calls: المستخدم العادي 0 طبيعيًا؛ المشرف 0 عند cold start للـHome، 1 عند أول فتح، 0 عند rebuild/resume، Cache نجاح 10 دقائق دون Timer.
- syncPresenceAdminRole: كل users write يولد حدثًا؛ غير المؤثر يخرج بلا Database I/O؛ دور/حظر/حذف مشرف يقرأ واحدة ويُجري معاملة ACL.
- Presence migration: WARNING للتوافق القديم؛ SAFE كتخزين تدريجي، لا مسح أو Cleanup للإصدار.
- Admin device transition: NEEDS ACTION؛ بناء/تثبيت واختبار النسخة الجديدة قبل Rules، وقبول Online بعد Backend قبل الطرح.
- Index: NEEDS ACTION (ABSENT؛ انتظار READY إلزامي).
- Cost risk after audit: MEDIUM.
- Security: PASS لنطاق الإحصائيات المراجع، مع سحب ACL غير ذري موثق.
- Compatibility: WARNING.

القرار: لا نشر الآن. حُسم مصدر القواعد واستدعاءات Callable؛ تبقى جاهزية Index وجهاز الإدارة وشروط التشغيل خطوات قبول قبل التنفيذ. لا يشمل الحكم اعتماد كل وظائف التطبيق العامة أو كل ملفات Firebase للنشر.

I've set up prototype Security Rules to keep the data in Firestore safe. They are designed to be secure for UID-owned activity and sessions, server timestamps, and server-authorized admin analytics reads. However, you should review and verify them before broadly sharing your app. If you'd like, I can help you harden these rules.
