# ANALYTICS AGGREGATION ARCHITECTURE REPORT

Design only, 2026-10-03. No production access, query, writes or deployment in this phase. Inspected local source and official documentation. Existing audited database: aqar-9f3f9/(default), STANDARD, nam5. No Enterprise migration proposed. Only this design document added locally.

## Recommendation

Start with Firestore native READ-TIME aggregation (count/sum) plus a server-managed one-document-per-UID session-start marker. Do not start by adding daily/hourly counter writes to every session. This reduces raw session downloads drastically with much less write amplification. Materialized Daily/Hourly counters are a fully evaluated SECOND option, gated by measured dashboard request volume and backend cost. This is an architecture recommendation, not authorization to implement.

Daily aggregation: NO in recommended initial implementation; YES as conditional later materialization.
Hourly aggregation: NO persisted hourly docs initially; YES exact hourly query buckets for current chart and optional later materialization.
Client writes aggregates: NO. Server managed: YES.

## Verified existing implementation

VisitTrackingService.startSession reserves a random app_sessions document ID synchronously, waits for server write, reuses pending ID after timeout rather than creating a second ID. Fields: visitorId=UID, userId=UID, displayName(nullable), isGuest=false, platform, startedAt=serverTimestamp, endedAt=null, durationSeconds=0.

AppActivityService observes FirebaseAuth continuously and serializes lifecycle/auth transitions. An authenticated non-anonymous foreground user starts a session; paused/hidden/detached, sign-out, account switching and beginSignIn stop it. Inactive native dialogs do not end it. Resume starts a new session; there is no short-background merge. Already-started same UID does not create another session. Different devices have separate legitimate sessions.

endSession detaches the current reference before awaiting create acknowledgment, writes endedAt=serverTimestamp and durationSeconds=max(0, monotonic stopwatch elapsed seconds). Duration is CLIENT measured, not endedAt-startedAt. Offline acknowledgment delays can make those measures differ. Failure/timeouts can leave an incomplete document. Crash/force kill may leave endedAt=null indefinitely. Aggregation must not invent completion.

AnalyticsService._sessions performs startedAt>=periodStart AND startedAt<=serverNow, get(), no limit/pagination. Summary/chart share the same future in a one-period cache15s. Changing period replaces cache; failed query invalidates it. New screen service normally starts cold. Dashboard setServerNow uses RTDB server offset; today boundary still constructs a local DateTime, so CURRENT midnight/chart timezone follows device timezone. 7/30 are rolling168/720h; do not silently replace with calendar periods.

sessions=snapshot.docs.length, including any legacy guest documents. displayed unique accounts=distinct userId (visitorId fallback) of isGuest=false sessions. Average includes every endedAt!=null with duration>=0, missing duration coerced0, including legacy guests. Hence a registered-only redesign deliberately filters isGuest=false for sessions AND completed duration; may differ from current legacy totals. UI hides guest metrics but raw summary still processes old guests. This must be disclosed and tested, not mistaken for an aggregation bug.

Current costs: session start0 application document reads/1write; normal end0/1write. Activity adds0reads and0or1write with local10min throttle. Natural resume/background can create/end another session. No writes just for remaining foreground30min. Firebase auth/profile/Rules-dependent reads and RTDB operations are separate; existing Rules-dependent reads may be billed and should not be called zero-total-account-cost. Each uncached historical filter returns S_total documents, billed max(1,S_total) document reads plus any rule-evaluation reads; no extra summary/chart read. Cache reuse0session reads. No historical listener/polling.

## Exact windows and native aggregates

Use a backend endpoint accepting enum periods only, authentication and server-side isAdmin && !isBlocked check on each request. Server obtains asOf T and computes midnight using IANA Asia/Baghdad (current UTC+3); store UTC instants. No phone clock. Windows half-open[start,T) for future design, avoiding double-count boundary buckets. Today=Baghdad midnight;24h=T-24h;7d=T-168h;30d=T-720h. Changing current inclusive endpoint to half-open must be explicit and parity-tested.

1. Registered session count query: isGuest=false, startedAt in window, native count().
2. Completed query: same start window, endedAt non-null timestamp and valid nonnegative numeric duration; combine count()+sum(durationSeconds). New protected sessions guarantee the types; legacy eligibility must be validated before depending on old data. Additional inequality/index scan costs are measured using Query Explain; do not assume only returned completed records were scanned.
3. Unique marker query count(), described below.
4. Chart: exact non-overlapping bucket count queries, intersect each day/hour with selected window. At most24 hour buckets Today,25 for rolling24h,8 calendar-day intersections7d,31 for30d. Native count on partial buckets preserves exact moving window without raw sessions. No scheduled refresh or polling.

