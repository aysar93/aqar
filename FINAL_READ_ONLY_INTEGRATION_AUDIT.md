# FINAL READ-ONLY INTEGRATION AUDIT — UNIFIED APP UI PROTECTION

- **المشروع:** عقارات الانبار (`D:\Projects\aqar-unified-wt`)
- **الفرع:** `feature/bookings-unified`
- **نوع المراجعة:** تدقيق قراءة فقط (Strict Read-Only Audit — بدون تعديل أي ملف مصدري أو بناء أو نشر)
- **تاريخ التدقيق:** 2026-11-17

---

## الحكم النهائي العام (Overall Verdict)

> [!WARNING]
> **الحكم النهائي: `FAIL` (مع توثيق كامل للنقاط الناجحة والنقاط غير المكتملة / التأثيرات الجانبية)**
>
> **أسباب الحكم بـ `FAIL` بدلاً من `PASS`:**
> 1. **تعميم الثيم النهاري غير مكتمل وأحدث مشكلة تباين (White-on-White) في بطاقات رئيسية:**
>    - في `lib/widgets/property_horizontal_card.dart` (السطر 69) تم تحويل خلفية البطاقة في الوضع النهاري إلى `Colors.white`، لكن نصوص العنوان (`property.title` سطر 361) والموقع (`property.location` سطر 428) وعناصر المعلومات (`_InfoItem` سطر 564) بقيت ثابتة باللون الأبيض (`Colors.white` / `Colors.white70`)، مما يجعل النص أبيض فوق خلفية بيضاء في الوضع النهاري.
>    - في `lib/widgets/home/property_requests/property_request_home_card.dart` (السطر 42) تم تحويل خلفية البطاقة في الوضع النهاري إلى `Colors.white`، لكن نصوص الصفوف الفرعية `_infoRow` (سطر 363) بقيت `Colors.white70` وخلفية الأيقونة `Colors.white.withValues(alpha: .04)`، مما يفقدها التباين في الوضع النهاري.
>    - أقسام رئيسية داخل `HomeScreen` نفسها لم تُربط بالثيم النهاري وبقيت داكنة ثابتة: `FeaturedOfficesSection` (`0xFF0F172A`) و`AppStatsCard` (`0xFF1E293B` / `0xFF0F172A`).
>    - بطاقة العقار العمودية `lib/widgets/property_card.dart` (المستخدمة في تبويب العقارات داخل المفضلة وفي شاشات العقارات) وأكثر من 80 شاشة ومكوناً في التطبيق الرئيسي (`property_details.dart`, `all_properties_screen.dart`, `my_properties_screen.dart`, `notifications_screen.dart`, `profile_screen.dart`, `add_property/*`, `chat/*`, `office/*`, `statistics/*`) لم تُربط بالثيم النهاري (`themeRefs = 0`) وبقيت بألوان داكنة ثابتة.
> 2. **أثر جانبي في التنقل داخل الحجوزات بعد تحويل `embedded: false`:**
>    - عند فتح الحجوزات من الشريط السفلي والتنقل عبر `BookingBottomBar` إلى تبويبات (`بحث`، `ريلز`، `حجوزاتي`، `حسابي`)، يختفي هيدر الاستكشاف (`BookingWelcomeSearch`) ولا يظهر أي زر رجوع مرئي في `AppBar` لأن الشرط في `booking_screen.dart:459` هو `leading: widget.embedded && tab != 0 ? ... : null` وبما أن `embedded` أصبح `false` فإن `leading` يصبح `null`.
>    - اختفاء قائمة `heroAction` (`لوحات الحجوزات` في `booking_screen.dart:609`) لأنها كانت مشروطة بـ `widget.embedded`.
> 3. **ملاحظات فنية في مؤشر تفاصيل المكان (`BookingVenueDetails`):**
>    - `_venueSelectedNotifier` المعرّف في `_BookingRequestScreenState` (`booking_screen.dart:1076`) لا يتم عمل `dispose()` له داخل `dispose()` (سطر 1261).
>    - `BookingVenueDetailsState` يسجل المستمع `track` مرتين على نفس التمرير (`widget.scrollController?.addListener(track)` في سطر 415 و`position?.addListener(track)` في سطر 433).
> 4. **عدم وجود تحقق بصري على الهاتف الفعلي للتعديلات الأخيرة:**
>    - التعديلات الأخيرة لم يتم بناؤها أو تثبيتها على الهاتف الفعلي (التزاماً بقيد عدم البناء بدون إذن)، وبالتالي لم يتم إثباتها بصرياً على الجهاز.

