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
