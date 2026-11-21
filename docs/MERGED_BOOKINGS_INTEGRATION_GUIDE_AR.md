# دليل التكامل المعماري الشامل بعد دمج نظام الحجوزات في «عقارات الانبار»

**الفرع المدمج:** `merge/bookings-into-main`  
**المرجع الأساسي للتطبيق (`main`):** `f4f56298378f1c14f8ba7dca280ac36f0e83c040`  
**مرجع نظام الحجوزات الموحد (`feature/bookings-unified`):** `649d8afbbbaf530913e32e57f0c6b8cbac7156d8`  
**نقطة الالتقاء المشتركة (`merge-base`):** `ae9207b6c33affb26b69f01014ab4fb7f` (`ae9207b6c33affb26b6872160848d5716f7ffb50`)

---

## 1. ملخص البنية المعمارية الموحدة

يجمع الفرع `merge/bookings-into-main` بين منظومة الوسائط والإشعارات الموثوقة الحديثة في `main` ومنظومة الحجوزات المتكاملة والهوية البصرية المحدثة (الوضع الليلي/النهاري) في `feature/bookings-unified` عبر **17 دفعة هندسية متسلسلة (Batches 1–17)**:

1. **منظومة الوسائط الموحدة والعزل الثلاثي للبيئات:**
   - الصور العامة والخاصة للتطبيق الرئيسي تستخدم `MediaStore` و`MediaImage` و`PrivateMediaImage`.
   - وسائط نظام الحجوزات تستخدم `BookingMediaService` و`BookingMediaImage` و`BookingVideoResolver`.
   - الريلز العامة في التطبيق الرئيسي تستخدم Cloudflare R2 (`aqar-reels`) دون أي تغيير.
   - العزل الثلاثي في `MediaStore`: يمنع الاتصال بمشاريع الإنتاج عند تفعيل أي من محددات الاختبار الثلاثة (`FCM_STAGING_PROJECT`, `MEDIA_STAGING_PROJECT`, `BOOKINGS_STAGING_PROJECT`).

2. **منظومة الإشعارات الموحدة (`FCMService` + `TrustedInbox` + `BookingForegroundNotice`):**
   - الحفاظ الكامل على بنية `FCMService` الحديثة في `main` مع بوابة `PushMigration` و`TrustedInbox` وحارس `mode=paused` في دالة الجسر.
   - دمج إشعارات الحجوزات الأمامية (`BookingForegroundNotice`) والتوجيه المباشر عند الضغط على إشعار الحجز إلى `BookingDetailsScreen` عبر `NotificationNavigationService`.

3. **تحديد رابط RTDB حسب المشروع الفعلي (`PresenceService` & `analytics_presence_access.js`):**
   - تحديد رابط قاعدة البيانات اللحظية `databaseURL` ديناميكياً من `Firebase.app().options.databaseURL` أو معرف المشروع النشط، لمنع اتصال بيئة `aqar-bookings-test-20261009` بقاعدة بيانات الإنتاج `aqar-9f3f9`.

4. **الهوية البصرية الموحدة وتجربة المستخدم (RTL & Dark/Light Mode):**
   - الوضع الافتراضي داكن (`ThemeMode.dark`) مع حفظ اختيار المستخدم محلياً في `SharedPreferences` (`app_theme_mode`).
   - ألوان هادئة ومعتمدة: الذهبي المطفأ `#C5A16B` والكحلي الداكن `#0F172A`.
   - الشريط السفلي الموحد بـ 5 أزرار بالترتيب العربي من اليمين إلى اليسار: `الرئيسية`، `المفضلة`، `أعلن`، `الريلز`، `الحجوزات`.
   - الهيدر الذهبي الموحد (`BookingGoldenHeaderContainer`) في الصفحة الرئيسية وصفحة الحجوزات.
   - القائمة الجانبية (`AppDrawer`) تحتوي على زر دردشة واحد فقط داخل قسم «اتصل بنا» بدون أسهم توسعة جانبية، مع مفتاح تبديل المظهر مثبت أسفل القائمة لجميع المستخدمين والضيوف.
   - إصلاح فيضان شاشة المفضلة في الوضع الأفقي عبر `SingleChildScrollView`.

5. **بوابة الإدارة الموحدة للحجوزات (9 تبويبات):**
   - `نظرة عامة`، `المواقع`، `الحجوزات`، `المدفوعات`، `النزاعات`، `الريلز`، `التقويم`، `التقارير`، `السجل`.
   - دعم سياسة العربون، تقارير النزاعات والاحتيال، وتصدير CSV.

6. **عزل بيئة الاختبار (Staging Isolation):**
   - حزمة أندرويد لاختبار الحجوزات: `com.andalus.aqar.bookingstest` مربوطة حصرياً بمشروع `aqar-bookings-test-20261009`.
   - حزمة الإنتاج `com.andalus.aqar` وملفات `android/app/google-services.json` و`ios/Runner/GoogleService-Info.plist` و`lib/firebase_options.dart` محفوظة بالكامل دون أي تعديل.