Official Standard core aggregation supports count/sum/average and bills index entries, not downloading all documents. Existing cloud_firestore5.6.12 local package has count/aggregate APIs; no dependency upgrade is implied. An admin Callable centralizes server boundaries and authorization; no use of existing Presence Callable for analytics. For strong cross-query snapshot consistency use supported Firestore readTime/transaction consistency selector; test SDK/REST support locally before selecting implementation. A cached report includes asOf, timezone, coverageStart, schemaVersion and freshness status. Cache suggested60s per exact period/authorization UID with manual refresh, no timer; permission check is not bypassed by server cache.

## Unique accounts: exact identity, not additive daily counts

A. analytics_daily/date/users/uid: deterministic marker accurately deduplicates that day. Costs at least lookup per session and one creation per distinct UID/day. Summing daily distinct counts DOES NOT yield week/month unique accounts. Union of all markers downloads U_day sums; multiplying per-user listeners unacceptable. Daily markers alone insufficient for rolling24h. Good only if historical day-level unique reports become a separate requirement.

B. Session ledger ID=sessionId: prevents repeated session contributions; not enough to deduplicate multiple sessions from same UID. Useful only for write-time counters and reversals.

C. RECOMMENDED: analytics_accounts/uid {latestSessionStartedAt, schemaVersion}. It is specifically session-start analytics, NOT user_activity.lastSeen; existing Active24h service unchanged. For current windows ending T, UID is in the window iff its maximum eligible session.startedAt<T is>=windowStart. One count query over markers provides distinct accounts for all four current periods. Supports concurrent devices and repeated sessions without double counting. Does NOT support arbitrary historical end dates or summing historical distinct groups. If those become requirements, new architecture approval needed.

Proposed creation trigger transaction reads canonical session and marker, validates registered identity, sets max(existingLatest, session.startedAt) only if newer; no write on duplicate/stale delivery. Canonical session read protects against a delayed creation event after document deletion. A separate onDeleted trigger recomputes that UID's current maximum with a limit1 indexed query over remaining eligible sessions, plus marker read in transaction; updates/removes marker only when necessary. Needed because current admin rules allow session deletion. No full scan. Concurrency causes transaction retry, not incorrect overwrite. Completion does NOT change marker and requires no trigger in this native design. Source session remains untouched. Index: isGuest,userId,startedAtDESC for bounded deletion query; marker timestamp indexed. All indexes are proposals only.

Async marker processing is eventually consistent: recent unique counts may briefly lag native session totals. Exact deduplication is not a promise of zero trigger delay. Report must expose data freshness, with bounded failure alerts/reconciliation. No constant global watermark write per session. Use common Firestore snapshot time for all query inputs to avoid a session afterT hiding an older in-window session in latest-marker lookup. Snapshot consistency does not eliminate a not-yet-processed trigger. Guaranteeing instant parity would require changing session write path/atomic server ingestion, outside minimal recommendation.

## Materialized alternative: Daily + Hourly + ledger

Optional paths analytics_daily/Baghdad-date and analytics_hourly/UTC-hour-key. Proposed fields schemaVersion,timezone,bucketStart,bucketEnd,sessionCount,completedSessionCount,totalDurationSeconds,updatedAt. Small integer totals, no UID arrays/profile copies. Completed duration assigned to START bucket, even if completion occurs next day/month, matching current startedAt selection. Historic buckets can change later; do not assume closed immutable buckets.

Daily docs supply whole-day totals; hourly docs support current hourly chart and exact rolling windows WITH boundary correction. 24h generally spans25 hourly buckets:23 whole hours plus two partial boundaries. Summing24 hourly docs is not exact. Boundary corrections use native count/sum on clipped raw-session indexes, not fetching all sessions. 7/30 rolling also have partial calendar days; use interior daily docs plus hourly edges and clipped partial-hour aggregation. Today needs daily1 + elapsed hourly chart up to24 docs. Full 24h:23whole-hour docs+boundary aggregate reads;7d:6full days+23whole edge hours;30d:29full days+23whole edge hours, for unaligned T (aligned case differs). No exact rolling query can be replaced by a fixed daily-doc sum alone.

Unique counts STILL use analytics_accounts/UID count; not daily-unique sums.

