from firestore_reports_rules_test import call, write, unittest
from storage_chat_rules_test import upload, download
import time
import urllib.request
import urllib.parse
from storage_chat_rules_test import BASE as STORAGE_BASE

class BookingRules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for uid in ['customer', 'owner', 'other', 'admin', 'reviewer', 'blocked']:
            assert write('users/'+uid, {'isAdmin':uid=='admin', 'isBlocked':uid=='blocked','canReviewBookingPayments':uid=='reviewer'}, 'SEED', timestamp=None)==200
        assert write('bookings/private', {'customerId':'customer','ownerId':'owner','status':'requested'}, 'SEED', timestamp=None)==200
        assert write('booking_venues/public', {'active':True}, 'SEED', timestamp=None)==200
        assert write('booking_venues/hidden', {'active':False}, 'SEED', timestamp=None)==200

    def test_booking_privacy_and_server_only_mutation(self):
        for uid in ['customer','owner','admin','reviewer']:
            self.assertEqual(call('/bookings/private',uid),200)
        for uid in [None,'other','blocked']:
            self.assertEqual(call('/bookings/private',uid),403)
        for uid in ['customer','owner','admin','reviewer']:
            self.assertEqual(write('bookings/private',{'status':'confirmed'},uid,True,timestamp=None),403)
            self.assertEqual(write('booking_venues/fake',{'active':True},uid,timestamp=None),403)

    def test_finance_role_cannot_be_self_assigned(self):
        self.assertEqual(write('users/newfinance',{'isAdmin':False,'isBlocked':False,'accountType':'user','accountMode':'user','canReviewBookingPayments':True},'newfinance',timestamp=None),403)
        self.assertEqual(write('users/customer',{'canReviewBookingPayments':True},'customer',True,timestamp=None),403)
        self.assertEqual(write('users/customer',{'canReviewBookingPayments':True},'admin',True,timestamp=None),403)
        self.assertEqual(call('/booking_venues/hidden','reviewer'),403)

    def test_venues_and_reports(self):
        self.assertEqual(call('/booking_venues/public'),200)
        self.assertEqual(call('/booking_venues/hidden'),403)
        self.assertEqual(call('/booking_venues/hidden','admin'),200)
        self.assertEqual(write('booking_reports/report',{'status':'open','userId':'customer'},'SEED',timestamp=None),200)
        self.assertEqual(call('/booking_reports/report','customer'),403)
        self.assertEqual(call('/booking_reports/report','admin'),200)
        self.assertEqual(write('booking_reports/report',{'status':'resolved'},'admin',True,timestamp=None),200)
        self.assertEqual(write('booking_reports/report',{'userId':'admin'},'admin',True,timestamp=None),403)

    def test_support_and_review_privacy(self):
        self.assertEqual(write('booking_support/ticket', {'userId':'customer','status':'open'}, 'SEED', timestamp=None),200)
        self.assertEqual(write('booking_reviews/verified', {'customerId':'customer','status':'approved','rating':5}, 'SEED', timestamp=None),200)
        for collection in ['booking_support/ticket','booking_reviews/verified']:
            for uid in ['customer','admin']: self.assertEqual(call('/'+collection,uid),200)
            for uid in [None,'owner','other','blocked']: self.assertEqual(call('/'+collection,uid),403)
            for uid in ['customer','admin']: self.assertEqual(write(collection,{'status':'resolved'},uid,True,timestamp=None),403)

    def test_receipts_are_private_immutable_and_only_before_expiry(self):
        self.assertEqual(write('bookings/receipt', {'customerId':'customer','ownerId':'owner','status':'held','holdUntil':int(time.time()*1000)+60000}, 'SEED', timestamp=None),200)
        path='booking_receipts/receipt/customer/123.jpg'
        self.assertEqual(upload(path,'customer','image/jpeg'),200)
        for uid in ['customer','owner','admin','reviewer']: self.assertEqual(download(path,uid),200)
        for uid in [None,'other','blocked']: self.assertEqual(download(path,uid),403)
        self.assertEqual(upload(path,'customer','image/jpeg'),403)
        self.assertEqual(upload('booking_receipts/receipt/customer/130.jpg','customer','image/jpeg',11*1024*1024),403)
        self.assertEqual(upload('booking_receipts/receipt/customer/130.exe','customer','image/jpeg'),403)
        self.assertEqual(upload('booking_receipts/receipt/owner/124.jpg','owner','image/jpeg'),403)
        self.assertEqual(upload('booking_receipts/receipt/customer/125.jpg','customer','text/plain'),403)
        self.assertEqual(write('bookings/receipt',{'holdUntil':1},'SEED',True,timestamp=None),200)
        self.assertEqual(upload('booking_receipts/receipt/customer/126.jpg','customer','image/jpeg'),403)

    def test_subscription_receipts_are_private_and_immutable(self):
        self.assertEqual(write('office_subscriptions/receipt_sub', {'ownerId':'customer','status':'pending'}, 'SEED', timestamp=None),200)
        path='subscription_receipts/receipt_sub/customer/123.jpg'
        self.assertEqual(upload(path,'customer','image/jpeg'),200)
        for uid in ['customer','admin']: self.assertEqual(download(path,uid),200)
        for uid in [None,'other','owner','reviewer','blocked']: self.assertEqual(download(path,uid),403)
        self.assertEqual(upload(path,'customer','image/jpeg'),403)
        self.assertEqual(upload('subscription_receipts/receipt_sub/other/124.jpg','other','image/jpeg'),403)
        self.assertEqual(upload('subscription_receipts/receipt_sub/customer/124.jpg','customer','text/plain'),403)
        self.assertEqual(write('office_subscriptions/receipt_sub', {'status':'active'}, 'SEED', True, timestamp=None),200)
        self.assertEqual(upload('subscription_receipts/receipt_sub/customer/125.jpg','customer','image/jpeg'),403)
        self.assertEqual(download(path,'customer'),200)

    def test_ownership_proof_and_media_are_private_until_review(self):
        self.assertEqual(write('booking_venues/proof', {'ownerId':'owner','verificationStatus':'pending','active':True}, 'SEED', timestamp=None),200)
        proof='booking_ownership_documents/proof/owner/proof.jpg'
        self.assertEqual(upload(proof,'owner','image/jpeg'),200)
        for uid in ['owner','admin']: self.assertEqual(download(proof,uid),200)
        for uid in [None,'customer','reviewer','blocked']: self.assertEqual(download(proof,uid),403)
        self.assertEqual(upload(proof,'owner','image/jpeg'),403)
        self.assertEqual(upload('booking_ownership_documents/proof/customer/proof.jpg','customer','image/jpeg'),403)
        media='booking_media/proof/owner/photo.jpg'
        self.assertEqual(upload(media,'owner','image/jpeg'),403)
        # Seed a pre-existing legacy object via the isolated emulator admin API.
        request=urllib.request.Request(STORAGE_BASE+'?name='+urllib.parse.quote(media,safe=''),data=b'legacy',method='POST',headers={'Authorization':'Bearer owner','Content-Type':'image/jpeg','X-Goog-Upload-Protocol':'raw'})
        with urllib.request.urlopen(request) as response: self.assertEqual(response.status,200)
        self.assertEqual(download(media,None),403)
        self.assertEqual(write('booking_media_reviews/proof_photo.jpg', {'status':'approved'}, 'SEED', timestamp=None),200)
        self.assertEqual(download(media,None),200)
        self.assertEqual(upload('booking_media/proof/owner/bad.mp4','owner','image/jpeg'),403)
        self.assertEqual(upload('booking_media/proof/owner/big.jpg','owner','image/jpeg',11*1024*1024),403)

    def test_v3_banner_images_are_server_only_and_public_only_when_active(self):
        path='booking_media_v3/banners/admin/banner-review.jpg'
        media={'schemaVersion':3,'kind':'banner','provider':'firebase','venueId':'banners','ownerUid':'admin','ownerId':'admin','path':path,'type':'image/jpeg','status':'pending'}
        self.assertEqual(write('booking_media_reviews/banner-review',media,'SEED',timestamp=None),200)
        self.assertEqual(upload(path,'admin','image/jpeg'),403)
        request=urllib.request.Request(STORAGE_BASE+'?name='+urllib.parse.quote(path,safe=''),data=b'jpeg',method='POST',headers={'Authorization':'Bearer owner','Content-Type':'image/jpeg','X-Goog-Upload-Protocol':'raw'})
        with urllib.request.urlopen(request) as response: self.assertEqual(response.status,200)
        self.assertEqual(download(path,'admin'),200)
        self.assertEqual(download(path),403)
        self.assertEqual(write('booking_media_reviews/banner-review',{'status':'approved','bannerId':'v3banner'},'SEED',True,timestamp=None),200)
        self.assertEqual(write('booking_banners/v3banner',{'imageUrl':path,'mediaId':'banner-review','isActive':True},'SEED',timestamp=None),200)
        self.assertEqual(download(path),200)
        self.assertEqual(write('booking_banners/v3banner',{'isActive':False},'SEED',True,timestamp=None),200)
        self.assertEqual(download(path),403)

    def test_v3_video_reservations_review_and_transfer(self):
        venue='v3venue'; path='booking_media_v3/v3venue/owner/video.mp4'
        self.assertEqual(write('booking_venues/'+venue, {'ownerId':'owner','active':True}, 'SEED', timestamp=None),200)
        media={'schemaVersion':3,'kind':'venue','provider':'firebase','venueId':venue,'ownerUid':'owner','ownerId':'owner','path':path,'type':'video/mp4','size':100,'status':'uploading','expiresAt':int(time.time()*1000)+60000}
        self.assertEqual(write('booking_media_reviews/video',media,'SEED',timestamp=None),200)
        self.assertEqual(upload(path,'other','video/mp4'),403)
        self.assertEqual(upload(path,'owner','image/jpeg'),403)
        self.assertEqual(upload(path,'owner','video/mp4',101),403)
        self.assertEqual(upload(path,'owner','video/mp4'),200)
        self.assertEqual(upload(path,'owner','video/mp4'),403)
        self.assertEqual(download(path,'owner'),403)
        self.assertEqual(write('booking_media_reviews/video',{'status':'pending'},'SEED',True,timestamp=None),200)
        self.assertEqual(download(path,'owner'),200)
        self.assertEqual(download(path),403)
        self.assertEqual(write('booking_media_reviews/video',{'status':'approved'},'SEED',True,timestamp=None),200)
        self.assertEqual(download(path),200)
        self.assertEqual(write('users/owner',{'isBlocked':True},'SEED',True,timestamp=None),200)
        self.assertEqual(download(path),403)
        self.assertEqual(write('users/owner',{'isBlocked':False},'SEED',True,timestamp=None),200)
        self.assertEqual(write('booking_venues/'+venue,{'ownerId':'other'},'SEED',True,timestamp=None),200)
        self.assertEqual(download(path),403)
        self.assertEqual(download(path,'owner'),403)
        self.assertEqual(write('booking_media_reviews/video',{'status':'delete_pending'},'SEED',True,timestamp=None),200)
        self.assertEqual(download(path,'admin'),403)
        self.assertEqual(upload('booking_media_v3/v3venue/owner/unreserved.mp4','owner','video/mp4'),403)

if __name__=='__main__': unittest.main()
