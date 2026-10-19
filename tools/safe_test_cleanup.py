"""Fail-closed cleanup primitive for NEW synthetic Q fixtures only.

Not a production garbage collector. Caller must stop all fixture writers,
prove client access is closed, enumerate ALL document references, and persist
an encrypted, verified recovery copy before invoking delete_if_unreferenced.
The generation precondition is mandatory even in the frozen test environment.
"""
import re
from urllib.parse import unquote

PROJECT = 'aqar-media-test-20261018'
BUCKET = PROJECT + '-media'

def contains_reference(value, path):
    if isinstance(value, dict):
        return any(contains_reference(v, path) for v in value.values())
    if isinstance(value, list):
        return any(contains_reference(v, path) for v in value)
    if not isinstance(value, str):
        return False
    # Accept plain object paths, gs:// URLs and encoded Firebase URLs.
    # A substring is deliberately conservative: false positives retain data.
    for _ in range(6):
        if path in value:
            return True
        decoded = unquote(value)
        if decoded == value:
            break
        value = decoded
    return False

def delete_if_unreferenced(*, project, bucket, path, run_id, generation,
                          documents, scan_complete, clients_closed,
                          writers_stopped, encrypted_backup_verified,
                          delete_generation):
    if project != PROJECT or bucket != BUCKET:
        raise ValueError('Only the isolated test project and bucket are allowed')
    if not re.fullmatch(r'[a-f0-9]{32}', run_id):
        raise ValueError('Invalid synthetic run identifier')
    if not path.startswith('migration-tests/' + run_id + '/') or '..' in path:
        raise ValueError('Only fixtures created by this test run may be removed')
    if not str(generation).isdigit() or int(generation) <= 0:
        raise ValueError('Generation must be pinned')
    if not all((scan_complete, clients_closed, writers_stopped,
                encrypted_backup_verified)):
        raise ValueError('Incomplete freeze, scan or recovery evidence')
    if any(contains_reference(d, path) for d in documents):
        return {'deleted': False, 'reason': 'referenced'}
    delete_generation(path, str(generation))
    return {'deleted': True, 'reason': 'unreferenced synthetic fixture'}
