# Media migration: code review only, no build or deployment

## Production state (20 October 2026)

Five previously public pilot originals now have Firebase references: three banner
images and two property covers. Each cover updates imageUrl and images[0] atomically;
the other gallery entries are preserved. The first cover passed real original
Google Play and App Store catalog/details/reopen checks. Four additional one-image,
one-document batches passed source/target SHA-256, generation and conditional
readback checks. Originals in Cloudinary were retained. Encrypted manifests,
document backups, user details, media bytes and capability URLs remain outside Git.

There are **222 additional public-only classified images** whose current Storage
paths remain denied. They were NOT converted to broken URLs. The candidate rules
allow 227 public-only images, excluding five mixed-use entries from the older
232-entry routing manifest. The other 244 private/mixed/unknown assets stay denied.
The 475 candidate cloud rule cases passed; those are tests, not a rules deployment.

## Application changes

- New image/audio uploads use an authenticated, bounded, idempotent media broker.
  The old Cloudinary upload helper fails explicitly; legacy URL readers remain.
- Private reads verify authentication and revocation at the broker and never mint
  download tokens. Private images do not use the public disk image cache.
- Public widgets use CachedNetworkImage / CachedNetworkImageProvider. Gallery,
  avatars, cards and banners share persistent public caching.
- Banner metadata is no longer discarded when an image prefetch fails offline.
  Failed public widgets retry every five seconds while mounted and refresh on
  resume. Closing the widget cancels retries. Private viewers reload on resume.
- Startup no longer waits indefinitely on optional branding or splash audio.
- Reels/R2 and FCM services, configuration and workflows are unchanged from main.
  Media uploads remain disabled in the existing FCM staging mode.

## Cleanup safety and remaining limitation

Clients remove references, never directly delete shared Storage objects. An
authenticated owner can request cleanup; duplicate requests share a stable ID.
The separate server queue acknowledges retained bytes, not successful deletion.

`media_cleanup_policy.js` only permits physical deletion with complete coverage
of every reference writer, an exclusive writer barrier, complete zero references,
no pending uploads, verified encrypted recovery, a stable reference revision and
an exact GCS generation. Tests cover sharing, reference changes during backup,
in-flight uploads, replacement generations and missing writer coverage.

**Production automatic garbage collection is not enabled or proven.** Legacy
clients cannot honor a new transactional tombstone contract. Do not replace this
barrier with a periodic scan, or declare physical deletion complete. Keep imported
originals and unproven orphans retained. A deployment design covering all writers
is required before enabling deletion. Queue creation itself does not solve that.

## Separate deployment/build prerequisites

This PR must not be merged or deployed automatically. No APK/AAB/IPA, Codemagic,
store submission or CI build is part of this task. Commits use `[skip ci]`;
existing workflow source is unchanged. Do not dispatch any workflow.

- Review and publish the separately tested Storage candidate only in the next
  authorized deployment task. Verify live access before converting the remaining
  222 images in small conditional batches with encrypted field backups.
- `firebase.media.json` describes a **separate** media functions codebase, not the
  FCM/default codebase. `media-server/` includes its handlers; no JSON credentials.
- Supply MEDIA_STORAGE_BUCKET explicitly to that server, scoped workload identity
  IAM, request limits and budget monitoring. Do not grant broad administrator roles.
- The next application build must explicitly supply MEDIA_STORAGE_BUCKET,
  MEDIA_UPLOAD_URL, MEDIA_PRIVATE_READ_URL and optionally MEDIA_CLEANUP_URL.
  Missing endpoints fail closed/retain bytes; they do not silently use Cloudinary.
- Firestore media validator changes are a separate candidate based on current
  main; no existing FCM rule changes are replaced or published by this PR.
- Keep old Cloudinary upload configuration and originals. Continue append-only
  delta inventory/backups keyed by asset_id + version; do not overwrite a newer
  owner upload with an old migration mapping. Cloudinary quota risk remains.

## Verification boundaries

Existing real Android/iPhone private access, session expiry, revocation, restore,
legacy upload and public reader tests remain historical evidence. They were not
rerun merely to increase counts. New Dart widget/HTTP tests are not device tests.
New cache/retry code has not passed a newly installed iOS/Android application test:
this task forbids building an application bundle. Verify those changed paths on
both real devices in the separately authorized build/test task.

Rollback restores only the exact approved media fields under updateTime CAS after
checking that the current media fields still equal this migration's after values.
Preserve views and unrelated owner edits; stop on ambiguous responses or changed
media. Never delete a Cloudinary or imported Firebase original during rollback.

References for avoiding unintended CI builds:
[GitHub skip instructions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs),
[Codemagic automatic triggers](https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically/).
