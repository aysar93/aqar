# إعداد نظام ريلز وCloudflare R2

لا تُخزّن مفاتيح R2 في تطبيق Flutter أو داخل المستودع. وظيفة
`createReelUploadUrl` تتحقق من أن المستخدم مدير ثم تُصدر رابط رفع مؤقتًا لمدة
10 دقائق. يستمر Cloudinary في خدمة صور العقارات دون تغيير.

## متغيرات الخادم السرية

اضبط الأسرار التالية في مشروع Firebase قبل نشر الوظائف:

```bash
firebase functions:secrets:set R2_ACCOUNT_ID
firebase functions:secrets:set R2_ACCESS_KEY_ID
firebase functions:secrets:set R2_SECRET_ACCESS_KEY
firebase functions:secrets:set R2_BUCKET
firebase functions:secrets:set R2_PUBLIC_BASE_URL
```

`R2_PUBLIC_BASE_URL` هو نطاق R2 العام أو النطاق المخصص، من دون مسار
`reels/original`.

## CORS المقترح لحاوية R2

اسمح بتابع `PUT` من نطاقات لوحة الإدارة الفعلية، وأضف نطاق المعاينة عند
الحاجة. تطبيقات Android وiOS لا ترسل Origin عادةً، لكن إعداد الويب يحتاجه.

```json
[
  {
    "AllowedOrigins": ["https://YOUR_ADMIN_DOMAIN"],
    "AllowedMethods": ["GET", "HEAD", "PUT"],
    "AllowedHeaders": ["Content-Type"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

## النشر

بعد ضبط الأسرار وCORS:

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes
```

تتولى الوظيفة المجدولة `publishScheduledReels` نشر الريلز المستحقة وتحويل
الريلز المنتهية كل خمس دقائق. يوصى بتفعيل سياسة Lifecycle في Firestore لحذف
مستندات `reel_event_dedup` اعتمادًا على الحقل `expiresAt`.
