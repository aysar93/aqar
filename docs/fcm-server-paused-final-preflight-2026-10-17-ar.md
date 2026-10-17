# قائمة النشر المتوقف وتدوير الاعتمادات — 17 أكتوبر 2026

> **أحدث تحضير للخادم:** [التقرير الموحد بلا JSON](fcm-keyless-server-final-2026-10-17-ar.md). اكتمل إثبات WIF في Preview التجريبي؛ لم يُغيّر Vercel الإنتاجي. بنود إنشاء JSON وتدوير OneSignal أو طلب البحث عنه ليست ضمن المرحلة الحالية. التبديل الإنتاجي ينتظر الموافقة المستقلة المحددة في التقرير الأحدث.

> **النطاق الأحدث المعتمد للتحضير:** [خطة التنفيذ المتوقف المستقل](fcm-paused-execution-scope-2026-10-17-ar.md). تبقى ONESIGNAL_API_KEY وجميع الاعتمادات القديمة كما هي، ولا يشترط تحديدها لتحضير الهوية الجديدة. بنود هذه الوثيقة التي تقترح تدوير OneSignal أو نسخ سره أو تفعيل Secret Manager أو إبطال القديم ليست ضمن المرحلة التالية. خطة النشر الجديدة لم تُنفذ ولم تُعتمد إنتاجيًا.

**تحضير وقراءة فقط. لا نشر أو تدوير أو تغيير إعداد إنتاج، ولا إرسال أو إعادة اختبار.** نتائج PASS السابقة معتمدة. لا تحديث App Store/Google Play ولا دمج PR #3. هذه الوثيقة تخصص مرحلة `paused` وتستبدل الوصف الأوسع للقواعد في قائمة الموارد السابقة؛ لا تمنح موافقة تنفيذ.

## 1. هوية الاعتمادات ومستهلكوها

| الاعتماد | ما ثبت | المستهلك المعروف وأثر الاستبدال |
|---|---|---|
| Vercel FIREBASE_SERVICE_ACCOUNT | مشروع notification-server، ID prj_DfyjRjfnIZFb7SKyN1EHD4HZfv1X، متغير Production ID mZdj1Btn5z4AWsDi، النوع sensitive. **client_email وprivate_key_id غير متاحين**؛ API لا يعيد قيمة وCLI يعيد [SENSITIVE]. لا يجوز افتراض أنه اعتماد compute أو firebase-adminsdk. | Firebase Admin bootstrap واستعلامات Firestore داخل /send في خادم notification-server. خلل الاعتماد الجديد قد يعطل بدء الخادم أو طلباته؛ لا نلغي المفتاح القديم قبل معرفة هويته وجرد مستهلكيه. مستهلكوه الآخرون لم يمكن نفيهم. |
| Vercel ONESIGNAL_API_KEY | متغير Production ID 5plLiQLO1EvcikP7، النوع sensitive؛ **Key ID/اسم المفتاح لدى OneSignal غير محسومين**. التطبيق المقصود من المصادر الموثقة 810a4d8d-cfac-492a-956e-0cff98248d25؛ يلزم مطابقة المفتاح الفعلي معه. يوجد تعيين اعتماد محتمل في .env المتعقب بمستودع الخادم، لكن لم يمكن مقارنة قيمته بالسر المنشور. | طلبات OneSignal من /send. النسخ القديمة تستخدم App ID العام وSDK، وليس هذا السر الخادمي في المسارات المفحوصة. إبطال المفتاح يوقف كل مستخدم API له، وقد توجد حملات/خدمات أخرى غير محصورة بعد. لا نعد SDK أو الأجهزة غير متأثرة مطلقًا إذا كانت الخدمة مشتركة. |
| ONESIGNAL_APP_ID | متغير Production ID OSG6S4ABXOWZBlPf؛ معرف تطبيق عام، وليس اعتمادًا سريًا للتدوير. | يبقى التطبيق نفسه؛ لا نقل مشتركين أو تغيير خطة/MAU. |
| L74V23VW58 / شهادات Apple / مفاتيح رفع المتاجر | خارج نطاق التدوير. | لا تغيير APNs أو توقيع أو متاجر. |
| هوية الدوال القائمة 1031621585901-compute@developer.gserviceaccount.com | مستخدمة في خمس Functions قائمة حسب الجرد. | **لا تعطيل أو إبطال لهذه الهوية المشتركة** ولا تعديل دوالها. |

