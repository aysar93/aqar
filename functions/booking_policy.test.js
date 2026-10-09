const {test} = require('node:test');
const assert = require('node:assert/strict');
const {overlaps, blocks, money} = require('./booking_policy');
test('overlap includes containment but allows adjacent slots',()=>{
  assert.equal(overlaps({start:10,end:20},{start:20,end:30}),false);
  assert.equal(overlaps({start:10,end:30},{start:15,end:20}),true);
  assert.equal(overlaps({start:10,end:20},{start:5,end:15}),true);
});
test('expired holds release inventory; uploaded payments keep inventory',()=>{
  assert.equal(blocks({status:'held',holdUntil:100},100),false);
  assert.equal(blocks({status:'held',holdUntil:101},100),true);
  assert.equal(blocks({status:'payment_review',holdUntil:1},100),true);
  assert.equal(blocks({status:'confirmed'},100),true);
  for(const status of ['requested','cancelled','rejected','expired','payment_rejected'])assert.equal(blocks({status},100),false);
});
test('amounts are integer dinars and deposit never exceeds total',()=>{
  assert.equal(money(100000,25000),true);
  for(const amounts of [[100,101],[100,0],[-100,10],[100.5,10],[100,NaN]])assert.equal(money(...amounts),false);
});

const {pricingConfig,quote,cancellationPolicy,refund}=require('./booking_policy');
test('offers are integer discounts, expire, and cannot undercut the deposit',()=>{
  const v={price:100000,deposit:20000,offer:{percent:25,until:Date.now()+60000}};
  const q=quote(v,{start:Date.now()+86400000,end:Date.now()+90000000});
  assert.equal(q.total,75000);assert.equal(q.pricing.discountPercent,25);
  assert.equal(quote({...v,offer:{percent:25,until:1}},{}).total,100000);
  assert.throws(()=>quote({...v,deposit:90000},{}));
});
test('shift prices use Baghdad check-in and next-day checkout',()=>{
  const v={price:100,deposit:50,...pricingConfig({pricingMode:'shifts',deposit:50,shifts:[{id:'night',name:'night',checkInMinute:1200,checkOutMinute:480,price:300}]})};
  const start=Date.UTC(2026,10,1,17);
  assert.deepEqual(quote(v,{start,end:start+12*3600000,shiftId:'night'}).total,300);
  assert.throws(()=>quote(v,{start:start+1,end:start+12*3600000+1,shiftId:'night'}));
  assert.throws(()=>quote(v,{start,end:start+11*3600000,shiftId:'night'}));
  assert.throws(()=>quote(v,{start,end:start+12*3600000,shiftId:'unknown'}));
  assert.throws(()=>pricingConfig({pricingMode:'shifts',deposit:50,shifts:[{id:'x',name:'x',checkInMinute:0,checkOutMinute:60,price:40}]}));
});
test('hourly pricing rejects fractions and overflow',()=>{
  const v={price:100,deposit:50,...pricingConfig({pricingMode:'hourly',hourlyPrice:100,deposit:50})};
  assert.equal(quote(v,{start:0,end:3*3600000}).total,300);
  assert.throws(()=>quote(v,{start:0,end:90*60000}));
  assert.throws(()=>quote({...v,hourlyPrice:Number.MAX_SAFE_INTEGER},{start:0,end:2*3600000}));
});
test('refund policy preserves integer dinars, cutoff and owner responsibility',()=>{
  const p=cancellationPolicy({freeCancellationHours:24,lateRefundPercent:15});
  const b={paid:1001,start:48*3600000,cancellationPolicy:p};
  assert.equal(refund(b,24*3600000,false),1001);
  assert.equal(refund(b,24*3600000+1,false),150);
  assert.equal(refund(b,47*3600000,true),1001);
  assert.equal(refund({...b,paid:Number.MAX_SAFE_INTEGER,cancellationPolicy:{...p,lateRefundPercent:33}},24*3600000+1,false),2972375754064527);
  assert.throws(()=>refund({...b,cancellationPolicy:null},0,false));
  assert.throws(()=>cancellationPolicy({freeCancellationHours:-1,lateRefundPercent:100}));
});
test('FCM booking payload retains identifiers needed to open details',()=>{
  const {notificationPushData}=require('./notification_push_data');
  assert.deepEqual(notificationPushData({type:'booking',bookingId:'customer_123'},'notice_1'),{type:'booking',bookingId:'customer_123',notificationId:'notice_1'});
  assert.deepEqual(notificationPushData({type:'property'},'notice_2'),{});
});
