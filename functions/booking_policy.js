const BLOCKING = new Set(['held', 'payment_review', 'confirmed']);
function overlaps(a, b) { return a.start < b.end && b.start < a.end; }
function blocks(b, now) { return BLOCKING.has(b.status) && (b.status !== 'held' || b.holdUntil > now); }
function money(total, deposit) { return Number.isSafeInteger(total) && total > 0 && Number.isSafeInteger(deposit) && deposit > 0 && deposit <= total; }
module.exports = { overlaps, blocks, money };
