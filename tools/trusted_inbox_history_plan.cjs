'use strict';
// Pure, offline plan over lossless Firestore REST document exports.
// Proofs are a separate privileged audit input, never a legacy document flag.
const {createHash}=require('node:crypto');
const canonical=v=>Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v;
const checksum=v=>createHash('sha256').update(JSON.stringify(canonical(v))).digest('hex');
const copy=v=>JSON.parse(JSON.stringify(v));
function planHistory(documents,proofs=[]){
 const seen=new Set(),approved=new Map(),archive=[],history=[],review=[];
 for(const p of proofs){if(approved.has(p.id))throw Error('NON_UNIQUE_PROOF');approved.set(p.id,p);}
 for(const document of documents){
  const id=document.name?.split('/').at(-1);
  if(!id||seen.has(id)||!document.updateTime||!document.fields)throw Error('NON_UNIQUE_OR_UNVERSIONED_EXPORT');seen.add(id);
  const digest=checksum(document),uid=document.fields.userId?.stringValue,proof=approved.get(id);
  archive.push({id,checksum:digest,sourceUpdateTime:document.updateTime,document:copy(document)});
  if(!uid||!proof||proof.checksum!==digest||proof.updateTime!==document.updateTime||proof.uid!==uid||!proof.auditReference||proof.sourceVerified!==true){review.push({id,reason:'source_or_ownership_not_proven'});continue;}
  const fields=copy(document.fields);
  if(!fields.title?.stringValue||!fields.message||!('stringValue'in fields.message)||!fields.createdAt?.timestampValue){review.push({id,reason:'schema_needs_review'});continue;}
  // Per-recipient projection retains the owner's read meaning. The archive
  // retains the entire original shared readBy list without truncation.
  const reads=Array.isArray(fields.readBy?.arrayValue?.values)?fields.readBy.arrayValue.values.filter(x=>x.stringValue===uid).slice(0,1):[];
  if(fields.isRead?.booleanValue===true&&!reads.some(x=>x.stringValue===uid))reads.push({stringValue:uid});
  fields.readBy={arrayValue:{values:reads}};fields.isRead={booleanValue:reads.some(x=>x.stringValue===uid)};fields.isDismissed={booleanValue:false};
  fields.historyAuditReference={stringValue:proof.auditReference};
  history.push({id,userId:uid,sourceChecksum:digest,sourceUpdateTime:document.updateTime,fields});
 }
 return {dryRun:true,deleteOperations:[],archive,history,review,requiresProductionApproval:true};
}
module.exports={checksum,planHistory};
