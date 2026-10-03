# FINAL PRE-RELEASE SECURITY + UI ACCEPTANCE REPORT

2026-10-04 — Asia/Baghdad. Project: aqar-9f3f9. Scope: office_followers permissions and the proven catalog Load More overlap only.

## OFFICE_FOLLOWERS SECURITY

Current public-read behavior BEFORE repair: anonymous and any authenticated caller could enumerate every relationship. Production contained TWO overlapping office_followers matches. The first `allow read: if true` won by OR over the second restrictive match. The second also allowed own/admin update/delete, so the first identity-checking update and delete=false did not provide complete protection. Creation checked authenticated userId but did not validate office/schema. Root local rules contained the same follower blocks plus unrelated pre-existing changes; those unrelated changes were preserved locally and never deployed.

Current Production rule AFTER repair: one scoped match, with `followerAdmin()` and `validFollower()` defined inside that match. Exact code: [production-after.rules](pre-release-security-ui/production-after.rules). Exact before/after diff: [office-followers-only.diff](pre-release-security-ui/office-followers-only.diff). Comparison proves every non-follower nonblank line is unchanged, including Chat, office_events and other permissions. The isolated approved file—not root firestore.rules—was deployed.

Data fields exposed by the old public read, from18 current documents: userId:string; officeId:string; userName:string; userImageUrl:string; isActive:boolean; createdAt:timestamp; updatedAt:timestamp. No email, phone or provider fields were found in this bounded complete current sample. No Production field values are reproduced here. Risk BEFORE: MEDIUM—public identity/name/photo and follow relationships, plus insufficient update validation. Remaining scoped risk AFTER: LOW; this is not a comprehensive security certification for every collection.

Public read necessary: NO. Required client access: self follow-state lookup `officeId + userId,limit1`; own following/profile-refresh records; office owner’s own follower list and publication notification recipients; active server-authorized Admin approval notifications/list. Office cards, featured cards and details counts read `offices.followersCount`, not follower rows. The owner list remains20/page, with complete owner search unchanged. Removing owner access would break an actual feature; it was deliberately retained. Cloud counter Functions use Admin SDK and bypass these client rules.

Full dependency inventory: [access-inventory.md](pre-release-security-ui/access-inventory.md).

Final access model:

- Read: authenticated self, relevant office owner or active server-authorized Admin. Admin privilege comes from protected users/{uid}.isAdmin and isBlocked fields, not client-provided follower fields.
- Create: authenticated self only; existing office, valid IDs/types/lengths/field allowlist; new record active with timestamp fields.
- Update: self only; userId,officeId,createdAt immutable. Only isActive,userName,userImageUrl,updatedAt may change, with resulting data validated.
- Unfollow: existing application behavior is an isActive=false update, not document deletion. It remains supported.
- Delete: self or active Admin, preserving required cleanup behavior. Office ownership alone does not authorize deleting someone else's relationship.

| Check | Result / evidence |
|---|---|
| Rule changed | YES, only follower matches/scoped helpers |
| Production Rules deployed | YES, Firestore Rules only, no force |
| Anonymous enumeration | DENIED: Production403 and Emulator |
| Unauthorized authenticated enumeration | DENIED: Emulator; no new Production test account created |
| Own follow read | PASS, including missing isAdmin and missing profile document cases |
| Follow | PASS, Emulator + installed app |
| Unfollow | PASS, Emulator + installed app |
| Follow state | PASS, live app button changed then returned |
| Follower count | PASS, read-only stored/source comparison for5 offices |
| Create for another UID | DENIED |
| Delete another UID | DENIED |
| Malformed/unknown-field write | DENIED |
| UID/officeId/createdAt mutation | DENIED |
| Office cards / featured offices / office details | PASS, summary source preserved; installed office route/card smoke |
| Office counter Functions | PASS, unchanged code/deployments, actual follow count transition |
| Required Admin behavior | PASS, Emulator active Admin allowed, blocked Admin denied |
| Security Emulator tests | PASS,32 new focused cases |
| Security blocker remaining for this repair | NO |

Production acceptance used one normal app follow/unfollow on an existing non-owned office. State changed follow → unfollow and the server-maintained count changed0 →1 →0, matching the source at both checks. All5 current offices’ stored follower counts matched active source counts. No manual Firestore/RTDB edits or test property/message publication.

