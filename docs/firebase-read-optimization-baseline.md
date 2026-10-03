# Firebase read optimization baseline — 2026-10-03

Captured before application/backend edits in this task. Current source was inspected again; the previous audit is context, not the baseline. Application version remains 1.0.4+19. Existing uncommitted Presence/Activity/security changes belong to previous tasks and must be preserved.

The fresh static inventory contains 352 candidate access/trigger sites in 84 source files, including the Cloudflare worker. These are source sites, not 352 active queries or measured physical subscriptions.

## Inventory and billing interpretation

`firebase-current-query-inventory.txt` records call sites across `lib/` and `functions/`; the Cloudflare worker is also reviewed below. `get`, `snapshots`, `safeSnapshots`, aggregates, transactions, collection-group queries, listener cancellation and actual callers were checked. Test/diagnostic code is not normal app consumption. SDK cache can reduce actual billed reads; document counts below describe a cold successful server query, not a measured Firebase bill. A rejected query, empty query, security-rule dependent reads, reconnection and index-entry billing are separate costs.

Symbols: S=approved properties; O=active offices; P/F/R/E=an office's properties/active followers/reviews/events; V=user favorite IDs; N=user notifications; M=chat messages; U=users; H=historical sessions in the selected period; L=reels returned (at most 100); T=distinct related reel targets. An unchanged SDK listener may share transport, so application subscription counts must not be presented as exact physical listener billing.

