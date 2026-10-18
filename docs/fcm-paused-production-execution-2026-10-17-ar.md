# نتيجة النشر المتوقف — 17 أكتوبر 2026

> تحديث لاحق: أُغلق مانع Eventarc وفصلت هوية الأحداث بإذن المستخدم. راجع [نتيجة PASS للدوال الثماني](fcm-events-paused-deployed-2026-10-17-ar.md). تبقى هذه الوثيقة سجلًا للمحاولة الجزئية السابقة؛ Vercel والإرسال ما زالا خارج التنفيذ.

**الحالة: تنفيذ جزئي متوقف؛ ليست PASS للنشر الكامل.** وافق المستخدم على المرحلة المتوقفة فقط. توقف التنفيذ عند رفض Google إنشاء محفزات Firestore بسبب إذن eventarc.events.receiveEvent المفقود؛ لم يُوسّع IAM بعد الخطأ ولم يُغيّر Vercel. قائمة الصلاحيات السابقة أغفلت إذن استلام الأحداث اللازم لهوية المحفز. لا إرسال أو canary أو merge أو متاجر.

## الموارد التي تغيرت فعليًا

المشروع aqar-9f3f9 فقط:

- أُنشئ aqar-push-vercel@aqar-9f3f9.iam.gserviceaccount.com وaqar-push-runtime@aqar-9f3f9.iam.gserviceaccount.com. لم يصدر مفتاح JSON لأي منهما؛ كلاهما بلا USER_MANAGED keys عند التحقق النهائي.
- أُنشئ الدور aqarPushDataRuntime وربط بالهويتين: datastore.databases.get وdatastore.entities.get/list/create/update/delete. أُنشئ aqarPushAuthLookup وربط بهوية الدوال فقط: firebaseauth.users.get. لا cloudmessaging.messages.create في الصلاحيات الممنوحة، ولا Storage/Cloudinary/R2/IAM permissions للتطبيق.
- أُنشئ push_bridge_config/rollout: mode=paused، percent=0، legacyIngressCoordinated=false، installationAllowlist وlegacyRecoveryAllowlist فارغتان، وcohort.userIds/installations/legacyTargets فارغة وproviders=['fcm'].
- نُشرت القواعد ذات الإضافة الخاصة لعشر مجموعات فقط. ruleset الجديد projects/aqar-9f3f9/rulesets/c67b967f-6cb6-4a73-bb68-53135c0736f8؛ السابق projects/aqar-9f3f9/rulesets/0854e006-fa1f-438c-b11e-1f34f3ccb9cc. المقارنة المحلية أثبتت تطابق النص خارج الإدراج؛ لا تغيير notifications أو Storage أو indexes.
- أصبحت أربع Functions جديدة ACTIVE ضمن codebase push-bridge في us-central1/Node24: registerPushDevice، unregisterPushDevice، reviewPushDeliveryHealth، monitorPushDeliveryHealth. هويتها aqar-push-runtime، minInstances=0، الحد الأعلى 2 عدا المراقب 1. BRIDGE_ONESIGNAL_ENABLED=false، ولا secret bindings.
- فُعّل Cloud Scheduler API وأنشئت مهمة firebase-schedule-monitorPushDeliveryHealth-us-central1 كل خمس دقائق، وحالتها ENABLED. حالة نجاح أول تنفيذ دوري لم تثبت في نافذة التحقق؛ ليست اختبار إرسال. لا سياسة بريد إنتاجية جديدة أُنشئت، وبقي Secret Manager DISABLED.
- موارد Cloud Run/Build/Artifact Registry التابعة للدوال الجديدة أُنشئت عبر Firebase CLI. لا رفع وسائط أو تعديل buckets التطبيق؛ لا تعديل Cloudinary أو Firebase Storage أو Worker الريلز. لم يُستخدم firebase deploy الشامل.

## ما لم يكتمل

فشل إنشاء deliverBridgeNotification وbridgeCommentCreated وbridgeReplyCreated وbridgeChatMessageCreated بخطأ HTTP 403: eventarc.events.receiveEvent denied. سجل طلب الإنشاء يحدد aqar-push-runtime@aqar-9f3f9.iam.gserviceaccount.com لهوية المحفز وruntime معًا. الدوال الأربع الفاشلة لا تظهر ضمن قائمة الدوال المنشأة النهائية. لم تُنشر الثماني كاملة.