Duplicate behavior: current client reuses an existing legacy relationship or deterministic officeId_UID document. Repeated identical writes to that document produce one row; unchanged event contribution produces no counter delta. For compatibility, the Rule does not globally enforce unique(officeId,userId) across arbitrary different legacy document IDs. That pre-existing integrity limitation is documented, not presented as a uniqueness guarantee; imposing a new ID contract on old clients is separate work. Scoped audit JSON score4: [security-audit.json](pre-release-security-ui/security-audit.json).

## LOAD MORE UI

Root cause: the catalog ListView ended with fixed EdgeInsets.all(16) and no bottom system inset. Under edge-to-edge its final button could scroll into the Android navigation region. Repository text inventory found other uses of “عرض المزيد”, including office description expansion and other lists. The demonstrated pagination overlap was specifically AllPropertiesScreen; unrelated widgets were not redesigned.

Screen/widget: lib/screens/all_properties_screen.dart, catalog ListView containing OutlinedButton.icon('عرض المزيد'). Dart change: bottom padding now `16 + MediaQuery.viewPaddingOf(context).bottom`; horizontal/top spacing remains16. No query, cursor, page size, button styling, loading logic or end-of-results logic changed.

| UI acceptance | Result |
|---|---|
| Real system bottom inset used | YES |
| Strategy | existing design spacing + MediaQuery.viewPadding.bottom |
| Hard-coded navigation workaround | NO |
| Edge-to-edge preserved | YES |
| Global SystemChrome behavior changed | NO |
| Button design changed | NO |
| Button fully visible | PASS, installed APK screenshot |
| Button tappable | PASS, actual tap loaded next page |
| System navigation overlap | ABSENT |
| Bottom clipping / Overflow | ABSENT in target acceptance; no matching app errors |
| Scroll to bottom | PASS |
| Load More / Next page | PASS:20 first,15 next from current dataset |
| End-of-results behavior | PASS: button absent after terminal page |
| Fewer-than-page/search results | PASS: three complete search results without catalog paging button |
| Search completeness / outside-first-page result | PASS, installed APK found property53 |
| Filter pagination / price ASC / price DESC / views | PASS, existing64-shape regression suite retained |
| Featured/adType/category/office combinations | PASS regression, architecture/query unchanged |
| Loading layout | same inset-protected list; no new overflow observed; no exhaustive transient-frame capture claimed |
| Android real-device acceptance | PASS on authorized CPH2365 with3-button navigation |
| App data preserved | YES |
| iOS shared Safe Area review | PASS |
| iOS physical acceptance | PENDING |
| UI regression | NONE observed in targeted acceptance |

The installed screenshot confirms the full button above the system bar. It is retained privately under pre-release-security-ui/load-more-bottom.png and not embedded here because property cards contain personal information. Gesture-navigation and iPhone layouts use the same dynamic inset; they were reviewed in shared code, not falsely reported as physically tested. No ancestor bottom SafeArea is added; the pushed screen’s Scaffold has no bottom navigation bar, and the app builder adds BlockScope rather than a global SafeArea. Thus no double Safe Area or arbitrary large bottom spacer was introduced. SystemChrome remains unchanged in main.dart. App navigation, cards, colors and button design remain intact.

## FIREBASE REGRESSION

| Feature | Result / scope |
|---|---|
| Structured pagination | PASS,20/page,existing64 queries retained |
| Search completeness | PASS,full text semantics retained |
| Outside-first-page result | PASS,tests + installed search |
| Office counters | PASS,unchanged server code; actual follow0→1→0 and5 office comparisons |
| Property View recount | ABSENT,protected Function implementation unchanged |
| Favorites | PASS,targeted suite/source; existing heart state retained |
| Reels | PASS,targeted suite/source |
| Chat | PASS,targeted suite/source |
| Notifications | PASS,targeted suite/source; owner/Admin follower recipient queries allowed |
| Admin | PASS,security/regression tests; no destructive moderation test |
| Map completeness | PASS,query unchanged; installed map still showed35 properties |
| Major avoidable full reads | NONE added or reopened |

These results describe regression coverage, not fresh exhaustive physical testing of every previously accepted feature. No optimization redesign or architectural migration was performed.

## PRESENCE / ACTIVITY

