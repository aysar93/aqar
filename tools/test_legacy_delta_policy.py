import unittest
from legacy_delta_policy import asset_key,replacement_plan,conditional_transition,replace_exact

class DeltaPolicyTests(unittest.TestCase):
    def setUp(self):
        self.a=dict(asset_id='synthetic',version=1,resource_type='image',classification='public_approved',url='old')
        self.v=dict(sizeMatches=True,sha256Matches=True,publicReadVerified=True,persistentToken=False,url='new')
    def test_repeat_and_new_legacy_version(self):
        keys={asset_key(self.a)}
        self.assertEqual(replacement_plan(self.a,self.v,keys)['action'],'already_verified')
        a={**self.a,'version':2}
        self.assertEqual(replacement_plan(a,self.v,keys)['action'],'propose_exact_replacement')
    def test_private_unknown_and_unverified_never_public(self):
        for classification in ['private','unresolved',None]:
            self.assertEqual(replacement_plan({**self.a,'classification':classification},self.v,set())['action'],'quarantine')
        for patch in [dict(sizeMatches=False),dict(sha256Matches=False),dict(publicReadVerified=False),dict(persistentToken=True)]:
            self.assertTrue(replacement_plan(self.a,{**self.v,**patch},set())['action'].startswith('stop_'))
    def test_exact_mixed_arrays_and_rollback(self):
        before={'images':['old','old-late','unmapped'], 'nested':{'media':'old'},'status':'approved'}
        after=replace_exact(before,'old','new')
        self.assertEqual(after['images'],['new','old-late','unmapped'])
        self.assertEqual(replace_exact(after,'new','old'),before)
        self.assertEqual(before['nested']['media'],'old')
    def test_late_old_client_writes_stop_cutover_or_rollback(self):
        doc={'updateTime':'later','fields':{'image':'late-cloudinary'}}
        self.assertEqual(conditional_transition(doc,'earlier','old','new')['action'],'conflict_preserve_and_replan')

if __name__=='__main__':unittest.main()
