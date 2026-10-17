# نتيجة نشر خادم الإشعارات المتوقف — 18 أكتوبر 2026

**PASS / GO لمرحلة النشر المتوقف فقط. الإرسال غير مفعّل، ولا تشمل النتيجة موافقة إطلاق FCM.** نُفذت موافقة المستخدم على خطة 17 أكتوبر، وأُبقيت نتائج الاختبارات السابقة معتمدة دون إعادة اختبارات الأجهزة أو الحمل أو CI.

## ما تغير فعليًا في الإنتاج

في Firebase/Google Cloud `aqar-9f3f9`:

- تفعيل `sts.googleapis.com`؛ IAM Credentials كان مفعّلًا مسبقًا.
- إنشاء workload identity pool `aqar-vercel-paused` وprovider `vercel-production`.
- الثقة مقيدة بالفريق `team_OuMMNqbA3ALsK4nAoBE7UxSe` والمشروع `prj_DfyjRjfnIZFb7SKyN1EHD4HZfv1X` وبيئة `production` وsubject `owner:aysar93s-projects:project:notification-server:environment:production`، مع issuer وجمهور فريق Vercel المحددين في الخطة.
- إنشاء الدور `aqarPushFederatedToken` بإذن **`iam.serviceAccounts.getAccessToken` فقط**، وربطه بالـprincipal المحدد على حساب `aqar-push-vercel@aqar-9f3f9.iam.gserviceaccount.com` وحده. لا ربط لهذا الدور على المشروع.
- لم تُضف صلاحية إرسال FCM أو تُنشأ مفاتيح JSON. صلاحيات البيانات للحساب بقيت دور `aqarPushDataRuntime` المعتمد بست صلاحيات Firestore فقط.

في مشروع Vercel `notification-server`:

