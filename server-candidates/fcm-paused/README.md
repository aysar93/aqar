# Paused keyless notification server candidate

This is a separate, reviewable server artifact. It has not replaced the live
`notification-server` deployment or its `/send` endpoint.

The isolated Preview uses `aqar-fcm-test-20261014` and short-lived Vercel OIDC /
Google Workload Identity Federation credentials. No legacy JSON credential or
OneSignal API key is read by the new authentication path. Google STS performs
cryptographic verification; the application adds immutable team/project and
environment checks before token exchange. No JSON keys were created.

The `production-paused` profile accepts only the production Vercel project,
production environment and `aqar-push-vercel` identity. Production federation,
environment changes, deployment and domain promotion require separate approval.

Every valid request checks for `paused`, `percent=0`, empty recipient lists and
`legacyIngressCoordinated=false`. Missing/changed configuration fails closed.
The old HTTP envelope can only wake an existing protected Firestore event; it
does not establish a sender, recipient or message. Missing IDs return 400,
unknown/unverified IDs 202, and `handled` is not a provider receipt.

`npm ci --ignore-scripts`, then Node 24 `npm test` runs only the new bootstrap
security tests. Existing device/bridge tests are not duplicated here.

The copied bridge modules are the already validated shared implementation.
Production entry and WIF bootstrap are new. Source hashes and limited Preview
evidence are linked from `docs/fcm-keyless-server-final-2026-10-17-ar.md`.

The rate limiter uses the socket address conservatively; on Vercel it can be
shared and is not per-user isolation. It does not replace perimeter abuse
controls or a budget limit. Eventarc delivery does not depend on HTTP wakeups.

For an auth-independent paused recovery artifact, see the sibling
`fcm-paused-maintenance` directory. It never calls Firebase or a provider.
