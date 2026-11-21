const {test}=require('node:test');
const assert=require('node:assert/strict');
const {ownerSettlement,refundSettlement,refund}=require('./booking_policy');
const current=()=>({paid:1001,commissionBps:333,commissionBasis:'deposit'});
test('current settlement preserves exact integer rounding and explicit zero',()=>{
  assert.deepEqual(ownerSettlement(current()),{ownerSettled:968,platformCommission:33});
  assert.deepEqual(ownerSettlement({...current(),paid:0,commissionBps:0}),{ownerSettled:0,platformCommission:0});
  assert.deepEqual(ownerSettlement({...current(),paid:Number.MAX_SAFE_INTEGER,commissionBps:10000}),{ownerSettled:0,platformCommission:Number.MAX_SAFE_INTEGER});
  assert.deepEqual(ownerSettlement({...current(),refunded:1,refundStatus:'settled'}),{ownerSettled:967,platformCommission:33});
});
test('unknown legacy money and commission cannot become a zero settlement',()=>{
  for(const key of ['paid','commissionBps','commissionBasis']) {
    const b=current();delete b[key];assert.throws(()=>ownerSettlement(b));
  }
  for(const paid of [null,'1001',NaN,Infinity,-1,1.5,Number.MAX_SAFE_INTEGER+1]) assert.throws(()=>ownerSettlement({...current(),paid}));
  for(const commissionBps of [null,'333',-1,10001,1.5]) assert.throws(()=>ownerSettlement({...current(),commissionBps}));
  for(const refunded of [null,'0',-1,1002,1.5]) assert.throws(()=>ownerSettlement({...current(),refunded}));
  assert.throws(()=>ownerSettlement({...current(),refundStatus:'settled'}));
  assert.throws(()=>ownerSettlement({...current(),commissionBasis:'total'}));
});
test('refund settlement requires known outstanding money within collected payment',()=>{
  const b={paid:1001,refundDue:1001,refunded:0};assert.equal(refundSettlement(b),1001);
  for(const patch of [{paid:null},{paid:'1001'},{refundDue:undefined},{refundDue:'1001'},{refundDue:0},{refundDue:1002},{refunded:undefined},{refunded:1},{refunded:null}]) assert.throws(()=>refundSettlement({...b,...patch}));
});
test('historical malformed cancellation snapshots never calculate refunds',()=>{
  const b={paid:1001,start:172800000,cancellationPolicy:{freeCancellationHours:24,lateRefundPercent:15}};
  assert.equal(refund(b,86400000,false),1001);
  for(const patch of [{paid:'1001'},{paid:null},{start:'172800000'},{cancellationPolicy:{freeCancellationHours:24,lateRefundPercent:150}},{cancellationPolicy:{freeCancellationHours:'24',lateRefundPercent:15}}]) assert.throws(()=>refund({...b,...patch},86400000,false));
});
