from firestore_reports_rules_test import call, write, unittest
from storage_chat_rules_test import upload, download
import time

class BookingRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for uid in ['customer', 'owner', 'other', 'admin', 'blocked']:
            assert write('users/'+uid, {'isAdmin':uid=='admin', 'isBlocked':uid=='blocked'}, 'SEED', timestamp=None)==200
        assert write('bookings/private', {'customerId':'customer','ownerId':'owner','status':'requested'}, 'SEED', timestamp=None)==200
        assert write('booking_venues/public', {'active':True}, 'SEED', timestamp=None)==200
        assert write('booking_venues/hidden', {'active':False}, 'SEED', timestamp=None)==200

    def test_booking_privacy_and_server_only_mutation(self):
        for uid in ['customer','owner','admin']:
            self.assertEqual(call('/bookings/private',uid),200)
        for uid in [None,'other','blocked']:
            self.assertEqual(call('/bookings/private',uid),403)
        for uid in ['customer','owner','admin']:
            self.assertEqual(write('bookings/private',{'status':'confirmed'},uid,True,timestamp=None),403)
            self.assertEqual(write('booking_venues/fake',{'active':True},uid,timestamp=None),403)

    def test_venues_and_reports(self):
        self.assertEqual(call('/booking_venues/public'),200)
        self.assertEqual(call('/booking_venues/hidden'),403)
        self.assertEqual(call('/booking_venues/hidden','admin'),200)
        self.assertEqual(write('booking_reports/report',{'status':'open','userId':'customer'},'SEED',timestamp=None),200)
        self.assertEqual(call('/booking_reports/report','customer'),403)
        self.assertEqual(call('/booking_reports/report','admin'),200)
        self.assertEqual(write('booking_reports/report',{'status':'resolved'},'admin',True,timestamp=None),200)
        self.assertEqual(write('booking_reports/report',{'userId':'admin'},'admin',True,timestamp=None),403)

    def test_receipts_are_private_immutable_and_only_before_expiry(self):
        self.assertEqual(write('bookings/receipt', {'customerId':'customer','ownerId':'owner','status':'held','holdUntil':int(time.time()*1000)+60000}, 'SEED', timestamp=None),200)
        path='booking_receipts/receipt/customer/123.jpg'
        self.assertEqual(upload(path,'customer','image/jpeg'),200)
        for uid in ['customer','owner','admin']: self.assertEqual(download(path,uid),200)
        for uid in [None,'other','blocked']: self.assertEqual(download(path,uid),403)
        self.assertEqual(upload(path,'customer','image/jpeg'),403)
        self.assertEqual(upload('booking_receipts/receipt/owner/124.jpg','owner','image/jpeg'),403)
        self.assertEqual(upload('booking_receipts/receipt/customer/125.jpg','customer','text/plain'),403)
        self.assertEqual(write('bookings/receipt',{'holdUntil':1},'SEED',True,timestamp=None),200)
        self.assertEqual(upload('booking_receipts/receipt/customer/126.jpg','customer','image/jpeg'),403)

if __name__=='__main__': unittest.main()
