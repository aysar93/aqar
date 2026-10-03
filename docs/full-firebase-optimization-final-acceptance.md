# FULL FIREBASE OPTIMIZATION — FINAL ACCEPTANCE REPORT

Project: AQAR / aqar-9f3f9. Date: 2026-10-03, Asia/Baghdad.

**الحالة: الإصلاح الخلفي والتحسينات المحلية والاختبارات والبناء نجحت. قبول Android الفعلي لم يكتمل لأن الهاتف انقطع عن ADB قبل التثبيت. لا يُعتبر هذا التقرير موافقة إصدار عام.**

## Audit coverage

تمت مراجعة 352 موضع وصول مرشح في 84 ملفًا ضمن Flutter وFunctions وخادم الريلز Cloudflare، ثم تتبع مصادر الشاشات والخدمات الفعلية. يتضمن النطاق Home، الكتالوج والبحث والفلاتر، التفاصيل والنشر والتعديل، المفضلة، المكاتب والتقييم والمتابعة والإحصاءات، الريلز والخريطة، المحادثات والإشعارات، المستخدمين والإدارة والبلاغات والحظر، Activity/Presence، والتحليلات التاريخية. المواضع غير المستدعاة لا تُحسب كتكلفة فعلية.

المراجع المحلية:

- `docs/firebase-read-optimization-baseline.md`: baseline قبل هذه التعديلات.
- `docs/firebase-current-query-inventory.txt`: inventory المصادر.
- `docs/firebase-optimization-query-check.json`: تحقق قراءة فقط من صلاحية الاستعلامات والفهارس.
- `docs/firebase-optimization-production-sanity.json`: تطابق Production Rules وثبات الفهارس وPresence Functions.
- `docs/firebase-optimization-analyze-comparison.json`: مقارنة التحليل بالملاحظات السابقة.

## OFFICE BACKEND

| Check | Result |
|---|---|
| Functions reviewed | refreshOfficePropertyMetrics / refreshOfficeFollowerMetrics / refreshOfficeReviewMetrics |
| Functions deployed | الثلاث نفسها فقط؛ ACTIVE / Gen 2 / Node 24 |
| Targeted deploy | YES؛ `--only` لهذه الدوال الثلاث باستخدام firebase.activity-deploy.json |
| Configuration | us-central1؛ Eventarc nam5؛ retry enabled؛ timeout 30s؛ maxInstances 3 |
| Rules changed | NO |
| IAM manually changed | NO |
| App Check changed | NO |
| Backfill offices | 2؛ جميع المكاتب الموجودة وقت الالتقاط، وليس عينة متخيلة من مكاتب إضافية |
| Backfill reads | 39 documents returned في apply؛ تقدير billing نحو 40 مع الحد الأدنى للاستعلام الفارغ |
| Backfill writes | 2 office documents فقط |
| Rollback snapshot | YES؛ office-counter-repair/rollback-office-summary-values.json |
| Property counters verified | PASS — Production source comparison + emulator transitions |
| Follower counters verified | PASS — Production source comparison + emulator transitions |
| Rating counters verified | PASS — Production source comparison + emulator transitions |
| Follow/unfollow maintenance | PASS — Emulator؛ لم نختلق علاقة متابعة عامة لاختبارها |
| Property transition maintenance | PASS — Emulator؛ لم نعدل عقارات حقيقية لصناعة الاختبار |
| Property view changes propertyCount | NO |
| Retry storm | NONE OBSERVED في نافذة المراقبة الناجحة؛ القراءة النهائية للسجلات محدودة بـ429 |
| Recursive trigger | ABSENT by design + tests |

تعريف العدادات: العقارات المعتمدة المرتبطة بالمكتب؛ علاقات المتابعة الفعالة، مع default القديم للحقل المفقود؛ المراجعات المنشورة، مع default القديم للحالة المفقودة؛ rating مضبوط على 1–5 كما في Model الحالي. الأرقام لا تعتمد على delta يرسله العميل.

