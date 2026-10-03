# FINAL PRESENCE & ACTIVITY FIX ACCEPTANCE REPORT

Date: 2026-10-03. Project: aqar-9f3f9. Android: OPPO CPH2365, Android 13.

Root cause addressed: **YES — corrected shared client implementation**. Public deployment remains unauthorized and has not happened. Old public clients still require an Android/iOS app update; their legacy online flags are not live connections.

## Implementation and files changed in this task

Previous uncommitted changes were preserved. These are this task's changes, not all changes visible in Git:

| File | Change |
|---|---|
| `lib/analytics/services/app_activity_service.dart` | Central `recordSuccessfulAction`: captures authenticated actor UID before the operation, records only after success, catches activity errors without changing action result, guards UID switching. Resets first-meaningful-action confirmation on identity transitions. |
| `lib/analytics/services/visit_tracking_service.dart` | First-action `ensureDocument` merge can bypass stale lifecycle throttle without a read. Subsequent actions retain 10-minute throttle and per-UID in-flight deduplication. Only successful acknowledgments populate local throttle. A previous UID's session ID is not attached to another UID's activity. |
| `lib/screens/add_property/add_property_screen.dart` | Successful property document creation records activity for the original author, before unrelated follow-up notifications. |
| `lib/screens/edit_property/services/edit_property_service.dart` | Successful current property edit records activity; actor captured before uploads. |
| `lib/screens/edit_property_screen.dart` | Successful legacy property edit path also records activity. |
| `lib/chat/services/chat_service.dart` | Successful message batch commit records activity for authenticated sender, including admin sender's actual UID. Notification failure does not undo the successful-message hook. |
| `lib/services/favorites_service.dart` | Successful favorite add/remove records activity; original UID also remains fixed for the favorite operation. No new reads. |
| `lib/screens/property_details.dart` | Independent favorite path in property details also records successful add/remove. |
| `lib/analytics/screens/activity_users_screen.dart` | Explicit refresh button, pull-to-refresh retained, “آخر نشاط مسجل” wording and server-adjusted loaded-as-of label. Refresh clears the cursor and reloads the first page; no timer or collection listener. |
| `test/analytics/activity_tracking_test.dart` | Success/failure hooks, missing-document repair despite cached lifecycle timestamp, concurrent deduplication, throttle boundary, identity changes, unauthenticated/anonymous rejection, process/device-local state and server timestamps. |
| `test/analytics/presence_lifecycle_test.dart` | Two independent app instances with one UID keep separate connections and remove only their own. Existing reconnect, authorization, failure and cleanup tests retained. |
| `test/analytics/analytics_ui_test.dart` | Explicit refresh reloads latest timestamp and first-page cursor; pagination deduplicates. Existing loading/error and dashboard/card checks retained. |
| `test/goldens/activity_users.png` | Reviewed RTL snapshot updated for refresh button and loaded-as-of text. |

Read-only evidence helpers, logs and this report are under `docs/production-acceptance-2026-10-03/` and `docs/`. Neither `PresenceService` nor `AnalyticsService` was changed in this task. No queries, rules, indexes, Functions, dependencies, Firebase identity, signing or version settings were changed.

## Presence and activity acceptance

PASS in this table refers to code plus automated tests unless a real-device result is explicitly named.

| Check | Result |
|---|---|
| Presence independent from Analytics | YES — presence connects before Firestore session/activity acknowledgments; session rejection does not prevent connection. |
| Auth UID tracking | PASS — one continuous auth subscription, serialized reconciliation. |
| Login after startup | PASS — initially unauthenticated app reconciles after authentication. |
| Account switch | PASS — cleanup precedes new tracking; successful action cannot be attributed to a replacement UID. |
| Logout cleanup | PASS — cleanup uses still-authenticated identity before sign-out. Real-device logout was not performed, preserving the admin session. |
| Foreground | PASS — shared lifecycle and Android device. |
| Background cleanup | PASS — shared lifecycle and Android device. |
| Reconnect | PASS — automated physical-connection rotation and server onDisconnect coverage. Phone foreground reconnect also passed; deliberate internet interruption was not performed. |
| Multi-device architecture | PASS — SDK doubles and real RTDB emulator onDisconnect tests; two physical production devices PENDING. |
| Online unique UID counting | PASS — multiple connections count as one UID; disconnecting one leaves the other online. |
| Legacy online included in count | NO |
| Property publish updates Activity | PASS — actual success call site reviewed; central success-hook tests passed. No fake public property submitted. |
| Property edit updates Activity | PASS — both actual edit call sites reviewed; success-hook tests passed. No real public property altered for testing. |
| Chat send updates Activity | PASS — actual successful batch hook reviewed; success-hook tests passed. No test message sent to another person. |
| Favorite updates Activity | PASS — both paths covered; real Android add/remove acceptance passed and original state restored. |
| Missing Activity document creation | PASS — first meaningful action forces one merge even with cached lifecycle throttle; zero reads. Automated plus emulator creation coverage; production documents were not deleted to simulate absence. |
| 10-minute throttle | PASS — automated boundary/concurrency cases and actual device events inside/after the interval. |
| Heartbeat | ABSENT — no application heartbeat or periodic activity writes. |
| Polling | ABSENT |
| Activity Dashboard refresh | PASS — real explicit refresh, new loaded-as-of time and new activity displayed. |
| Activity pagination | PASS — 30-result filtered cursor query unchanged; actual second page loaded; duplicate IDs covered by widget test. |
| Google provider path | PASS — shared UID tests on Android/iOS; fresh real-provider login PENDING. |
| Apple provider path | PASS — shared UID tests; real Apple login/device PENDING. |
| Facebook provider path | PASS — shared UID tests; real Facebook login PENDING. |
| Phone provider path | PASS — shared UID tests; fresh real-provider login PENDING. |
| Email/password path | PASS — shared UID tests; fresh real-provider login PENDING. |
| Android shared implementation | PASS |
| iOS shared implementation | PASS — no Android-only tracking guard; physical iPhone acceptance PENDING. |

