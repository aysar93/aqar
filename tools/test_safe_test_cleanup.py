import unittest
from safe_test_cleanup import PROJECT, BUCKET, delete_if_unreferenced, contains_reference

class SafetyTests(unittest.TestCase):
    def setUp(self):
        self.calls=[]
        self.run='a'*32
        self.path='migration-tests/'+self.run+'/image.png'
        self.args=dict(project=PROJECT,bucket=BUCKET,path=self.path,run_id=self.run,
            generation='123',documents=[],scan_complete=True,clients_closed=True,
            writers_stopped=True,encrypted_backup_verified=True,
            delete_generation=lambda *x:self.calls.append(x))
    def test_shared_and_encoded_reference_retained(self):
        for ref in [self.path,'gs://'+BUCKET+'/'+self.path,
                    self.path.replace('/','%2F'),self.path.replace('/','%252F')]:
            self.args['documents']=[{'fields':{'image':{'arrayValue':[ref]}}}]
            self.assertFalse(delete_if_unreferenced(**self.args)['deleted'])
        self.assertEqual(self.calls,[])
    def test_every_evidence_gate_fails_closed(self):
        for key in ['scan_complete','clients_closed','writers_stopped','encrypted_backup_verified']:
            args={**self.args,key:False}
            with self.assertRaises(ValueError):delete_if_unreferenced(**args)
        self.assertEqual(self.calls,[])
    def test_production_and_originals_rejected(self):
        for patch in [dict(project='aqar-9f3f9'),dict(bucket='aqar-9f3f9-media-canary'),
                      dict(path='uploads/public/avatar/existing.jpg'),dict(generation='0')]:
            with self.assertRaises(ValueError):delete_if_unreferenced(**{**self.args,**patch})
        self.assertEqual(self.calls,[])
    def test_delete_is_generation_pinned(self):
        self.assertTrue(delete_if_unreferenced(**self.args)['deleted'])
        self.assertEqual(self.calls,[(self.path,'123')])

if __name__=='__main__':unittest.main()
