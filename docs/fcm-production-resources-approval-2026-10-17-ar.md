# موارد الإنتاج المعروضة لموافقة مستقلة — 17 أكتوبر 2026

**لم ينفذ أي تعديل إنتاجي.** هذه قائمة موارد مقترحة للنشر المتوقف فقط؛ لا تشمل فتح cohort أو دمج PR #3 أو المتاجر أو ترقية دفع. إصلاحا الصندوق والحصر اجتازا التحقق المحدود في [تقرير PASS](fcm-release-gates-2026-10-17-ar.md).

## ما تأكد للقراءة فقط

- Firebase/GCP: aqar-9f3f9، الرقم 1031621585901. قائمة Functions الحالية أعادت خمس دوال ACTIVE في us-central1: authorizePresenceDashboard وsyncPresenceAdminRole وrefreshOfficeFollowerMetrics وrefreshOfficePropertyMetrics وrefreshOfficeReviewMetrics. هويتها الحالية 1031621585901-compute@developer.gserviceaccount.com. **لا تعديل لهذه الدوال أو إبطال لهذه الهوية المشتركة ضمن الخطة.** لا دوال إشعارات منشورة ظهرت في جرد المناطق الحالي.
- Vercel: notification-server، ID `prj_DfyjRjfnIZFb7SKyN1EHD4HZfv1X`، الفريق aysar93s-projects، نطاق notification-server-henna.vercel.app، Node 24.x، iad1. مستودع الخادم المفحوص محليًا D:/Projects/notification_server، منفصل عن PR التطبيق؛ لم يعدل أو يدفع لأن دفعه قد ينشر الإنتاج.
- متغيرات Vercel الإنتاجية الموجودة: FIREBASE_SERVICE_ACCOUNT وONESIGNAL_API_KEY وONESIGNAL_APP_ID؛ القيم مخفية ولم تفك أو تطبع. ملف .env في مستودع الخادم متعقب ويحمل أسماء ONESIGNAL_API_KEY وONESIGNAL_APP_ID وPORT؛ أسماء فقط، لا قيم في الأدلة. لا يفترض أن القيمة المحلية تطابق السر المنشور.
- OneSignal الإنتاجي: التطبيق القائم `810a4d8d-cfac-492a-956e-0cff98248d25`، Mobile Push متوقف وفق تقرير المستخدم عن MAU. لا ترقية أو إعادة تشغيل أو نقل مستخدمين. APNs الحالي L74V23VW58 وبندل com.andalus.aqar لا يتغيران؛ لا APNs جديد لتفعيل FCM وحده.

## التغييرات التي تتطلب موافقة النشر المتوقف