---

## 1. تدقيق تغييرات التطبيق الرئيسي (Per-File Diff Audit)

إجمالي الملفات المعدلة في شجرة العمل مقارنةً بـ `HEAD` هو **153 ملفاً متتبعاً** (معظمها استبدال شامل سابق للون `#D4AF37` بـ `#C5A16B` ودمج الحجوزات)، منها **23 ملفاً** جرى تعديلها في مهمة تصحيح الواجهات الخمس الأخيرة.

فيما يلي التدقيق التفصيلي للملفات الرئيسية:

| الملف | ما الذي تغير؟ | مرتبط بالطلبات الـ 5؟ | هل تغيرت الأحجام / المسافات / الترتيب؟ | هل تغيرت وظيفة غير مطلوبة؟ | تأثير على الوضع الداكن / النهاري |
|---|---|---|---|---|---|
| `lib/screens/home_screen.dart` | 1) تغيير `endDrawer` إلى `drawer` و`openEndDrawer()` إلى `openDrawer()`.<br>2) تغيير `backgroundColor` من `0xFF0F172A` إلى `Theme.of(context).scaffoldBackgroundColor`.<br>*(ملاحظة من الدمج السابق على الفرع: إضافة زر المحادثة `_chatDoc` في الهيدر).* | نعم (طلب 1 وطلب 3) | لم تتغير أحجام أو مسافات أو ترتيب عناصر الصفحة | لا في التعديل الأخير (إضافة المحادثة للهيدر تمت في مرحلة الدمج السابقة) | الخلفية تتغير في النهاري؛ لكن بعض الأقسام الفرعية بداخلها بقيت داكنة |
| `lib/screens/main_shell.dart` | 1) جعل `bottomNavigationBar: currentIndex == 4 ? null : CustomBottomBar(...)`.<br>2) تمرير `BookingScreen(embedded: false, onBackToMain: _backToHome)` في `pages[4]`.<br>3) إضافة `PopScope` لإرجاع `currentIndex` إلى `0` عند زر الرجوع للنظام. | نعم (طلب 4) | لا | تحويل `embedded: false` أدى لإخفاء `leading` في `AppBar` للتبويبات الداخلية وإخفاء `heroAction` | سليم |
| `lib/widgets/navigation/custom_bottom_bar.dart` | تغيير لون الحاوية من `0xff1E293B` الثابت إلى `isDark ? const Color(0xff1E293B) : Colors.white` وتخفيف الظل في النهاري. *(ترتيب الأزرار الـ 5: الحجوزات، الريلز، أعلن، المفضلة، الرئيسية).* | نعم (طلب 1 وطلب 4) | الارتفاع `82` والحواف `28` وترتيب الأزرار الـ 5 محفوظة | لا | يعمل في النهاري والداكن |
| `lib/widgets/navigation/bottom_nav_item.dart` | استبدال `#D4AF37` بـ `#C5A16B`، وتغيير لون غير المحدد من `Colors.white70` إلى `isDark ? Colors.white70 : const Color(0xFF64748B)`. | نعم (طلب 1 وطلب 2) | لا (الحجم 70 وحجم الأيقونة 28 والخط 12 كما هي) | لا | يعمل في النهاري والداكن |
| `lib/widgets/home/home_header.dart` | 1) استبدال `#D4AF37` و`#F2C94C` بـ `#C5A16B`.<br>2) ربط نصوص الترحيب وأزرار الهيدر `_squareButton` وحدود الشارات بـ `isDark`. | نعم (طلب 1 وطلب 2) | لا (`AqarSizes` و`AqarSpacing` كما هي) | تدرج إطار الصورة الشخصية أصبح بلونين متطابقين `[0xFFC5A16B, 0xFFC5A16B]` (لون مسطح) | يعمل في النهاري والداكن |
| `lib/widgets/app_drawer.dart` | 1) استبدال `#D4AF37` و`#B8860B` بـ `#C5A16B`.<br>2) ربط خلفية الـ `Drawer` وبطاقات `section` و`guestHeader` و`userHeader` ونصوص العناصر بـ `isDark`.<br>*(ملاحظة من تعديل سابق على الفرع: إزالة عنصر "حجوزات الشاليهات" من القائمة الجانبية).* | نعم (طلب 1 وطلب 2) | لا | تدرج زر انضمام المكتب أصبح مسطحاً `[0xffC5A16B, 0xffC5A16B]` | يعمل في النهاري والداكن |
| `lib/widgets/home/search_section.dart` | 1) استبدال `#D4AF37` و`#F8D86B` بـ `#C5A16B`.<br>2) ربط خلفية صندوق البحث ولون النص والتلميح وأيقونة المسح بـ `isDark`. | نعم (طلب 1 وطلب 2) | لا | تدرج زر الفلتر أصبح مسطحاً `[0xffC5A16B, 0xffC5A16B]` | يعمل في النهاري والداكن |
| `lib/widgets/home/categories_section.dart` & `category_card.dart` | 1) استبدال `#D4AF37` و`#F8D86B` بـ `#C5A16B`.<br>2) ربط خلفية البطاقات والدوائر والنصوص بـ `isDark`. | نعم (طلب 1 وطلب 2) | لا | تدرج الدائرة النشطة أصبح مسطحاً `[0xffC5A16B, 0xffC5A16B]` | يعمل في النهاري والداكن |
| `lib/screens/favorites_screen.dart` | 1) استبدال `#D4AF37` بـ `#C5A16B`.<br>2) ربط خلفية `Scaffold` و`AppBar` و`TabBar` وحالات الفراغ وبطاقات الريلز المحفوظة بـ `isDark`. | نعم (طلب 1 وطلب 2) | لا | لا | شاشة المفضلة نفسها تتكيف، لكن قائمة العقارات المفضلة بداخلها تستخدم `PropertyCard` التي بقيت داكنة ثابتة (`0xff1E293B`) |
| `lib/widgets/home/why_aqar_section.dart` | 1) استبدال `#D4AF37` و`#F8D86B` بـ `#C5A16B`.<br>2) ربط العناوين والدوائر الداخلية والفوتر بـ `isDark`. | نعم (طلب 1 وطلب 2) | لا | نافذة الحوار المنبثقة عند الضغط على الميزة (سطر 145) ما زالت بخلفية داكنة ثابتة `[0xff1E293B, 0xff0F172A]` | القسم نفسه يتكيف، والنافذة المنبثقة داكنة |
| `lib/widgets/home/horizontal_properties_section.dart` & `property_requests_section.dart` | 1) استبدال `#D4AF37` و`#F8D66D` بـ `#C5A16B`.<br>2) ربط خلفية حاوية القسم وعناوينه بـ `isDark`. | نعم (طلب 1 وطلب 2) | لا | لا | حاوية القسم تتكيف مع الوضعين |
| `lib/widgets/home/property_requests/property_request_home_card.dart` | تحويل خلفية البطاقة إلى `Colors.white` في النهاري ولون العنوان إلى `0xFF0F172A`. | نعم (طلب 1 وطلب 2) | لا | لا | **خلل تباين في النهاري:** نصوص `_infoRow` (سطر 363) بقيت `Colors.white70` فوق خلفية بيضاء |
| `lib/widgets/property_horizontal_home_card.dart` | تحويل لون `Card` إلى `Colors.white` في النهاري واستبدال `#F8D86B` بـ `#C5A16B`. | نعم (طلب 1 وطلب 2) | لا | لا | مقبول لأن النص الأبيض مرسوم فوق تدرج الصورة الداكن (`0xff1E293B`) |
| `lib/widgets/property_horizontal_card.dart` | تحويل خلفية البطاقة (سطر 69) إلى `Colors.white` في النهاري واستبدال `#B8922F` بـ `#C5A16B`. | نعم (طلب 1 وطلب 2) | لا | لا | **خلل تباين حاد في النهاري:** العنوان (سطر 361) والموقع (سطر 428) و`_InfoItem` (سطر 564) بقيت `Colors.white` / `Colors.white70` فوق خلفية البطاقة البيضاء |
| `lib/widgets/property_card.dart` | استبدال `#D4AF37` بـ `#C5A16B` فقط. | نعم (طلب 2 فقط) | لا | لا | **لم يُربط بالثيم النهاري:** خلفية البطاقة ثابتة `const Color(0xff1E293B)` (سطر 273) |

