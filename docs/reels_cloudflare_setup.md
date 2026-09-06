# إعداد ريلز العقارات دون Firebase Blaze

يعمل نظام الريلز على Cloudflare Worker وR2، ولا يحتاج إلى Cloud Functions أو
Secret Manager أو Cloud Scheduler. يبقى Firebase Authentication وFirestore على
الخطة المجانية، وتبقى صور العقارات على Cloudinary.

## المتطلبات

- حاوية R2 باسم `aqar-reels`.
- رابط R2 عام مضبوط مسبقًا في `cloudflare/reels-worker/wrangler.jsonc`.
- حساب خدمة Firebase لمشروع `aqar-9f3f9`.
- مستخدم أدمن في `users/{uid}` يحمل `isAdmin: true`.

## إنشاء حساب خدمة Firebase

من Firebase Console افتح Project settings ثم Service accounts، واختر
`Generate new private key`. احفظ ملف JSON محليًا ولا ترفعه إلى GitHub.

## نشر Worker

```bash
cd cloudflare/reels-worker
npm install
npx wrangler login
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
npx wrangler deploy
```

عند أمر السر، الصق محتوى ملف حساب الخدمة JSON كاملًا. لا تضف مفاتيح R2 إلى
التطبيق؛ الـWorker يصل إلى الحاوية عبر R2 Binding مباشرة.

انسخ رابط Worker الناتج، ثم ابنِ التطبيق مع:

```bash
flutter build apk --release --dart-define=REELS_API_BASE_URL=https://aqar-reels-api.YOUR-SUBDOMAIN.workers.dev
```

## نشر قواعد وفهارس Firestore دون Blaze

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

لا تنشر `functions`. الريلز المجدولة تظهر عندما يحين `publishAt`، وتختفي عند
`expiresAt` من خلال قواعد Firestore ومنطق التطبيق، من دون مهمة مجدولة.

## حدود الرفع

الـWorker يقبل فيديوهات حتى 100MB وبأنواع `video/*`. الحد مناسب لريلز قصيرة،
ويمنع رفع ملفات ضخمة بالخطأ. رفع الفيديو مسموح للأدمن فقط بعد التحقق من Firebase
ID token ومن حقل `isAdmin` في Firestore.
