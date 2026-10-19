# Media deletion boundaries

UI deletion removes a Firestore reference. Clients must not physically delete
shared media. `MediaStore.deletePath` therefore retains uploaded objects.

`safe_test_cleanup.py` is restricted to newly generated synthetic fixtures in
`aqar-media-test-20261018-media/migration-tests/<random run>/`. It requires a
complete reference scan, closed clients, stopped writers, a verified encrypted
backup and an exact GCS generation precondition. It rejects the production
project, migrated originals and ordinary uploads. This is a frozen test
rehearsal, not a production garbage collector.

A production cleanup service still needs an authoritative transactional
reference registry and tombstones that all new writers honor. Legacy clients
cannot honor those tombstones. While they remain active, retain originals and
do not infer safety from a periodic Firestore scan. Use an append-only delta
ingestion journal keyed by Cloudinary asset ID + version + resource type;
verify bytes and classify access before proposing an exact URL replacement.
Unknown and private assets remain inaccessible by default. Replacements and
rollbacks must use document update-time preconditions, preserve unrelated
fields and stop on conflicting late legacy writes. Never deploy this document
as a production rule or cleanup policy automatically.

The isolated Storage rules candidate must deny client delete for public and
private objects. Publishing production rules or cutting over production URLs
requires separate final human approval.
