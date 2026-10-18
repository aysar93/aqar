# Isolated retirement overlay — not a deployment bundle

These three JavaScript files are reviewable replacements for the identically
named files in `functions/`. They retire only `sendNotificationToUser` and
`deliverFcmNotification`, retaining their exported interfaces as inert handlers.
No environment value can enable a provider call through these handlers.

Do not deploy this directory or the default Functions codebase wholesale. Both
historical functions were absent from production at inventory time, so no
production deployment is currently necessary for them. Apply this overlay to a
future source integration only with the associated test expectation migration:
first-generation direct-sender success tests describe retired behavior; the
accepted bridge suite covers live delivery. Existing deployment source and
previous successful test suites have deliberately not been modified here.

The current production keyless/paused server and eight deployed push Functions
remain unchanged. Rule candidates and the separate production change list are
in `docs/fcm-ingress-remediation-2026-10-18-ar.md`.
