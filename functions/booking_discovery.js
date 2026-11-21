const amenities = ['pool', 'parking', 'wifi', 'airConditioning', 'kitchen', 'playground', 'accessible'];
function normalized(value) {
  return String(value || '').toLowerCase().normalize('NFKC').replace(/[\u064B-\u065F\u0670\u0640]/g, '').replace(/[أإآ]/g, 'ا').replace(/ى/g, 'ي');
}
function metadata(data, previous = {}) {
  const result = {};
  for (const key of ['capacity', 'bedrooms']) {
    const value = data[key] ?? previous[key] ?? 0;
    if (!Number.isSafeInteger(value) || value < 0 || value > 10000) throw Error('سعة أو عدد غرف غير صالح');
    result[key] = value;
  }
  result.amenities = data.amenities ?? previous.amenities ?? [];
  if (!Array.isArray(result.amenities) || result.amenities.some(x => !amenities.includes(x)) || new Set(result.amenities).size !== result.amenities.length) throw Error('مرافق غير صالحة');
  for (const key of ['complexName', 'unitName']) {
    result[key] = data[key] ?? previous[key] ?? '';
    if (typeof result[key] !== 'string' || result[key].length > 200) throw Error('اسم وحدة غير صالح');
    result[key] = result[key].trim();
  }
  return result;
}
module.exports = {amenities, normalized, metadata};