---

## 2. تدقيق الثيمات (Light & Dark Theme Audit)

### 2.1 حفظ واسترجاع الثيم
- في `lib/providers/app_settings_provider.dart`: يتم حفظ اختيار المستخدم في `SharedPreferences` تحت المفتاح `'app_theme_mode'` واسترجاعه عند بدء التشغيل، والوضع الافتراضي هو `ThemeMode.dark`.
- في `lib/main.dart` (السطور 102-104): تم ربط `MaterialApp` بـ `theme: AppTheme.lightTheme` و`darkTheme: AppTheme.darkTheme` و`themeMode: settings.themeMode`.

### 2.2 حالة عناصر وشاشات التطبيق الرئيسي في الوضعين
| المكون / الشاشة | الوضع الداكن (Dark) | الوضع النهاري (Light) | ملاحظات التدقيق |
|---|---|---|---|
| خلفية الصفحة الرئيسية (`HomeScreen`) | سليم (`0xFF0F172A`) | سليم (`0xFFF8FAFC`) | مربوطة بـ `scaffoldBackgroundColor` |
| الهيدر (`HomeHeader`) والبحث (`SearchSection`) | سليم | سليم | النصوص والأيقونات والخلفيات تتكيف |
| الأقسام (`CategoriesSection`, `CategoryCard`) | سليم | سليم | الخلفيات والنصوص تتكيف |
| قسم المكاتب المميزة (`FeaturedOfficesSection`) | سليم | **داكن ثابت** | `sectionBackground = Color(0xFF0F172A)` في السطر 18 و`OfficeCard` داكنة ثابتة |
| شريط إحصائيات التطبيق (`AppStatsCard`) | سليم | **داكن ثابت** | تدرج ثابت `[0xFF1E293B, 0xFF111827, 0xFF0F172A]` في السطر 85 |
| بطاقة طلبات العقارات (`PropertyRequestHomeCard`) | سليم | **نقص تباين** | الخلفية بيضاء لكن نصوص `_infoRow` (الموقع، المساحة، السعر) `Colors.white70` |
| البطاقة الأفقية (`PropertyHorizontalCard`) | سليم | **خلل تباين (أبيض على أبيض)** | الخلفية بيضاء لكن العنوان والموقع وتفاصيل الغرف/المساحة `Colors.white` |
| البطاقة العمودية (`PropertyCard`) | سليم | **داكن ثابت** | الخلفية ثابتة `Color(0xff1E293B)` في السطر 273 |
| القائمة الجانبية (`AppDrawer`) | سليم | سليم | الخلفية والبطاقات والنصوص تتكيف |
| الشريط السفلي (`CustomBottomBar`) | سليم | سليم | الخلفية والأيقونات والنصوص تتكيف |
| شاشة المفضلة (`FavoritesScreen`) | سليم | **جزئي** | الهيكل والريلز المحفوظة تتكيف، لكن تبويب العقارات يعرض `PropertyCard` الداكنة الثابتة |
| شاشة الإعدادات (`SettingsScreen`) | سليم | سليم | تحتوي على مفتاح تبديل الثيم وتتكيف مع الوضعين |
| شاشة الريلز (`ReelsScreen`) | مظلم غامر | مظلم غامر (مقصود) | مطابق للمطلوب |
| بقية شاشات التطبيق الرئيسي (`property_details`, `all_properties`, `my_properties`, `notifications`, `profile`, `add_property`, `office`, `chat`, `statistics`) | سليم | **داكن ثابت (`themeRefs=0`)** | لم يتم تحويلها للثيم النهاري وتحتوي على ألوان داكنة ثابتة (`0xFF0F172A` / `0xFF1E293B`) |

