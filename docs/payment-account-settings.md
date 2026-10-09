# Shared receiving accounts

The administration settings page and booking settings link open the same editor.
`payment_configuration/shared` is the server-only source of truth, with `methods`
and a monotonically increasing `revision`. `payment_accounts/shared` contains only
currently enabled valid numbers and the revision; authenticated active users may
get this document, but cannot list the collection. Both payment screens subscribe
to it in real time. No client bundle contains the previous receiving account.

Qi accepts 10–16 ASCII digits; Zain Cash accepts an Iraqi local mobile number of
11 ASCII digits beginning with 07. Surrounding whitespace is trimmed. An enabled
empty/invalid number is rejected; a disabled empty number is allowed. Missing
configuration fails closed. Names, administrator identities and change history
are never copied to the customer configuration.

The shared document is a scope boundary: a later scoped override can be added
for bookings or subscriptions with an explicit resolver and corresponding rules.
There is currently one source for both purposes and no implicit asset fallback.

## Authorization and audit

Saving requires an active non-anonymous user whose user document has
`isAdmin: true` AND whose trusted Firebase Auth token has the custom claim
`canManagePaymentAccounts: true`. User document fields cannot grant this claim.
Grant/revoke it only through an independently authorized Firebase Admin operation,
preserving any existing claims. The administrator must refresh their ID token
(or sign in again) after a claim change. No role grant or production write has
been performed by this change.

The callable re-reads the administrator inside the transaction, checks the editor
revision, and atomically writes private configuration, minimal customer projection,
and an append-only `payment_account_audit` record containing actor, timestamp,
before and after. Direct writes to all three collections are denied, including
administrators. Audit reads require the same administrator claim. Concurrent
stale saves return an error instead of overwriting another editor.

## Payment handling

Booking receipt submission and both subscription service paths resolve the shared
configuration in a server transaction. Only Qi/Zain Cash are accepted for new
payments. The screen sends the number displayed when submission began, and a
changed number causes rejection for review before resubmission. Each transaction
stores `paymentAccountSnapshot` with method, number and configuration revision;
the existing `paymentAccount` text remains available for older display code.
Subscription amount and currency are obtained from the actual package on the
server; office and subscription ownership and pending status are verified.
Subscription creation is idempotent by owner/subscription ID and links the payment
atomically. Direct client creation and snapshot editing are denied by rules.

Disabling every method blocks new payment submissions. Already submitted payments
remain readable and can be approved/rejected; booking refunds and cancellations
continue to use the historical booking record. No historical records are migrated.
The former manual subscription option no longer creates a payment outside the two
configured methods. The existing Cloudinary receipt upload flow is retained.

## Release boundary

No Firebase rules, functions, claims, configuration or app have been deployed.
After separate release approval, deploy the callable functions and rules together
with the updated client; older clients create subscription payments directly and
will be rejected by the new rules. Before enabling new payments, an authorized
administrator must configure and verify the receiving numbers in the editor.
Missing configuration intentionally leaves all methods unavailable.

## Validation

Run `flutter test test/payment_accounts_test.dart` and the existing booking Flutter
tests. Run the booking emulator runner under project `demo-aqar` using
`firebase.bookings-test.json`; it includes lifecycle, settings callable and rules
privacy tests, plus the existing Python booking rules tests. Tests use isolated
Firestore/Storage emulators and never production services. The CI workflow runs
these new tests on `feature/bookings` pushes and does not deploy.