| Function | Trigger | Relevant changes | Reads / writes per normal relevant invocation |
|---|---|---|---|
| refreshOfficePropertyMetrics | properties/{propertyId}, document written | approval/membership/office association/create/delete | 2 / 2؛ transfer ≤3 / 3 |
| refreshOfficeFollowerMetrics | office_followers/{followerId}, document written | active membership/create/delete/office association | 2 / 2؛ transfer ≤3 / 3 |
| refreshOfficeReviewMetrics | office_reviews/{reviewId}, document written | publication/rating/association/create/delete | 2 / 2؛ transfer ≤3 / 3 |

تغيير views أو الاسم أو الصورة أو رد صاحب المكتب: **0 Firestore reads / 0 writes داخل handler**. يبقى invocation واحد للـdocument-written trigger؛ لا يدعم هذا trigger تصفية الحقول قبل الاستدعاء. لم تكن الدوال القديمة منشورة في Production قبل المهمة: تكلفة الصيانة الخلفية الجديدة مضافة، مقابل إزالة scans العميل وتصحيح الأرقام؛ لا ندّعي خفض تكلفة Function كانت غير منشورة أصلًا.

Idempotency: ledger خاص مبني على SHA256 لنوع الحدث ومعرّفه؛ ledger والعدادات في transaction واحدة. تكرار الحدث: 1 ledger read / 0 writes. الدلتا بين before/after تشمل النقل والحذف ولا تتكرر عند retry. القيم canonical الداخلية منفصلة عن حقول العرض القديمة، وتحافظ على signed deltas عند تغير ترتيب الأحداث. لا تكتب الدوال إلى source collections، فلا تعيد تشغيل نفسها. حذف المكتب لا يعيد إنشاءه؛ المكتب غير النشط يستمر في صيانة عداداته لإمكان استعادته.

Backfill: dry-run ثم snapshot ثم apply paginated office-scoped؛ حدود 50 مكتبًا و5000 source record لكل query؛ pages 100. جميع صفحات المصدر تستخدم server readTime واحدًا لكل مكتب. تحديث المكتب مشروط بـupdateTime لمنع lost updates؛ أحداث قبل cutoff محسوبة ضمن snapshot، وما بعده تطبقه الدوال مرة واحدة. لا حذف ولا تعديل Property/Followers/Reviews الأصلية. dry-run وapply والتحقق الأول والتحقق النهائي أعاد كل منها 39 document؛ مجموع هذه الجولات 156 returned-document reads، منفصلة عن metadata/index probes. إعادة تحقق نهائية: 14:45:55Z، zero mismatches، zero writes.

| Masked office | Stored / source properties | Stored / source followers | Stored / source reviews | Rating |
|---|---:|---:|---:|---:|
| cbe2ad4d | 13 / 13 | 11 / 11 | 5 / 5 | 5 |
| 2cf5c939 | 0 / 0 | 4 / 4 | 1 / 1 | 5 |

ملاحظة المراقبة: الاستعلام الناجح السابق للسجلات أظهر HTTP 200 بلا errors وبدون نتائج متابعة إضافية. آخر قراءة Cloud Logging أعادت `429 RESOURCE_EXHAUSTED`؛ لم تُكرر ولم تتحول إلى تعديل IAM. هذه مشكلة إتاحة قراءة السجلات، وليست دليلًا على فشل Function أو retry storm. لا نؤكد مراقبة نهائية كاملة بعد هذه النتيجة.

## HOME

Before: أقسام العقارات محدودة أصلًا، لكن streams شخصية تُنشأ في build، وبطاقات المكتب تحمل إحصاءات فرعية، وقلوب العقارات لها listeners مستقلة.

After: نفس الأقسام والأعداد والألوان؛ streams الحساب والإشعارات والمكتب مستقرة وتُستبدل عند UID change؛ بطاقة المكتب summary فقط؛ المفضلة مشتركة. Guest لا يفتح query شخصية بلا UID.

Reads BEFORE، ESTIMATED: حتى 24 property + حتى 10 featured office + profile + N notifications + favorite lookups + scans لبطاقات المكاتب المعروضة.

Reads AFTER، ESTIMATED: نفس الـbounded section documents + profile + N notifications + matching favorite documents ضمن batches؛ **0 child scans لبطاقة المكتب**. Badge الإشعارات N ما زال مطلوبًا لمنطق readBy الحالي ولم نضع حدًا يُخفي unread قديمة.

Result: PASS للاستقرار والبطاقات؛ unread badge يبقى high-read source.