---

## 3. تدقيق اللون الذهبي (`#C5A16B` Audit)

### 3.1 الدرجات الذهبية القديمة التي تم استبدالها بـ `0xFFC5A16B`
تم التحقق عبر المسح الشامل لمجلد `lib/` من اختفاء الدرجات التالية بالكامل (0 نتائج متبقية):
- `0xFFD4AF37` (استُبدلت في أكثر من 130 ملفاً عبر المشروع)
- `0xFFF8D86B` (استُبدلت في `search_section.dart`, `categories_section.dart`, `why_aqar_section.dart`, `property_horizontal_home_card.dart`)
- `0xFFF8D66D` (استُبدلت في `horizontal_properties_section.dart`, `property_requests_section.dart`)
- `0xFFF2C94C` (استُبدلت في `home_header.dart`)
- `0xFFB8922F` (استُبدلت في `property_horizontal_card.dart`)
- `0xFFB8972A` و`0xFFC9A227` (استُبدلتا في `property_card_social_service.dart`)
- `0xFFC5A059` (استُبدلت في `booking_browse_ui.dart`)
- `0xFFE6C894` (استُبدلت في `booking_screen.dart`, `booking_map.dart`)
- `0xFFB8860B` (استُبدلت في `app_drawer.dart`)

### 3.2 الملفات التي بقيت فيها درجات ذهبية أو صفراء في `lib/`
1. **درجات ذهبية زخرفية متبقية لم تُستبدل:**
   - `lib/features/property_card/property_card_widget.dart:21`: `static const _brightGold = Color(0xFFFFD700);`
   - `lib/widgets/gold_ring_painter.dart:33`: `const Color(0xFFFFE082)` (لمعة الحلقة الذهبية المتحركة).
