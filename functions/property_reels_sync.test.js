const test = require('node:test');
const assert = require('node:assert/strict');
const { buildPropertyReelPayload, applyPropertyReelSync } = require('./property_reels_sync');

// Mock in-memory Firestore database for isolated, reproducible testing
function createMockDb() {
  const collections = new Map();

  function getCollection(name) {
    if (!collections.has(name)) collections.set(name, new Map());
    return collections.get(name);
  }

  return {
    _collections: collections,
    collection(name) {
      const col = getCollection(name);
      return {
        doc(id) {
          return {
            id,
            path: `${name}/${id}`,
            async get() {
              const data = col.get(id);
              return {
                exists: data !== undefined,
                id,
                data: () => (data ? JSON.parse(JSON.stringify(data)) : undefined),
              };
            },
            async set(newData, options = {}) {
              const existing = col.get(id) || {};
              if (options.merge) {
                col.set(id, { ...existing, ...JSON.parse(JSON.stringify(newData)) });
              } else {
                col.set(id, JSON.parse(JSON.stringify(newData)));
              }
            },
          };
        },
      };
    },
  };
}

test('buildPropertyReelPayload: returns null when property has no video', () => {
  const propertyData = {
    title: 'أرض سكنية في الرمادي',
    propertyType: 'أرض',
    price: 80000000,
    videoUrl: null,
  };
  const payload = buildPropertyReelPayload('prop_1', propertyData);
  assert.equal(payload, null);
});

test('buildPropertyReelPayload: unapproved property produces draft reel (private)', () => {
  const propertyData = {
    title: 'بيت طابقين للإيجار',
    propertyType: 'بيت',
    city: 'الرمادي',
    district: 'حي المعلمين',
    price: 1500000,
    videoUrl: 'https://cdn.example.com/videos/house1.mp4',
    status: 'pending',
  };
  const payload = buildPropertyReelPayload('prop_2', propertyData);
  assert.notEqual(payload, null);
  assert.equal(payload.status, 'draft');
  assert.equal(payload.targetType, 'property');
  assert.equal(payload.propertyId, 'prop_2');
  assert.equal(payload.videoUrl, 'https://cdn.example.com/videos/house1.mp4');
});

test('buildPropertyReelPayload: approved property produces published reel', () => {
  const propertyData = {
    title: 'شقة مفروشة للبيع',
    propertyType: 'شقة',
    city: 'الفلوجة',
    district: 'حي الجولان',
    price: 120000000,
    videoUrl: 'https://cdn.example.com/videos/apt1.mp4',
    imageUrl: 'https://cdn.example.com/images/apt1.jpg',
    status: 'approved',
    officeId: 'office_99',
    officeName: 'مكتب الأنبار',
  };
  const payload = buildPropertyReelPayload('prop_3', propertyData);
  assert.notEqual(payload, null);
  assert.equal(payload.status, 'published');
  assert.equal(payload.officeId, 'office_99');
  assert.equal(payload.propertySnapshot.title, 'شقة مفروشة للبيع');
  assert.equal(payload.thumbnailUrl, 'https://cdn.example.com/images/apt1.jpg');
});

test('applyPropertyReelSync: regular user creates pending property with video -> creates draft reel with deterministic ID', async () => {
  const db = createMockDb();
  const propertyData = {
    title: 'مزرعة نخيل',
    propertyType: 'مزرعة',
    videoUrl: 'https://cdn.example.com/farm.mp4',
    status: 'pending',
    userId: 'regular_user_1',
  };

  const result = await applyPropertyReelSync('prop_farm_10', null, propertyData, db);
  assert.equal(result.reelId, 'property_prop_farm_10');
  assert.equal(result.outcome, 'created_draft');

  const reelDoc = await db.collection('reels').doc('property_prop_farm_10').get();
  assert.equal(reelDoc.exists, true);
  assert.equal(reelDoc.data().status, 'draft');
  assert.equal(reelDoc.data().propertyId, 'prop_farm_10');
});

test('applyPropertyReelSync: office owner verified property -> auto-approved creates published reel', async () => {
  const db = createMockDb();
  const propertyData = {
    title: 'عمارة استثمارية',
    propertyType: 'عمارة',
    videoUrl: 'https://cdn.example.com/bldg.mp4',
    status: 'approved',
    userId: 'office_user_1',
    officeId: 'office_andalus',
  };

  const result = await applyPropertyReelSync('prop_bldg_20', null, propertyData, db);
  assert.equal(result.reelId, 'property_prop_bldg_20');
  assert.equal(result.outcome, 'created_published');

  const reelDoc = await db.collection('reels').doc('property_prop_bldg_20').get();
  assert.equal(reelDoc.exists, true);
  assert.equal(reelDoc.data().status, 'published');
  assert.equal(reelDoc.data().officeId, 'office_andalus');
});

