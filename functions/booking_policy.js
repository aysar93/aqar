const BLOCKING = new Set(['held', 'payment_review', 'cancel_requested', 'confirmed', 'arrived', 'completed']);
function overlaps(a, b) { return a.start < b.end && b.start < a.end; }
function blocks(b, now) { return BLOCKING.has(b.status) && (b.status !== 'held' || b.holdUntil > now); }
function money(total, deposit) { return Number.isSafeInteger(total) && total > 0 && Number.isSafeInteger(deposit) && deposit > 0 && deposit <= total; }
function cancellationPolicy(p) {
  if (!p || !Number.isInteger(p.freeCancellationHours) || p.freeCancellationHours < 0 || p.freeCancellationHours > 8760 || !Number.isInteger(p.lateRefundPercent) || p.lateRefundPercent < 0 || p.lateRefundPercent > 100) throw Error('سياسة إلغاء غير صالحة');
  return {freeCancellationHours:p.freeCancellationHours,lateRefundPercent:p.lateRefundPercent};
}
function pricingConfig(d) {
  const mode = d.pricingMode || 'fixed';
  if (!['fixed','shifts','hourly'].includes(mode)) throw Error('نوع تسعير غير صالح');
  const shifts = mode === 'shifts' ? d.shifts : [];
  if (mode === 'shifts' && (!Array.isArray(shifts) || !shifts.length || shifts.length > 12)) throw Error('أضف شفتاً');
  const ids = new Set();
  for (const s of shifts) {
    if (!s || typeof s.id !== 'string' || !/^[a-zA-Z0-9_-]{1,40}$/.test(s.id) || ids.has(s.id) || typeof s.name !== 'string' || !s.name.trim() || s.name.length > 100 || !Number.isInteger(s.checkInMinute) || s.checkInMinute < 0 || s.checkInMinute >= 1440 || !Number.isInteger(s.checkOutMinute) || s.checkOutMinute < 0 || s.checkOutMinute >= 1440 || !money(s.price,d.deposit)) throw Error('شفت غير صالح');
    ids.add(s.id);
  }
  if (mode === 'hourly' && !money(d.hourlyPrice,d.deposit)) throw Error('سعر الساعة غير صالح');
  return {pricingMode:mode,shifts:shifts.map(s=>({id:s.id,name:s.name.trim(),checkInMinute:s.checkInMinute,checkOutMinute:s.checkOutMinute,price:s.price})),hourlyPrice:mode==='hourly'?d.hourlyPrice:null};
}
function quote(v, d) {
  let total = v.price, pricing = {mode:v.pricingMode || 'fixed'};
  if (pricing.mode === 'hourly') {
    const minutes = (d.end-d.start)/60000;
    if (!Number.isInteger(minutes) || minutes < 60 || minutes % 60) throw Error('اختر ساعات كاملة');
    total = v.hourlyPrice * (minutes/60); pricing = {...pricing,hours:minutes/60,hourlyPrice:v.hourlyPrice};
  } else if (pricing.mode === 'shifts') {
    const s = v.shifts.find(s=>s.id === d.shiftId);
    if (!s) throw Error('اختر شفتاً');
    // Baghdad UTC+03:00; all venue schedules use this timezone, not the device zone.
    const local = new Date(d.start + 180*60000);
    const duration = ((s.checkOutMinute-s.checkInMinute+1440)%1440 || 1440)*60000;
    if (local.getUTCHours()*60+local.getUTCMinutes() !== s.checkInMinute || local.getUTCSeconds() || local.getUTCMilliseconds() || d.end-d.start !== duration) throw Error('وقت الشفت غير صالح');
    total = s.price; pricing = {...pricing,...s,timeZone:'Asia/Baghdad'};
  }
  if(v.offer && Number.isInteger(v.offer.percent) && v.offer.percent>=0 && v.offer.percent<=50 && v.offer.until>=Date.now()) {
    pricing={...pricing,priceBeforeDiscount:total,discountPercent:v.offer.percent};
    total=Number(BigInt(total)*BigInt(100-v.offer.percent)/100n);
  }
  if (!money(total,v.deposit)) throw Error('مبلغ غير صالح');
  return {total,pricing};
}
function refund(b, now, cancelledByOwner) {
  const p = b.cancellationPolicy;
  if (!p) throw Error('الحجز القديم يحتاج سياسة تسوية معتمدة');
  const percent = cancelledByOwner || now <= b.start-p.freeCancellationHours*3600000 ? 100 : p.lateRefundPercent;
  return Number(BigInt(b.paid)*BigInt(percent)/100n);
}
module.exports = { overlaps, blocks, money, pricingConfig, quote, cancellationPolicy, refund };