Activity uses server timestamp transforms only. Local monotonic time controls write frequency, not stored timestamps. Concurrent requests on a device share the pending write; separate devices do not share a local lock. Server commit timestamps prevent an older client-clock timestamp overwriting a newer timestamp.

First meaningful action after a process/identity activation can add one confirmation write even if startup already wrote activity. This is intentional to repair the missing-document/cache case without reading Firebase. After a successful confirmation, ordinary actions are throttled. Deleting an activity document externally later within that interval cannot be detected without another read; the next eligible event or new identity activation recreates it. No automatic retry loop was added: failed tracking is best-effort and retried only on a later natural event.

## Tests, build and installed APK

| Check | Result |
|---|---|
| flutter analyze | PASS for strict tracking/UI/service/test scope: no issues. Full-project standard command returned 1 for lint findings, with zero compiler errors. It reported 19 warnings and 152 information findings; the two new flow-control information findings were then fixed and the scope rechecked clean. Existing unrelated lint cleanup was not performed. |
| Flutter tests | PASS — 65 regression tests, including 42 analytics/tracking/UI tests. |
| Security emulator tests | PASS — 11 Firestore tests and 5 RTDB/Functions integration tests; 1 rollback-bridge test skipped because that optional configuration is not deployed. |
| APK Build | PASS — exactly one `flutter build apk --debug`; Gradle 192.6s. |
| Installed as update | YES — `adb install -r`, Success. |
| App data preserved | YES — original firstInstallTime retained, existing authenticated admin UID/profile retained; no uninstall/reset/clear operation. |

APK: `D:/Projects/aqar/build/app/outputs/flutter-apk/app-debug.apk`

Version: **1.0.4+19**, unchanged test build. Size: 249,690,541 bytes.

SHA-256: `3eadf8aa98697013d7797bc11eaaa9c9b1d1c7c32cf753cb32c52a0f5d3b8c58`.

The installed `base.apk` has the same SHA-256, confirming this is the newly built installed binary, not Hot Restart. First installation remained 2026-10-02 18:23:44 Baghdad; update time 2026-10-03 13:19:26 Baghdad.

## Real Android/production evidence

Masked test UID: `a25691df`. Times below are Baghdad UTC+3.

| Observation | Own New connections | Global New online UIDs | lastSeen |
|---|---:|---:|---|
| Before build | 1 | 1 | 12:03:28 |
| Installed authenticated startup | 1 | 1 | 13:20:44 |
| First successful favorite action | 1 | 1 | 13:22:14 |
| Immediate favorite restore, inside throttle | 1 | 1 | 13:22:14 unchanged |
| Background | 0 | 0 | 13:22:14 unchanged |
| Foreground | 1 | 1 | 13:22:14 unchanged |
| First meaningful action after throttle | 1 | 1 | 13:33:32 |
| Final observation | 1 | 1 | 13:33:32 |

| Check | Result |
|---|---|
| Real-device New Presence | PASS |
| Real-device background cleanup | PASS |
| Real-device foreground reconnect | PASS |
| Real-device Activity | PASS — favorite add/remove, first confirmation, inside-throttle dedup and later eligible activity. |
| Dashboard Online matches RTDB | PASS — dashboard 1, production New Presence unique UIDs 1. |