## ALL PROPERTIES

| Check | Result |
|---|---|
| Real pagination | PASS — cursor Firestore، وليس إظهار المزيد محليًا فقط |
| Page size | 20 |
| Full initial collection read | ABSENT في العرض الافتراضي؛ PRESENT في fallback البحث/بعض الفلاتر العالمية |
| Load More | PASS — next 20، مع منع الطلب المتداخل |
| Search outside loaded page | PASS by code path؛ البحث الكامل مستقل عن الصفحات المحملة |
| Filters | PASS للمسارات المحفوظة؛ category مدعوم server-side حيث يسمح الفهرس |
| Stable query | PASS — إعادة build العادية لا تعيد الاشتراك |
| Favorites N+1 | REMOVED per-card backend listeners؛ batch ≤30 IDs |

الاختبارات تثبت 20→40→60، cursors وعدم duplicates، تغير الرأس، displaced boundaries في الرأس والصفحات الأقدم، والحذف الحي. لكل صفحة محملة listener محدود؛ bridge queries لمعرفات حدود أزاحها وصول محتوى جديد مجمعة في ≤10 IDs، وليست listener لكل property. تُلغى جميعها عند dispose/refresh. الهدف هو حفظ الحذف والاعتماد والحظر أثناء التصفح، لا تحويل الكتالوج إلى نسخة stale.

Production read-only proof: 33 approved properties؛ ordered createdAt وviews كلاهما 33، فلا فقد بسبب حقول ترتيب مفقودة في الحالة الحالية. استعلامات bridge للعقارات والريلز نجحت HTTP 200 بفهرس قائم.

الحد الصريح: arbitrary Arabic substring / AND search، price sorting وfeatured/adType وبعض office filters تحتفظ بالمسار الكامل الصحيح عند غياب query مكافئة. لا ندّعي إزالة full read من البحث؛ تقليصه إلى أول 20 كان سيكسر النتائج. لا خدمة بحث خارجية أو migration.

## OFFICES

| Check | Result |
|---|---|
| Office card full scans | REMOVED |
| Summary counters | PASS — source verified |
| Historical events on card | ABSENT |
| Views recount cascade | REMOVED؛ view event لا يكتب office.updatedAt أو يعيد count |
| Default offices pagination | PASS — 20/page |
| Reads/card BEFORE | ESTIMATED: 2+P+F+R+E لمستخدم مصرح ينجح له scan؛ ordinary user قد يفشل follower query ويعرض fallback القديم الخاطئ |
| Reads/card AFTER | 0 additional documents؛ office document موجود من parent list (1 لو جُلب مستقلًا) |

Office details: header والعدادات من office document؛ owner/Admin views count scalar عند الحاجة، لا تحميل E events للعدد. Reviews تُحمّل عند التبويب وتستخدم stream مستقرة؛ لا client rating recount/write. إنشاء follow/review جديد يستخدم ID حتمي office+UID لتفادي duplicates متزامنة مع احترام السجلات القديمة. نموذج تعديل المكتب لا يعيد كتابة summary قديمة فوق تحديث الخادم.

**Remaining:** أحدث عقارات المكتب و"عرض الكل" والمراجعات التفصيلية ما زالت تستعمل المصدر الكامل المرتب محليًا، للحفاظ على newest/global order. Pagination لهذه القوائم ليست مقبولة بعد. Query office_reviews officeId+createdAt DESC ثبت أنها تحتاج composite index غير موجود. لم ننشر index خارج موافقة counters ولم نضع limit عشوائيًا يعطي "أحدث" خاطئًا. Owner detailed statistics ما زالت تحتاج P/F/R/E للتفاصيل التاريخية؛ أُزيلت من البطاقة فقط.

## REELS

| Check | Result |
|---|---|
| Pagination | PASS — 20/page |
| Stable query | PASS — feed لا يُنشأ عند كل swipe/mute rebuild |
| Related N+1 | REDUCED — distinct-target cache + in-flight deduplication؛ ليست zero reads |
| Correct blocking/deletion | PASS shared filtering/lifecycle؛ related-document TTL 30s مع revalidation عند activation |
| 10 Reels BEFORE | ESTIMATED: مصدر L≤100 + حتى 2L targets لكل إعادة validation؛ resubscription كان ممكنًا عند swipe، وليس إثبات billed 10×L |
| 10 Reels AFTER | ESTIMATED: أول 20 reel + T distinct related docs، T≤40؛ إضافات likes/saves وworker events منفصلة |