2. **درجة ذهبية رملية مساندة للتدرج في الثيم والحجوزات (`0xFFD8BD95` / `0xFF8B6B23`):**
   - `lib/theme/app_theme.dart:7`: `static const Color secondaryColor = Color(0xFFD8BD95);`
   - `lib/bookings/booking_discovery_design.dart:41`: `colors: [Color(0xFFD8BD95), Color(0xFFC5A16B)]`
   - `lib/bookings/booking_account_screen.dart:235`: `colors: [Color(0xFFD8BD95), Color(0xFFC5A16B)]`
   - `lib/bookings/admin/booking_admin_theme.dart:17`: `static const Color goldHover = Color(0xFFD8BD95);`
   - `lib/bookings/booking_screen.dart:700`: `const Color(0xFF8B6B23)` (لون نص التبويب المختار في الوضع النهاري لتحقيق تباين مقروء).
3. **ألوان حالات وظيفية وتقييمات (محفوظة بحق ولا يجب تغييرها):**
   - `0xFFF4B042` في `property_details.dart`، و`0xFFFFB020` في `office_status.dart` و`office_subscription_status.dart`، و`0xFFFBBF24` في `booking_shift_visual.dart`، و`0xFFFDE047` في `booking_admin_overview_tab.dart`.

### 3.3 ملاحظة حول طريقة استخدام `#C5A16B` في التدرجات
- في 8 مواضع (`home_header.dart:58`, `search_section.dart:173`, `categories_section.dart:191`, `why_aqar_section.dart:262`, `horizontal_properties_section.dart:152`, `property_requests_section.dart:304`, `property_horizontal_card.dart:441`, `app_drawer.dart:341`) تم استبدال اللون الفاتح في `LinearGradient` بـ `0xFFC5A16B` ليصبح التدرج `[Color(0xffC5A16B), Color(0xffC5A16B)]`، أي لوناً مسطحاً بلا تدرج فعلي.

---

## 4. تدقيق القائمة الجانبية (Side Drawer Audit)

- **النتيجة:** **PASS**
- **التحليل الفني:**
  - في الفرع الأصلي `main` لم يكن `main.dart` يفرض `Directionality(textDirection: TextDirection.rtl)` في `builder`، فكان `endDrawer` يفتح من اليمين.
  - بعد إضافة `Directionality(textDirection: TextDirection.rtl)` في `main.dart` (السطر 100-101)، أصبح الطرف الأيمن في Flutter هو `start` (`drawer`) والطرف الأيسر هو `end` (`endDrawer`).
  - تعديل `lib/screens/home_screen.dart:113` إلى `drawer: const AppDrawer()` والسطر `179` إلى `Scaffold.maybeOf(context)?.openDrawer()` أعاد فتح القائمة من **اليمين** بشكل صحيح في بيئة RTL دون المساس بترتيب أو مواضع عناصر الهيدر أو الصفحة.

---

## 5. تدقيق الشريط السفلي (Bottom Bar Switching Audit)

