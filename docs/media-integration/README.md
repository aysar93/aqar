# Optional booking-feature media integration

The older media worktree contains a media-only change to `lib/bookings/booking_screen.dart`. That booking feature does not exist in current main or this PR checkout. The attached patch preserves the migration delta without importing a separate unfinished feature or changing the older checkout.

The patch routes booking receipt upload/read through the existing MediaStore authenticated broker methods instead of direct client Storage operations. It has **not been applied or compiled against the current main application**, which has no such screen. Apply/reconcile and test it only when the separately maintained booking feature is integrated. Do not treat earlier isolated booking tests as tests of a screen shipped in this PR.

All 26 other previously modified paths are represented in the migration checkout. Their final integration also preserves current-main changes and later media fixes; byte equality with the older worktree is not expected. Existing changes outside this media task remain in the original worktree.

This is a zero-context patch to keep the artifact whitespace-clean. Check it with `git apply --check --unidiff-zero` against the reviewed booking-feature base before applying; reconcile any later feature edits manually. A reverse check against the existing older media worktree passed without modifying it.