الصفحات المحملة live وتُلغى عند المغادرة. القائمة القديمة للفئات حتى 100 تُحمّل فقط عند فتح قائمة الفلاتر، حتى لا يُستبعد category خارج أول صفحة. Deep link يقرأ reel المحدد مباشرة. Cache قصير، scoped للـUID، لا يُستخدم لاتخاذ صلاحية Admin. لا تغيير Cloudflare backend؛ مسار administrative reel deletion/asset-sharing scan بقي مسجلًا كحد نادر.

## PROPERTY DETAILS

- Favorite state أصبح من shared registry؛ إزالة listener آخر مستقل للتفاصيل.
- Avatar/profile presentation cache 30s مع in-flight deduplication وتنظيف عند UID change؛ permission checks لا تستخدم هذا cache.
- Owner/office/contact/comments reads اللازمة بقيت؛ لا ندّعي إزالة كل N+1.
- Related bounded: لا توجد related-properties collection query في هذا المسار حتى نختلق تحسينًا لها.
- View cascade: REMOVED من ربط view بإعادة عد المكتب؛ property view وoffice view event الأصليان محفوظان.

## CHAT

| Check | Result |
|---|---|
| Recent bounded | YES — 50 messages |
| Older pagination | PASS — 50/window cursor |
| Realtime | PASS architecture + merge regression tests |
| Full history initial | ABSENT |

عند طلب أول older page يُثبت الحد الأدنى للرأس الحي؛ قد يُعاد تحميل الرأس 50 مرة واحدة، ثم كل نافذة أقدم 50 بدل إعادة تحميل 100 ثم150. new messages والحذف يبقيان live؛ ترتيب timestamp+ID وdedup محفوظان. Search/jump الصريح الذي يحتاج تاريخًا أوسع بقي صحيحًا وقد يقرأ تاريخًا أوسع. Receipt/draft/typing behavior وsuccessful-send Activity hook محفوظة. إرسال رسالة Production إلى شخص حقيقي لم يُستخدم كاختبار مصطنع.

## NOTIFICATIONS

- Pagination: PASS — user notifications 20/page؛ admin management 30/page.
- Full initial history: ABSENT في صفحات القوائم؛ PRESENT في unread header بالمنطق الحالي.
- Unread: PASS by retained logic؛ read/delete local overlays تمنع إعادة إظهار حالة قديمة للصفحات المحملة.
- Delete-all action وبث notification لجميع المستخدمين ما زالا يتطلبان مجموعتهما عند طلب المستخدم الصريح، وليس عند فتح الشاشة.

## MAP

Full collection read: PRESENT. Optimization: NO unsafe limit. Approved map coverage محفوظة؛ لم نُخفِ عقارات خارج أول page. Remaining migration: geospatial/viewport indexing وتصميم clustering منفصل يحتاج موافقة. Current source S، ولا ندّعي خفضه.

## ADMIN

Large lists:

- Property management: 10/page، full complete search fallback؛ 4 native summary counts بدل تنزيل كل العقارات للـheader. يُعاد summary عند membership/status change، لا عند كل views أو Load More.
- Users: 30/page؛ exact counts scalar؛ complete name/role search fallback؛ refresh واضح.
- Pending properties: 20/page؛ حذف client propertyCount increment لمنع double count بجانب Function.
- Office requests: 30/page؛ exact pending header/search مصادرهما العالمية عند الحاجة.
- Notifications management: 30/page.
- Admin chat: source conversations محفوظة للترتيب global pin/unread؛ profiles فقط للـUIDs الموجودة في المحادثات، batches≤30 + cache5min، بدل users collection كاملة.
- Property requests: مشاركة streams الثلاث بين badges/list؛ لا query إضافية للقائمة المختارة. ما زالت global lists لتحقيق counters/order الحالي.
- Reports/comments/blocked-user/subscription/moderation routes التي تحتاج مصادر عامة أو تفاصيل joins بقيت موثقة، ولم نُدخل limits تكسر الترتيب أو الصلاحيات.