New Connections preserved: YES. Unique UID counting preserved: YES. Legacy online counting: ABSENT. Activity10-minute throttle: PRESERVED. Heartbeat: ABSENT. Polling: ABSENT. Presence regression: PASS. Activity regression: PASS. Protected source hashes remain unchanged; existing lifecycle/activity tests passed. No Presence or Activity backend/client logic edits.

## QUALITY

flutter analyze: PASS change gate,0 errors and0 new issues;162 existing notices versus165 reference. Full analyzer exits1 for existing warnings/info, not a claimed clean exit0. One redirected analyzer launch stalled; the completed full analysis log and comparison are the evidence used.

Flutter tests:204 PASS, all current tests; reference198. No Flutter test was removed or expectation weakened for this task. Emulator tests:132 unique PASS (100 existing regression cases +32 focused follower cases),1 old skipped. Initial full run passed100+29; the final focused run passed all32 including additional legacy-profile/duplicate cases. Security Rules tests:32 focused follower cases plus retained existing security regressions. The old public-read assertion was updated to assert the repaired denial, not deleted.

APK build: PASS, ONE build,193.5s. Installed as UPDATE: YES. Data preserved: YES—same app UID10424 and firstInstallTime, authenticated office session retained. Android acceptance: PASS targeted. iOS shared-code review: PASS. iOS physical: PENDING.

Version1.0.4+19,package com.andalus.aqar,signing,Firebase project and dependencies unchanged. Built and installed APK SHA256 both d52fda890ccf15ca49234d756bb552782133bd6af7ad9abaa4d879754242fff5. No uninstall/clear data/clear cache/reset.

Files changed in this task: firestore.rules; isolated docs/deploy-audit/deploy.firestore.activity-only.rules; lib/screens/all_properties_screen.dart; test/firestore_query_pagination.integration.cjs; new test/office_followers_security.integration.cjs; local diagnostic/evidence/report files. Other pre-existing working-tree changes preserved.

## PRODUCTION

Firestore Rules changed: YES, office_followers only; duplicate broad match removed and strict scoped validation/read permissions installed. Exact command: `firebase deploy --project aqar-9f3f9 --config firebase.activity-deploy.json --only firestore:rules --non-interactive`. No force. Post-deploy source equals approved file. Ruleset4d10e63b-7a17-4eff-99a1-7c9c7e9cf134; SHA2564e6346a1f48714f261f1d236008a7bfe88a741f995efd3e6d149f33eaa2fbc65.

Functions changed: NO. Indexes changed: NO. RTDB Rules changed: NO. IAM changed: NO manual changes. App Check changed: NO. Production migration/manual data edits/backfill: NO. Normal authorized app follow/unfollow and lifecycle writes occurred during acceptance; they are not manual data repair. The follow relationship remains inactive as designed after unfollow.

Office Functions preserved: YES,all five existing Functions ACTIVE with unchanged updateTimes.33 Firestore indexes preserved: YES,allREADY.12 protected source/config files other than intentionally changed Firestore Rules match prior hashes. Monitoring:7 sampled office-Function log entries over20 minutes,0 errors,untruncated; no observed retry storm or unexpected loop. This is a bounded sample, not an all-time guarantee. Current-process application error check found no unexpected permission/index/overflow/crash matches.

Rollback snapshot: pre-release-security-ui/production-before.rules, previous exact Production ruleset recorded in pre-deploy-gate.json. No rollback required or performed. Only this known snapshot would be used for a necessary scoped rollback; no random rule widening.

Layout cleanup adds0 Firebase reads/writes/listeners. Private follower authorization may require cached Rules user/office document lookups, unlike the old unconditional public allowance; this is authorization overhead, not a new full collection read or client recount.

## DEFERRED — NOT RELEASE BLOCKERS

Arabic full-text search: DEFERRED. Geospatial Map optimization: DEFERRED. Necessary exact-feature full reads: DOCUMENTED. iOS physical acceptance: PENDING. Legacy follower-ID uniqueness contract: documented separate compatibility/integrity follow-up; no migration performed. Final public version decision remains for Release Preparation.

## FINAL

Security blocker remaining for the approved privacy/ownership repair: NO. Load More UI blocker remaining: NO. Major avoidable Firebase read blocker: NO. Presence/Activity preserved: YES. Office counters preserved: YES. Pagination preserved: YES. Android acceptance: PASS.

READY FOR FINAL RELEASE PREPARATION: YES.

STOP. No Commit,Push,version bump,Google Play/App Store upload,TestFlight or public release.
