# FULL FIREBASE READ OPTIMIZATION ACCEPTANCE REPORT

Date: 2026-10-03. Status: **STOPPED AT REQUIRED PRODUCTION BACKEND GATE**. The audit and pre-change baseline are complete; the requested optimization/build/device acceptance is not complete. No savings or test PASS are claimed for work not performed.

## Audit coverage

Fresh static inventory: 352 candidate access/trigger sites across 84 source files in Flutter `lib`, Firebase Functions and Cloudflare reels worker. Review covered current property/search/filter/favorite flows, Home, office cards/services/details/statistics, reels feed/related validation, map, chat/history, notification/history/badge, admin/moderation, auth/profile/settings, activity/presence/session caching and backend counter triggers. Candidate sites are not active-query counts. The baseline includes small configuration/subscription/banner/request services and currently unused legacy notification badge.

Evidence files:

- `docs/firebase-read-optimization-baseline.md`: current-source inventory table and A–M budgets captured before changes.
- `docs/firebase-current-query-inventory.txt`: fresh source call-site list.
- `docs/firebase-optimization-readonly-evidence.json`: masked Production office counter truth, database edition, deployed Functions and READY indexes.
- `docs/firebase-optimization-readonly-check.cjs`: reproducible read-only helper; credentials are neither printed nor stored.
- `docs/firebase-optimization-readonly-check.log`: sanitized metadata output, no tokens/user names/phone numbers.

Files changed in this task: only the documentation/diagnostic files listed above and this report. No Flutter source, Functions source, Rules, index configuration, dependencies, version, package name, Firebase identity or signing changes.

## Critical evidence and reason for stopping

Production project: `aqar-9f3f9`, default Firestore STANDARD. Final capture: 2026-10-03 14:47:05 Asia/Baghdad.

| Masked office | Stored propertiesCount | Actual approved properties | Stored followersCount | Actual active followers |
|---|---:|---:|---:|---:|
| cbe2ad4d | 0 | 13 | 0 | 11 |
| 2cf5c939 | 0 | 0 | 0 | 4 |

Two bounded office documents and filtered native count queries were used; no property/follower document collection was downloaded and no data was changed. These are genuine source-counter mismatches, not estimated values.

Gen 2 Functions list contains only `authorizePresenceDashboard` and `syncPresenceAdminRole`, both ACTIVE. Gen 1 list is empty. Both lists have no continuation token. Thus the three local office counter maintainers are absent from Production. Existing counters cannot be assumed trustworthy.

`office_followers` Rules permit Admin, the follower itself, or the owning office account to read a record. Ordinary visitors cannot aggregate the full follower set. A native count() still obeys these Rules. Using the current summary fields would display wrong zeros; opening follower reads publicly would change security; writing corrected office summaries from the client is also unauthorized. None is an acceptable optimization.

The explicit user gate in sections 31/32/37 requires stopping when correct completion needs a Production backend deployment or initialization/backfill. This is that gate, rather than a request to approve an ordinary local edit.

## HOME

Before: properties already limited to 4 featured + 10 latest + 10 most-viewed; featured office query already limited to 10 with a cached stream. Additional notification history, per-card favorites and heavy office statistics dominate excess reads.

After: unchanged, no implementation performed. Estimated cold document-return pattern: ≤24 properties + ≤10 offices + mounted favorite reads + own profile + N notifications + office statistics scans when authorized. No measured reduction. Acceptance: NOT COMPLETED.

## ALL PROPERTIES

| Check | Current result |
|---|---|
| Real pagination | FAIL: display limit only |
| First page size | 10 shown; all S matching approved documents downloaded |
| Load More | FAIL: exposes more already-downloaded records |
| Full collection initial read | PRESENT for matching approved set |
| Query stable across rebuild | FAIL: safeSnapshots created inline |
| Search outside loaded page | Existing search operates on full source; no new paginated implementation tested |
| Filters | Existing behavior retained, no new tests run |
| Favorites N+1 | PRESENT: per mounted card document stream |

Existing search is normalized Arabic multiword substring matching across many fields, numbers and document ID. Native bounded Firestore queries cannot reproduce it directly. Global price sort also needs indexes absent from the verified Production index list. A pagination design must preserve correct global search/sort, not silently search only the first 20 records. Correct fallback and explicit future query/index choices must be part of implementation.

## OFFICES

| Check | Result |
|---|---|
| Office card full scans | PRESENT |
| Stored property count correctness | FAIL in verified office: 0 versus 13 |
| Stored followers count correctness | FAIL in both verified offices: 0 versus 11 / 4 |
| Rating correctness | NOT VERIFIED against representative reviews |
| Historical events loaded by card | YES when authorized statistics query succeeds |
| View → office recount Function cascade | PRESENT IN LOCAL SOURCE; NOT DEPLOYED in Production |