- **النتيجة:** **PASS WITH EDGE-CASE LIMITATION**
- **ما تم إثبات صحته:**
  1. يظهر `CustomBottomBar` في تبويبات التطبيق الرئيسي (`0`: الرئيسية، `1`: المفضلة، `3`: الريلز) بترتيب الـ 5 أزرار المطلوب من اليمين لليسار: **الحجوزات ← الريلز ← أعلن ← المفضلة ← الرئيسية**.
  2. عند الضغط على تبويب الحجوزات (`currentIndex == 4`)، يختفي `CustomBottomBar` تماماً (`bottomNavigationBar: currentIndex == 4 ? null : CustomBottomBar(...)`).
  3. يظهر `BookingBottomBar` المستقل داخل شاشة الحجوزات (`embedded: false`) بـ 5 تبويبات: **استكشف ← بحث ← ريلز ← حجوزاتي ← حسابي**.
  4. لا يظهر شريطان سفليان في الوقت نفسه إطلاقاً.
  5. زر السهم في أعلى شاشة استكشاف الحجوزات (`BookingWelcomeSearch`، سطر 49 من `booking_discovery_design.dart`) يستدعي `onBack` المربوط بـ `_backToHome` في `MainShell` فيعيد `currentIndex = 0` ويُرجع `CustomBottomBar`. كما أن زر الرجوع الفعلي في نظام أندرويد يعيد إلى الرئيسية عبر `PopScope` في `MainShell`.
- **القصور الجانبي المسجل:**
  - عندما ينتقل المستخدم داخل الحجوزات عبر `BookingBottomBar` إلى أي تبويب غير `استكشف` (مثل `بحث`، `ريلز`، `حجوزاتي`، `حسابي`)، لا يوجد زر رجوع مرئي في `AppBar` لأن `booking_screen.dart:459` يشترط `widget.embedded && tab != 0`، وبما أن `embedded` أصبح `false` فإن `leading` يكون `null` (يظل الرجوع متاحاً عبر زر النظام في الهاتف أو العودة لتبويب `استكشف` أولاً).
  - كذلك اختفت أيقونة القائمة المنسدلة `heroAction` (`لوحات الحجوزات` في `booking_screen.dart:609`) لأنها مشروطة بـ `widget.embedded`.

---

## 6. تدقيق مؤشر تفاصيل المكان (`BookingVenueDetails` Audit)

- **النتيجة:** **PASS WITH MINOR RESOURCE LEAK & TEST GAP**
- **مراجعة الكود في `lib/bookings/booking_venue_details.dart` و`lib/bookings/booking_screen.dart`:**
  1. **التمرير اليدوي ← تحديث المؤشر:** يتم عبر `track()` التي تستدعي `syncScroll(updateActive: !jumping)` وتقارن `box.localToGlobal(Offset.zero).dy <= top + 180` لتحديث `effectiveSelectedNotifier.value = active`.
  2. **الضغط على التبويب ← التمرير وتحديث المؤشر:** يتم عبر `onTabTap: (i) => _venueDetailsKey.currentState?.jump(i)`، حيث تحدث `jump(int index)` قيمة `effectiveSelectedNotifier.value = index` فوراً ثم تستدعي `Scrollable.ensureVisible(c, alignment: .12, ...)`.
  3. **عدم تكرار شريط التبويبات وبقاؤه ثابتاً:** في `BookingRequestScreen` (سطر 1758) يتم بناء `BookingVenueDetails.buildTabBarWidget` أعلى `Expanded(child: ListView(...))`، ويُمرر `showTabBar: false` إلى `BookingVenueDetails` بالداخل فلا يتكرر الشريط ولا يختفي أثناء التمرير.
- **الملاحظات الفنية المسجلة:**
  1. **عدم التخلص من `_venueSelectedNotifier`:** في `_BookingRequestScreenState` (`booking_screen.dart:1076`)، يتم تعريف `final ValueNotifier<int> _venueSelectedNotifier = ValueNotifier<int>(0);`، وفي دالة `dispose()` (السطور 1261-1267) يتم التخلص من `_venueScrollController` و`_isVenueTabPinned` ولكن **لا يتم استدعاء `_venueSelectedNotifier.dispose()`**.
  2. **تسجيل مستمع التمرير مرتين:** في `BookingVenueDetailsState`، يتم تسجيل `track` على `widget.scrollController?.addListener(track)` (سطر 415) وأيضاً على `position?.addListener(track)` (سطر 433) لنفس الـ `Scrollable` الأب، مما يجعل `track()` يُستدعى مرتين في كل حدث تمرير (مع أنه يُزال من كليهما في `dispose()`).

