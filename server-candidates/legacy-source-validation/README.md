# Isolated source-validation overlay

Two files for a future reviewed Functions source integration. Do not deploy this
directory directly and do not replace the deployed eight-Function bundle now.

`source-authorization.cjs` accepts persisted source/parent/property snapshots from
the existing authenticated handler. It does not expose an HTTP endpoint, infer
source IDs from text/time, or read client-supplied authorization fields. It binds
the recipient to the source relationship and rejects hidden/deleted parents or
replies. Administrative explicit sends retain their existing trusted role path.

The candidate adapter keeps canonical event derivation, source-trigger fallback,
inbox persistence and cohort/delivery claims unchanged. Thus older writers can
still create their original comments/replies; the server observes their actual
source paths. This does not prevent the initial acceptance of an unverifiable
legacy inbox document. No deletion/quarantine of such documents is implemented.

Only the new authorization policy was tested. No physical or previous bridge
suite has been rerun, and production compatibility is not re-certified here.