Idempotency ledger analytics_session_ledger/sessionId stores schemaVersion,UID,buckets,countApplied,completionApplied,appliedDuration,canonicalRevision/tombstone. Trigger reads canonical session+ledger transactionally, optional UID marker for initial contribution; applies delta once with atomic increments to daily+hourly and ledger state. Completion-first delivery can apply both contributions, subsequent creation delivery no-op. Duplicate completion no second sum. Deletes reverse exactly recorded contribution and correct UID marker. Snapshot updateTime and canonical re-read prevent stale events resurrecting deleted counters. Aggregation never writes app_sessions, so no trigger feedback loop. Retention must preserve replay/backfill protection; no automatic ledger TTL until a proved replay horizon/tombstone policy is approved.

Shared daily doc can become hotspot:100K/day~1.16session starts/s average,~2.31start+end events/s if all finish, but peaks unknown. No fixed promise of safe single-doc throughput. Sharding only after load testing: increases bucket reads or needs cached rollups and more scheduled operations. Counts below assume unsharded and no retries; not guaranteed100K peak capacity.

## Cost comparison (additional analytics backend only)

S=session starts/day, C=valid completions/day, M=UID-marker advancement writes<=S. Other app/session/activity writes unchanged. Costs shown exclude deletes, duplicate delivery, contention retries, indexes/storage, execution GB/CPU-seconds/Eventarc transport, security authorization reads and dashboard requests. Reads include billed missing-document lookups. Function event payload does not itself require an explicit Firestore read.

A client-maintained counters: can use ~S+C ledger transactions, bucket writes comparable to server option, no Functions; trustworthy validation is complex and clients may forge counters. REJECT.
B on every source write: ~S+C invocations currently; extra future updates also invoke even if handler exits. For full materialization normal upper baseline reads3S+2C, writes3(S+C)+M, transactionsS+C.
C lifecycle triggers: create and update for full counters stillS+C invocations; an onUpdated trigger cannot filter endedAt change before invocation. For native recommendation only create/delete triggers needed: normal S invocations,2S reads, M<=S writes, S transactions. Completions incur ZERO added aggregation backend work.
D scheduled raw scan everyhour: can reread overlapping data~24S/day and miss late completions if naïve startedAt checkpoint; no recommendation. Native on-demand/server-cached summaries have no per-session summary writes; whole-day count/sum batch is cheaper, but late completion/correction requires dirty tracking or deliberate bounded recomputation and declared staleness. Scheduled materialization is a future measured alternative, not free.
E hybrid recommendation: native exact summary+chart and server-managed UID marker; optional materialized buckets later only when query volume justifies write amplification.

Assume C=S, M=S, no deletes/retries:

| S/day | existing session client writes | Recommended extra reads | extra writes | invocations | transactions | Daily+Hourly+ledger extra reads | extra writes | invocations | transactions |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
|1000|2000|2000|1000|1000|1000|5000|7000|2000|2000|
|10000|20000|20000|10000|10000|10000|50000|70000|20000|20000|
|100000|200000|200000|100000|100000|100000|500000|700000|200000|200000|

Function duplicate creation adds invocation+up to2transaction reads, normally0writes. Transaction contention adds repeated reads/attempts and latency, not counted above. UID deletion recovery adds bounded query and marker operations. Full materialized duplicate event costs canonical+ledger reads,0writes. No claim total invoice always falls: admin opening frequency matters.

## Dashboard reads BEFORE/AFTER

Define K(E)=max(1,ceil(E/1000)) for index-entry billed aggregate reads, E=entries actually scanned (not necessarily matching docs), U=matching one-per-UID marker entries. Let A_P=1 authorization users/UID read +K(E_sessions,P)+K(E_completed,P)+K(U_P). Let G_P=sum K(E_each chart bucket). All values cache miss, no realtime/presence cost included; Rules-dependent reads would be additional for direct-client variant. Empty queries incur minimum read.

| Period | Current reads | Proposed recommended reads incl chart | Reduction |
|Today|max(1,S_total,today)|A_today+G_today, at most24 chart queries|1-(A+G)/max(1,S_total)|
|24h|max(1,S_total,24h)|A_24h+G_24h, at most25 chart queries|same formula|
|7d|max(1,S_total,7d)|A_7d+G_7d, at most8 chart queries|same formula|
|30d|max(1,S_total,30d)|A_30d+G_30d, at most31 chart queries|same formula|

When indexes scan about one entry/session, summary reads scale roughly2ceil(S_registered/1000)+ceil(U/1000)+1; chart adds bucket aggregate reads. Actual billing depends indexes; Query Explain is a required implementation gate. Do NOT claim one aggregate query always costs one read. With few sessions these fixed small-query minimums can be more costly than one tiny raw query. Dynamic thresholds/fallback not added now; architecture gate must measure actual dashboard frequency. No dollar estimate because project rates/free-tier/GBseconds not measured.

