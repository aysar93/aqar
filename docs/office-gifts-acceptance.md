# Office request badges and subscription gifts

Implemented locally on 2026-10-04.

- Dashboard Office Management badge watches pending officeRequests.
- Each office card shows a live pending-subscription count above its name; tapping opens its subscription management.
- Office action menu offers a gift from active existing subscription_packages.
- Gift preview shows office, package, free price, duration, expiry, and replacement/extension behavior.
- Same active package preserves remaining time. Different, expired, or suspended package starts a fresh gift duration.
- Grant transaction rechecks administrator, office owner, authoritative package and current subscription pointer; retires active/suspended subscriptions and saves new gift, office entitlements and owner notification together.
- Price is zero. Payment method is gift and displayed as an administration gift. No payment request is generated.
- Existing pending subscription/payment requests remain for separate review.
- External push uses the existing notification service after commit; the in-app notice is already saved regardless of push delivery.

Validation: six Dart gift business-rule tests and six isolated Firestore emulator authorization tests passed. Targeted Flutter analysis passed. Emulator used demo-aqar, not production.

Activation requires a new application build and publishing the office subscription/package rules changes. No deployment or live notifications performed. Preserve unrelated existing changes in firestore.rules when preparing a deployment; this working tree includes changes from other tasks.

See office-gifts-security-review.json for the scoped security review and inherited issues.
