# Isolated booking network harness

These tools are not imported by production entry points. No deploy or build runs
automatically. Project is `demo-aqar`; all service endpoints are loopback.

1. `node tool/booking_network/start-emulators.cjs --run`
2. `node tool/booking_network/functions-proxy.cjs`
3. For a separately approved native Android run, seed a new local fixture with
   `node tool/booking_network/seed-native-fixture.cjs --seed`. Its ignored defines
   file contains only local synthetic login data. Never commit or print it.
4. After approval for native build/install: use flavor `bookingsLocalDiagnostic`, the native
   integration test `integration_test/booking_network_local_test.dart`, and the
   generated fixture copied into the app's private files directory (never embed
   login credentials in APK defines). Reverse ports 5001/9099/8185/9198 over USB as
   needed. Verify the APK's native Firebase config is demo-only before install.

The service harness ran on a physical OPPO CPH2365 / Android 13 with the real
image service and native Functions SDK. The separate original-screen harness
`booking_original_screen_local_test.dart` also ran against loopback emulators.
N3 actual HTTP ingress prefix/abort and the original editor S3 callback window
and fresh-process state recovery have local evidence. See the calling task outputs
`android-local-closure`. This does not close cloud/radio-cut UAT or release acceptance.

Proxy controls (local POST JSON): `/__arm`, `/__release`; state: `/__state`.
`cut` submits only the selected body prefix upstream and closes that request;
records distinguish bytes read by the proxy from bytes submitted upstream.
For N3, `receiver-observer.cjs` separately records actual Emulator HTTP ingress
receipt and abort by trace/requestId; the proxy waits for the receiver receipt
before cutting. This is not proof of handler-body receipt or physical radio timing.
`hold-response` holds a completed Functions response; Firestore requires separate
query/document gates. All controls bind to 127.0.0.1 and cannot target Staging.

SDK smoke runs require an **existing** Firebase JS SDK via environment variable
`BOOKING_FIREBASE_JS_SDK_ROOT`. `--image`, `--hold-image`, and `--cut-chunk` each
exercise a distinct local boundary; they do not invoke Flutter/native SDK.

Known blocker: Storage Emulator returns HTTP 501 for GCS compose used by the
original video finalizer. Do not replace production compose or label a shim as
Firebase support. Actual Staging/radio-cut acceptance and V5 finish remain
separate prerequisites. Native image recovery/render evidence is scoped to
the original editor with synthetic inputs; it is not whole-app acceptance.

Do not export local emulator data or copy raw debug logs containing payloads.
Stop only the processes created by this harness; no Codex/Windows restart.
