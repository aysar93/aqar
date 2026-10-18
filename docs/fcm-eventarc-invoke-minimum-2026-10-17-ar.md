# صلاحية استدعاء خدمات Eventarc الخاصة — 17 أكتوبر 2026

> أُجيز الإذن المفرد وربط بالخدمات الأربع فقط؛ [نتيجة التنفيذ PASS](fcm-events-paused-deployed-2026-10-17-ar.md). ما يلي سجل الموافقة السابقة، وليس طلبًا معلقًا.

**توقف قبل أي كتابة إنتاجية في هذه الجولة.** لم تُنشأ aqar-push-events بعد، ولم تُمنح أدوار أو تُنشر دوال. تبقى الموافقة على فصل الهوية محفوظة، لكن التنفيذ ينتظر إذن الاستدعاء الإضافي وفق شرط المستخدم الصريح بالتوقف إذا لزم أي إذن آخر.

## سبب التوقف

الدوال الأربع Eventarc/Cloud Functions Gen2 لها خدمات Cloud Run خاصة. إذن eventarc.events.receiveEvent يسمح باستلام الحدث، لكنه لا يمنح الهوية استدعاء الخدمة الخاصة. توثيق Google يوضح أن المحفز قد ينشأ ويظهر نشطًا مع فشل التسليم إن لم تتوفر صلاحية الاستدعاء. لا يجوز اعتبار ACTIVE وحده نجاح تشغيل أو ادعاء خلو أخطاء الصلاحيات. [توثيق Google](https://docs.cloud.google.com/eventarc/docs/roles-permissions).

فحص قراءة metadata الحي أثبت أن run.routes.invoke مدعوم في الأدوار المخصصة وعلى موارد خدمة Cloud Run. الدور الجاهز roles/run.invoker يحتوي حاليًا run.routes.invoke وrun.instances.invoke وrun.jobs.run؛ لا يُستخدم لإضافة صلاحيات غير لازمة. [قائمة أدوار Cloud Run](https://docs.cloud.google.com/iam/docs/roles-permissions/run).

## الإضافة المحددة المطلوبة للموافقة

- إنشاء الدور المخصص projects/aqar-9f3f9/roles/aqarPushServiceInvoke، وصلاحيته الوحيدة run.routes.invoke.
- ربطه بهوية aqar-push-events@aqar-9f3f9.iam.gserviceaccount.com فقط، على خدمات Cloud Run الأربع التابعة لـdeliverBridgeNotification وbridgeCommentCreated وbridgeReplyCreated وbridgeChatMessageCreated، بعد معرفة أسماء الخدمات الفعلية من metadata النشر.
- لا ربط invocation على المشروع كله، ولا run.jobs.run أو run.instances.invoke، ولا public/allUsers، ولا صلاحية إرسال FCM.
- تستمر بقية الموافقة كما هي: هوية جديدة بلا JSON، ربط صلاحيات البيانات والتحقق السابقة، ودور Eventarc يحوي receiveEvent فقط، وتغيير runtime/trigger identity للأربع الفاشلة فقط. لا إعادة نشر الأربع الناجحة ولا تغيير هويتها أو صلاحياتها. Vercel وبقية الخدمات خارج النطاق.

هذه الإضافة هي المتطلب الإضافي المعروف من مراجعة المسار الحالي، ولا تمنح موافقة مفتوحة على صلاحيات أخرى. إذا ظهر متطلب آخر يتوقف التنفيذ لعرضه. لا يُستخدم نشر ناجح شكليًا مع محفز غير قادر على الاستدعاء كبديل عن الموافقة.

## الحالة المؤكدة الآن

أُعيدت قراءة metadata فقط: الأربع الناجحة ما زالت ACTIVE وبنفس هوية/updateTime السابقة. mode=paused وpercent=0 وقوائم الحسابات والأجهزة وlegacy فارغة. لم تُنفذ إشعارات أو اختبارات أجهزة أو حمل أو CI، ولم يحدث أي تغيير إنتاجي جديد.

الدليل: fcm-paused-production-execution-2026-10-17/event-invoke-readonly.json. لا تكلفة بناء أو نشر جديدة في هذه الجولة؛ استهلاك الموارد القائمة من الجولة السابقة مستمر ومبلغ الفاتورة غير محسوم.