[metadata القراءة وإخفاق كشف الأسرار المحمية](fcm-production-preflight-2026-10-17/credential-access-metadata.json). الملف المؤقت لقراءة env حُذف؛ لم يُحفظ مفتاح أو يُطبع. عدم إتاحة أسرار sensitive ليس تصريحًا لتجاوز الحماية. يلزم من المستخدم مسار JSON الأصلي الذي استخدم للمتغير، واسم/Key ID من صفحة OneSignal؛ لا قيم أسرار في المحادثة. حتى ذلك الحين **لا يمكن تقديم جرد مكتمل لهوية كل مفتاح ومستهلكيه أو طلب موافقة إبطاله بثقة**.

### طريقة التبديل المقترحة بعد تحديد الهوية والموافقة

إنشاء اعتماد بديل منفصل وتحديث مستهلكيه أولًا، ثم إبطال المفتاح القديم المحدد فقط. لا تدوير in-place لـOneSignal أثناء خدمة العملاء: وفق [وثائقه](https://documentation.onesignal.com/docs/en/keys-and-ids) يُبطل Rotate القيمة القديمة فورًا. البديل الموازي يقلل نافذة الفشل؛ إن كان المفتاح Legacy لا يفترض أن له صف Key ID حديث أو آلية إبطال مطابقة دون تحقق. حذف مفتاح Google يمنع إصدار رموز جديدة به، ولا يضمن سحب access tokens سبق إصدارها فورًا؛ لا نعطل حساب خدمة مشترك لمعالجة ذلك بلا جرد.

الهوية المستقبلية المقترحة للخادم aqar-push-vercel@aqar-9f3f9.iam.gserviceaccount.com، وللدوال aqar-push-runtime@aqar-9f3f9.iam.gserviceaccount.com؛ **لم تُنشآ**. لا Owner/Editor أو Storage permissions. صلاحيات Firestore الخادمية على مستوى قاعدة البيانات وليست حصر مجموعات، لذلك يحصر الكود عملياته في سجل الإشعارات/الجسر؛ لا نسمي ذلك عزل IAM عن كل بيانات الوسائط في القاعدة المشتركة.

## 2. الدوال والتكوين المحدد

جهزت حزمة مصدر مقترحة محليًا في `work/production-preflight-20261017/functions`، codebase مستقل `push-bridge`، Node24، us-central1، هوية runtime المخصصة، maxInstances=2 وminInstances=0. ملف دخولها لا يصدر حسابات الدخول/الحضور/المكاتب/حذف مرفقات المحادثة من index العام؛ يصدر الثماني التالية فقط:

- registerPushDevice وunregisterPushDevice.
- deliverBridgeNotification.
- bridgeCommentCreated وbridgeReplyCreated وbridgeChatMessageCreated.
- reviewPushDeliveryHealth وmonitorPushDeliveryHealth.

لا نشر deliverFcmNotification أو sendNotificationToUser، ولا الدوال الخمس القائمة: authorizePresenceDashboard وsyncPresenceAdminRole وrefreshOfficeFollowerMetrics وrefreshOfficePropertyMetrics وrefreshOfficeReviewMetrics. لا استعمال `firebase deploy` شاملًا. الحزمة مقترح محلي/فحص syntax فقط، لا deployment أو ادعاء تشغيل جديد.

تكوين الخادم والدوال: GCLOUD_PROJECT=aqar-9f3f9، FCM_MIGRATION_ENABLED=true، PUSH_BRIDGE_ENABLED=true؛ معرف OneSignal الإنتاجي نفسه، واعتماد BRIDGE_ONESIGNAL_API_KEY خادمي فقط بعد موافقة التدوير. لا تعديل أعلام التطبيق أو ملف native Firebase أو firebase_options.dart.

[تكوين rollout المقترح](fcm-production-preflight-2026-10-17/rollout.paused.json): mode=paused، percent=0، قوائم installationAllowlist وlegacyRecoveryAllowlist فارغة، legacyIngressCoordinated=false، وcohort بحسابات/أزواج أجهزة/أهداف legacy فارغة وproviders=['fcm']. ينشأ قبل ربط إرسال. حتى بعد تنسيق المسارات لا يفتح paused أو تملأ مجموعة ضمن هذه الموافقة.

Cloud Run/Eventarc تتبع الدوال الجديدة، وجدولة مراقب الصحة كل خمس دقائق. القراءة أكدت **Cloud Scheduler وSecret Manager DISABLED** في الإنتاج؛ تفعيل API لهما سيكون تغييرًا إنتاجيًا يحتاج إدراجه في الموافقة، لا افتراض أنهما جاهزان. Eventarc/Run/Build/Artifact Registry مفعلة أصلًا. [الحالة](fcm-production-preflight-2026-10-17/api-status.json).

## 3. القواعد والفهارس — أقل نطاق لمرحلة paused

القواعد المنشورة الحالية: release cloud.firestore، ruleset `0854e006-fa1f-438c-b11e-1f34f3ccb9cc`، تحديث 8 أكتوبر، SHA256 `9d2623330e8fa8e60dfa5a54fee59ded283ac914182ea1d63ff4e36a5efa557d`. قبل التنفيذ يعاد فحص revision فقط لمنع طمس نشر متزامن؛ هذا فحص تعارض إعداد لا إعادة اختبار.

**المقترح لهذه المرحلة فقط:** [patch إضافة عشر مجموعات خاصة](fcm-production-preflight-2026-10-17/firestore.paused-only.patch) ترفض قراءة/كتابة العميل: push_tokens، push_installations، push_deliveries، push_registration_limits، push_bridge_events، push_bridge_inbox، push_ingress_limits، push_subscription_bindings، push_legacy_token_approvals، push_bridge_config. باقي القواعد، بما فيها notifications، تبقى حرفيًا خارج موضع الإدراج. لا إضافة/حذف فهرس في هذه المرحلة؛ الاستعلامات ذات الحقول المتعددة تُراجع فهارسها المطلوبة قبل فتح الإرسال، دون نشر ملف indexes كاملًا أو افتراض أنها جاهزة.

**مفصول عن مرحلة paused:** [patch تشديد notifications للمراجعة فقط](fcm-production-preflight-2026-10-17/firestore.notifications-strict-deferred.patch). القواعد الحالية تسمح لأي مسجل بإنشاء صندوق لمستلم آخر، وتحديث المالك لا يحصر الحقول أو يثبت userId؛ عيوب قائمة وليست مستحدثة بالنشر المتوقف. التشديد يحمي المصدر والمستلم، لكنه قد يرفض كتابات نسخ قديمة بلا source IDs. source triggers تحفظ الحدث الخادمي، لكنها لا تثبت نجاح عملية الكتابة أو واجهة المرسل القديم. لهذا لا ندخله بصمت في موافقة النشر المتوقف ولا ندعي إغلاق توافق المنتجين القديمين باختبار الاستقبال. يلزم حسمه قبل فتح cohort بإجراء منفصل؛ لا إعادة اختبارات مكتملة الآن.

[مراجعة القواعد الثابتة المحدودة](fcm-production-preflight-2026-10-17/rules-static-review.json). لم تنشر أو تُجمع القواعد المقترحة باختبار جديد، ولم تتغير نتائج PASS السابقة.

## 4. مسارات Vercel التي ستتغير

المشروع نفسه notification-server على notification-server-henna.vercel.app، Node24/iad1؛ لا نطاق جديد للمستخدمين. التغيير المقترح يخص:

- POST /send: استبدال أخذ المستلم/النص/الجمهور من الطلب العام بإيقاظ حدث Firestore مثبت، والـdispatcher المشترك وledger وcohort. request بلا notificationId صالح يرفض، وغير المثبت يعيد pending دون إرسال. لا توليد ID بديل واعتباره مصدرًا مخولًا.
- GET /: health/status خادمي بلا أسرار. لا إضافة أو تغيير /upload أو أي مسار Cloudinary/R2/Storage.
- bootstrap: حارس تطابق مشروع الإنتاج وهوية الاعتماد الجديد، وإعداد البيئة الصحيح؛ لا نشر preview-entry.cjs المقفول على التجريبي كما هو. adapter والـlock المدققان، وحد حجم JSON والسياسة المحددة للـrate limit؛ لا الثقة في forwarded IP عام. العد الحالي من socket قد يكون مشتركًا على Vercel، فيُوثّق كحد محافظ مشترك لا كحد لكل مستخدم؛ إرسال source triggers لا يعتمد على نجاح HTTP wakeup.
- المتغيرات: تحديث FIREBASE_SERVICE_ACCOUNT وONESIGNAL_API_KEY بعد تحديد هويتهما، وإضافة GCLOUD_PROJECT وأعلام الجسر ومعرف/سر bridge حسب wiring المعتمد. تغيير env وحده لا يحدث الإصدارات القائمة؛ يجب نشر إصدار خادم جديد. المفتاح القديم لا يبطل قبل خروج مستهلكيه من الخدمة.

المستودع المحلي للخادم به تعديل سابق في server.js؛ لم يُمس أو يدفع. التغيير النهائي يُجهز في نسخة معزولة وdiff محدد، لا فوق تعديل المستخدم ولا بدفع قد ينشر تلقائيًا. جهز bootstrap و[فرق server.js المقترح](fcm-production-preflight-2026-10-17/server.proposed.patch) في مجلد منفصل، مع [قائمة الاعتماديات المقترحة](fcm-production-preflight-2026-10-17/server.package.proposed.json) وقفل محلي مدقق 250 حزمة بلا تنبيهات. يعتمد على وحدات الجسر المشتركة ذات بصمات مسجلة؛ يرفض اعتمادًا لا ينتمي إلى هوية الخادم المخصصة. لا axios أو body-parser مستقلان؛ express.json يحد JSON بـ64KB. هذا مقترح ومراجعة syntax وليس تشغيل خادم إنتاج أو اختبار إرسال جديد.

## 5. عدم التداخل مع Cloudinary → Storage

- **الكود/النشر:** لا storage.rules أو قواعد RTDB أو buckets أو روابط imageUrl/images/photoUrl/receiptUrl أو بيانات العقارات/المكاتب/المحادثات أو R2 Worker/رفع الصوت/الريلز ضمن التغيير. config المقترح لا يحتوي storage/database/hosting/flutter أو indexes، وحزمة Functions لا تحمل chat_functions أو دوال حذف المرفقات أو index التطبيق العام.
- PR يحتوي تعديلًا سابقًا صغيرًا في cloudinary_service.dart يمنع الرفع عند PushMigration.isolated فقط؛ هذا ليس نقل وسائط ولا يدخل الحزمة الخادمية أو نسخة المتجر الحالية. لا ادعاء أن PR كله يخلو من ملفات الوسائط.
- **المشروع/الهوية:** Firestore وفوترة مشروع GCP مشتركان. استعلام/حذف duplicate notification محصور في notifications لنفس الحدث، لا حذف media أو أصل رسالة. الهوية الجديدة بلا Storage/Cloudinary صلاحيات؛ لكن لا يمكن إثبات أن الاعتماد القديم غير مشترك مع عمل وسائط قبل تحديده وجرد مستهلكيه. لذلك لا تعطيل حسابه أو إبطال مفتاحه الآن. فصل مسارات الكود مثبت بالمراجعة؛ فصل كل استخدام للاعتماد الحالي غير محسوم.
- قبل أي نشر، يؤخذ ruleset الحالي ويطبق patch الإشعارات وحده؛ إن تغيرت revision بسبب عمل Storage/Firestore متزامن يُعاد تركيب patch فوق الأحدث دون طمس عمل الوسائط. لا استخدام إعداد Firebase الشامل في الجذر.

## 6. خطة النشر المتوقف والتراجع والتوقف المحتمل

1. **قبل الموافقة:** استكمال client_email/private_key_id وKey ID/نوع OneSignal وجرد المستهلكين، وdiff الخادم النهائي وفهارس الاستعلامات. لا طلب إبطال مفتاح مجهول. حفظ نسخة قواعد وإعداد ونشر حاليين ومعرفات الإصدارات، بلا أسرار في Git.
2. **بعد موافقة منفصلة على النطاق:** إنشاء الهوية/الاعتماد البديلين وتفعيل Scheduler/Secrets المطلوبين، إنشاء rollout paused وفارغ، ثم نشر codebase الإشعارات الثماني وpatch private-only والخادم المحدد. مطابقة metadata النشر وpaused؛ لا إشعار تحقق حقيقي ضمن هذه المرحلة.
3. **استكمال التبديل:** تحديث كل مستهلك معروف، ثم إبطال المفتاح القديم المحدد. لا تدوير فوري in-place قبل التبديل. مع paused لا توجد استعادة تلقائية لإشعارات الفترة كدفعات لاحقة؛ يحتفظ المستخدم بالمحتوى في الصندوق عند المسارات الموثقة، ولا تعاد أحداث غامضة بصورة عمياء.
4. **مراقبة التشغيل المتوقف:** scheduler وحالة الدوال وأخطاء الخادم، stale attempting/review_required، والفوترة والتنبيهات. قبول FCM ليس قراءة، وميزانية التنبيه ليست سقفًا؛ لا حمل جديد. البيانات المالية الفعلية غير متاحة حتى تقرير Billing.
5. **تراجع آمن:** يبقى mode=paused وcohort فارغًا؛ تعاد قواعد النسخة السابقة مع مراعاة أي تعديل متزامن. للـVercel إصدار صيانة paused أو نسخة آمنة بالاعتماد الجديد، **لا rollback أعمى لإصدار immutable يحمل سرًا أُلغي أو sender قديم يتجاوز الحصر**. لا حذف ledger أو الصندوق، ولا إيقاف/ترقية OneSignal، ولا إعادة تفعيل إرسال بمجرد rollback.

**التوقف:** لا توقف متعمد لرفع الوسائط أو تصفح التطبيق أو تسجيل الدخول. مسار الدفع الجديد يبقى متوقفًا عمدًا؛ OneSignal أبلغ المستخدم أنه موقوف أصلًا، لكن لا نفترض أن كل قنوات/مستهلكي الاعتماد متوقفة. خطأ secret أو إبطال قبل التبديل قد يسبب فشل /send، وأي مستهلك آخر لاعتماد مشترك قد يتأثر؛ لذلك لا وعد بصفر توقف. الهدف overlap مضبوط بالاعتماد البديل مع ملاحظة أن المفتاح المحتمل انكشافه لا يبقى صالحًا بلا نهاية.

## القرار وما يحتاج المستخدم

**تحديث جرد الاعتمادات:** راجع [مراجعة المصدر](fcm-credential-source-review-2026-10-17-ar.md). اكتمل فحص الملفات المحلية وmetadata المتاحة قبل طلب البحث اليدوي. ظهر مستهلك محتمل آخر لحساب Google في aqar-reels-api عبر FIREBASE_SERVICE_ACCOUNT_JSON؛ اشتراك المفتاح نفسه غير محسوم، ويجب حسمه قبل الإبطال. لا تكفي مطابقة توقيت إنشاء مفتاح IAM مع تحديث Vercel. يقتصر المطلوب من المستخدم على اسم/Key ID/نوع OneSignal ومصدر ملف إعداد Google إن توفر؛ لا محتويات أسرار.

التحضير المحدود جاهز للمراجعة، **لكن قائمة التدوير النهائية ليست مكتملة الهوية**. المطلوب الآن فقط مسار ملف Google الأصلي أو بيانات client_email/private_key_id، واسم/Key ID/نوع OneSignal من الحساب؛ لا قيمة سر. إذا لم تتوفر، تُسجّل كعائق ولا يُخمن المفتاح. بعد مطابقة المستهلكين واعتماد diff الخادم المقترح تعرض موافقة التدوير والنشر المتوقف وحدها. فتح المجموعة/الإرسال العام وتشديد notifications/توسيع النسب ودمج PR والمتاجر موافقات منفصلة؛ كلها خارج التنفيذ الحالي.
