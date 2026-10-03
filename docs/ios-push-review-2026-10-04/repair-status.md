# iOS push repair status

Local fixes completed:
- OneSignal subscription and FCM token are saved independently.
- iOS FCM registration waits briefly for APNs without blocking OneSignal storage.
- Account changes during token retrieval prevent writes to the previous user.
- Missing tokens never overwrite existing tokens.
- Refresh callbacks catch persistence errors.
- Permission handling isolates provider errors.
- iOS foreground FCM presentation enables alert, badge and sound.

Validation: eight isolated push-token tests passed. No APNs delivery test performed.

APNs key AuthKey_L74V23VW58.p8 was identified from the user-provided folder and screenshot as an Apple Push Notifications service key. Private key was not copied into the repository or displayed. OneSignal setup is prepared but has not been executed: Apple Team ID is still required from the user.

Activation of local code fixes requires a new iOS build. External Apple setup and delivery verification remain outstanding.
