# Prepared controls, not installed in production

Current decision: retain both historical deployments and Git integration.
The reversible strategy in `docs/fcm-reversible-retirement-final-2026-10-18-ar.md`
supersedes the earlier Git-disconnect/deletion proposal below. Use the gate's
`--reversible` mode for new retirement evidence. No approval for deletion exists.

Current proposed controls are an Ignored Build Step (`exit 0`) and the exact-host
deny rule in `legacy-host-deny.proposed.json`. Neither has been applied. Existing
Firewall is disabled, so enabling the reviewed custom rule is a separately
approved project change; do not enable bot challenges/managed rules or publish
unrelated drafts. The current source and maintenance hostnames are excluded.

Historical preparation, retained for context only (not execution authority):

1. Under separate production approval, disconnect the Vercel project's Git
   integration to block automatic deployment of the legacy repository. Do not
   disconnect GitHub for the account/team or change the application repository.
2. Inventory and disable only this project's deployment hooks. A source file
   setting is not proof that all hooks or privileged manual deployments stopped.
3. The included `git.deploymentEnabled=false` fragment is defense in depth for a
   future reviewed server source integration. Merge it into existing `vercel.json`;
   do not replace rewrites, runtime settings or existing configuration wholesale.
   It does not alter already deployed code or restrict every manual CLI/API call.
4. Manual production builds/promotions must use the approved keyless paused
   source and explicit review. After retiring historical deployments, apply the
   offline gate before declaring retirement complete or requesting canary. Do not claim the
   offline gate is a Vercel platform enforcement mechanism or that it can prevent
   a privileged owner from bypassing operational policy.
5. Preserve the current paused deployment and independent maintenance deployment.
   Only then retire the two historical deployment IDs listed by the gate and
   their historical branch alias. Do not revoke their old keys as a side effect.

No production setting has been changed. Reconnecting Git to the unreviewed
legacy source is not the rollback procedure: promote maintenance instead.

Official configuration: https://vercel.com/docs/project-configuration/git-configuration
