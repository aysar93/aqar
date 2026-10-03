# Current changes release source review

2026-10-04. Repository: aysar93/aqar. Target: main. Version: 1.0.5+20.

This review covers the actual working tree relative to origin/main, not just the
previous acceptance reports. No tracked deletion or rename was found. The remote
and local starting commit were 1c2b301; fetch confirmed neither side was ahead.

## Newly discovered user changes

- Platform-specific Android/iOS store URLs, backward-compatible update model,
  link validation and store-launch error handling.
- External banner URL entry now persists and validates its target.
- Pending office-request/subscription badges and administrator subscription gifts.
  Gift grants re-read authoritative packages and office pointers in a transaction;
  owner-created pending requests cannot impersonate administrative gifts.
- Status-chip constrained-width layout and its regression test.
- Gift and platform-update tests and scoped gift security documentation.

## Previously accepted source included

New multi-connection Presence and unique-UID counting; independent Auth UID
reconciliation; successful-action Activity hooks and ten-minute throttle; explicit
Activity refresh; catalog cursor pagination and complete text search; system-inset
Load More layout; shared favorites; bounded reels/chat/notifications/admin queries;
office summary cards and idempotent incremental counter triggers; restricted
office_followers rules; 33 composite indexes; necessary correctness-preserving
architecturally deferred raw queries. No redesign or backend deployment occurred.

## Changes made during this review

- pubspec version and the two visible manual labels updated to 1.0.5+20 / 1.0.5.
- Activity deployment config now references the current 33-index source instead
  of a stale historical 13-index diagnostic file. No deployment performed.
- Reproducible demo-only emulator config/runner uses current root rules and tests
  both existing protections and new gift permissions.
- Ignore rules keep raw device/Production acceptance evidence and compiled mobile
  packages local. No files were deleted. Historical documents remain historical.

## Exclusions and privacy

447 initial untracked files were reviewed/classified; 405 diagnostic files are
excluded from the commit. These include APK, device screenshots/XML, raw Production
samples/exports, CLI and emulator evidence, historical diagnostic diffs and one-off
Production inspection/backfill scripts. They remain on disk. Required rule sources,
application code, reusable tests and documentation are included. Two changed PNGs
are deliberate test goldens, not build artifacts. Firebase client configuration is
not treated as a private credential. No private key or OAuth/GitHub token was found
in the selected files. Existing support contact strings are application content,
not exported user data. No secret values or user records are reproduced here.

## Verification

- Flutter: all 204 existing tests passed again, plus eight new push-token tests
  passed sequentially. A concurrent test-cache collision was reproduced and
  resolved by sequential execution; no source failure or cache deletion.
- Local Firebase demo emulators: 138 passed; one previously skipped test retained.
- Flutter analyze (all lib/test sources): 162 existing notices, zero errors and
  zero new issues compared with the previous saved analysis. Exit code 1 reflects
  those existing notices; the no-new-issues review gate passes.
- No build, Firebase deploy, Production write, IAM or App Check change.

A new concurrent iOS notification review was also discovered from Git and retained.
Its metadata contains field names/booleans only, no credentials. It documents a
separate APNs provisioning limitation; no notification settings were changed.
Further current-tree changes added independent OneSignal/FCM token persistence,
bounded APNs readiness checks and isolated token-refresh errors. They were reviewed,
analyzed and tested before a follow-up commit. The one-off APNs configuration
script remains local and is excluded, as are any private keys or configuration
verification exports. No script was executed in this task.

## Complete selected-file classification

No Android/iOS native, localization or application asset changes were discovered.
No unexplained or unrelated file is included. Raw evidence classification is local.

| Category | Files |
|---|---:|
| A Flutter/Dart application | 62 |
| D Firebase Rules | 3 |
| E Firebase Functions | 5 |
| F Firebase indexes/config | 5 |
| I Tests (including reference golden images) | 18 |
| J Documentation | 22 |
| K Version/config | 2 |

