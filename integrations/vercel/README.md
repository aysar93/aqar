# Vercel compatibility adapter — not deployed

Keep the current production deployment unchanged. In a separate preview checkout,
copy `legacy-ingress.cjs` and the audited `functions/push_*` modules together with
their exact package lock. After Firebase Admin initialization and before the old
`app.post('/send', ...)` body, wire:

```js
const {createLegacyIngress} = require('./legacy-ingress.cjs');
const {internals} = require('./push_bridge_functions');
const bridgeIngress = createLegacyIngress({db,
  dispatch: event => internals.dispatchBridge(event, db)});
// At the start of the existing /send handler:
if (process.env.PUSH_BRIDGE_ENABLED === 'true') return bridgeIngress(req, res);
```

Use the same Firebase test project, protected outbox, event/device claim ledger,
and a dedicated test OneSignal app. Never put OneSignal API credentials in the
client. Keep legacy mode on production until verified trigger provenance and
old/new clients pass the preview matrix. The adapter does not generate an ID
when one is absent: that request cannot be correlated safely and returns 400.
Unknown events return 202 and await the authenticated Firestore trigger; this is
not a claim that an alert was delivered. Public anonymous wakeups are bounded;
only a saved verified event can dispatch. The plan must additionally account for
CDN/forwarded IP policy before production (the local socket may be shared).

Old releases that omit source IDs or notification IDs remain an explicit release
gate until their actual binary payloads are inspected. The adapter is not a way
to trust arbitrary old document writes or to silently drop legacy users.