| Feature | Current query/listener | Limit | Pagination | Realtime | Recreated on rebuild | N+1 | Estimated cold reads | Risk / priority |
|---|---|---:|---|---|---|---|---|---|
| Home property sections | approved featured/latest/views | 4/10/10 | separate catalog | yes | main streams already cached | favorite per card | ≤24 properties + mounted favorites | medium |
| Home profile/header | user, optional office, user's notifications | none on notifications | no | yes | nested streams built inline | no | 1 + optional 1 + N | high |
| Home featured offices | active+featured | 10 | no | yes | parent already cached | card statistics | ≤10 + Σ(P+F+R+E+2) | critical |
| All properties | approved; optional office | none | local visible count 10 | yes | yes, typing/filter/load more | favorite per card | S or office-approved S | critical |
| Search/filter/sort | all words substring across Arabic-normalized fields; category/ad type/featured; createdAt/views/price | same full source | no server cursor | source realtime | yes | no extra query, but resubscription | S per new source subscription | critical, cannot restrict search to first page |
| Property details | property stream; owner/office/profile lookup; favorites; comments | related lists require separate review | mixed | yes | some inline | related profiles | 1 + related lookups/comments | high |
| Add/edit property | profile/office/subscription, number transaction and success write | document/limit 1 where applicable | n/a | mostly no | action based | no catalog scan required | operation-specific few documents | preserve Activity hooks |
| Favorites | all favorite IDs, requested property documents | property display 10 | display/property loading only | IDs realtime | IDs subscription cached | property gets per ID | V + ≤10 properties initially | high |
| Office list | all active offices | none | no | yes | inline stream | statistics per card | O + Σ(P+F+R+E+2) | critical |
| Office card | office snapshot → statistics full scans | none | no | yes | yes | four collection scans | 2+P+F+R+E per calculation | critical |
| Office header/overview | office + overlapping review/property/follower/event streams | none | no | yes | nested inline | profile lookups | 1+P+F+R+E, some repeated | critical |
| Office properties (owner) | all office properties including pending/rejected | none | no | yes | main stream cached | favorite/state dependencies | P | high |
| Office reviews/followers | all office records; profile/avatar lookups | none | no | yes | some inline | yes | R or F + missing profiles | high |
| Office statistics/dashboard | office plus full statistics scans | none | no | yes | office updates repeat scans | no per-document call, but full scans | 2+P+F+R+E | high |
| Office subscriptions | filtered subscription stream + all offices join | none on offices | no | yes | explicit cancel present | shared office collection | subscriptions+O | high |
| Reels feed | published/scheduled ordered query | 100 | no | yes | every swipe/category rebuild | property+office validation | L + up to 2L targets | critical |
| Reel likes/saves | viewer/reel document | 1 each | n/a | yes | card build | 2 per mounted reel | up to 2 per mounted card | medium |
| Saved reels | viewer save records → reel → property/office | none | no | yes | screen dependent | yes | saves + up to 3 per save | high |
| Reel moderation | all reels/reports and target lookup | mixed/unbounded | no | yes | some inline | target lookup | collection-dependent | high |
| Map | all approved properties; map validity/filtering local | none | no | yes/one-shot | controller lifecycle | no | S | high; viewport schema absent |
| Market statistics | approved properties, shared in-flight/cache 2 minutes | none | no | no | cache present | no | S per cache miss | retain correctness |
| Active chat | settings + chat doc + latest messages | latest 50 | expands live limit | yes | explicit subscriptions | reply/property previews | 2+min(M,50) | high older-page rereads; preserve realtime/search/jump |
| Conversations/admin chat | chats plus all users for profile join | none | no | yes | chat list stream inline | profile join full U | chats+U | high |
| Notifications list | userId+createdAt DESC | none | no | yes | inline stream | no | N | high |
| Notification header badge | user's notification history, local readBy filtering | none | no | yes | nested rebuild | no | N | high; array-not-contains unavailable |
| NotificationBadge legacy widget | all notifications | none | no | yes | inline | no | zero if unused (no callers found) | do not attribute unused cost |
| Send notification | all users for broadcast; user read per targeted send | none/1 | no | action | n/a | broadcast recipient profiles | U + targeted lookups | explicit action, not normal screen read |
| Admin dashboard | pending properties/requests/reel reports + all chats unread sum | none | no | yes | inline | no | pending sets + all chats | high |
| Admin users/properties/offices | full respective lists, office stats repeated | none | no | yes | inline | profile/summary joins | respective collection sizes | high |
| Admin comments | comments collectionGroup + authors | none | no | yes | inline | yes | all comments + distinct uncached authors | high |
| Admin reports/moderation | reports, target details | mixed/unbounded | mostly no | yes | screen dependent | target gets | reports+targets | high |
| Property requests | public/admin/my requests, counter transaction | mixed/unbounded | mostly no | mixed | some inline | owner/detail reads | request-set size | medium/high |
| Activity users | isGuest=false + lastSeen range DESC + batch profiles | 30 | cursor | no, explicit refresh | no | batch ≤30, cache 5 min | ≤30 activity + ≤30 missing profiles | already fixed, preserve |
| Online Now | RTDB presence parent, count UIDs with new connections | one listener while dashboard | n/a | yes | lifecycle-managed | no | small current Presence payload | already fixed, preserve |
| Activity/session tracking | authenticated UID, 10-min activity throttle; session lifecycle | document | n/a | auth/lifecycle only | no | no | zero reads for throttle; writes event-driven | already fixed, no heartbeat |
| Historical analytics | startedAt range shared raw sessions summary/chart | H time-bounded | no | no | 15-second in-flight/cache reuse | no | H once per selected period cache miss | deliberately no aggregates |
| Blocks | own blockedUsers | viewer's set | no | yes | shared singleton, account reset | no | blocked IDs only | safety-critical, preserve |
| Profile/settings/auth | own document/settings; login indexes bounded; legacy admin migration marker | mostly 1 | n/a | mixed | some inline | migration may read U once | document reads; existing migration separate | no migration during this task |
| Banners/app updates/packages | small configuration lists/documents | mostly unbounded small lists | no | mixed | some inline | no | list sizes | medium, do not hide valid entries |
| Functions office properties | every properties write → office + all approved office properties → office update | none | no | trigger | every view update too | cascading scans | 1+approved P + downstream clients | critical |
| Functions office followers/reviews | every record write → full source recount → office update | none | no | trigger | unrelated edits included | no | 1+F or 1+published R | high |
| Functions Presence ACL | role changes with updateTime idempotency; callable 10-min client success cache | own user/ACL | n/a | trigger/callable | irrelevant role updates early exit | no | reviewed bounded operations | preserve |
| Functions chat | authorization/settings/chat/message/audit/recipient previews | bounded documents | n/a | callable/trigger | explicit event | recipients bounded | handler-specific bounded reads | preserve deletion/idempotency |
| Cloudflare reels events | dedup doc, increment event count | 1 dedup | n/a | HTTP event | action | no | 1 read per event + writes | updates wake feed snapshots |
| Cloudflare delete reel | reel+all reels for asset sharing; associated interaction queries | none | no | HTTP admin action | no | dependent deletes | reel collection+associated interactions | infrequent administrative operation, no production cleanup |

