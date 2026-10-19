# Isolated media device test prerequisites

- Bundle: `local.aqar.fullMediaTest`; Firebase project: `aqar-media-test-20261018`.
- Import only the dedicated single-device Ad Hoc profile in the manual signed workflow.
- The active banner query needs the composite index in `test-firestore-indexes.json`. Confirm its state is READY before starting a bounded cloud test window. This file does not deploy anything.
- No store publication, production Firebase changes, FCM changes, or R2 changes are part of these workflows.
- Compilation/signature checks do not establish real-device media behavior. Device operations and cloud evidence must be recorded separately.