- إضافة ستة متغيرات Production عامة: `FCM_SERVER_PROFILE=production-paused`، `GCLOUD_PROJECT=aqar-9f3f9`، `GCP_PROJECT_NUMBER=1031621585901`، `FCM_MIGRATION_ENABLED=true`، `PUSH_BRIDGE_ENABLED=true`، `BRIDGE_ONESIGNAL_ENABLED=false`.
- بقيت متغيرات `FIREBASE_SERVICE_ACCOUNT` و`ONESIGNAL_API_KEY` و`ONESIGNAL_APP_ID` محفوظة دون تعديل؛ مسار المصادقة الجديد لا يقرأ اعتماد JSON أو مفتاح OneSignal القديم. تحققنا من ثبات معرفات المتغيرات وتواريخ تعديلها؛ لم نكشف قيمها.
- نشر نسخة الصيانة والمرشح أولًا دون نقل النطاق القانوني `notification-server-henna.vercel.app`. أُثبت بقاء هذا النطاق على النشر السابق خلال البناء والفحص، ثم رُوّج المرشح بعد النجاح.
- النشر الحالي: **`dpl_DYZa5Drina73ujWgZdiUnCoKHqCm`**، ورابطه الثابت [المرشح المنشور](https://notification-server-hvfh08cal-aysar93s-projects.vercel.app).
- النطاق العام [notification-server-henna.vercel.app](https://notification-server-henna.vercel.app) أصبح يشير إليه. قد يُعيّن Vercel أيضًا alias المشروع العام خلال النشر؛ نسخة التراجع معتمدة بمعرفها ورابطها الثابت، لا بذلك alias المتحرك.

لم تتغير دوال Firebase الثماني أو تواريخ تحديثها أو هويات تشغيلها. لم ننشر قواعد، ولم نغير OneSignal أو Cloudinary أو Storage أو الريلز أو تطبيقات المتاجر. لم ندمج PR #3 أو main.

## التحقق المحدود ونتيجته

| التحقق الجديد الضروري | النتيجة |
|---|---|
| نسخة الصيانة المستقلة عن Google: GET ثم POST /send | 200 ثم 202، paused وpushSent=false |
| المرشح: قراءة rollout عبر OIDC → STS → انتحال الحساب المحدد | GET=200، ready وpaused |
| المرشح: /send بمعرّف فحص غير مرتبط بمستلم أو حدث | 202، awaiting_verified_firestore_event، pushSent=false |
| النطاق العام بعد الترويج، دون bypass | GET=200؛ POST /send بلا معرّف=400 |
| الحالة النهائية | paused، percent=0، جميع قوائم الحسابات والأجهزة والاستعادة فارغة |
| سجل التسليم الإنتاجي | صفر مستندات push_deliveries |
| الاعتماد والدوال | صفر USER_MANAGED keys للهوية، لا صلاحية إرسال مضافة، الدوال الثماني ACTIVE دون تغيير |
| سجلات أخطاء نشر المرشح في نافذة التحقق | صفر سجلات ERROR، دون صفحات متبقية |

لم ننشئ إشعارًا أو حسابًا أو رمز جهاز أو حدث إرسال إنتاجيًا. طلب المعرّف غير الموجود شغّل فقط حارس الدخول وعداد تحديد المعدل الداخلي؛ لا وجهة مستلم ولا استدعاء مزود. هذه نافذة تحقق محدودة وليست ضمانًا لغياب أخطاء مستقبلية. لم نكرر اختبارات الاستقبال أو التوجيه أو الحمل السابقة.

`legacyIngressCoordinated=false` بقي دون تغيير. يرفض الخادم تغيير paused أو ملء المجموعة؛ المرشح الحالي مخصص للإيقاف، وتفعيل canary لاحقًا يحتاج مرشح تفعيل معتمد، وليس مجرد قلب علم خفي.

## الخطأ المعالج والتكلفة

فشل بناء الصيانة الأول `dpl_6AvDKvLybVugqqxxSsXs3Dp2hTep` لأن إعداد إطار المشروع حاول اكتشاف Express داخل نسخة HTTP مستقلة. لم يُنقل النطاق القانوني إلى البناء الفاشل. أُضيف `framework: null` إلى ملفي نشر الصيانة والمرشح، دون تعديل إعدادات المشروع العامة أو منطق الجسر، ثم نجح البناء والفحص. لا خطأ مؤثر متبقٍ في التحقق النهائي، ولم نحتج توسيع IAM.

جرى بناء فاشل واحد وبناءان ناجحان وعدد محدود من طلبات HTTP وFirestore وIAM. لا ترقية خطة أو حمل أو مورد دائم مرتفع التكلفة أُنشئ. **التكلفة الفعلية غير محسومة** لعدم استخراج تقرير فوترة، ولا يُدعى مبلغ صفري. لم يُعَد اختبار الحمل. يستمر احتساب البناء والتشغيل والقراءات والسجلات وفق حصص الحسابات القائمة.

## التراجع الجاهز

نسخة الصيانة **READY ومفحوصة**:

- المعرف: `dpl_BJ7BcrBbLzNFPywfjzRamajXyKYw`.
- الرابط الثابت: [نسخة الصيانة](https://notification-server-5ss2dr2rx-aysar93s-projects.vercel.app).
- عند خطأ مؤثر يُنفذ من مشروع notification-server: `vercel promote dpl_BJ7BcrBbLzNFPywfjzRamajXyKYw --scope aysar93s-projects --yes`، ثم يتحقق GET=200 maintenance وPOST /send=202 paused. يبقى rollout فارغًا ولا تُعدل مفاتيح أو دوال.
- الصيانة لا تستدعي Google أو مزودي الإرسال، وتقبل /send بإقرار إيقاف. لا نعتمد إعادة النشر القديم غير المقيد كتراجع آمن. لم يلزم تراجع فعلي في هذه الجولة؛ مدة انتقال alias ليست ضمانًا لصفر انقطاع.

## المتبقي لتفعيل FCM تدريجيًا

1. موافقة مستقلة على خطة canary: الحسابات والأجهزة المحددة وحدود التوسع والإيقاف، وهوية الإرسال وصلاحيتها المحدودة. **هذه المرحلة لم تمنح صلاحية الإرسال لأي هوية جديدة.**
2. إغلاق بنود التفعيل المؤجلة في الخطة السابقة: قواعد notifications القديمة وفهارس المسارات المطلوبة وتنسيق جميع مداخل الإرسال القديمة. نقل النطاق لا يلغي روابط النشر القديمة أو مفاتيحها؛ لا يجوز اعتبار التنسيق مثبتًا أو تفعيل legacyIngressCoordinated لمجرد نجاح هذا النشر.
3. نشر مرشح يدعم وضع canary بضوابطه بعد اعتماده، مع بقاء قوائم المجموعة فارغة أثناء تحضيره. تُفحص الأجزاء المتغيرة فقط؛ نتائج الأجهزة السابقة محفوظة، ومحدودية فتح الرئيسية في iOS القديم مقبولة سابقًا بشروطها.
4. ربط/تأكيد مراقبة أخطاء الإنتاج والتنبيهات والميزانية والاحتفاظ بالسجلات ضمن خطة التفعيل، واستخراج بيانات Billing لحسم التكلفة الفعلية. نجاح بريد التنبيه التجريبي سابقًا لا يُعرض كدليل لتفعيل قناة إنتاج جديدة في هذه الجولة.

لا حاجة الآن إلى جهاز أو كلمة مرور أو بحث عن مفتاح من المستخدم. المرحلة المصرح بها مكتملة، وأي إرسال أو تفعيل يحتاج موافقة لاحقة.

الأدلة المنقحة: `docs/fcm-production-keyless-paused-2026-10-18/`؛ ملفات before وjournal وprovision-verified وafter-provision وmaintenance/candidate-deployment وsmoke وpre-promote وpromoted وcanonical-smoke وfinal-state وlog-audit. الأوقات في JSON بتوقيت UTC، والتنفيذ وقع بعد منتصف ليل 18 أكتوبر بتوقيت بغداد.
