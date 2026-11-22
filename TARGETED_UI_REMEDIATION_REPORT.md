# TARGETED UI REMEDIATION REPORT — IN PROGRESS

- **المشروع:** عقارات الانبار (`D:\Projects\aqar-unified-wt`)
- **الفرع:** `feature/bookings-unified`
- **المرجع:** `FINAL_READ_ONLY_INTEGRATION_AUDIT.md`

---

## سجل التنفيذ المرحلي (Phase Progress Log)

### المرحلة الأولى: إصلاح العيوب المثبتة (Completed)
- **الملفات المعالجة:**
  1. `lib/widgets/property_horizontal_card.dart`: إصلاح تباين عنوان العقار (`property.title`)، والموقع (`property.location`)، وعناصر المعلومات (`_InfoItem`) وحالات تحميل الصور في الوضع النهاري مع الحفاظ على الوضع الداكن والتصميم والأبعاد.
  2. `lib/widgets/home/property_requests/property_request_home_card.dart`: إصلاح تباين نصوص `_infoRow` (الموقع، المساحة، السعر) وخلفية الأيقونة ونافذة تأكيد الحذف في الوضع النهاري.
- **الفحص الساكن (`dart analyze`):** `0 errors` (`Exit Code: 1` فقط بسبب تحذير مسبق `unused_element` على `_confirmDeleteRequest`).

### المرحلة الثانية: إصلاح أثر `embedded` في الحجوزات (Completed)
- **الملفات المعالجة:**
  1. `lib/bookings/booking_screen.dart`: تعريف `isHosted = widget.embedded || widget.onBackToMain != null` لإعادة إظهار زر الرجوع `leading` في `AppBar` داخل التبويبات الفرعية (`بحث`، `حجوزاتي`، `حسابي`، ولوحات المالك/الإدارة/المالية) وإعادة إظهار قائمة `heroAction` (`لوحات الحجوزات`) في شاشة الاستكشاف دون إخفاء `BookingBottomBar` ودون تكرار عناصر `AppBar`.
- **الفحص الساكن (`dart analyze lib/bookings/booking_screen.dart`):** **`Exit Code: 0`** (`0 errors`, `0 warnings`).

### المرحلة الثالثة: تعميم الثيم على التطبيق الرئيسي
- **الوحدة 3.1: الرئيسية ومكوناتها (Completed):**
  - `lib/widgets/home/featured_offices_section.dart`
  - `lib/office/widgets/office_card.dart`
  - `lib/widgets/app_stats/app_stats_card.dart`
  - `lib/widgets/app_stats/app_stat_item.dart`
  - `lib/widgets/navigation/advertise_options_sheet.dart`
  - `lib/widgets/notification_permission_sheet.dart`
  - `lib/widgets/aqar_refresh_header.dart`
  - `lib/widgets/home/why_aqar_section.dart` (نافذة تفاصيل الميزة)
- **الوحدات المتبقية قيد التنفيذ:**
  - الوحدة 3.2: العقارات وتفاصيل العقار (`property_card.dart`, `property_details.dart`, `all_properties_screen.dart`, `publisher_properties_screen.dart`, `property_image.dart`)
  - الوحدة 3.3: المفضلة والطلبات (`my_properties_screen.dart`, `pending_properties.dart`, `all_property_requests_screen.dart`, `property_request_details_screen.dart`, `property_request/*`)
  - الوحدة 3.4: الملف الشخصي والإشعارات (`profile_screen.dart`, `notifications_screen.dart`, `send_notification_screen.dart`, `onboarding_screen.dart`, `bottom_sheets/*`)
  - الوحدة 3.5: الدردشة والمكاتب والإحصائيات والخرائط (`chat/*`, `office/*`, `statistics/*`, `features/property_map/*`, `features/property_card/*`)
  - الوحدة 3.6: إضافة وتعديل العقارات وبقية الشاشات (`add_property/*`, `edit_property/*`, `screens/admin/*`, `app_updates/*`)
