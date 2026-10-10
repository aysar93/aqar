# Booking Firebase media gateway

The old v3 Storage rules read three different Firestore documents for public reads
(media, owner and venue) and video creates (media, user and venue). Storage permits
two documents per rule evaluation. Staging reproduced both failures with HTTP 403.

## Authorization

`bookingMediaContent` checks live Auth identity (when supplied), blocked users,
canonical media records, publication status, current venue ownership and active
publication references. Pending media is restricted to its owner or an independent
administrator. Approved public media additionally requires an unblocked owner and
an active matching venue/banner. Deleted, rejected and uploading media is denied.
Every Range request rechecks authorization. Already downloaded bytes cannot be
revoked retrospectively.

Legacy venue objects, v3 objects and temporary chunks have no client Storage grants. No public ACL,
signed public URL or Firebase download token is issued. Images still use the
server image decoder/re-encoder and the existing administrative review lifecycle.
The gateway also supports canonical pre-v3 Firebase venue records without rewriting
or deleting historical data. Cloudinary property handling and R2 reels are unchanged.

## Video transport and retries

The reservation keeps the existing 50 MiB maximum and quotas. Authenticated POSTs
to `uploadBookingVideoChunk` send 4 MiB parts; the last part has its exact remaining
size. Each part requires a live, unexpired reservation and current ownership.
Object creation uses generation preconditions. An identical retry succeeds, while
a different payload at the same index returns 409. Private parts cannot be read
through the gateway or client Storage SDK.

`finishBookingVideo` checks all part lengths, composes the object on the server,
checks size and MP4 header, strips download tokens, and rechecks ownership/blocking
in a transaction before marking pending. Repeated finalization succeeds only for
the same authorized owner and already pending/approved record. Cleanup removes
parts and final objects with the existing lifecycle and generation protection.
Video validation retains the existing MP4 header check; this is not a full server
codec/decode validation. Administrative review and Android playback remain required.

The content gateway exposes HEAD and single byte ranges, including suffix ranges.
Streaming responses are bounded to 8 MiB to respect Functions response limits.
Flutter also reads legacy images up to 10 MiB through bounded ranges when needed.
Flutter downloads 4 MiB authenticated ranges into a private temporary file and
uses the native video decoder. The temporary directory is removed on closing the
video view (including failure paths). Abrupt process termination can leave an OS
cache file; no cross-account download URL or public token is generated.

## Deployment

Use an explicit verified staging project:

```powershell
firebase deploy --project aqar-bookings-test-20261009 --config firebase.bookings-staging.json --only 'storage,functions:bookingMediaContent,functions:uploadBookingVideoChunk,functions:finishBookingVideo,functions:cleanupBookingExternalMedia'
```

Do not deploy this branch to production without a separate release decision.
Existing staging APKs using direct v3 Storage access require the updated APK.
The two new gateway functions have maxInstances=5 and concurrency=4; this is not
an overall spending cap.

## Verification

Local policy tests cover publication, blocked owners, ownership transfer, pending
previews, expired reservations and unrelated users. Flutter tests cover project
isolation, reservation namespace validation and the new gateway URLs.
Actual staging tests cover image approval, native Auth sessions, authorization
revocation, chunk retries/conflicts, real MP4 data, ranges, independent reviews,
rejections, ownership transfer, deletion and scheduled physical cleanup. The
user-facing report contains final results and Android evidence for this run.

References: [Storage cross-service limit](https://firebase.google.com/docs/storage/security/rules-conditions#enhance_with_firestore)
and [Functions response limits](https://firebase.google.com/docs/functions/quotas).
