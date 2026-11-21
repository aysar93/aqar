// UNWIRED PROPOSAL. Not imported by index.js or booking_functions.js.
// Never deploy/use until migration and legacy-client compatibility are approved.
const fail = message => {throw new Error(message);};
const amount = n => Number.isSafeInteger(n) && n > 0;
function validate(p) {
 if(!p||p.version!==2||p.timeZone!=='Asia/Baghdad'||!amount(p.deposit))fail('سياسة غير صالحة');
 if(!Array.isArray(p.weekendDays)||p.weekendDays.some(d=>!Number.isInteger(d)||d<0||d>6)||new Set(p.weekendDays).size!==p.weekendDays.length)fail('أيام عطلة غير صالحة');
 if(!Array.isArray(p.shifts)||p.shifts.length!==3)fail('ثلاثة تعريفات مطلوبة');
 const kinds=new Set();let active=0;
 for(const s of p.shifts) {
  if(!['morning','evening','full_day'].includes(s.kind)||kinds.has(s.kind)||typeof s.enabled!=='boolean')fail('نوع فترة غير صالح');kinds.add(s.kind);
  if(!s.enabled)continue;active++;
  if(!Number.isInteger(s.startMinute)||s.startMinute<0||s.startMinute>=1440||!Number.isInteger(s.endMinute)||s.endMinute<0||s.endMinute>=1440||![0,1].includes(s.endDayOffset))fail('وقت غير صالح');
  const duration=s.endMinute+s.endDayOffset*1440-s.startMinute;
  if(duration<=0||duration>1440||!amount(s.weekdayPrice)||!amount(s.weekendPrice)||p.deposit>s.weekdayPrice||p.deposit>s.weekendPrice)fail('سعر أو مدة أو عربون غير صالح');
 }
 if(!active)fail('لا توجد فترة مفعلة');return JSON.parse(JSON.stringify(p));
}
function quoteDraft(policy,{kind,start,end}) {
 const p=validate(policy),s=p.shifts.find(s=>s.kind===kind&&s.enabled);
 if(!s||!Number.isSafeInteger(start)||!Number.isSafeInteger(end))fail('طلب غير صالح');
 const local=new Date(start+180*60000);if(!Number.isFinite(local.getTime())||local.getUTCHours()*60+local.getUTCMinutes()!==s.startMinute||local.getUTCSeconds()||local.getUTCMilliseconds()||end-start!==(s.endMinute+s.endDayOffset*1440-s.startMinute)*60000)fail('وقت الطلب لا يطابق الفترة');
 const weekend=p.weekendDays.includes(local.getUTCDay()),total=weekend?s.weekendPrice:s.weekdayPrice;
 return {total,deposit:p.deposit,remaining:total-p.deposit,pricing:{version:2,kind,startMinute:s.startMinute,endMinute:s.endMinute,endDayOffset:s.endDayOffset,dayGroup:weekend?'weekend':'weekday',timeZone:p.timeZone,currency:'IQD'}};
}
function requireOwner(trustedActor,venue){if(!trustedActor||typeof trustedActor.uid!=='string'||!trustedActor.uid.trim()||trustedActor.isBlocked||!venue||trustedActor.uid!==venue.ownerId)fail('للمالك الفعلي فقط');}
module.exports={validate,quoteDraft,requireOwner};
