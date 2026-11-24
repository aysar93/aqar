const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

/**
 * Builds the canonical reel document payload from trusted Firestore property data.
 * Returns null if the property has no video.
 */
function buildPropertyReelPayload(propertyId, propertyData) {
  if (!propertyData) return null;
  const videoUrl = typeof propertyData.videoUrl === 'string' ? propertyData.videoUrl.trim() : '';
  if (!videoUrl) return null;

  const isApproved = propertyData.status === 'approved';
  const title = (propertyData.title || '').trim();
  const description = (propertyData.description || '').trim();
  const price = typeof propertyData.price === 'number'
    ? propertyData.price
    : (Number(propertyData.price) || 0);
  const city = (propertyData.city || '').trim();
  const district = (propertyData.district || propertyData.areaName || '').trim();
  const location = city && district ? `${city} - ${district}` : (city || district);
  const area = typeof propertyData.area === 'number'
    ? propertyData.area
    : (Number(propertyData.area) || 0);

  const images = Array.isArray(propertyData.images) ? propertyData.images : [];
  const firstImage = images.length > 0
    ? String(images[0])
    : (typeof propertyData.imageUrl === 'string' ? propertyData.imageUrl : '');
  const thumbnailUrl = (typeof propertyData.videoThumbnailUrl === 'string' && propertyData.videoThumbnailUrl.trim())
    ? propertyData.videoThumbnailUrl.trim()
    : firstImage;

  const officeId = typeof propertyData.officeId === 'string' ? propertyData.officeId.trim() : '';
  const officeName = typeof propertyData.officeName === 'string' ? propertyData.officeName.trim() : '';
  const officeLogoUrl = typeof propertyData.officeLogoUrl === 'string' ? propertyData.officeLogoUrl.trim() : '';
  const propertyType = typeof propertyData.propertyType === 'string' && propertyData.propertyType.trim()
    ? propertyData.propertyType.trim()
    : 'عقار';

  const tags = [city, district, propertyType].filter(t => t && t.length > 0);

  return {
    title: title,
    description: description,
    videoUrl: videoUrl,
    thumbnailUrl: thumbnailUrl,
    qualityUrls: { auto: videoUrl },
    // Public visibility gate: only approved properties receive 'published' status.
    // Unapproved or pending properties receive 'draft' status so they remain private.
    status: isApproved ? 'published' : 'draft',
    targetType: 'property',
    propertyId: propertyId,
    officeId: officeId,
    category: propertyType,
    tags: tags,
    externalUrl: '',
    ctaLabel: 'عرض العقار',
    isPinned: false,
    isFeatured: propertyData.isFeatured === true,
    isSponsored: false,
    publishAt: propertyData.createdAt || FieldValue.serverTimestamp(),
    sortOrder: 0,
    propertySnapshot: {
      title: title,
      price: price,
      location: location,
      area: area,
      imageUrl: firstImage,
    },
    officeSnapshot: {
      name: officeName,
      logoUrl: officeLogoUrl,
    },
    updatedAt: FieldValue.serverTimestamp(),
  };
}

/**
 * Applies the reel synchronization idempotently.
 * Uses deterministic document ID 'property_' + propertyId to prevent duplicate reels.
 */
async function applyPropertyReelSync(propertyId, beforeData, afterData, db = getFirestore()) {
  if (!propertyId || typeof propertyId !== 'string') {
    throw new Error('INVALID_PROPERTY_ID');
  }

  const reelId = `property_${propertyId}`;
  const reelRef = db.collection('reels').doc(reelId);

  // Case 1: Property was deleted
  if (!afterData) {
    const existing = await reelRef.get();
    if (existing.exists) {
      await reelRef.set({
        status: 'archived',
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return { outcome: 'archived_on_delete', reelId };
    }
    return { outcome: 'noop_deleted', reelId };
  }

  const videoUrl = typeof afterData.videoUrl === 'string' ? afterData.videoUrl.trim() : '';

  // Case 2: Property has no video (or video was removed)
  if (!videoUrl) {
    const existing = await reelRef.get();
    if (existing.exists) {
      await reelRef.set({
        status: 'archived',
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return { outcome: 'archived_no_video', reelId };
    }
    return { outcome: 'noop_no_video', reelId };
  }

  // Case 3: Property has a video
  const payload = buildPropertyReelPayload(propertyId, afterData);
  const existing = await reelRef.get();

  if (!existing.exists) {
    // New reel document: initialize engagement counters
    payload.views = 0;
    payload.completions = 0;
    payload.likes = 0;
    payload.saves = 0;
    payload.shares = 0;
    payload.propertyClicks = 0;
    payload.externalClicks = 0;
    payload.reports = 0;
    payload.createdAt = FieldValue.serverTimestamp();

    await reelRef.set(payload);
    return {
      outcome: payload.status === 'published' ? 'created_published' : 'created_draft',
      reelId,
      status: payload.status,
    };
  } else {
    // Existing reel document: update fields while preserving existing engagement metrics
    await reelRef.set(payload, { merge: true });
    return {
      outcome: payload.status === 'published' ? 'updated_published' : 'updated_draft',
      reelId,
      status: payload.status,
    };
  }
}

const syncOptions = document => ({
  document,
  region: 'us-central1',
  timeoutSeconds: 30,
  maxInstances: 5,
  memory: '256MiB',
});

const syncPropertyReels = onDocumentWritten(syncOptions('properties/{propertyId}'), async (event) => {
  const propertyId = event.params.propertyId;
  const before = event.data.before ? event.data.before.data() : null;
  const after = event.data.after ? event.data.after.data() : null;

  try {
    const result = await applyPropertyReelSync(propertyId, before, after);
    console.log(`[PropertyReelsSync] propertyId=${propertyId} outcome=${result.outcome} reelId=${result.reelId}`);
    return result;
  } catch (error) {
    console.error(`[PropertyReelsSync ERROR] propertyId=${propertyId}:`, error);
    throw error;
  }
});

module.exports = {
  buildPropertyReelPayload,
  applyPropertyReelSync,
  syncPropertyReels,
};