Successful authorized card calculation reads approximately office listener + office get + P+R+F+E documents. Ordinary users can encounter follower permission denial and fallback to wrong stored summaries; their successful-download formula is different and must not be reported as the full authorized scan.

## REELS

Pagination: FAIL (100-document feed limit, no cursor). Stream stability: FAIL (recreated on swipe/category rebuild). Related-document N+1: PRESENT. Blocked/deleted correctness: existing validation preserved; no changes or new acceptance tests. Ten-reel BEFORE/AFTER: unchanged. If each swipe resubscribes, the source pattern can repeat L + up to 2L target reads per rebuild; actual SDK billing is not measured. Distinct-target deduplication and stable feed remain safe planned optimizations.

## PROPERTY DETAILS

Current owner/office/favorite/comment reads retained. No N+1 optimization performed. Related-list limits and repeated profile Futures remain in the call-site inventory. The undeployed office-property counter trigger must be guarded before any future deployment, so views cannot cause a recount. Client office event/statistics-touch writes remain separate.

## MAP

Current strategy: all approved properties, then geographic validity and filters locally. Optimized: NO. Full approved set read: PRESENT. No existing geohash/viewport index was verified; truncating with limit would silently lose markers. Geographic schema/index design needs a separate approved backend decision if exact full-map behavior is retained.

## CHAT

Recent messages bounded: YES, current 50-message live window. Older-message pagination: FAIL as a cursor optimization; current load-more increases the live limit and resubscribes. Realtime new messages: existing implementation retained, not retested. Full history initial read: ABSENT for the normal conversation screen. Existing message search/jump/history/deletion/receipts require careful preservation when splitting older pages from the live window. Successful-send Activity hook untouched.

## NOTIFICATIONS

Pagination: FAIL. Full history initial read: PRESENT. Home unread badge uses full user history and readBy membership; simple limit(10) would incorrectly miss unread notifications behind already-read records. Unused legacy global badge is not counted as current consumption. No schema/Rule changes or new unread counters introduced.

## ADMIN

Large users/properties/offices/comments/reports lists include unbounded queries; collection-group comments and whole-user profile joins remain. No pagination changes applied. Activity pagination: existing 30-page cursor preserved. Presence/Last Activity regression: no protected source changed, new tests NOT RUN. This is not a new device PASS claim.

## ANALYTICS

Aggregation introduced: NO. Shared time-bounded raw sessions summary/chart query preserved: YES. Existing cache/in-flight reuse preserved. Additional backend writes: 0. No analytics_accounts, daily/hourly counters, session trigger or backfill.

## FIREBASE COST

All patterns below are **ESTIMATED source budgets**. AFTER equals BEFORE because implementation stopped before source changes. There is no fabricated saving percentage.

| Scenario | BEFORE | AFTER |
|---|---|---|
| A Cold start/Home | ≤24 properties + ≤10 offices + own profile/optional office + N notifications + favorite reads + authorized office scans | unchanged |
| B All Properties | S approved documents + mounted favorites | unchanged |
| C Load More ×2 | may reattach S-sized query twice; display expands locally | unchanged |
| D Search/filter | S-source subscription may restart per edit; full global substring search | unchanged |
| E Property details | property/profile/office/favorite/comments; view/event writes | unchanged |
| F Favorite | 1 existence read + 1 write + ≤1 throttled Activity write | unchanged |
| G Offices | O offices + Σ(2+P+R+F+E) for successful authorized cards | unchanged |
| H Office details | office + overlapping property/review/follower/event sets + profile lookups | unchanged |
| I Ten reels | up to ten repeated L-sized source/related validation passes on rebuild; likes/saves/events additional | unchanged |
| J Chat | settings+chat+latest min(M,50), then growing live window on older load | unchanged |
| K Notifications | N user notification documents | unchanged |
| L Map | S approved property documents | unchanged |
| M Admin Activity | H shared historical sessions + one RTDB listener; active list ≤30 activity + ≤30 missing profiles | unchanged |

Production audit itself: two captures of two office documents and four filtered count aggregations per capture. No property/follower records downloaded. Metadata/Functions/index listing is control-plane read-only. Count aggregations have minimum/index-entry read billing; these are not claimed to be free or a single returned-document read. No function invocation, RTDB data mutation or application write was caused by the diagnostic.

## QUALITY

