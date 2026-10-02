function deleteWindowHours(preferences = {}) {
  const value = Number(preferences.deleteHours);
  return Number.isInteger(value) && value >= 1 && value <= 168 ? value : 24;
}

function canDeleteMessage({ message, uid, admin, now, preferences }) {
  if (message.deletedAt) return true;
  if (admin) return true;
  if (message.senderType !== "user" || (message.authorUid || message.senderId) !== uid) return false;
  const createdAt = message.createdAt?.toMillis?.();
  const age = now - createdAt;
  return Number.isFinite(age) && age >= 0 && age < deleteWindowHours(preferences) * 3600000;
}

function isOfficeOpen(preferences = {}, instant = new Date()) {
  if (!preferences.hoursEnabled) return true;
  const local = new Date(instant.getTime() + 3 * 3600000);
  const day = local.getUTCDay() || 7;
  const minute = local.getUTCHours() * 60 + local.getUTCMinutes();
  const days = Array.isArray(preferences.workDays) ? preferences.workDays : [1, 2, 3, 4, 6, 7];
  const opening = Number.isInteger(preferences.openingMinute) ? preferences.openingMinute : 540;
  const closing = Number.isInteger(preferences.closingMinute) ? preferences.closingMinute : 1080;
  if (opening < closing) return days.includes(day) && minute >= opening && minute < closing;
  return (days.includes(day) && minute >= opening) || (days.includes(day === 1 ? 7 : day - 1) && minute < closing);
}

module.exports = { deleteWindowHours, canDeleteMessage, isOfficeOpen };
