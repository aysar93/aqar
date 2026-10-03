const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { createHash } = require('node:crypto');

// Existing offices require the approved snapshot initialization. Offices created
// after rollout start begin with an empty source baseline. The initialization
// captures all offices again after the three triggers are ACTIVE.
const ROLLOUT_START = Timestamp.fromDate(new Date('2026-10-03T12:04:23Z'));

function contribution(kind, data) {
  if (!data || typeof data.officeId !== 'string' || !data.officeId.trim() || data.officeId.includes('/')) return null;
  const officeId = data.officeId.trim();
  if (kind === 'properties') {
    return data.status === 'approved' ? { officeId, count: 1, rating: 0 } : null;
  }
  if (kind === 'followers') {
    // Matches OfficeFollowerModel's legacy default; false means unfollowed.
    return data.isActive == null || data.isActive === true ? { officeId, count: 1, rating: 0 } : null;
  }
  if (kind === 'reviews') {
    if ((data.status ?? 'published') !== 'published') return null;
    const value = Number(data.rating);
    return { officeId, count: 1, rating: Math.max(1, Math.min(5, Number.isFinite(value) ? value : 0)) };
  }
  throw new Error('Unknown office metric');
}

function deltas(kind, before, after) {
  const old = contribution(kind, before), next = contribution(kind, after);
  const result = new Map();
  for (const [value, sign] of [[old, -1], [next, 1]]) {
    if (!value) continue;
    const current = result.get(value.officeId) ?? { count: 0, rating: 0 };
    result.set(value.officeId, { count: current.count + sign, rating: current.rating + sign * value.rating });
  }
  return [...result].filter(([, d]) => d.count !== 0 || d.rating !== 0);
}

function timestampFromIso(iso) {
  if (typeof iso !== 'string') throw new Error('Missing server event time');
  const match = iso.match(/^(.*?)(?:\.(\d+))?Z$/);
  if (!match) throw new Error('Invalid server event time');
  return new Timestamp(Math.floor(Date.parse(`${match[1]}Z`) / 1000), Number((match[2] ?? '').padEnd(9, '0').slice(0, 9)));
}

function newer(left, right) {
  // Firestore persists microsecond precision; do not treat discarded nanos as
  // an event after a snapshot that already contains it.
  return left.seconds > right.seconds || (left.seconds === right.seconds && Math.floor(left.nanoseconds / 1000) > Math.floor(right.nanoseconds / 1000));
}

async function applyOfficeEvent(kind, event, db = getFirestore()) {
  const before = event.data?.before?.exists ? event.data.before.data() : null;
  const after = event.data?.after?.exists ? event.data.after.data() : null;
  const changes = deltas(kind, before, after);
  // Important: no database access and no ledger for view/name/reply changes.
  if (!changes.length) return { outcome: 'irrelevant', reads: 0, writes: 0 };
  if (!event.id) throw new Error('Missing server event ID');
  // Deleted snapshots carry their previous updateTime, so use CloudEvent time.
  const revision = after ? event.data.after.updateTime : timestampFromIso(event.time);
  if (!revision) throw new Error('Missing source revision');
  const ledger = db.collection('office_counter_events').doc(createHash('sha256').update(`${kind}:${event.id}`).digest('hex'));
  return db.runTransaction(async transaction => {
    const processed = await transaction.get(ledger);
    if (processed.exists) return { outcome: 'duplicate', reads: 1, writes: 0 };
    const references = changes.map(([id]) => db.collection('offices').doc(id));
    const offices = await Promise.all(references.map(ref => transaction.get(ref)));
    const pending = [];
    for (let i = 0; i < offices.length; i++) {
      const office = offices[i];
      if (!office.exists) continue; // Never recreate a deleted office.
      const data = office.data();
      let baseline = data.officeCounterBaselineAt;
      if (data.officeCounterVersion !== 1 || !baseline) {
        if (!newer(office.createTime, ROLLOUT_START)) {
          throw new Error('OFFICE_COUNTER_BASELINE_PENDING');
        }
        baseline = office.createTime;
      }
      if (!newer(revision, baseline)) continue; // Snapshot already includes it.
      const delta = changes[i][1];
      const initial = data.officeCounterVersion === 1;
      const totals = initial ? data.officeCounterTotals : { propertiesCount: 0, followersCount: 0, reviewsCount: 0, ratingSum: 0 };
      if (initial && (!totals || !Number.isFinite(totals.propertiesCount) || !Number.isFinite(totals.followersCount) || !Number.isFinite(totals.reviewsCount) || !Number.isFinite(totals.ratingSum))) throw new Error('OFFICE_COUNTER_TOTALS_INVALID');
      const patch = {};
      if (!initial) Object.assign(patch, { propertiesCount: 0, followersCount: 0, reviewsCount: 0, ratingSum: 0, rating: 0, officeCounterVersion: 1, officeCounterBaselineAt: baseline });
      const field = { properties: 'propertiesCount', followers: 'followersCount', reviews: 'reviewsCount' }[kind];
      const count = totals[field] + delta.count;
      // Do not clamp an out-of-order intermediate delta: deltas commute.
      patch[field] = Math.max(0, count);
      if (kind === 'reviews') {
        const sum = totals.ratingSum + delta.rating;
        patch.ratingSum = sum;
        patch.rating = count > 0 ? Math.max(1, Math.min(5, sum / count)) : 0;
      }
      patch.officeCounterTotals = { ...totals, [field]: count, ...(kind === 'reviews' ? { ratingSum: patch.ratingSum } : {}) };
      pending.push([references[i], patch]);
    }
    if (!pending.length) return { outcome: 'covered-or-deleted', reads: 1 + offices.length, writes: 0 };
    for (const [ref, patch] of pending) transaction.update(ref, patch);
    transaction.create(ledger, { kind, source: event.document ?? '', processedAt: revision });
    return { outcome: 'applied', reads: 1 + offices.length, writes: 1 + pending.length };
  });
}

const options = document => ({ document, region: 'us-central1', timeoutSeconds: 30, maxInstances: 3, retry: true });
exports.refreshOfficePropertyMetrics = onDocumentWritten(options('properties/{propertyId}'), event => applyOfficeEvent('properties', event));
exports.refreshOfficeFollowerMetrics = onDocumentWritten(options('office_followers/{followerId}'), event => applyOfficeEvent('followers', event));
exports.refreshOfficeReviewMetrics = onDocumentWritten(options('office_reviews/{reviewId}'), event => applyOfficeEvent('reviews', event));
exports.contribution = contribution;
exports.deltas = deltas;
exports.applyOfficeEvent = applyOfficeEvent;
exports.timestampFromIso = timestampFromIso;
