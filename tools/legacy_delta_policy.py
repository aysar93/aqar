"""Pure planning policy; never uploads objects or writes Firestore.

Unknown/private assets never enter a public URL replacement plan. Cloudinary
stays available while released clients can create new versions/references.
"""
from copy import deepcopy

def asset_key(asset):
    return (asset['asset_id'], str(asset['version']), asset['resource_type'])

def replacement_plan(asset, verified, existing_keys):
    key=asset_key(asset)
    if key in existing_keys:
        return {'action':'already_verified','key':key}
    if asset.get('classification')!='public_approved':
        return {'action':'quarantine','key':key}
    if not verified.get('sizeMatches') or not verified.get('sha256Matches'):
        return {'action':'stop_integrity','key':key}
    if not verified.get('publicReadVerified') or verified.get('persistentToken'):
        return {'action':'stop_access','key':key}
    return {'action':'propose_exact_replacement','key':key,
            'old':asset['url'],'new':verified['url']}

def replace_exact(value, old, new):
    if isinstance(value,dict):return {k:replace_exact(v,old,new) for k,v in value.items()}
    if isinstance(value,list):return [replace_exact(v,old,new) for v in value]
    return new if isinstance(value,str) and value==old else deepcopy(value)

def conditional_transition(current, expected_update_time, old, new):
    if current['updateTime']!=expected_update_time:
        return {'action':'conflict_preserve_and_replan'}
    return {'action':'conditional_proposal','expectedUpdateTime':expected_update_time,
            'before':deepcopy(current['fields']),
            'after':replace_exact(current['fields'],old,new)}
