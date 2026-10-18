'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {authorize}=require('../server-candidates/legacy-source-validation/source-authorization.cjs');
const comment=()=>({actor:'sender',type:'comment',declaredRecipient:'owner',property:{publisherUid:'owner'},parent:{userId:'sender'}});
const reply=()=>({actor:'sender',type:'reply',declaredRecipient:'owner',parent:{userId:'owner'},reply:{userId:'sender'}});
test('source authorization derives the recipient from persisted source relationships, not legacy claimed fields',()=>{
 for(const make of [comment,reply]){
  assert.equal(authorize(make()).recipient,'owner');
  assert.equal(authorize({...make(),declaredRecipient:'outsider'}).authorized,false);
  assert.equal(authorize({...make(),actor:'forged'}).authorized,false);
 }
 assert.equal(authorize({...comment(),parent:undefined}).authorized,false);
 assert.equal(authorize({...reply(),reply:undefined}).authorized,false);
});
test('hidden or deleted source and parent cannot be revived by a later notification write',()=>{
 for(const state of [{isHidden:true},{isDeleted:true},{deletedAt:1}]){
  assert.equal(authorize({...comment(),parent:{userId:'sender',...state}}).authorized,false);
  assert.equal(authorize({...reply(),parent:{userId:'owner',...state}}).authorized,false);
  assert.equal(authorize({...reply(),reply:{userId:'sender',...state}}).authorized,false);
 }
});
