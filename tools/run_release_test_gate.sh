#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "Running Verified Release Test Gate (42 test suites)"
echo "=========================================================="

flutter test \
  test/services/splash_startup_test.dart \
  test/services/app_settings_startup_test.dart \
  test/navigation_return_test.dart \
  test/booking_navigation_test.dart \
  test/admin_property_status_chip_test.dart \
  test/firebase_read_optimization_test.dart \
  test/services/property_statistics_service_test.dart \
  test/structured_catalog_pagination_test.dart \
  test/office_subscription_gift_test.dart \
  test/user_blocks_test.dart \
  test/home_auth_layout_test.dart \
  test/iraqi_phone_service_test.dart \
  test/chat_preferences_test.dart \
  test/services/chat_history_preferences_test.dart \
  test/hold_voice_button_test.dart \
  test/real_estate_video_and_reels_test.dart \
  test/reel_model_test.dart \
  test/booking_reels_comments_lifecycle_test.dart \
  test/theme_toggle_drawer_reels_test.dart \
  test/canary_gaps_closure_test.dart \
  test/booking_admin_venue_approval_test.dart \
  test/booking_receipt_integrity_test.dart \
  test/booking_detail_access_test.dart \
  test/booking_details_safety_test.dart \
  test/booking_location_test.dart \
  test/booking_rejection_ui_test.dart \
  test/booking_request_intent_store_test.dart \
  test/booking_media_service_test.dart \
  test/booking_global_killswitch_test.dart \
  test/notification_route_coordinator_test.dart \
  test/push_token_sync_test.dart \
  test/push_registration_policy_test.dart \
  test/push_logout_policy_test.dart \
  test/booking_foreground_notice_test.dart \
  test/payment_accounts_test.dart \
  test/booking_finance_query_test.dart \
  test/booking_receipt_service_test.dart \
  test/booking_ledger_access_test.dart \
  test/theme_switcher_test.dart \
  test/booking_staging_isolation_test.dart \
  test/booking_test_isolation_test.dart \
  test/analytics/presence_project_isolation_test.dart

echo "=========================================================="
echo "✓ All 42 Release Gate Test Suites Passed Successfully!"
echo "=========================================================="