## Baseline scenarios (engineering estimates, not billing measurements)

| Scenario | Existing cold server-return pattern |
|---|---|
| A Home | ≤24 properties + ≤10 featured offices + mounted favorite documents + own profile + N notifications + office-card scans |
| B All properties | S + favorite documents for visible cards |
| C Load More twice | source may resubscribe at each rebuild; worst-case 3S across initial/open/load-more; not guaranteed billed 3S due SDK sharing/cache |
| D Search/filters | full source resubscription potential per edit; exact Arabic substring semantics require all relevant candidates without a search index |
| E Details | property/profile/office/favorite/comments + views write; possible office recount/cascade |
| F Favorite | 1 favorite existence read + 1 set/delete; Activity ≤1 extra throttled best-effort write |
| G Offices | O + Σ(P+F+R+E+2) for mounted cards |
| H Office detail | 1 office + overlapping P/F/R/E streams + requested profile lookups |
| I 10 reels | 10 rebuilds can restart feed L + up to 2L validation each; actual billing depends SDK; likes/saves and worker event costs additional |
| J Chat | 2+min(M,50); expanding limit to 100/150 reattaches growing live window |
| K Notifications | N history documents |
| L Map | S approved documents |
| M Admin Activity | H shared raw sessions + one RTDB presence listener; list ≤30+≤30 profiles |

## Constraints and correctness gates

- No Production change. New query indexes, Functions, Rules, or counter initialization need an explicit backend gate. Public office follower records are not generally readable by other users; do not replace summary fields with a denied follower query.
- Standard Firestore cannot implement existing arbitrary substring/AND cross-field Arabic search as a single native bounded query. Pagination must not silently restrict search or global price sorting. A bounded exact-search solution needs a proven existing backend index/representation; otherwise retain correct fallback and report its cost.
- Existing office summary counts are server-managed and approved-property based; historical `getStatistics.totalProperties` includes pending records. Verify deployed maintainer and representative source counts before trusting summaries. Do not silently fabricate counters or perform backfill.
- Existing New Presence/Activity implementation, tests, query page size, ownership and lifecycle are protected. No timers/polling added.
- Production billing cannot be measured by counting snapshot sizes. Changes will be reported as returned-doc/query/subscription budgets and actual test evidence where available.

## Newly verified Production blocker

Read-only capture at 2026-10-03T11:47:05Z (14:47:05 Asia/Baghdad), project `aqar-9f3f9`, default database `STANDARD`:

| Masked office | Stored propertiesCount | Approved property source count | Stored followersCount | Active follower source count |
|---|---:|---:|---:|---:|
| cbe2ad4d | 0 | 13 | 0 | 11 |
| 2cf5c939 | 0 | 0 | 0 | 4 |

Counts were obtained using filtered native server-side count queries, not downloads of property/follower collections. Only two office documents were returned. Neither office was modified. Both Gen 2 and Gen 1 lists were checked: Gen 2 contains only ACTIVE `authorizePresenceDashboard` and `syncPresenceAdminRole`; Gen 1 is empty; neither response has a next-page token. Consequently `refreshOfficePropertyMetrics`, `refreshOfficeFollowerMetrics`, and `refreshOfficeReviewMetrics` in local source are not deployed maintainers in this project.

This changes the earlier audit interpretation: the local property-view → property-count Function cascade is real source code, but it is **not an active Production Function cascade** today. Client office-event/statistics touch → office listeners remains a separate source path. Do not attribute invocations to undeployed Functions.

The current card's full statistics calculation can finish for an Admin/authorized owner. Its cold-read formula `2+P+F+R+E` applies to successful authorized calls. For an ordinary unrelated user, office_followers reads are denied by current Rules, after earlier office/property/review reads, and the card falls back to the incorrect stored fields. Simply removing scans and substituting current stored summaries would preserve incorrect zeros. Native client count() over followers is subject to the same Rules and does not bypass authorization.

**STOP gate:** reliable server-maintained office summaries plus an explicitly approved, bounded initialization/reconciliation are necessary before the highest-priority card optimization can be accepted without changing accuracy or broadening Rules. User task sections 31/32/37 prohibit performing that Production deployment/backfill automatically. No application/backend implementation has been started following this evidence.
