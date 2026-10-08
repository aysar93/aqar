# Office property featuring

The previous rules allowed owners to change `isFeatured` independently of a subscription and allowed quota consumption independently of a property transition. They already permitted incrementing the counter; a Firestore `unavailable` error does not demonstrate a rules rejection. No production logs or deployed rules were available to establish the cause of that reported availability error.

The client retains its Firestore transaction and now rereads office ownership and subscription eligibility in that transaction. It sets `featuredSubscriptionId` on the property and `lastFeaturedPropertyId` on the subscription. Rules use `getAfter` to require the two writes together: one published property transitions from unfeatured to featured, the matching active office subscription permits featuring, its dates include server request time, and usage increases by exactly one within quota. Property creation and the general owner edit permission cannot bypass the featuring rule. Cancellation neither consumes nor refunds an attempt. Zero or negative maximum retains the existing unlimited convention; a missing legacy usage counter starts at zero.

The feature button requires a currently active subscription with featuring enabled. Technical errors are displayed in Arabic. Existing admin permissions are retained.

## Verification

Run `npm ci --prefix test/firestore`, then:

```sh
npx firebase-tools emulators:exec --only firestore --project demo-aqar --config firebase.reports-test.json "node --test test/firestore/featured_properties.test.cjs && python test/firestore_safety_rules_test.py"
```

The new tests cover atomic consumption, cancellation, exhausted/expired/future/disabled/pending/foreign subscriptions, blocked and foreign callers, unpublished properties, legacy usage, unlimited quota, forged associations, multiple properties per attempt, repeated calls, concurrent transactions on the final attempt, ordinary edits, and admin permissions. The existing safety suite also runs in CI. Flutter analysis and the iOS build run in the existing GitHub workflow; no local Flutter SDK is installed in the editing environment.

## Production rollout

This commit does not deploy Firebase rules or release an app. The new fields must be written by the updated app. Deploying these rules before offices update will reject featuring requests from older app versions, because their transaction does not include those fields. Coordinate the rules deployment with the new app release and require the updated version for office owners before enabling the strict rules. Existing records do not need a data migration. No new Cloud Function is required.

Deploy only the reviewed Firestore rules using the authenticated production environment:

```sh
firebase deploy --only firestore:rules --project aqar-9f3f9
```

Verify on a subscribed office account in Android and iOS: feature, cancel, feature again, exhaust quota, and confirm usage. Investigate service availability separately if `unavailable` persists (network, Firestore status and production logs).
