# FINAL FIREBASE OPTIMIZATION CLOSURE REPORT

2026-10-03 — AQAR / aqar-9f3f9. This closes safe remaining gaps against `full-firebase-optimization-final-acceptance.md`; it does not repeat or redesign previous PASS implementations. Results below distinguish source/test verification, bounded read-only Production evidence, and actual installed-APK smoke tests. There is no invented billing percentage or physical-device PASS for unperformed cases.

## SEARCH

Full read before: non-paged text/filter/price-sort fallback could fetch S approved properties (or all office candidates), then filter/sort locally.

Full read after: text search still fetches the COMPLETE matching structured candidate set Sκ, not the first loaded page. `status=approved`, officeId, propertyType, adType and isFeatured predicates now narrow this set server-side. Text changes reuse the same candidate subscription until structured predicates change. Default highest/lowest-price catalog is now 20 documents/page; default office catalog is 20/page.

Search completeness: **PASS** — exact existing Arabic normalization, multi-field AND substring behavior and document-ID matching retained. Flutter test finds a record beyond page one; the installed APK also found property number 53 outside the initial 20 results. Its additional matches are valid matches in other searchable fields, not ID-only search.

Remaining limitation: the current Standard Firestore database/schema and Dart query path have no equivalent indexed arbitrary substring search across 27 inputs with Arabic normalization. Without structured filters this still reads S; with filters it reads Sκ ≤ S. A future normalized token/n-gram/search-index contract needs its own design, index/data compatibility review, and approved initialization. No external search service was added.

**Additional unclosed optimization:** `PropertyCatalogQuery.bounded` deliberately retains a complete candidate fallback for featured/ad-type filters, category combined with price/views sort, and office combined with category or price/views sort. These are not text-search impossibilities: additional composite query/index coverage could paginate them correctly. They remain an avoidable, bounded-by-matching-set but unbounded-document-count source. Do not claim all structured combinations are paginated or that this gap has been closed.

## MAP

Full read before: S approved properties.

Full read after: S approved properties, unchanged. Read-only snapshot had 33; the later installed map displayed 34 as live data changed. These are point-in-time observations, not a constant database size.

Correct map completeness: **PASS** for retained source/filters and installed map launch/cluster rendering. No arbitrary limit hides properties. Current UI supports complete Anbar coverage, global/visible counts and city filters; location handling includes legacy aliases/formats.

Migration required: **YES for a consistently bounded geospatial design**, not for running this APK. Snapshot: 33 numeric root latitude/longitude records, zero geohash, zero canonical nested GeoPoint records. City-only equality does not implement complete viewport intersection or current global-count behavior across legacy formats. Canonical indexed geospatial fields, viewport query/dedup and count semantics need a separate approved design. **DEFERRED ARCHITECTURAL OPTIMIZATION**; no migration/backfill performed.

## DETAIL SCREENS

| Screen/source | Before | Fixed in this round | Remaining exact-data requirement |
|---|---|---|---|
| Public office property preview | all Pₐ approved office properties | ordered query limit8 | none for preview |
| Public office full property page | Pₐ |20/page, real cursor | text/unsupported sort-filter fallback remains complete |
| Owner office properties | P all statuses |20/page, server status filter; four cached scalar count queries | owner text search still P; totals count whole office, not loaded page |
| Public office reviews | R |20 raw records/page; published filtering preserves missing-status legacy records | page may contain fewer than20 visible reviews; Load More remains available |
| Owner office followers | F |20 raw records/page + one office summary document; cached avatar reads | by-name search still F; missing isActive is retained as legacy-active |
| Owner review management | R |stable cached source, no subscription from plain rebuild | all R for exact whole-office histogram/average including hidden/legacy normalized ratings and complete comment/name search; public summary has different semantics |
| Owner detailed statistics | office document + P + F + R + E |reuse office snapshot; followers/rating totals from trusted summary; stable source | P + E for all statuses, cumulative views/favorites/shares, legacy events and distinct/time comparisons |
| Publisher properties | all Ppublisher statuses |server approved predicate; stable source | Papproved for exact live global view sum, featured count and complete text search |
| Property comments |two application query consumers C |one shared upstream C for count/body; stable per-comment reply streams | C and replies Rᶜ for exact visibility/block-aware counts; body preserves legacy createdAt-order existence semantics |
| Property details settings/property |duplicate get/listen and property sources |removed extra settings get; shared stable live property stream | necessary live property/settings, related-document cache retained |
| Admin office details |recreated document source; legacy singular count precedence |stable source; canonical propertiesCount/followersCount precedence |one office document |

