## Live follow-up (2026-10-02)

The project has no Firebase Storage bucket and is on Spark. Function deployment
was rejected because Blaze is required. Do not assume the functions below are live.
Chat images now use the existing Cloudinary image preset; audio uses its video
endpoint (validated with a one-second synthetic WAV upload, HTTP 200). The current
client deletes messages in a Firestore transaction, with server-time authorization
in security rules. These Firestore rules have been published to aqar-9f3f9.
Deletion removes message payloads for both participants; Cloudinary physical asset
cleanup and notification cleanup require a signed backend. Previously delivered
notifications/downloads remain. The prepared server away-reply functions are still
not active on this Spark project.

Recording now uses a long press with a counter and immediate sending on release.
No preview is shown; failed uploads retain a retry/cancel row. Lifecycle changes
cancel recording. The composer places attachments on the left and send/mic on the
right. The header restores the configured logo, falling back to the bundled logo.
The property inquiry is a plain white text button below phone/WhatsApp buttons.
Administrator settings use a persistent SafeArea-protected save button.

The deployment instructions and Storage implementation notes below describe the
optional Firebase backend, which requires activating Storage and Blaze first.

# Chat upgrade

The user and administrator share `ConversationScreen`. Appearance follows the
app's navy and gold palette. Viewing appointments are intentionally excluded.

Implemented: local single-message and whole-history deletion; authenticated
server deletion with a configurable 24-hour default; deleted-message placeholders;
live reply references; property cards from the property details screen and
attachment picker; voice recording with preview, duration limit and retry;
message search; administrator quick replies; account-scoped local text/reply
drafts; Baghdad working hours; typing expiry; and a daily idempotent server reply
outside office hours. Opening loads the latest 50 messages and permits loading
older history. Searching loads the conversation's full history on demand.

Administrator configuration is available from the conversations list and each
administrator conversation, and is stored under
`settings/app_settings.chatPreferences`. Working-hour shifts may cross midnight.
An empty quick-reply row is omitted when saving. Replies can be reordered upward.

## Backend activation

Before distributing the updated app, publish the new Firestore and Storage rules
and these functions together:

```
npx -y firebase-tools@latest deploy --project aqar-9f3f9 --only firestore:rules,storage,functions:deleteChatMessage,functions:chatAwayReply,functions:chatDeletedAttachmentCleanup
```

The app uses default-region callable functions and the existing default Firebase
Storage bucket. Storage cross-service rule evaluation may require granting the
Firebase Rules service access to Firestore when prompted by Firebase deployment.
No production deployment is performed by the tests.

New media is privately scoped to the conversation. Storage download URLs are
bearer URLs; as with any received attachment, a recipient may retain a downloaded
copy. Deletion clears chat content, reply previews, current in-app notification
previews, and the stored new-media object. Cleanup retries on a server trigger.
Old Cloudinary uploads cannot be physically erased without signed Cloudinary
credentials, though their message content is removed. Previously delivered push
notifications cannot be recalled.

Local deletion and drafts stay on the current device and are isolated by account
and conversation. Voice drafts survive upload failure while the screen remains
open; leaving the screen discards unsent recordings. Search does not transcribe
audio. The picker searches the loaded pages of approved properties and allows
loading additional pages. When the sender's phone clock differs, the delete
button may be shown or hidden differently; server time always decides permission.

## Verification

Flutter tests cover draft/history isolation, working hours, deleted previews,
message actions and narrow Arabic layouts. `test/goldens/chat_formal.png` is a
render of the production message widgets. Emulator tests cover Firestore and
Storage authorization and callable/trigger integration, including repeated and
concurrent outside-hours events. `functions/chat_policy.test.js` checks time and
ownership boundaries without network access. Android/iOS microphone permission
descriptions are included; hardware recording and real-device network behavior
still need device testing.

```
flutter test --no-pub test/chat_preferences_test.dart test/chat_message_tile_test.dart test/services/chat_history_preferences_test.dart
node --test functions/chat_policy.test.js
npx -y firebase-tools@latest emulators:exec --only firestore,storage --project demo-aqar --config firebase.chat-test.json "python test/storage_chat_rules_test.py && python test/firestore_chat_rules_test.py && node --test functions/chat_functions.integration.test.js"
```
