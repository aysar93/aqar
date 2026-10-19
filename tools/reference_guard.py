"""Conservative cleanup policy for coordinated synthetic writers.

All production deletion stays disabled. Legacy writers that do not participate
in a transactional registry make physical cleanup ineligible, regardless of a
point-in-time reference scan.
"""
def decision(state, action, *, all_writers_coordinated=False):
    if state.get('state') not in ['live','deleting','held','deleted']:
        return 'retain_invalid_state'
    refs=state.get('refs');pending=state.get('pendingUploads')
    if not isinstance(refs,list) or not all(isinstance(x,str) for x in refs):
        return 'retain_invalid_refs'
    if type(pending) is not int or pending<0:
        return 'retain_invalid_uploads'
    if action=='begin_upload':
        return 'allow_conditional_upload_reservation' if state['state']=='live' else 'retain_tombstone'
    if action!='begin_delete':return 'retain_unknown_action'
    if not all_writers_coordinated:return 'retain_uncoordinated_writer'
    if state['state']!='live':return 'retain_tombstone'
    if refs:return 'retain_active_reference'
    if pending:return 'retain_inflight_upload'
    return 'allow_conditional_tombstone'