Historical Activity H is deliberately unchanged: one shared raw sessions query/cache calculates unique accounts/chart/averages. No analytics aggregation, session trigger or analytics backfill.

Other retained high-read sources from the full inventory: shared market-statistics S for exact medians/outliers/normalized-region totals (2-minute cache); notification-header N for exact legacy readBy/missing-read-flag behavior; global Admin unread/status badges and some report/comment/request/subscription joins; complete management text search; explicit broadcast/delete-all/asset-reference cleanup workflows. Native aggregation cannot be presented as a live scalar listener or COUNT DISTINCT replacement. Small metadata option collections remain complete intentionally. These are not newly introduced reads. They require individual read-state/summary/query-contract work; indiscriminate limits would change results or workflow coverage.

## OFFICE PAGINATION

Exact necessary indexes created using the official Firestore Admin **create-one-index REST endpoint** (each request creates only its listed composite; no general CLI index deploy/delete):

| Collection scope | Ordered fields | Reason | State |
|---|---|---|---|
| properties / COLLECTION |status ASC, officeId ASC, createdAt DESC |approved office preview/page and status-filtered owner pages |READY |
| properties / COLLECTION |officeId ASC, createdAt DESC |owner list including all statuses |READY |
| office_reviews / COLLECTION |officeId ASC, createdAt DESC |public review cursor pages |READY |
| properties / COLLECTION |status ASC, price ASC |lowest-price catalog20/page |READY |
| properties / COLLECTION |status ASC, price DESC |highest-price catalog20/page |READY |
| office_followers / COLLECTION |officeId ASC, createdAt DESC |owner follower cursor pages |READY |

Exact definitions/reasons were shown before creation. All13 pre-existing Production indexes preserved; total19, all required READY. Local `firestore.indexes.json` also includes three already-deployed definitions previously absent locally (office requests, notifications, banners), preventing a future accidental deletion proposal; those three were NOT newly deployed. Implicit document-name tie fields are server-provided.

Queries: properties where officeId [and approved/status IN where applicable], orderBy createdAt DESC, limit20, startAfterDocument; reviews/followers where officeId, same ordering/cursor. Existing rows checked for ordered-field presence before activation. Do not assume future malformed/missing-createdAt rows can participate in an ordered query: valid writers must preserve the existing timestamp contract.

Pagination first/next page: **PASS** automated + Firestore Emulator; real Production cursor queries succeeded. Office currently13 properties,5 reviews,11 raw followers, so a non-empty second office page is **EMULATOR VERIFIED**, not a fabricated Production device result. Real price pages returned20+13 in both directions with complete coverage. Emulator uses58 approved properties,60 owner properties,45 reviews and45 followers, tied timestamps/prices, hidden/inactive first pages and legacy missing status/isActive. Duplicates: **NONE**. Missing: **NONE** in tested valid-schema datasets. Installed office page displayed13; owner scalar counts13/13/0/1; follower page11.

## COST

All formulas below are **ESTIMATED source/returned-document budgets** unless explicitly MEASURED. S = approved catalog; Sκ = structured matching candidates; P/Pₐ = all/approved office properties; F/R/E = office followers/reviews/events; C = comments; Rᶜ = replies for mounted comments; N = unread-header candidate history; H = sessions in selected period; T = distinct uncached related targets; B = matching favorite records in requested-ID batches. For an aggregate q(I)=max(1,ceil(I/1000)) billed reads for eligible index entries scanned; four count queries are not a free or universally one-read operation. Firestore cache hits, SDK target multiplexing, Rules dependent reads, index-entry charging, live changes and transaction retries can change billed totals. No bill-level metric was collected.

| Scenario | Last accepted implementation → this closure | Evidence |
|---|---|---|
| Cold start/Home |≤24 property section results + featured offices≤10 + N/header/profile/config/favorites → unchanged |ESTIMATED; installed Home PASS |
| All Properties |default20 →20; price fallback S →20 first +20/page |MEASURED Production price query20+13; installed default20 |
| Load More x2 |default up to60 →same; price formerly S →up to60 |ESTIMATED; actual device Next Page works |
| Search/filter |S or office P →Sκ when structured filters narrow candidates; unfiltered text S →S |ESTIMATED; outside-first-page device search PASS |
| Property details |duplicate C consumers →one shared C; extra settings get removed; stable shared property/replies |ESTIMATED application sources; do not infer doubled billed reads where SDK already multiplexed identical targets |
| Favorite |shared≤30-ID query batches, B returned records →unchanged; optimistic toggle/activity retained |automated; stored hearts/session retained on device |
| Offices |20 office docs/page,0 child scans/card →unchanged |device shows13/11/5 and0/4/5; source counters verified read-only |
| Office details |preview Pₐ→min(Pₐ,8); full property/review/follower list Pₐ/R/F→min(n,20)+20/page |ESTIMATED; Production counts13/5/11 below20 |
| Owner properties |P→min(P,20)+four q(I) aggregates; views do not refresh counts |ESTIMATED; current small P=13 adds aggregate charges, not a claimed universal saving |
| Owner detailed statistics |office +P+F+R+E→office +P+E, office snapshot reused |ESTIMATED |
|10 Reels |20 feed page +T distinct validation targets/cache→unchanged |ESTIMATED; installed feed opens |
| Chat |live50 head +older50/page; avoids expanding-history reattach →unchanged |ESTIMATED; original300→prior200 for initial+two older full pages, retained; installed conversation opens |
| Notifications |20 initial +20/page, header N remains →unchanged |ESTIMATED; installed list opens |
| Map |S→S |MEASURED snapshot33; later device34 live count; no claimed reduction |
| Admin Activity |H shared/cache + active30/profile batches +one necessary RTDB listener→unchanged |ESTIMATED; installed Analytics/active refresh PASS |

