import 'package:cloud_firestore/cloud_firestore.dart';

enum AnalyticsPeriod {
  today,
  last24Hours,
  last7Days,
  last30Days,
}

extension AnalyticsPeriodX on AnalyticsPeriod {
  String get label => switch (this) {
        AnalyticsPeriod.today => 'اليوم',
        AnalyticsPeriod.last24Hours => '24 ساعة',
        AnalyticsPeriod.last7Days => '7 أيام',
        AnalyticsPeriod.last30Days => '30 يومًا',
      };

  DateTime start(DateTime now) => switch (this) {
        AnalyticsPeriod.today => DateTime(
            now.year,
            now.month,
            now.day,
          ),
        AnalyticsPeriod.last24Hours => now.subtract(
            const Duration(hours: 24),
          ),
        AnalyticsPeriod.last7Days => now.subtract(
            const Duration(days: 7),
          ),
        AnalyticsPeriod.last30Days => now.subtract(
            const Duration(days: 30),
          ),
      };
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.sessions,
    required this.uniqueUsers,
    required this.registeredUsers,
    required this.guests,
    required this.averageDurationSeconds,
  });

  final int sessions;
  final int uniqueUsers;
  final int registeredUsers;
  final int guests;
  final int averageDurationSeconds;
}

class ActivityUser {
  const ActivityUser({
    required this.id,
    required this.displayName,
    required this.lastSeen,
    required this.isGuest,
    this.userId,
    this.photoUrl = '',
    this.platform = 'unknown',
  });

  final String id;
  final String? userId;
  final String displayName;
  final String photoUrl;
  final DateTime? lastSeen;
  final bool isGuest;
  final String platform;

  factory ActivityUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    final isGuest = data['isGuest'] as bool? ?? true;
    final storedName = (data['displayName'] ?? '').toString().trim();
    final storedPhoto = (data['photoUrl'] ?? '').toString().trim();
    final storedUserId = (data['userId'] ?? '').toString().trim();

    return ActivityUser(
      id: document.id,
      userId: storedUserId.isEmpty ? null : storedUserId,
      displayName:
          storedName.isNotEmpty ? storedName : (isGuest ? 'زائر' : 'مستخدم'),
      photoUrl: storedPhoto,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      isGuest: isGuest,
      platform: data['platform']?.toString() ?? 'unknown',
    );
  }

  ActivityUser withProfile({
    required String name,
    required String imageUrl,
  }) {
    return ActivityUser(
      id: id,
      userId: userId,
      displayName: name.trim().isEmpty ? displayName : name.trim(),
      photoUrl: imageUrl.trim().isEmpty ? photoUrl : imageUrl.trim(),
      lastSeen: lastSeen,
      isGuest: isGuest,
      platform: platform,
    );
  }
}

class ChartPoint {
  const ChartPoint(
    this.label,
    this.value,
  );

  final String label;
  final int value;
}