| File | Classification | Change |
|---|---|---|
| `lib/services/fcm_service.dart` | A Flutter/Dart application | Modified |
| `lib/services/push_token_sync.dart` | A Flutter/Dart application | Added |
| `test/push_token_sync_test.dart` | I Tests | Added |
| `docs/ios-push-review-2026-10-04/repair-status.md` | J Documentation | Added |
| `.gitignore` | K Version/config | Modified |
| `docs/activity-analytics-repair.md` | J Documentation | Modified |
| `docs/activity-final-deploy-audit.md` | J Documentation | Added |
| `docs/activity-predeploy-review.md` | J Documentation | Added |
| `docs/activity-security-audit.json` | J Documentation | Modified |
| `docs/activity-stage4-blocker-review.md` | J Documentation | Added |
| `docs/analytics-aggregation-architecture-report.md` | J Documentation | Added |
| `docs/current-changes-release-review.md` | J Documentation | Added |
| `docs/deploy-audit/deploy.database.rules.json` | D Firebase Rules | Added |
| `docs/deploy-audit/deploy.firestore.activity-only.rules` | D Firebase Rules | Added |
| `docs/deploy-audit/rollback.database.admin-bridge.rules.json` | J Documentation | Added |
| `docs/final-firebase-optimization-closure-report.md` | J Documentation | Added |
| `docs/final-pagination-optimization-acceptance-report.md` | J Documentation | Added |
| `docs/final-pre-release-security-ui-acceptance-report.md` | J Documentation | Added |
| `docs/final-presence-activity-fix-acceptance.md` | J Documentation | Added |
| `docs/firebase-read-optimization-acceptance.md` | J Documentation | Added |
| `docs/firebase-read-optimization-baseline.md` | J Documentation | Added |
| `docs/firestore-read-audit-2026-10-03.md` | J Documentation | Added |
| `docs/full-firebase-optimization-final-acceptance.md` | J Documentation | Added |
| `docs/ios-push-review-2026-10-04/onesignal-platform-metadata.json` | J Documentation | Added |
| `docs/ios-push-review-2026-10-04/report-ar.md` | J Documentation | Added |
| `docs/office-counter-repair-review.md` | J Documentation | Added |
| `docs/office-gifts-acceptance.md` | J Documentation | Added |
| `docs/office-gifts-security-review.json` | J Documentation | Added |
| `firebase.activity-deploy.json` | F Firebase indexes/config | Added |
| `firebase.final-audit-test.json` | F Firebase indexes/config | Added |
| `firebase.final-bridge-test.json` | F Firebase indexes/config | Added |
| `firebase.release-test.json` | F Firebase indexes/config | Added |
| `firestore.indexes.json` | F Firebase indexes/config | Modified |
| `firestore.rules` | D Firebase Rules | Modified |
| `functions/analytics_presence_access.integration.test.js` | E Firebase Functions | Modified |
| `functions/analytics_presence_access.js` | E Firebase Functions | Modified |
| `functions/index.js` | E Firebase Functions | Modified |
| `functions/office_counters.integration.test.js` | E Firebase Functions | Added |
| `functions/office_counters.js` | E Firebase Functions | Added |
| `lib/analytics/screens/activity_users_screen.dart` | A Flutter/Dart application | Modified |
| `lib/analytics/screens/analytics_dashboard_screen.dart` | A Flutter/Dart application | Modified |
| `lib/analytics/services/app_activity_service.dart` | A Flutter/Dart application | Modified |
| `lib/analytics/services/presence_service.dart` | A Flutter/Dart application | Modified |
| `lib/analytics/services/visit_tracking_service.dart` | A Flutter/Dart application | Modified |
| `lib/app_updates/app_update_dialog.dart` | A Flutter/Dart application | Modified |
| `lib/app_updates/app_update_model.dart` | A Flutter/Dart application | Modified |
| `lib/app_updates/app_update_service.dart` | A Flutter/Dart application | Modified |
| `lib/app_updates/app_updates_management_screen.dart` | A Flutter/Dart application | Modified |
| `lib/bottom_sheets/about_sheet.dart` | A Flutter/Dart application | Modified |
| `lib/chat/conversation_screen.dart` | A Flutter/Dart application | Modified |
| `lib/chat/services/chat_service.dart` | A Flutter/Dart application | Modified |
| `lib/chat/utils/message_windows.dart` | A Flutter/Dart application | Added |
| `lib/core/data/document_read_cache.dart` | A Flutter/Dart application | Added |
| `lib/core/data/paged_query.dart` | A Flutter/Dart application | Added |
| `lib/core/data/property_catalog_query.dart` | A Flutter/Dart application | Added |
| `lib/core/data/property_text_search.dart` | A Flutter/Dart application | Added |
| `lib/core/data/shared_stream.dart` | A Flutter/Dart application | Added |
| `lib/office/screens/followers/office_followers_screen.dart` | A Flutter/Dart application | Modified |
| `lib/office/screens/office_profile_screen.dart` | A Flutter/Dart application | Modified |
| `lib/office/screens/offices_screen.dart` | A Flutter/Dart application | Modified |
| `lib/office/screens/properties/office_properties_screen.dart` | A Flutter/Dart application | Modified |
| `lib/office/screens/reviews/office_reviews_screen.dart` | A Flutter/Dart application | Modified |
| `lib/office/screens/statistics/office_statistics_screen.dart` | A Flutter/Dart application | Modified |
| `lib/office/screens/subscription/office_subscription_screen.dart` | A Flutter/Dart application | Modified |
| `lib/office/services/office_detail_queries.dart` | A Flutter/Dart application | Added |
| `lib/office/services/office_follower_service.dart` | A Flutter/Dart application | Modified |
| `lib/office/services/office_review_service.dart` | A Flutter/Dart application | Modified |
| `lib/office/services/office_service.dart` | A Flutter/Dart application | Modified |
| `lib/office/services/office_statistics_service.dart` | A Flutter/Dart application | Modified |
| `lib/office/services/office_subscription_gift_service.dart` | A Flutter/Dart application | Added |
| `lib/office/widgets/office_card.dart` | A Flutter/Dart application | Modified |
| `lib/reels/screens/reels_screen.dart` | A Flutter/Dart application | Modified |
| `lib/reels/services/reel_service.dart` | A Flutter/Dart application | Modified |
| `lib/screens/add_property/add_property_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/add_banner_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/admin_chat_list_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/admin_dashboard.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/notifications_management_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/office_details_admin_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/office_gift_subscription_dialog.dart` | A Flutter/Dart application | Added |
| `lib/screens/admin/office_management_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/office_requests_management_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/office_subscriptions_management_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/property_management_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/property_requests/admin_property_requests_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/users_management_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/admin/widgets/status_chip.dart` | A Flutter/Dart application | Modified |
| `lib/screens/all_properties_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/edit_property/services/edit_property_service.dart` | A Flutter/Dart application | Modified |
| `lib/screens/edit_property_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/favorites_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/home_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/notifications_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/pending_properties.dart` | A Flutter/Dart application | Modified |
| `lib/screens/profile_screen.dart` | A Flutter/Dart application | Modified |
| `lib/screens/property_details.dart` | A Flutter/Dart application | Modified |
| `lib/screens/publisher_properties_screen.dart` | A Flutter/Dart application | Modified |
| `lib/services/favorites_service.dart` | A Flutter/Dart application | Modified |
| `lib/widgets/home/horizontal_properties_section.dart` | A Flutter/Dart application | Modified |
| `pubspec.yaml` | K Version/config | Modified |
| `test/admin_property_status_chip_test.dart` | I Tests (including reference golden images) | Added |
| `test/analytics/activity_tracking_test.dart` | I Tests (including reference golden images) | Modified |
| `test/analytics/analytics_ui_test.dart` | I Tests (including reference golden images) | Modified |
| `test/analytics/presence_lifecycle_test.dart` | I Tests (including reference golden images) | Modified |
| `test/app_update_platform_test.dart` | I Tests (including reference golden images) | Added |
| `test/firebase_optimization_closure_test.dart` | I Tests (including reference golden images) | Added |
| `test/firebase_read_optimization_test.dart` | I Tests (including reference golden images) | Added |
| `test/firestore_activity_rules_test.py` | I Tests (including reference golden images) | Modified |
| `test/firestore_office_gift_rules_test.py` | I Tests (including reference golden images) | Added |
| `test/firestore_query_pagination.integration.cjs` | I Tests (including reference golden images) | Added |
| `test/goldens/activity_dashboard.png` | I Tests (including reference golden images) | Modified |
| `test/goldens/activity_users.png` | I Tests (including reference golden images) | Modified |
| `test/office_followers_security.integration.cjs` | I Tests (including reference golden images) | Added |
| `test/office_subscription_gift_test.dart` | I Tests (including reference golden images) | Added |
| `test/run_firebase_tests.cjs` | I Tests (including reference golden images) | Added |
| `test/structured_catalog_pagination.integration.cjs` | I Tests (including reference golden images) | Added |
| `test/structured_catalog_pagination_test.dart` | I Tests (including reference golden images) | Added |