| المورد | التغيير المقترح فقط |
|---|---|
| IAM: aqar-push-runtime@aqar-9f3f9.iam.gserviceaccount.com | هوية جديدة مخصصة للدوال الثماني، بلا تعديل هوية compute الحالية. صلاحيات FCM وFirestore اللازمة؛ firebaseauth.users.get للتحقق الخادمي من المرسل، ووصول إلى السر المحدد فقط. |
| IAM: aqar-push-vercel@aqar-9f3f9.iam.gserviceaccount.com | هوية جديدة للخادم، اعتماد خادمي محدود؛ لا Owner/Editor أو Auth admin. تثبت طريقة الاعتماد المدعومة قبل إنشائه، وتظل الأسرار خارج Git/التطبيق/المحادثة. |
| دورا aqarPushRuntime / aqarPushVercel المقترحان | cloudmessaging.messages.create، firebase.projects.get، datastore.entities.get/list/create/update/delete، datastore.databases.get/getMetadata؛ إضافة firebaseauth.users.get للدوال فقط. حذف المستند مطلوب لطي نسخة صندوق مكررة مثبتة. IAM هنا على مستوى قاعدة البيانات، لا يضمن حصرًا بمجموعات؛ حصر العملية في الكود والمصادر المحمية، وليس ادعاء صلاحية IAM لكل مجموعة. |
| Vercel FIREBASE_SERVICE_ACCOUNT | استبدال اعتماد الخادم بهوية الخادم المخصصة، ثم إبطال **المفتاح القديم المحدد فقط** بعد جرد مستهلكيه. هوية صاحب السر القديم وprivate_key_id لم تفكا حتى الآن؛ لا تشمل هذه القائمة إذن إلغاء حساب/مفتاح مجهول أو هوية compute المشتركة. يلزم عرض metadata المطابقة قبل الإبطال. |
| OneSignal ONESIGNAL_API_KEY | معالجة الاعتماد المحتمل انكشافه تتطلب مفتاح App API بديلًا للتطبيق الإنتاجي نفسه وتبديل كل مستهلكيه قبل إبطال المحدد القديم. **هذا تغيير اعتماد OneSignal إنتاجي ويحتاج ذكره صراحة في موافقة منفصلة**؛ لا تغيير الخطة أو APNs أو التطبيق أو المشتركين. المعرف/الاسم الفعلي للمفتاح القائم يحتاج تأكيد metadata، ولا يستنتج من اسم متغير. |
| Secret Manager BRIDGE_ONESIGNAL_API_KEY | سر إنتاجي جديد/إصدار جديد لتزويد الدوال باعتماد OneSignal البديل إذا تمت الموافقة على تدويره. لا نسخ سر الاختبار ولا رفع مفتاح APNs. بيانات Google طويلة العمر إن لزمت تبقى في بيئة Vercel المشفرة لا GitHub. |
| Vercel /send وbootstrap وlock | إصدار خادم مدقق يثبت مشروع الإنتاج وهوية اعتماد مطابقة، ويستخدم source verification وledger المشترك وcohort لكل المزودين. استبدال FIREBASE_SERVICE_ACCOUNT، وإضافة GCLOUD_PROJECT وPUSH_BRIDGE_ENABLED وFCM_MIGRATION_ENABLED وBRIDGE_ONESIGNAL_APP_ID/BRIDGE_ONESIGNAL_API_KEY حسب wiring النهائي؛ الحفاظ على ONESIGNAL_APP_ID كمعرف لا تغيير تطبيق. إزالة مرجع الإرسال غير المنسق، وضبط حدود IP الموثوقة. لا نشر حزمة Preview المقفلة على التجريبي كما هي. |
| Functions us-central1 — ثماني دوال جديدة فقط | registerPushDevice، unregisterPushDevice، deliverBridgeNotification، bridgeCommentCreated، bridgeReplyCreated، bridgeChatMessageCreated، reviewPushDeliveryHealth، monitorPushDeliveryHealth. flags: FCM_MIGRATION_ENABLED=true وPUSH_BRIDGE_ENABLED=true؛ runtime Node24 حسب مصدر الإنتاج. لا نشر شامل functions أو مساس بالدوال الخمس القائمة. لا حاجة لنشر deliverFcmNotification أو sendNotificationToUser القديمتين. حارس الأخيرة في المصدر يمنع تجاوز الجسر إذا نشرت مستقبلًا. |
| Cloud Run / Eventarc / Scheduler | الخدمات المرتبطة بالدوال الثماني، وأربع مراقبات Firestore للمصادر، وجدولة monitorPushDeliveryHealth كل خمس دقائق في us-central1، وصلاحية استدعاء الجدولة المحددة؛ موارد البناء/الحاويات المدارة التابعة لهذه الإصدارات. لا نشر خدمة إرسال أخرى. |
| Firestore push_bridge_config/rollout | ينشأ **قبل الإرسال**: mode=paused، percent=0، installationAllowlist=[]، legacyIngressCoordinated=false، legacyRecoveryAllowlist=[]، cohort={userIds:[],installations:[],legacyTargets:[],providers:['fcm']}. لا كتابة قائمة أجهزة في مرحلة النشر المتوقف. |
| مجموعات Firestore | push_installations وpush_tokens وpush_subscription_bindings وpush_legacy_token_approvals وpush_bridge_events وpush_bridge_inbox وpush_deliveries وpush_registration_limits وpush_ingress_limits. إنشاؤها حسب الاستخدام فقط، لا استيراد جماعي. notifications يحتفظ بعنصر مرئي صحيح للمستلم قبل أي دفع؛ قد تُطوى نسخة عميل مكررة مثبتة لنفس الحدث مع دمج حالة القراءة. لا حذف رسائل/عقارات/حسابات مستخدمين. |
| Firestore rules / indexes | patch خاص بالإشعارات والمجموعات المحمية والفهارس اللازمة، مقابل نسخة إنتاج محفوظة؛ لا نشر ملف قواعد المستودع كاملًا بصورة عمياء، ولا تغيير مجالات أخرى. بيانات النسخ القديمة بلا هوية مصدر لا تعد هوية موثوقة؛ source triggers بديلها المخول. يُعرض diff النهائي للقواعد قبل التنفيذ. |
| Cloud Monitoring / Logging / Billing | سياسة جديدة مقترحة Aqar production push delivery failures، قناة بريد aysar.aliraqe@gmail.com **للإنتاج بموافقة منفصلة عن الاختبار**، ومراقب خمس دقائق، وتنبيهات ميزانية إنتاجية محددة القيمة والعتبات عند الموافقة. قراءة إعداد احتفاظ الإنتاج قبل أي تغيير؛ 30/400 يومًا المؤكدة تخص التجريبي. لا تغيير خطة الدفع أو سقف مفترض. |