---

## 7. التحقق من نتائج الاختبارات والفحص الساكن (Tests & Static Analysis)

لم نكتفِ بعبارة PASS؛ فيما يلي السجل الكامل للأوامر التي شُغّلت ونتائجها الفعلية وأكواد الخروج (Exit Codes)، بما في ذلك المحاولات التي فشلت أولاً وأسباب فشلها:

### 7.1 سجل تشغيل الاختبارات الآلية

| الاختبار | الأمر الفعلي | المحاولات السابقة (إن وجدت) | التشغيل النهائي (Exit Code) | المخرجات الفعلية وما يثبته الاختبار |
|---|---|---|---|---|
| `theme_switcher_test.dart` | `cd D:\Projects\aqar-unified-wt; flutter test test/theme_switcher_test.dart` | محاولة أولى شُغّلت بالخطأ من المجلد الأب `D:\Projects` فانتهت بـ `Exit Code: 1` (`Error: No pubspec.yaml file found`). | **`Exit Code: 0`**<br>`00:04 +2: All tests passed!` | يثبت أن `AppSettingsProvider` يبدأ بـ `ThemeMode.dark`، ويحفظ ويستعيد `light`/`dark` من `SharedPreferences`، ويثبت تبديل الثيم في `SettingsScreen`. *(لا يختبر شاشات التطبيق الرئيسي الأخرى بصرياً).* |
| `bottom_bar_visual_rtl_test.dart` | `cd D:\Projects\aqar-unified-wt; flutter test test/bottom_bar_visual_rtl_test.dart` | لا توجد محاولات فاشلة | **`Exit Code: 0`**<br>`00:02 +1: All tests passed!` | يثبت وجود الـ 5 أزرار في `CustomBottomBar` وترتيب إحداثياتها الهندسية X في RTL:<br>الحجوزات (`353.45`) ← الريلز (`274.91`) ← أعلن (`196.36`) ← المفضلة (`117.82`) ← الرئيسية (`39.27`). |
| `booking_pinned_tab_bar_test.dart` | `cd D:\Projects\aqar-unified-wt; flutter test test/booking_pinned_tab_bar_test.dart` | لا توجد محاولات فاشلة | **`Exit Code: 0`**<br>`00:05 +1: All tests passed!` | يختبر `BookingRequestScreen` فعلياً: يثبت بقاء شريط التبويبات عند `top = 77.0` أثناء السحب `-600px` و`-1200px` والعودة `+2000px`، ويثبت تنفيذ `jump` عند النقر على التبويبات من 1 إلى 4 ثم 0. |
| `final_ui_integration_fixes_test.dart` | `cd D:\Projects\aqar-unified-wt; flutter test test/final_ui_integration_fixes_test.dart` | - **المحاولة 1 (`Exit Code: 1`):** فشلت لأن `Directionality` لم تكن داخل `MaterialApp.home` فظهر الـ Drawer في LTR عند `dx = 304.0` بدلاً من `800.0`، ولأن `tester.element(find.byType(Scaffold))` استُدعي قبل بناء الشجرة.<br>- **المحاولة 2 (`Exit Code: 1`):** نجح اختبارا الـ Drawer والشريط السفلي، وفشل الاختبار الثالث لأن `find.text('الأسعار')` وجد عنصرين (عنوان التبويب وعنوان القسم). | **`Exit Code: 0`**<br>`00:07 +3: All tests passed!` | بعد استخدام `Directionality` داخل `home` و`find.text('الأسعار').first` نجحت الاختبارات الـ 3.<br>**ملاحظة تدقيقية:** هذا الاختبار يختبر `Scaffold` معزولاً في الاختبارين 1 و2 (وليس `HomeScreen` و`MainShell` الفعليين بسبب اعتمادهما على Firebase)، وفي الاختبار 3 يمرر `onTabTap: (i) => selectedNotifier.value = i` مباشرة دون اختبار تحديث المؤشر عبر التمرير اليدوي `tester.drag`. |

### 7.2 نتيجة الفحص الساكن (`dart analyze`)

