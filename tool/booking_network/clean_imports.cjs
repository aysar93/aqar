const fs = require('fs');

function cleanFile(filePath) {
  let text = fs.readFileSync(filePath, 'utf8');
  text = text.replace(/import\s+['"]booking_my_venues_screen\.dart['"];\r?\n/, '');
  fs.writeFileSync(filePath, text, 'utf8');
}

cleanFile('D:/Codex-Booking-UAT-20261022/aqar/lib/bookings/booking_screen.dart');
cleanFile('E:/Codex-Booking-Native-20261023-111137/app/lib/bookings/booking_screen.dart');
console.log('Cleaned unused import!');

