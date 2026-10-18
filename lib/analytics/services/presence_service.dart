// Isolated full-app test: no production RTDB or presence function access.
class PresenceService {
 void invalidateDashboardAuthorization() {}
 Future<void> connect(String uid) async {}
 Future<void> disconnect() async {}
 Future<DateTime> serverNow() async => DateTime.now();
 Stream<int> onlineCount() => Stream.value(0);
}