The final activity list displayed this account's new recorded timestamp (“منذ 1 دقيقة”, then “منذ 2 دقيقة” after refresh), not its previous hour-old value. Refresh and pagination were checked without a full Firestore collection scan. Guest records are excluded by the existing `isGuest == false` server query. No provider or platform filter was added.

163 legacy UID nodes remained; they were not deleted, converted, or added to the online count. New client coverage in the public population will grow only after an authorized public Android/iOS update.

## Firebase cost

These are **tracking operations**, excluding existing property/chat/favorite/profile/business operations and dashboard reads. Reads = client Firestore document reads. This change adds zero activity-throttle reads, no aggregation writes/functions, and zero RTDB operations per meaningful action.

| Event | Firestore reads | Firestore tracking writes | RTDB operations |
|---|---:|---:|---|
| Cold authenticated start | 0 | 2: session creation + activity | 1 connection set + 1 onDisconnect registration; event-driven metadata/own-connection subscription |
| Login | 0 | 1 session + 0–1 activity; previous session cleanup if switching | same connection publication; previous connection cleanup if switching |
| Foreground | 0 | 1 new session + 0–1 activity | connection set + onDisconnect registration |
| Background | 0 | 1 session completion | 1 update deleting only owned connection IDs + cancellation of own onDisconnect registration |
| Logout | 0 | 0–1 session completion | owned connection cleanup and subscription cancellation |
| Property publish | 0 | 0–1 activity | 0 |
| Property edit | 0 | 0–1 activity | 0 |
| Chat send | 0 | 0–1 activity | 0 |
| Favorite toggle | 0 | 0–1 activity | 0 |
| 30 minutes foreground, no natural activity/lifecycle events | 0 | 0 periodic writes | 0 application data writes; SDK transport keep-alive is separate |

Additional Firestore writes from this fix: **at most one first-meaningful-action confirmation per process/UID activation**, then at most one eligible activity write per 10-minute interval containing a natural event. Concurrent events share a write; N actions inside the throttle do not produce N successful activity writes. Failed best-effort operations are not credited to the success throttle.

Additional RTDB operations from this fix: **0**. Existing lightweight multi-connection lifecycle retained.

Activity list reads unchanged: up to 30 activity documents per page/refresh, plus only uncached needed profiles in existing whereIn batches. Repeated refresh reuses profile cache. Historical session query/cache/chart unchanged. No full users scan, N+1 per-user reads, new collection listener, heartbeat or polling.

## Backend/monitoring safety

| Check | Result |
|---|---|
| Unexpected Firebase errors | NONE in the app PID's reviewed acceptance log. Existing “No AppCheckProvider installed” warning remains FOLLOW-UP. |
| Functions health | Both ACTIVE, unchanged updateTime/configuration. Complete bounded sample 13:20–13:30 Baghdad: 1 authorizePresenceDashboard request HTTP 200; 2 syncPresenceAdminRole requests HTTP 204, about 4–6ms. No ERROR entries or retry/invocation loop in that sample. |
| Final Cloud Logging observation | HTTP 429 while reading logs; no retry. Retained successful complete sample. This is an observation API quota limit, not a function/app failure. The later part of acceptance was not reverified through Cloud Logging. |
| Rules changed | NO — production rules verified read-only again, same ruleset/hashes. |
| Functions changed | NO |
| IAM changed | NO |
| App Check changed | NO |
| Production data manually modified | NO — only ordinary app lifecycle and reversible private favorite actions; no manual document correction, fake public listing, backfill or migration. |
| Analytics aggregation implemented | NO |

Protected source/configuration files were hashed before build and compared afterward: **0 changed**, including PresenceService, AnalyticsService, both rules/indexes, Functions code/dependencies, Firebase config, Android signing/applicationId and version files. Existing unrelated Git changes were preserved. No commit, push or release occurred.

## Release status and remaining limitations

Public Android version status: **UNKNOWN** for the actual deployed store binary. Local/test APK remains 1.0.4+19. **RELEASE VERSION DECISION REQUIRED** before release; no next number guessed.

Public iOS version status: **UNKNOWN** for the deployed store binary; no iOS build or release on this Windows environment.

Android public update required: **YES**.

iOS public update required: **YES**.

Remaining limitations: physical iPhone/provider login acceptance and physical two-device same-UID acceptance PENDING; existing full-project lint findings; App Check security follow-up; final monitoring window limited by Cloud Logging 429; public old clients remain uncovered until the update is distributed. External deletion of a confirmed activity record within a throttle window is repaired on the next eligible event, without an extra read.

**READY FOR PUBLIC RELEASE REVIEW: YES — implementation and Android test acceptance ready for review, not authorization to release.**

No Google Play, App Store, TestFlight, staged/public rollout, Git commit or push was performed. Work stops here.