أوقفت الخطوات اللاحقة: لا مفتاح خادمي جديد، لا تبديل FIREBASE_SERVICE_ACCOUNT، لا تحديث متغير ONESIGNAL_API_KEY، ولا نشر /send الجديد على Vercel. تواريخ تحديث المتغيرين بقيت كما في الجرد السابق. لم تُلغَ أو تُدوّر مفاتيح Google/OneSignal القديمة، ولم تتغير تطبيقات أو APNs أو متاجر أو PR #3.

## التحقق المحدود والأخطاء

- تحقق محلي خاص بالتكوين الجديد: ثمانية exports فقط، منع OneSignal قبل الشبكة، secret bindings وdeclared secret params فارغة. لم تُعد اختبارات الأجهزة أو الحمل أو التوافق أو CI.
- تحقق قراءة بعد النشر الجزئي: إعداد paused مطابق تمامًا، قوائم فارغة، لا صلاحية FCM في روابط الهويتين والأدوار الجديدة، صفر سجلات في push_deliveries، وصفر استدعاءات إرسال مزود نفذتها هذه الجولة. لا ادعاء اختبار وصول جديد أو قياس سلوك كل مستهلك قديم.
- الدوال الخمس السابقة بقيت ACTIVE وبالهويات وlabels وبصمات الكود السابقة. لم يُلتقط updateTime القديم، لذا المقارنة لا تدعي تطابق كل حقل metadata.
- عولج محليًا اختلاف CRLF في القواعد قبل نشرها، وصُحح غلاف طلب Rules API بعد HTTP 400؛ نُشر ruleset واحد جديد. عولج مسار اعتماديات محلي وتعريف Secret Param الذي تسبب بمحاولة قراءة Secret Manager وHTTP 403؛ لم تُفعّل الخدمة. رفض CLI نشر retry policy دون force أولًا؛ نشر الكود المحدد فقط استخدم force بعد التأكد من codebase المنفصل. الخطأ المتبقي الحقيقي هو Eventarc receiveEvent.

## التكلفة

لا إرسال FCM أو OneSignal في هذه الجولة. بناء الصور وحفظها والمراقب الدوري وقراءات Firestore قد تولّد رسومًا رغم paused. مهمة Scheduler واحدة: مجانية إذا توفرت الحصة المشتركة أو نحو 0.10 دولار/شهر خارجها. تقدير الحركة الخفيفة السابق 0–5 دولارات/شهر للزيادة تخطيطي وليس سقفًا أو فاتورة. المبلغ الفعلي لهذه الجولة غير محسوم دون بيانات Billing؛ لا اختبارات حمل جديدة. [تسعير Scheduler](https://cloud.google.com/scheduler/pricing)، [تسعير Firebase](https://firebase.google.com/pricing).

## الاستكمال والتراجع

للاستكمال يلزم اعتماد تصحيح قائمة IAM: منح eventarc.events.receiveEvent لهوية aqar-push-runtime فقط، بأضيق دور ممكن، دون FCM send أو Editor/Owner. أي صلاحية استدعاء Cloud Run لازمة للمحفز تقيد بخدمات الدوال المعنية وتُدرج صراحة قبل الإضافة؛ لا تعميم صلاحية مشروع. بعد ذلك تُعاد محاولة الدوال الأربع الفاشلة فقط، ثم يُستكمل اعتماد Vercel والنشر المتوقف المصرح به، والتحقق من الحالة دون إرسال. لا تُعاد الدوال الأربع الناجحة أو اختبارات سابقة بلا سبب.

**التراجع المقترح — غير منفذ:** إبقاء rollout paused فارغًا؛ إيقاف مهمة المراقبة الجديدة وإزالة الدوال الأربع الجديدة فقط عند طلب التراجع، واستعادة release القواعد السابق بشرط عدم وجود نشر متزامن، وإزالة روابط IAM/الهويتين الجديدتين بعد زوال التبعيات. لا حذف ledger أو إشعارات أو بيانات أخرى؛ لا تغيير اعتماد قديم أو Vercel القديم. لا حاجة لتراجع Vercel لأنه لم يتغير أصلًا. التراجع نفسه تغيير إنتاجي يُنفذ بموافقة مستقلة، إلا إجراء احتواء عاجل إذا ظهرت مخالفة إرسال؛ لم تظهر مخالفة في التحقق.

الأدلة المنقحة: docs/fcm-paused-production-execution-2026-10-17/. ملفات الأسرار وfirebase-debug.log وسياسة IAM الكاملة ليست ضمن الأدلة المنشورة. **القرار: الإرسال الجديد متوقف؛ مرحلة النشر الكامل غير مكتملة وتنتظر تصحيح صلاحية Eventarc المحددة.**