Additional document writes caused by this closure: **0**. Additional RTDB operations/Function invocations caused by UI read optimization: **0**. Normal user navigation/lifecycle still executes previously approved business writes/session/activity/Presence and notification read-state behavior. Six new indexes add storage and index-maintenance cost to relevant existing writes; not zero-cost metadata. No percentage saving invented.

## REGRESSION

| Feature | Result | Scope |
|---|---|---|
|Home |PASS |automated/source + installed launch |
|Properties |PASS |20/page, cursor/dedup/order; device Load More |
|Search |PASS |complete semantics + outside-first-page device result |
|Favorites |PASS |shared/account-switch/toggle tests; device hearts and prior favorites retained; no artificial repeated Production toggles |
|Offices |PASS |summary correctness read-only; owner/public device pages; pagination automated |
|Reels |PASS |bounded/stable source, block/delete tests; device feed opens; physical full10-reel traversal not claimed |
|Chat |PASS |recent/older/new-message merge tests; existing device conversation opens; no unsolicited message sent |
|Notifications |PASS |pagination/unread tests and device list |
|Map |PASS |correct retained complete query/filters, device cluster rendering; full-read optimization intentionally deferred |
|Admin |PASS |source/tests; installed main/Analytics; no destructive moderation test |
|Presence |PASS |protected source unchanged; regression tests; installed dashboard1 equals read-only new-presence UID1 |
|Activity |PASS |protected source10-minute throttle unchanged; tests; installed active list/manual refresh and recent lastSeen |

Device evidence: foreground UID1/connections2; background UID1/connections1; resumed UID1/connections2. This proves own connection cleanup/recreation without erasing the remaining connection or counting connections as users. It does not identify the owner/device of the other existing connection. lastSeen stayed at18:55:29Z across18:55–19:04 activity inside throttle; android/isGuest=false. Legacy online is not counted. No heartbeat/polling introduced.

## QUALITY

flutter analyze: **PASS change gate** —0 errors,0 new issues;165 pre-existing warnings/info versus previous169. Full command exits1 for existing notices; not a claimed clean analyzer. Final Admin detail scoped analyzer likewise only pre-existing notices. No tests deleted or golden expectations changed in this closure.

Flutter tests: **132 PASS** full suite, final confirmation log included. Previous report102; this closure directly adds8 focused Flutter cases plus richer test-double query support; do not attribute all30 difference to this round alone.

Emulator tests: **32 PASS** (11 Python Rules +21 Node integration), **1 old skipped**,0 failed. Previous26; six real Firestore cursor/legacy/ownership-baseline cases added. All previous security tests retained. Demo project/local loopback guarded fixtures only, no Production fixtures or mutations.

Important existing **SECURITY FOLLOW-UP**: approved baseline has two office_followers matches; the earlier unconditional read allowance wins by OR. Ordinary/public follower reading is therefore currently allowed, contrary to a prior report premise. A new diagnostic assertion expecting denial exposed this and was corrected to document the actual baseline; no existing test was removed and no Rule was changed. This is independent of Presence/admin/activity ownership, whose existing security tests PASS. Do not claim follower read privacy is enforced. Separate Rules review/approval required if that legacy public contract is unintended.

## ANDROID

APK: **PASS** —single debug build,260.6s, `build/app/outputs/flutter-apk/app-debug.apk`; SHA256 e59d818c0b90b1074b6663ce93410a9dff7368128651c4f91e43ec75dc93256c. Debug kernel verified new query/search/office/reply implementation markers. Version1.0.4+19/package com.andalus.aqar/signing/dependencies unchanged.

