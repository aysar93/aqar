const { validate: validateV2, quoteDraft: quoteV2 } = require('./booking_pricing_v2_draft');
const BLOCKING = new Set(['held', 'payment_review', 'cancel_requested', 'confirmed', 'arrived', 'completed']);
function overlaps(a, b) { return a.start < b.end && b.start < a.end; }
function blocks(b, now) { return BLOCKING.has(b.status) && (b.status !== 'held' || b.holdUntil > now); }
function money(total, deposit) { return Number.isSafeInteger(total) && total > 0 && Number.isSafeInteger(deposit) && deposit > 0 && deposit <= total; }
function cancellationPolicy(p) {
  if (!p || !Number.isInteger(p.freeCancellationHours) || p.freeCancellationHours < 0 || p.freeCancellationHours > 8760 || !Number.isInteger(p.lateRefundPercent) || p.lateRefundPercent < 0 || p.lateRefundPercent > 100) throw Error('سياسة إلغاء غير صالحة');
  return {freeCancellationHours:p.freeCancellationHours,lateRefundPercent:p.lateRefundPercent};
}
const V2_LABELS = { morning: 'الفترة الصباحية', evening: 'الفترة المسائية', full_day: 'اليوم الكامل' };
function venueDeposit(v) {
  if (!v || typeof v !== 'object') return null;
  const v1 = Number.isSafeInteger(v.deposit) && v.deposit > 0 ? v.deposit : null;
  const isV2 = v.pricing && typeof v.pricing === 'object' && v.pricing.version === 2;
  const v2 = isV2 && Number.isSafeInteger(v.pricing.deposit) && v.pricing.deposit > 0 ? v.pricing.deposit : null;

  if (v1 !== null && v2 !== null) {
    if (v1 !== v2) throw Error('تعارض بين عربون المكان وعربون التسعير المتقدم');
    return v1;
  }
  if (v2 !== null) return v2;
  if (v1 !== null) return v1;
  return null;
}
function pricingConfig(d) {
  if (d.pricing && typeof d.pricing === 'object' && d.pricing.version === 2) {
    const deposit = venueDeposit(d) ?? (d.pricing.deposit ?? d.deposit);
    const validated = validateV2({ ...d.pricing, deposit });
    const shifts = validated.shifts.filter(s => s.enabled).map(s => ({
      id: s.kind,
      name: (typeof s.name === 'string' && s.name.trim()) ? s.name.trim() : (V2_LABELS[s.kind] || s.kind),
      checkInMinute: s.startMinute,
      checkOutMinute: s.endMinute,
      endDayOffset: s.endDayOffset,
      weekdayPrice: s.weekdayPrice,
      weekendPrice: s.weekendPrice,
      price: Math.min(s.weekdayPrice, s.weekendPrice),
    }));
    return { pricingMode: 'shifts', pricing: validated, shifts, hourlyPrice: null };
  }
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
  if (v.pricing && typeof v.pricing === 'object' && v.pricing.version === 2) {
    const v2 = quoteV2({ ...v.pricing, deposit: v.pricing.deposit ?? v.deposit }, { kind: d.shiftId || d.kind, start: d.start, end: d.end });
    total = v2.total;
    pricing = { ...v2.pricing, id: v2.pricing.kind, mode: 'shifts' };
  } else if (pricing.mode === 'hourly') {
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
  const effectiveDeposit = venueDeposit(v);
  if (!effectiveDeposit || !money(total, effectiveDeposit)) throw Error('مبلغ غير صالح');
  return { total, pricing, deposit: effectiveDeposit };
}
function refund(b, now, cancelledByOwner) {
  const p = cancellationPolicy(b.cancellationPolicy);
  if (!Number.isSafeInteger(b.paid) || b.paid < 0 || !Number.isSafeInteger(b.start) || !Number.isSafeInteger(now)) throw Error('الحجز القديم يحتاج بيانات مالية معتمدة');
  const percent = cancelledByOwner || now <= b.start-p.freeCancellationHours*3600000 ? 100 : p.lateRefundPercent;
  return Number(BigInt(b.paid)*BigInt(percent)/100n);
}
// Never infer an unknown historical payment or commission as zero. Current
// bookings omit refunded until cancellation; only that no-refund shape defaults.
function ownerSettlement(b) {
  const refunded = b.refunded === undefined && (b.refundStatus === undefined || b.refundStatus === 'none') ? 0 : b.refunded;
  if (!Number.isSafeInteger(b.paid) || b.paid < 0 ||
      !Number.isSafeInteger(refunded) || refunded < 0 || refunded > b.paid ||
      !Number.isInteger(b.commissionBps) || b.commissionBps < 0 || b.commissionBps > 10000 ||
      b.commissionBasis !== 'deposit') throw Error('الحجز القديم يحتاج بيانات مالية وعمولة معتمدة قبل التسوية');
  const collected = b.paid - refunded;
  const platformCommission = Number(BigInt(collected) * BigInt(b.commissionBps) / 10000n);
  return {ownerSettled:collected-platformCommission,platformCommission};
}
function refundSettlement(b) {
  if (!Number.isSafeInteger(b.paid) || b.paid < 0 || !Number.isSafeInteger(b.refundDue) || b.refundDue <= 0 || b.refundDue > b.paid || b.refunded !== 0) throw Error('الحجز القديم يحتاج بيانات استرداد معتمدة قبل التسوية');
  return b.refundDue;
}

function resolveBookingRecipients(booking, options = {}) {
  const { customerId, ownerId, status, refundStatus } = booking || {};
  const reviewers = Array.isArray(options.reviewers) ? options.reviewers : [];
  const admins = Array.isArray(options.admins) ? options.admins : [];

  const recipients = new Set();
  if (customerId && typeof customerId === 'string') recipients.add(customerId);
  if (ownerId && typeof ownerId === 'string') recipients.add(ownerId);

  switch (status) {
    case 'payment_review':
      // Only finance reviewers review payment receipts. Do NOT flood general admins.
      for (const r of reviewers) recipients.add(r);
      break;

    case 'cancel_requested':
      // Cancellation during review requires both finance and admin awareness.
      for (const r of reviewers) recipients.add(r);
      for (const a of admins) recipients.add(a);
      break;

    case 'cancelled':
      // If a refund is due, notify reviewers to process settlement.
      if (refundStatus === 'pending') {
        for (const r of reviewers) recipients.add(r);
      }
      break;

    case 'confirmed':
    case 'held':
    case 'requested':
    case 'rejected':
    case 'expired':
    case 'payment_rejected':
    case 'arrived':
    case 'completed':
    default:
      // Normal lifecycle: Customer and Owner only.
      // Do NOT send confirmation or routine events to reviewers or general admins.
      break;
  }

  return Array.from(recipients);
}

function toEnglishDigits(input) {
  return String(input)
    .replace(/[\u0660-\u0669]/g, ch => String.fromCharCode(ch.charCodeAt(0) - 0x0660 + 48))
    .replace(/[\u06F0-\u06F9]/g, ch => String.fromCharCode(ch.charCodeAt(0) - 0x06F0 + 48));
}

function normalizeValidPhone(raw) {
  if (typeof raw !== 'string') return null;
  const cleaned = toEnglishDigits(raw.trim());
  if (!cleaned || cleaned.length > 50) return null;
  if (/[a-zA-Z\u0600-\u06FF]/.test(cleaned)) return null;
  const compact = cleaned.replace(/[\s\-()]/g, '');
  if (/^07[3-9]\d{8}$/.test(compact)) return `+964${compact.slice(1)}`;
  if (/^\+9640?7[3-9]\d{8}$/.test(compact)) {
    const rest = compact.replace(/^\+9640?/, '');
    return `+964${rest}`;
  }
  if (/^009640?7[3-9]\d{8}$/.test(compact)) {
    const rest = compact.replace(/^009640?/, '');
    return `+964${rest}`;
  }
  if (/^\+[1-9]\d{7,14}$/.test(compact)) return compact;
  return null;
}

function validateGuestInput(d, fallbackCustomer = {}) {
  let customerName;
  if (d?.guestName !== undefined) {
    if (typeof d.guestName !== 'string') throw Error('يرجى إدخال اسم الضيف بشكل صحيح');
    const trimmed = d.guestName.trim();
    if (trimmed.length < 2 || trimmed.length > 100) throw Error('يرجى إدخال اسم الضيف بشكل صحيح');
    customerName = trimmed;
  } else {
    customerName = typeof fallbackCustomer.name === 'string' && fallbackCustomer.name.trim()
      ? fallbackCustomer.name.trim()
      : '';
    if (customerName.length < 2) throw Error('يرجى إدخال اسم الضيف بشكل صحيح');
  }

  let customerPhone;
  if (d?.guestPhone !== undefined) {
    const normalized = normalizeValidPhone(d.guestPhone);
    if (!normalized) throw Error('رقم هاتف الضيف غير صالح');
    customerPhone = normalized;
  } else {
    const fallbackPhone = typeof fallbackCustomer.phone === 'string' ? fallbackCustomer.phone.trim() : '';
    const normalized = normalizeValidPhone(fallbackPhone);
    if (!normalized) throw Error('رقم هاتف الضيف غير صالح');
    customerPhone = normalized;
  }

  let guestCount = 1;
  if (d?.guestCount !== undefined) {
    if (!Number.isInteger(d.guestCount) || d.guestCount < 1 || d.guestCount > 100) {
      throw Error('عدد الضيوف غير صالح');
    }
    guestCount = d.guestCount;
  }

  return { customerName, customerPhone, guestCount };
}

module.exports = { overlaps, blocks, money, venueDeposit, pricingConfig, quote, cancellationPolicy, refund, ownerSettlement, refundSettlement, resolveBookingRecipients, normalizeValidPhone, validateGuestInput };