- flutter analyze: NOT RUN in this task (no application implementation, stopped at backend gate).
- Pre-existing lints: previous task report remains historical evidence; no fresh analyze count claimed.
- New errors: no application changes; no newly measured analyze result.
- Tests: NOT RUN in this task; previous test results are not relabeled as new acceptance.
- APK build: NOT RUN.
- Installed as update: NO new installation in this task.
- App data preserved: YES, no uninstall/data/cache/reset operations performed.
- Android device acceptance: NOT RUN for optimization.
- iOS shared code: unchanged; no new review PASS claimed.
- iOS device acceptance: PENDING.

## BACKEND

Firestore Rules changed locally: NO. RTDB Rules changed locally: NO. Functions source changed locally: NO. Index config changed locally: NO. Production Rules/Functions/IAM changed: NO. Production data migrated: NO. Backfill: NO. App Check: NO. Protected Presence/Activity/auth/signing/version source untouched.

**PRODUCTION BACKEND DEPLOY REQUIRED: YES** for the verified office-counter blocker. Nothing below was executed.

## PRODUCTION BACKEND DEPLOY PLAN — proposal requiring separate approval

1. Review local implementations of exactly `refreshOfficePropertyMetrics`, `refreshOfficeFollowerMetrics`, `refreshOfficeReviewMetrics` before deploying them. Add membership guards: approved status/office ownership changes for property count, active membership/office changes for followers, published status/rating/office changes for reviews. A views-only property update must return before source reads/writes; a follower display-name edit must not recount; office transfers must update both offices. Idempotent recount from source, duplicate delivery and concurrency must be tested. Do not deploy the current unguarded implementations.
2. Select the minimum source calculation: server-native count for properties/followers; verify rating data types and legacy status semantics before replacing the reviewed rating calculation with any aggregate. No new Presence/Activity/session trigger. Use finite runtime/instance limits consistent with project operation. Existing deploy config `firebase.activity-deploy.json` can scope Functions, but its two Activity exports must not be republished accidentally. Exact proposed scope: `functions:refreshOfficePropertyMetrics,functions:refreshOfficeFollowerMetrics,functions:refreshOfficeReviewMetrics`.
3. Separately approve a bounded office-summary initialization/reconciliation. Deployment of triggers alone does not repair unchanged historical records. Begin only with an explicitly approved office ID list and native filtered counts, record prior values and source timestamps, estimate count/index scanning cost, and compare concurrency/re-run behavior. Do not scan/rewrite all offices or touch event/property/follower source data. Ratings initialization requires its own validated source definition. No broad automatic backfill.
4. Verify representative source counts equal stored summaries and triggers preserve them on approved test events. Then replace card statistics scans with the already-loaded office summary fields. Ordinary visitor security remains unchanged. Preserve same card layout. Add cold-load/live-update/error/account-switch tests.
5. Continue the local application optimization from the baseline: cursor catalog/notifications/reels/chat/admin pagination, shared favorite state, stable subscriptions and bounded related-document deduplication. Proposed status+price and office+status+createdAt compound indexes are not currently READY; list exact selected query shapes and stage an isolated index approval if required, preserving all 13 current indexes. No speculative deployment now.

| Resource | Reason | Risk | Rollback | Expected benefit |
|---|---|---|---|---|
| Three office metric Functions only | Current maintainers absent; sources already demonstrate wrong counters | Current unguarded code would recount on views; rating/status semantics and ordering must be tested first | Disable/delete only newly approved three Functions; keep two Presence authorization Functions; restore previous client build if needed | reliable summaries, no card collection scans; no views-only recount |
| Explicit office summary fields initialization only | Historical counters do not become correct simply by publishing a trigger | Bounded Production writes require approval; concurrent source edits and legacy types | Keep prior summary backup and conditional/version-aware restoration; never delete source records | initial correctness before switching cards to summaries |
| Only indexes required by final selected pagination queries | Some global sort/filter/office-order shapes absent | Index build delay/storage; client cannot depend on them before READY | restore prior client query; existing indexes remain untouched; review removal of only new index separately | bounded pages with correct global sort/filter |

No IAM/Rules/App Check change is proposed as a workaround. No broad deploy command is authorized by this report. Function rollback/initialization restoration also require their own controlled approval unless protecting a proven live incident.

## FINAL

- Major read sources fixed: NONE in this task; audit identified concrete targets and a new Production correctness blocker.
- Remaining high-read sources: office scans, full catalog/search source, favorites per-card listeners, unstable reels and target gets, office overview scans, map, notification history, admin lists and growing chat-history listener.
- Estimated overall improvement: 0 applied; no percentage claim.
- UI/features changed: NO.
- Presence/Activity fixes preserved: YES, no changes.
- READY FOR FINAL RELEASE PREPARATION: **NO**.
- Remaining blocker: approved server-side office-summary maintenance and bounded initial correction, followed by implementation/tests/build/device acceptance. App remains at 1.0.4+19; no release/commit/push/deploy performed.