Activity 30/page: PASS preserved. Presence regression: PASS tests، real-device NOT TESTED للـAPK الجديد. Activity regression: PASS tests، real-device NOT TESTED للـAPK الجديد.

## ANALYTICS

New aggregation: NO. New session trigger: NO. analytics_accounts/daily/hourly/backfill: NO. Raw shared query: PRESERVED؛ summary/unique/average/chart من نفس H، cache/in-flight reuse الحالي 15s محفوظ. Additional analytics backend writes: 0.

## COST

هذه **document-return/query budgets**، وليست فاتورة Production مقاسة. MEASURED يعني fake-SDK test أو metadata/source evidence صريح، لا عدد billed reads الفعلي. Cache المحلي وSDK multiplexing وlistener reconnects وSecurity Rules dependent reads وindex-entry billing قد تغير الفاتورة. Empty queries لها minimum billing؛ native count ليست "قراءة document واحدة" دائمًا: تكلفة index entries تُحسب منفصلة. انظر [Firestore billing](https://firebase.google.com/docs/firestore/pricing) و[aggregation queries](https://firebase.google.com/docs/firestore/query-data/aggregation-queries).

الرموز: S كل approved properties؛ O مكاتب المصدر؛ P/F/R/E مصادر مكتب واحد؛ N تاريخ إشعارات المستخدم؛ M messages؛ H جلسات الفترة؛ L مصدر الريلز القديم≤100؛ T related target documents المميزة؛ C conversations؛ U كل users؛ J users المشاركون في C؛ V favorite IDs المطلوبة للبطاقات؛ B نتائج favorite documents داخل V. `q(n)=max(1,ceil(index entries scanned/1000))` للتقدير الأساسي لعملية count، مع استثناءات query/rules وفق المصدر الرسمي.

| Scenario | BEFORE | AFTER | Evidence |
|---|---|---|---|
| Cold start / Home | ≤24 properties + ≤10 offices + profile + N + per-card favorites + office scans | نفس bounded sections/profile/N + B batched favorites؛ zero office child scans | ESTIMATED |
| All Properties | S properties initial | min(S,20)؛ source proof S=33، page contract20 | ESTIMATED Production / MEASURED unit limit |
| Load More x2 | المصدر الكامل S كان محملًا؛ rebuild قد يعيد subscription وليس billed 3S مضمونًا | مجموع min(S,60)، حتى20 جديد لكل request؛ حاليًا33 ثم end | MEASURED unit 20→40→60 / ESTIMATED actual |
| Search | S مع احتمال stream recreation لكل keystroke | S complete fallback؛ stable query بدل إعادة إنشائها عند الكتابة | ESTIMATED؛ ليس billed-read elimination |
| Property details | needed property/profile/office/favorite/comments + view cascade | same needed docs؛ shared favorite/avatar cache؛ no office recount/touch on view | ESTIMATED |
| Favorite toggle | 1 existence read +1 set/delete، Activity≤1 throttled write | نفس write/read action؛ heart state queries مجموعات≤30 بدل listener/card | MEASURED shared-registry unit / ESTIMATED billing |
| Offices | O + Σ(2+P+F+R+E) authorized scans | min(O,20)، 0 child scan/card | ESTIMATED؛ counter source MEASURED |
| Office details | office + overlapping full statistics/source queries | office summaries + requested P/R؛ no F/E full reads just for counters؛ lazy reviews | ESTIMATED؛ detail pagination pending |
| 10 Reels | L + related validation، potential resubscriptions per swipe | first20 + T≤40 distinct initial targets؛ stable source؛ interaction reads separate | ESTIMATED |
| Chat recent+2 older | 50+100+150 =300 message documents across growing-window attaches | initial50 + one head reattach50 + older50+50 =200؛ subsequent page +50 | ESTIMATED full pages؛ live new/deletion extra separate |
| Notifications | N | min(N,20) initial +20/page؛ header N unchanged | ESTIMATED |
| Map | S | S preserved | ESTIMATED، no reduction |
| Admin Activity | H shared historical query + one RTDB listener؛ active30+uncached profiles≤30 | unchanged H/shared cache + same listener/list30 | ESTIMATED، zero regression optimization |

Favorite listener proof: 20 mounted hearts => **1 bounded backend query** in test، not20. 60 distinct requested IDs => typically2 batches، plus loaded catalog-page listeners. B document reads can remain B when all requested properties are favorites; the gain is not an invented 20× billing reduction. Account switch/logout cancels/reset user-specific state.

Overall improvement formula: catalog cold source `S → min(S,20)`؛ office card incremental reads `2+P+F+R+E →0`؛ notifications initial `N→min(N,20)`؛ feed `L→20` with related-target dedup؛ older chat windows avoid repeated growth. **No overall percentage invented.** Backend adds bounded office transition 2 reads/2 writes + invocation/ledger storage; view-only invocation 0 reads/0 writes. Transaction contention/retries can add reads. Ledger retention requires a future bounded retention policy; none implemented/deleted now.

## QUALITY

| Check | Result |
|---|---|
| flutter analyze | PASS change gate: 0 errors / 0 new diagnostics؛ full command exit1 due existing warnings/info |
| New errors | 0 |
| Pre-existing lints | 169 remain؛ baseline171، لم تُحذف tests لإخفائها |
| Flutter tests | PASS — 102 full-suite cases؛ optimization targeted10 rerun PASS |
| Emulator tests | PASS — 11 Python rules +15 Node integration =26 passed؛1 pre-existing rollback-bridge SKIP |
| APK build | PASS — واحد فقط، assembleDebug227.9s |
| Installed as update | NO — device disconnected before installation |
| App data preserved | No uninstall/clear/reset performed؛ update preservation acceptance NOT TESTED |
| Android acceptance | PENDING، لا يُختلق PASS |
| iOS shared implementation | PASS code review؛ platform-neutral services/queries، no Android-only optimization |
| iOS physical acceptance | PENDING |

APK: `build/app/outputs/flutter-apk/app-debug.apk`، 249690541 bytes؛ SHA256 `CEB9F5C90546829E0263379CD5D7CFF23C5C447D8EDDF588F761082170DB4BA8`.

Manifest verified: com.andalus.aqar / 1.0.4 / build19؛ package/Firebase/signing/version/dependencies لم تتغير. هذه نسخة debug اختبار وليست store release. الهاتف CPH2365 كان authorized في بداية الفحص ثم اختفى من ADB قبل installation؛ لم نحاول uninstall أو تغيير بياناته. screenshots/read-budget Production device flows لم تُنجز للـAPK الجديد.

## Files changed in THIS task

لا تشمل القائمة تغييرات Auth/Presence/Activity السابقة الموجودة أصلًا في working tree.

| Files | Change |
|---|---|
| functions/index.js; functions/office_counters.js; functions/office_counters.integration.test.js | exports الثلاث، atomic incremental maintenance، integration tests |
| lib/core/data/paged_query.dart | bounded live cursor windows/refresh/dedup/disposal/error/order |
| lib/core/data/document_read_cache.dart | short actor-scoped cache + concurrent read dedup |
| lib/core/data/shared_stream.dart | route-owned replay/shared upstream cancellation |
| lib/services/favorites_service.dart | shared bounded favorite IDs registry؛ serialized optimistic toggles |
| lib/screens/all_properties_screen.dart | real20-page query، stable complete-search fallback |
| lib/screens/home_screen.dart; lib/screens/favorites_screen.dart | stable actor streams/account cleanup |
| lib/screens/property_details.dart | shared favorite state / avatar cache |
| lib/office/widgets/office_card.dart | summary-only card، same visual layout |
| lib/office/screens/offices_screen.dart; lib/office/screens/office_profile_screen.dart | offices20/page؛ summaries/lazy stable detailed streams |
| lib/office/services/office_service.dart | presentation edits do not overwrite server summaries |
| lib/office/services/office_follower_service.dart; office_review_service.dart | deterministic new relation IDs؛ remove client summary recount |
| lib/office/services/office_statistics_service.dart | view does not touch office document |
| lib/reels/services/reel_service.dart; lib/reels/screens/reels_screen.dart |20-page stable feed/target cache/activation validation/like-save streams |
| lib/chat/services/chat_service.dart; lib/chat/conversation_screen.dart; lib/chat/utils/message_windows.dart | live50 head+cursor history/merge |
| lib/screens/notifications_screen.dart; lib/screens/pending_properties.dart | bounded lists؛ remove double office increment |
| lib/screens/admin/property_management_screen.dart; users_management_screen.dart |10/30 pages + scalar summaries/complete search |
| lib/screens/admin/office_requests_management_screen.dart; notifications_management_screen.dart |30-page management lists |
| lib/screens/admin/admin_chat_list_screen.dart | relevant profile batch loading instead of all users |
| lib/screens/admin/property_requests/admin_property_requests_screen.dart | stable shared status streams |
| test/firebase_read_optimization_test.dart |10 budget/pagination/cache/actor/error/realtime merge regression tests |
| docs/firebase-*; docs/office-counter-*; docs/full-firebase-optimization-final-acceptance.md | baseline، bounded diagnostic/backfill scripts، immutable rollback snapshot، evidence and report |

## PRODUCTION

Office Functions changed: YES — exact three exports above. Production Rules changed: NO. Production IAM manual change: NO. Production App Check change: NO. Production data modified: **YES — ONLY approved two office summary baseline backfill documents**؛ subsequent server event maintenance is intended. No unrelated production data changed: YES. Analytics backfill: NO. Legacy Presence migration: NO. No Properties/Followers/Reviews source rewrites/deletion.

Final read-only Rules SHA proof: Firestore `0b98421e1d46c7c69b50fbf351549f6026537f22bac71210a6269d953fd0e916`؛ RTDB canonical `d0a6d609db39ac06fa4f56485548c9a03a6b99544a74938b804303d0d5a37a47`. All13 indexes READY. Presence Functions retain previous updateTime؛ no redeploy. Protected-file hash comparison changed only the explicitly approved functions/index.js among protected files.

### Remaining backend plan — NOT executed

No further backend deploy is required to run the built APK on its retained fallback paths. To complete newest-ordered **office-detail** pagination, separately review/add only required composite indexes:

1. properties: officeId ASC + status ASC + createdAt DESC for public office properties.
2. properties: officeId ASC + createdAt DESC if owner list must include all statuses.
3. office_reviews: officeId ASC + createdAt DESC.

Exact queries/coverage of missing ordered fields must be checked before changing clients. Wait for READY before activating cursor queries. No Rules/IAM/schema/source rewrite required for these candidates. Risk: omitting missing createdAt records or changing complete sort order. Rollback: retain/revert to current correct query path; remove no existing index; no source data rollback. Not deployed because current authorization is specifically counter repair, not an unrelated index rollout.

Counter incident rollback: stop only unsafe affected maintainer(s)، preserve source records، conditionally restore approved office summary fields from logical snapshot only after checking concurrent updates، and use previous correct client query paths if summaries cannot be trusted. Do not rollback Presence Functions/Rules. No rollback performed; no unsafe counter incident observed.

## FINAL

Major read sources fixed: office cards/featured cards، normal property catalog20/page، per-card favorite listeners، stable reel feed + bounded prefetch/cache، notifications lists، key admin lists/profile joins، chat older-window rereads، client office recounts.

Remaining high-read sources: complete substring/global-sort search fallback؛ office-detail ordered property/review lists pending indexes؛ detailed owner statistics P/F/R/E؛ unread notification header N؛ map S؛ exact global admin badges/request/report/comment/subscription lists؛ explicit broadcast/delete-all/history search； administrative Cloudflare asset-sharing cleanup scan. Historical H is intentionally preserved.

UI changed: NO redesign؛ only small loading/refresh/load-more behavior and loaded-count labels necessary for true pagination. Features removed: NO. Presence/Activity preserved: YES shared implementation/tests؛ New Connections only، unique UID count، event-driven activity10-minute throttle، no heartbeat/polling introduced. Physical regression verification of THIS APK remains pending.

**READY FOR FINAL RELEASE PREPARATION: NO.**

Remaining blockers: reconnect authorized Android device، install the existing built APK with `adb install -r`، verify retained session/data and A–M core routes including Presence foreground/background and Activity؛ complete a short bounded monitoring window when Logging API quota permits؛ review the office-detail index/pagination follow-up and retained high-read limitations. iOS physical acceptance is PENDING. No second build is needed merely to install the APK already produced.

No Commit / Push / Google Play / App Store / TestFlight / public rollout performed.
