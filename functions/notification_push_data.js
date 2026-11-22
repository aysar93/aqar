function notificationPushData(data, notificationId) {
  return data.type === 'booking'
    ? {type:'booking',bookingId:String(data.bookingId),notificationId:String(notificationId)}
    : {};
}
module.exports = {notificationPushData};
