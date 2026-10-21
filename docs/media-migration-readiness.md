# Media migration readiness — 21 October 2026

## Current production result

All **223 currently proved public images** from the 471-file inventory now have Firebase references: five previously migrated images plus 218 additional images across 73 conditional atomic batches. The remaining **248** files stay protected: 244 previously excluded private/mixed/unresolved files and four formerly public candidates now unproved or without a current reference. No Cloudinary/imported original was deleted. Do not publish the excluded paths just to reduce the remaining count.

A fresh all-descendant scan verified zero old Cloudinary references for the eligible cohort. The 218-image phase changed 74 documents; imageUrl/images[0] consistency passed for 55 affected properties. Some Cloudinary URLs intentionally remain for excluded files and future legacy uploads. There is no deployed continuous delta importer.

## Published components and actual tests

The three independent media HTTP functions are ACTIVE in us-central1 with the dedicated runtime identity. Storage rules permit exactly 223 imported public objects and new public upload paths, deny private imported paths, and deny all client mutations/list operations. Firestore changed only two media path expressions, preserving old chat paths and all unrelated live rules. See [deployment details](media-production-2026-10-21.md).

Verified: 962 cloud Storage rule cases, 471 actual object checks (223 public SHA-256 matches /248 protected denials), 27 production broker cases, eight demo Firestore cases, seven cloud rule cases and six actual Firestore read/denial cases. No production chat writes were sent to test path acceptance because they would trigger notifications. Positive new/legacy write coverage is the demo rule test, not a claimed production write.

The latest affected Flutter suite passed6/6: banner stream recovery, exact public manifest, permanent-denial retry suppression, transient image retry, private account-switch clearing and real local HTTP timeout/recovery. Node passed10/10 top-level tests, including legacy missing-flag compatibility and malformed-flag rejection. Changed Dart source analyzed with no issues. Prior native original-store public URL tests remain evidence; no mobile bundle was built for the newly changed code.

## Code and configuration

All known Cloudinary image/audio upload callers use the authenticated Firebase media broker; old HTTPS readers remain supported. Three remaining public image readers in chat now use the persistent public image path. Banner metadata survives a transient stream error, updates on recovery and still clears on a successful empty list. New code treats missing legacy isBlocked/isClosed flags consistently with live Firestore defaults while rejecting explicit blocked/malformed values. No legacy user/chat document was changed for that fix.

Use `config/media.production.json` as the explicit media define configuration in the separately authorized build/test task. It contains no credential. FCM staging guards remain; FCM/R2/services/workflows were not changed. PR is not merged and no workflow was dispatched.

## Recovery, retention and next-task boundaries

Every batch has an encrypted before/after manifest and independent D-drive copy. Decryption round trips succeeded. Rollback checks current after-values, uses updateTime CAS, restores only affected fields and verifies readback. No migration rollback was needed. DPAPI recovery depends on the original Windows identity; transfer its recovery arrangement before moving backups to another account.

Physical production GC is **disabled**. Cleanup acknowledgements mean queue-only retention. All old/new reference writers must honor a proved exclusive barrier before deletion can be enabled. Imported/private/unclassified originals are never automatic deletion targets. Only dedicated synthetic broker fixtures are eligible for manual test cleanup after reference and generation checks.

Dedicated builder and temporary keyless signer grants are removed after final deployment tests; runtime keeps only its necessary scoped read/create/data permissions. Both new service accounts have zero user-managed keys.

Next: build/test the changed code on real Android/iPhone in a separate task, continue bounded monitoring, and keep Cloudinary available while store versions still upload there. Accepted legacy offline/restart limitations are temporary; local/widget tests do not certify native cache behavior. This is readiness of the executed public cohort and deployed backend, not authorization for store deployment, main merge, physical GC or Cloudinary shutdown.