Cost break-even recommended marker overhead per day=(2S*pRead)+(M*pWrite)+S*functionCost; must be below sum_over_dashboard_cache_misses((oldReads-newReads)*pRead) plus transfer savings. Full materialization overhead uses5Sreads+7Swrites+2Sinvocations baseline. Paid write/read price ratio matters. Scale alone does not justify always-on counters for rarely opened dashboard.

## Duration, reliability, safety

Average=floor(totalValidCompletedDuration/validCompletedCount), undefined/no-completions represented explicitly rather than asserting measured0duration. Zero duration valid if endedAt valid. Never include unfinished sessions in denominator; no timed writes/forced crash completion. No timers/heartbeat/polling. Existing client-measured duration may be forged by authenticated owner; server-owned counters protect derived documents, not source truth. A separate decision can cap plausible duration or derive server elapsed; these differ from foreground stopwatch and must not be silently substituted.

Session restarts are legitimate distinct sessions by different IDs; they increase sessions, not unique accounts. Marker monotonicity/recomputation and ledger protect duplication under retries/concurrent devices, not fraudulent repeated new-session creation. Function auth/admin SDK bypasses Rules, so handler validates eligibility, bounded period enums, authorization/blocking, and never client-provided increments. New derived collections would deny client writes/all public reads. Admin-only aggregates/markers or callable-only access must be reviewed with emulator tests later. No current rule modified. No provider/platform filtering.

## Backfill and rollout proposal

Backfill REQUIRED to show complete prior30days from UID markers immediately. OPTIONAL if new data intentionally labeled coverageStart and old dashboard used until sufficient30day coverage. No historical raw sessions rewrite/deletion.

Before any backfill, bounded indexed count estimate for desired30day registered window (NOT full production scan), plus explain index scan, storage and reads/writes budget. New marker backfill: paginated200session documents, process max perUID via same protected transaction logic, resume cursor and bounded task budget; source readsS_30 plus marker transaction reads/writes up to perUID/session depending batch grouping. It does not need session completion updates. Add marker completeness flags per migration job; no false complete reports. For materialized option ledger transaction per session creates greater write cost; separately estimate before approval.

Capture cutover timestamp, deploy approved trigger and READY indexes before enabling consumers, backfill overlaps safely using deterministic UID/ledger logic, reconcile bounded day/window native totals, then switch read path behind rollback flag. Keep old path for controlled rollback; no automatic double-query every dashboard view. No destructive migration, no deleted Production records. Data shape change requires explicit implementation approval.

Phases:
1. Approve semantics (registered-only, Baghdad boundaries, rolling7/30, client stopwatch), freshness and cost model. Local emulator native queries+marker create/delete/idempotency/authorization tests, Query Explain plan; no deployment.
2. Separate approval for index/derived rules/new marker triggers/callable, bounded30day backfill with cost cap, parity/latency/cost gate; deploy only after reviewed plan, switch dashboard reading, preserve Active24h and Presence.
3. Measure cache-miss frequency/aggregation latency. Only if financially justified approve Daily/Hourly ledger materialization and burst load tests/sharding. No scheduled raw scans or counters introduced automatically.

Risks: trigger lag; duplicate delivery read overhead; incomplete sessions; unvalidated legacy guest/duration shapes; marker backfill; arbitrary past-end windows unsupported by latest marker; admin deletions; ledger storage; contention/bursts; single aggregate query deadline at large indexes; unknown admin request volume; client source duration/session spam. No new UID-profile reads.

PRODUCTION CHANGED: NO.
READY FOR IMPLEMENTATION REVIEW: YES (design only; not ready for deployment).

## Sources
- https://firebase.google.com/docs/firestore/query-data/aggregation-queries — Standard core aggregates/index-backed summary, no raw document downloads.
- https://firebase.google.com/docs/firestore/pricing — index-entry aggregation pricing/minimum query reads/security reads.
- https://firebase.google.com/docs/functions/firestore-events — at-least-once delivery and unordered events; update event cannot be narrowed to field before invocation.
- https://firebase.google.com/docs/firestore/solutions/aggregation — write-time tradeoffs/latency.
- https://firebase.google.com/docs/firestore/best-practices — single-document write throughput depends workload and requires load tests.
- https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/runAggregationQuery — supported readTime/transaction consistency selector.

Local source: lib/analytics/services/visit_tracking_service.dart; app_activity_service.dart; analytics_service.dart; models/analytics_models.dart; screens/analytics_dashboard_screen.dart; approved deploy.firestore.activity-only.rules. Existing cloud_firestore5.6.12 API inspected locally; no dependency change.
