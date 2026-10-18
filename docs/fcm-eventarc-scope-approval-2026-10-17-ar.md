# قيد حصر إذن Eventarc — 17 أكتوبر 2026

> أُجيز فصل الهوية ونُفذ لاحقًا؛ [الحالة النهائية والأدلة](fcm-events-paused-deployed-2026-10-17-ar.md). ما يلي سجل قرار النطاق السابق، وليس مانعًا مفتوحًا.

**قراءة فقط؛ لم تُنفذ أي كتابة إنتاجية في هذه الجولة.** نتائج الاختبارات السابقة معتمدة ولم تُعد. أحدث موافقة تحصر eventarc.events.receiveEvent بهوية دوال Firestore الأربع فقط، وتمنع إضافة أي صلاحية أخرى دون موافقة.

## النتيجة المثبتة

- IAM queryTestablePermissions أكد أن eventarc.events.receiveEvent مدعوم في custom roles، وليس محصورًا بالأدوار الجاهزة. يمكن تجهيز الدور projects/aqar-9f3f9/roles/aqarPushEventReceive بإذن واحد فقط، دون أي صلاحية إضافية. لم يُنشأ.
- الدور الجاهز roles/eventarc.eventReceiver يحتوي أيضًا eventarc.events.receiveAuditLogWritten. لا حاجة لاستخدامه، ولم يُمنح.
- أقل نطاق موثق لمنح دور استلام أحداث Eventarc هو المشروع. لا ندعي أن IAM يمكنه حصر receiveEvent بأسماء الدوال الأربع عبر سياسة على الدالة؛ التحقق يتعلق باستلام أحداث المشروع. [توثيق الأدوار](https://docs.cloud.google.com/iam/docs/roles-permissions/eventarc)، [هوية المحفز ومنح الإذن على المشروع](https://docs.cloud.google.com/eventarc/docs/roles-permissions).
- aqar-push-runtime@aqar-9f3f9.iam.gserviceaccount.com مستخدمة بالفعل في registerPushDevice وunregisterPushDevice وreviewPushDeliveryHealth وmonitorPushDeliveryHealth. بقيت ACTIVE وبنفس updateTime السابق. الحزمة المقترحة للدوال الأربع الفاشلة تستعمل الهوية نفسها. منح الإذن لهذه الهوية لا يكون حصريًا للأربع الفاشلة؛ لم يُطبق ذلك بصمت.
- إعادة قراءة rollout أكدت mode=paused وpercent=0 وجميع قوائم الحسابات والأجهزة وlegacy فارغة. لا محاولة إرسال أو تشغيل اختبارات سابقة أو تعديل Vercel أو أسرار أو خدمات وسائط.

## التعديل المحدد المطلوب للموافقة قبل المتابعة

إنشاء هوية ثالثة مخصصة aqar-push-events@aqar-9f3f9.iam.gserviceaccount.com، بلا مفتاح JSON، واستخدامها runtime/trigger في deliverBridgeNotification وbridgeCommentCreated وbridgeReplyCreated وbridgeChatMessageCreated فقط. تبقى الدوال الأربع الناجحة وهويتها ونشرها كما هي.

صلاحيات الهوية المقترحة قبل أي تطبيق:

1. الدور القائم aqarPushDataRuntime: datastore.databases.get وdatastore.entities.get/list/create/update/delete، وهي صلاحيات البيانات نفسها المعتمدة سابقًا، وتحتاج الموافقة على ربطها بالهوية الجديدة.
2. الدور القائم aqarPushAuthLookup: firebaseauth.users.get، للتحقق من المرسل، مع الموافقة على ربطه بالهوية الجديدة.
3. الدور الجديد aqarPushEventReceive: eventarc.events.receiveEvent فقط، على المشروع aqar-9f3f9، لهذه الهوية وحدها. لا receiveAuditLogWritten أو FCM send أو أدوار إدارية أو Storage.

هذا يفصل هوية الاستلام عن الدوال الناجحة، لكنه لا يدعي تقييد الإذن نفسه بأربعة موارد داخل IAM؛ حد النطاق المدعوم هو المشروع والربط بهوية لا تُستخدم إلا للأربع. لا يُنشأ أي مورد أعلاه قبل الموافقة على هذا التعديل. إذا ظهرت حاجة إلى run.routes.invoke أو أي إذن آخر أثناء الاستكمال، يتوقف التنفيذ لعرض الإذن والنطاق قبل منحه؛ ليس ضمن هذه الموافقة المقترحة.

بعد الموافقة فقط: فرق صغير يعيّن serviceAccount للـexports الأربعة، ثم نشر هذه الأسماء الأربعة بالاسم دون بقية codebase؛ تحقق metadata للحالة والثبات وpaused، دون إرسال أو إعادة اختبارات مكتملة. Vercel خارج هذا الاستكمال وفق أحدث طلب.

الدليل المنقح: fcm-paused-production-execution-2026-10-17/eventarc-scope-readonly.json. **الحالة: لم يُمنح إذن Eventarc بعد؛ توقف الامتثال لنطاق الهوية يتطلب هذا القرار من المستخدم.**