## تسلسل التنفيذ المتوقف، ثم التفعيل بموافقة أخرى

1. حفظ مراجع النشر والقواعد وIAM/إصدارات الأسرار؛ إتمام هوية المفتاحين القديمين وجرد مستهلكيهما وdiff القواعد وحدود Vercel. هذه تفاصيل يجب أن تظهر قبل إبطال أي اعتماد؛ ليست موافقة عامة على إبطال أسرار غير محددة.
2. تهيئة الهوية والسر البديلين، وإنشاء rollout فارغ paused، ثم نشر الدوال الثماني والخادم والقواعد المحددة. فحص metadata النشر والهوية والإعداد المتوقف؛ لا إشعار اختبار أو عام ضمن هذه المرحلة.
3. بعد تنسيق جميع المسارات يمكن ضبط legacyIngressCoordinated=true مع بقاء paused، ثم إبطال المفتاح القديم المحدد بعد تبديل المستهلكين. لا تحويل OneSignal إلى مسار تراجع تلقائي.
4. **موافقة مستقلة لفتح أول cohort:** قائمة حساب/جهاز مرتبطة بأزواج UID+installationId، أو UID+legacyTargetKey، مع إثبات الرمز ومدة موافقة الاستعادة. legacyRecoveryAllowlist وحدها ليست إذن إرسال؛ يلزم cohort وموافقة الرمز أيضًا. حقل users القديم قد يمثل آخر جهاز فقط للحساب.
5. **موافقات توسع منفصلة:** إضافة أجهزة مؤهلة صريحة والتوسع 1/5/25/100% داخل القائمة المخولة، لا جمهور المشروع. مراقبة أول نافذة 24 ساعة دون إعادة اختبارات ناجحة. لا تحديث متجر أو دمج PR ضمنها.

## الأثر والإيقاف والمراقبة

النشر المتوقف لا يفتح دفعًا جديدًا. أحداث المصدر الموثقة قد تحفظ عناصر الصندوق حتى أثناء pause أو إيقاف المستخدم للدفع؛ لا تُحذف البيانات عند فشل FCM. يتغير مصدر إرسال الدفعة وحصره؛ أجهزة خارج المجموعة لا تتلقى إرسالًا جديدًا عبر FCM أو OneSignal من الجسر. الأجهزة القديمة التي لا نملك عنوانًا صالحًا لها لا تستعاد بوعد خادمي، وiOS القديم قد يفتح الرئيسية لكن محتواه محفوظ في التنبيهات ضمن المسارات المصححة.

الإيقاف: mode=paused وإيقاف التوسع. يعاد فحص pause/cohort داخل معاملة الحجز لكل مزود؛ لا سحب لطلب تجاوز الحجز أو رسالة قبلها المزود. تعطيل هوية الإرسال المخصصة إجراء احتياطي مخول، لا إلغاء الهوية المشتركة. لا حذف ledger أو إعادة رسالة ملتبسة أو رجوع أعمى لمرسل قديم يتجاوز الحارس. OneSignal الموقوف ليس تراجعًا مضمونًا.

المراقبة: stale attempting بعد دقيقتين وreview_required وأخطاء الدوال وفشل scheduler، مع بريد كل سياسة الإنتاج. قبول المزود ليس وصولًا أو قراءة. مراجعة يومية لفاتورة الخدمات؛ FCM نفسه بلا رسم خدمة، ومبلغ التشغيل الفعلي غير محسوم. لا اختبار حمل جديد؛ الميزانية تنبيه لا سقفًا. أي خلط حساب أو تكرار مثبت يوقف المجموعة فورًا؛ الفشل الملتبس يمنع التوسع حتى المصالحة.

**حد الموافقة المطلوبة الآن:** مراجعة القائمة فقط. لم يطلب أو ينفذ تغيير إنتاجي. بعد حسم metadata الاعتمادات وdiff النشر يعرض نطاق التدوير والنشر المتوقف بصورة نهائية؛ فتح المجموعة ودمج PR والمتاجر تبقى موافقات مستقلة.

## مرجع مرحلة paused الأحدث

القائمة المخصصة للنشر المتوقف فقط، مع هوية متغيرات Vercel وما منع إتمام تعريف المفتاحين، وفرق القواعد فوق الإنتاج الحالي وفصل الوسائط وخطة التوقف/التراجع، في [مراجعة النشر المتوقف](fcm-server-paused-final-preflight-2026-10-17-ar.md). لهذه المرحلة يضاف رفض وصول العميل لعشر مجموعات push فقط؛ تشديد notifications مفصول للمراجعة قبل فتح الإرسال، ولا ينفذ ضمن paused بصمت. لم تتغير أسرار أو قواعد أو خدمات إنتاج، ولم تعد الاختبارات.