1. **التشغيل الأول (Task `42386`) على قائمة الـ 23 ملفاً المعدلة:**
   - **الأمر:**
     ```powershell
     cd D:\Projects\aqar-unified-wt; dart analyze lib/screens/home_screen.dart lib/screens/main_shell.dart lib/screens/favorites_screen.dart lib/bookings/booking_screen.dart lib/bookings/booking_venue_details.dart lib/bookings/booking_filters.dart lib/bookings/booking_discovery_design.dart lib/widgets/navigation/custom_bottom_bar.dart lib/widgets/navigation/bottom_nav_item.dart lib/widgets/home/home_header.dart lib/widgets/home/search_section.dart lib/widgets/home/category_card.dart lib/widgets/home/categories_section.dart lib/widgets/home/why_aqar_section.dart lib/widgets/home/horizontal_properties_section.dart lib/widgets/home/property_requests/property_requests_section.dart lib/widgets/home/property_requests/property_request_home_card.dart lib/widgets/app_drawer.dart lib/widgets/property_horizontal_home_card.dart lib/widgets/property_horizontal_card.dart lib/features/property_card/property_card_social_service.dart lib/bookings/booking_browse_ui.dart lib/bookings/booking_map.dart
     ```
   - **النتيجة:** **`Exit Code: 1`** (بسبب 5 أخطاء `Undefined name 'isDark'` في `lib/screens/favorites_screen.dart` عند الأسطر `358, 393, 444, 451, 464`، بالإضافة إلى 3 تحذيرات `warning` و58 ملاحظة `info`).
2. **التشغيل الثاني (Task `42410`) بعد تعريف `isDark` في `favorites_screen.dart`:**
   - **الأمر:** `cd D:\Projects\aqar-unified-wt; dart analyze lib/screens/favorites_screen.dart`
   - **النتيجة:** **`Exit Code: 0`** (`0 errors`, `0 warnings`, `5 info` في `favorites_screen.dart`).
   - **ملاحظة:** لم تتم إعادة تشغيل `dart analyze` على كافة ملفات المشروع (`153` ملفاً معدلاً) دفعة واحدة، وإنما تم فحص الـ 23 ملفاً في التشغيلة الأولى (التي لم تُظهر أي `error` في الـ 22 ملفاً الأخرى) ثم فُحص `favorites_screen.dart` منفرداً بعد إصلاحه.

---

## 8. المخاطر والنقاط التي لم يمكن إثباتها (Risks & Unverified Items)

1. **عدم التحقق البصري على الهاتف الفعلي للتعديلات الأخيرة (`NOT VERIFIED ON DEVICE`):**
   - التزاماً بالقيود الإلزامية (منع `flutter build` أو `adb install` دون إذن صريح)، لم يتم بناء APK جديد بعد تعديلات الـ 23 ملفاً الأخيرة؛ النسخة المثبتة حالياً على الجهاز هي نسخة جلسة UAT السابقة التي سبقت هذه التعديلات.
2. **مشكلة التباين في الوضع النهاري داخل البطاقات المعدلة جزئياً:**
   - `PropertyHorizontalCard` و`PropertyRequestHomeCard` ستظهران بنصوص بيضاء شبه مختفية على خلفية بيضاء عند تفعيل الوضع النهاري.
3. **بقاء الشاشات الفرعية في التطبيق الرئيسي بالوضع الداكن الثابت:**
   - الانتقال من الصفحة الرئيسية النهارية إلى تفاصيل عقار (`PropertyDetailsScreen`) أو كل العقارات (`AllPropertiesScreen`) أو إعلاناتي (`MyPropertiesScreen`) أو الإشعارات (`NotificationsScreen`) سيعرض شاشات ذات خلفية داكنة ثابتة (`0xFF0F172A`).
4. **غياب زر الرجوع العلوي في التبويبات الفرعية لـ `BookingBottomBar`:**
   - في تبويبات `بحث` و`ريلز` و`حجوزاتي` و`حسابي` داخل الحجوزات، لا يظهر زر سهم رجوع في `AppBar`، ويعتمد الخروج للرئيسية على زر الرجوع في نظام الهاتف أو العودة لتبويب `استكشف`.
5. **عدم استدعاء `_venueSelectedNotifier.dispose()`:**
   - في `_BookingRequestScreenState.dispose()` داخل `lib/bookings/booking_screen.dart:1261`.