Installed as UPDATE: **YES**, `adb install -r` Success, authorized CPH2365 reconnected before acceptance. Data preserved: **YES**, unchanged package UID/firstInstallTime, updated lastUpdateTime, authenticated session/favorites/office credentials retained. No uninstall/clear data/cache/reset. Normal in-app personal/office mode navigation was exercised and office mode restored.

Real-device acceptance: **PASS smoke** —launch/Home, catalog first/next, outside-page search, category filtering, details, favorites display, offices/cards/public and owner details/followers, reels feed, existing chat, notifications, map, Admin, Online Now, Last Activity/manual refresh, background/foreground. Exhaustive physical toggle/new-message/reel10 and populated office second-page cases are not claimed; automated/Emulator coverage is specified above. No crash/permission/index error matched the bounded current-process log check. No screenshots with personal data are embedded in this report.

iOS shared-code review: **PASS** —query/services remain platform-neutral, no Android-only identity/provider filter. iOS physical acceptance: **PENDING**.

## PRODUCTION

Rules changed: **NO**. IAM changed: **NO**. App Check changed: **NO**. Production data migration/backfill/manual document modifications: **NO**. Office counter Functions preserved: **YES**; all five existing Functions retain updateTime/stateACTIVE. Property View does not trigger office property recount. Read-only counter comparison matches both existing offices:13/11/5/rating5 and0/4/1/rating5.

Index-only Production deployment: **six exact CREATE operations listed above**,19 READY with13 originals preserved. No unrelated deployment or deletion. Final read-only Rules hashes remain Firestore0b98421e1d46c7c69b50fbf351549f6026537f22bac71210a6269d953fd0e916 and RTDBd0a6d609db39ac06fa4f56485548c9a03a6b99544a74938b804303d0d5a37a47. Protected-file verification13/13 unchanged for this round, including Presence/Activity/Analytics/Office Functions/Rules/package identity. Bounded Functions monitoring has no observed error storm; it is a sampled window, not a perpetual guarantee.

## FILES CHANGED IN THIS CLOSURE

New: lib/core/data/property_catalog_query.dart; property_text_search.dart; lib/office/services/office_detail_queries.dart; test/firebase_optimization_closure_test.dart; test/firestore_query_pagination.integration.cjs; docs/firebase-closure diagnostic/evidence files; this report.

Modified: lib/screens/all_properties_screen.dart; publisher_properties_screen.dart; property_details.dart; lib/office/screens/office_profile_screen.dart; properties/office_properties_screen.dart; followers/office_followers_screen.dart; reviews/office_reviews_screen.dart; statistics/office_statistics_screen.dart; lib/office/services/office_statistics_service.dart; lib/screens/admin/office_details_admin_screen.dart; test/firebase_read_optimization_test.dart; firestore.indexes.json. Existing unrelated working-tree changes are preserved, not attributed to this closure.

Evidence: docs/firebase-closure/production-queries.json, production-sanity.json, index-plan.json/index-state.json, follower-schema.json, protected-verification.json, analyze-comparison-final.json, emulator-tests-acceptance.log, flutter-tests-final-confirmed.log, apk-acceptance.json, device-presence-foreground/background/resumed.json and installed-device XML captures. Raw private UI captures are local evidence, not public-release artifacts.

## FINAL

Major avoidable full reads remaining: **YES** —unsupported non-text compound filter/sort catalog paths and complete office owner/publisher search fallback. The non-text combinations can be addressed with additional explicit indexed pagination coverage; this round did not close that coverage. Owner searches retain complete semantics, not first-page-only search. Do not equate narrower predicates with a hard result limit.

Architectural optimizations intentionally deferred: Arabic substring index/schema, complete geospatial viewport/count contract, exact global market/admin/read-state summaries, owner statistics/distinct event totals, review histogram/legacy semantics and comment/reply visible counts. Historical sessions raw shared query deliberately preserved. UI branding/features preserved; only necessary loading/refresh/load-more states added.

Presence/Activity preserved: **YES**. Office counters preserved and correct: **YES**, read-only source and installed UI verified.

**READY FOR FINAL RELEASE PREPARATION: NO for the requested complete optimization-closure gate.** Actual remaining optimization blocker: unsupported non-text compound filter/sort combinations still take the full matching-set path. There is no current index-readiness, build, Rules, IAM, Office-counter or Android-install blocker. Architectural deferrals and iOS physical PENDING are recorded separately; they are not fabricated new Android failures. The existing follower public-read contract also needs a separate security disposition before claiming follower privacy, without unauthorized Rules changes here.

STOP. No Commit/Push/Play/App Store/TestFlight/public release; no further deploy or build performed after this report.