test('applyPropertyReelSync: approving a pending property promotes draft reel to published', async () => {
  const db = createMockDb();
  const pendingProperty = {
    title: 'فيلا حديثة',
    videoUrl: 'https://cdn.example.com/villa.mp4',
    status: 'pending',
  };
  await applyPropertyReelSync('prop_villa_30', null, pendingProperty, db);

  const approvedProperty = {
    ...pendingProperty,
    status: 'approved',
  };
  const result = await applyPropertyReelSync('prop_villa_30', pendingProperty, approvedProperty, db);
  assert.equal(result.outcome, 'updated_published');

  const reelDoc = await db.collection('reels').doc('property_prop_villa_30').get();
  assert.equal(reelDoc.data().status, 'published');
});

test('applyPropertyReelSync: replacing video updates reel and preserves engagement counters', async () => {
  const db = createMockDb();
  const initialProperty = {
    title: 'بيت قديم',
    videoUrl: 'https://cdn.example.com/old_video.mp4',
    status: 'approved',
  };
  await applyPropertyReelSync('prop_house_40', null, initialProperty, db);

  // Simulate user engagement on the reel
  const reelRef = db.collection('reels').doc('property_prop_house_40');
  await reelRef.set({ views: 42, likes: 10, saves: 5 }, { merge: true });

  // Update property with a new video
  const updatedProperty = {
    ...initialProperty,
    videoUrl: 'https://cdn.example.com/new_hd_video.mp4',
  };
  await applyPropertyReelSync('prop_house_40', initialProperty, updatedProperty, db);

  const reelDoc = await reelRef.get();
  assert.equal(reelDoc.data().videoUrl, 'https://cdn.example.com/new_hd_video.mp4');
  assert.equal(reelDoc.data().views, 42); // Preserved!
  assert.equal(reelDoc.data().likes, 10); // Preserved!
  assert.equal(reelDoc.data().saves, 5); // Preserved!
});

test('applyPropertyReelSync: removing video archives the linked reel', async () => {
  const db = createMockDb();
  const propertyWithVideo = {
    title: 'محل تجاري',
    videoUrl: 'https://cdn.example.com/shop.mp4',
    status: 'approved',
  };
  await applyPropertyReelSync('prop_shop_50', null, propertyWithVideo, db);

  const propertyWithoutVideo = {
    ...propertyWithVideo,
    videoUrl: '', // Video removed
  };
  const result = await applyPropertyReelSync('prop_shop_50', propertyWithVideo, propertyWithoutVideo, db);
  assert.equal(result.outcome, 'archived_no_video');

  const reelDoc = await db.collection('reels').doc('property_prop_shop_50').get();
  assert.equal(reelDoc.data().status, 'archived');
});

test('applyPropertyReelSync: deleting property archives the linked reel', async () => {
  const db = createMockDb();
  const property = {
    title: 'شقة للبيع',
    videoUrl: 'https://cdn.example.com/apt.mp4',
    status: 'approved',
  };
  await applyPropertyReelSync('prop_del_60', null, property, db);

  const result = await applyPropertyReelSync('prop_del_60', property, null, db);
  assert.equal(result.outcome, 'archived_on_delete');

  const reelDoc = await db.collection('reels').doc('property_prop_del_60').get();
  assert.equal(reelDoc.data().status, 'archived');
});

test('applyPropertyReelSync: idempotency guarantees no duplicate reels on retries', async () => {
  const db = createMockDb();
  const property = {
    title: 'أرض في الصوفية',
    videoUrl: 'https://cdn.example.com/land.mp4',
    status: 'approved',
  };

  // Run 5 times concurrently (simulating network retries or multiple triggers)
  await Promise.all([
    applyPropertyReelSync('prop_idempotent_70', null, property, db),
    applyPropertyReelSync('prop_idempotent_70', null, property, db),
    applyPropertyReelSync('prop_idempotent_70', null, property, db),
    applyPropertyReelSync('prop_idempotent_70', null, property, db),
    applyPropertyReelSync('prop_idempotent_70', null, property, db),
  ]);

  // Check reels collection has exactly 1 entry for this property
  const reelsMap = db._collections.get('reels');
  assert.equal(reelsMap.size, 1);
  assert.equal(reelsMap.has('property_prop_idempotent_70'), true);
});
