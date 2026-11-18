# Media production components — 21 October 2026

This phase explicitly authorizes Firebase media backend/rule publication and public-only reference batches. It does not authorize mobile builds, Codemagic, store updates, main merge, Cloudinary deletion or changes to FCM/R2.

## Live components

Project `aqar-9f3f9`, bucket `aqar-9f3f9-media-canary`, region `us-central1`.
Three separate Gen2 HTTP functions: `uploadMedia`, `readPrivateMedia`, `requestMediaCleanup`. Each uses a maximum of one instance, concurrency one, 256 MiB, 60-second timeout, dedicated `aqar-media-runtime` identity and an explicit bucket. The public HTTPS ingress requires a Firebase ID token verified with revocation checking inside every handler. No anonymous application operations are accepted.

Storage rules in `storage.media.production.rules` allow exactly 223 reviewed imported public images plus authenticated-broker-created public upload paths. Private, mixed, unresolved and newly unproved imported objects remain denied; all client create/update/delete/list operations remain denied. `.firebaserc` and `firebase.media.json` target only the named media bucket. Never run a blanket project deployment.

Firestore publication was based on the freshly downloaded live source, preserving all unrelated rules and whitespace. Only two media path expressions were extended for new chat image/audio paths. Legacy path alternatives remain accepted. No production chat messages were created to exercise these alternatives: that would trigger notifications. Positive legacy/new write tests ran against the production-derived rules in a demo emulator; read/denial tests also ran against actual published Firestore.

## Identities and authorization boundaries

The dedicated runtime custom permissions are `datastore.entities.get/create/update`, `datastore.databases.get` (needed for transaction begin and empty duplicate commits), and `firebaseauth.users.get` (revocation lookup). Server SDK access is IAM-based and is not narrowed to Firestore collections by client rules; only reviewed handler code writes upload budgets and cleanup requests. No datastore delete permission is granted.

Storage object read is limited to this bucket; object create is conditioned to its new upload/booking receipt prefixes. Runtime has no object delete/update/list permissions and cannot overwrite an existing generation. Public objects are immutable, generation-pinned and token-free. Private objects never receive download tokens.

The dedicated builder temporarily received logging writer, artifact repository writer and source/upload-bucket object viewer. These grants were revoked after the final backend source operations completed. A temporary, service-account-scoped signBlob grant was used to obtain a test session without a JSON key; it was revoked in a finally block. No new administrative JSON keys were created.

## Operations and recovery

Public reference commits use three images at most per batch. Every document write has an updateTime precondition; all references to those selected images in a batch are committed together. Every batch verifies local-original and cloud-object hashes, exact object generation and public access, then rereads changed fields. A copy of the encrypted before/after manifest remains outside Git on two local paths. DPAPI decryption round trips were checked; recovery of the encryption identity must be arranged before moving those backups to another Windows account.

Rollback restores only fields still equal to the batch after-values, under a fresh updateTime condition. It preserves unrelated edits and stops on newer media edits or ambiguous state. No original object is deleted during rollback.

Cleanup is queue-only. A 202 response means retained bytes, not a successful physical deletion. Physical production GC remains disabled until every legacy/new reference writer participates in a proved exclusive barrier and generation/reference recovery checks. Private and unclassified originals are never cleanup candidates.

The final broker accepts missing legacy isBlocked/isClosed fields as the existing rules do, while explicit true/null/nonboolean flags remain rejected. Ten legacy user records and twelve chat records had missing flags; no such record was edited. Isolated regressions cover the compatibility fix.

## Coexistence and next task

Old published apps continue to read ordinary Firebase HTTPS public URLs and to upload new media to Cloudinary. No Cloudinary preset, account or original was modified. Their newly created Cloudinary URLs are retained; there is no deployed automatic continuous delta importer. Recheck new references before each future migration cohort.

The next separately authorized build/test task should consume `config/media.production.json`, then test the newly changed cache/banner/upload/private flows on real Android and iPhone devices. Those device tests were not performed with this code because this task forbids mobile builds. Prior original-store public-link compatibility evidence remains valid; it does not prove that the new code ran on a device. Offline recovery remains bounded by locally cached bytes and cache eviction; no guarantee is made for never-cached media.

## Validation evidence

Local private evidence and encrypted backups are deliberately outside Git. Recorded checks include 962 prepublication Storage rule cases, 471 actual object access checks (223 public hash matches / 248 protected denials), 27 actual production broker cases, eight demo Firestore cases, seven cloud rule-engine cases, six live Firestore read/denial cases, ten Node tests, and six affected Flutter cases. Changed Dart files analyzed without issues. Earlier test failures during narrow IAM propagation were retained and resolved; they are not presented as successful first attempts.

Final migration counts, side-effect monitoring, commit and pull-request metadata are recorded in the task report; do not infer full migration success from this deployment document alone. No new-code native device test, store update, physical GC activation or Cloudinary shutdown is claimed.
