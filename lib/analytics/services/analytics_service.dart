import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/analytics_models.dart';

class AnalyticsService {
  AnalyticsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  AnalyticsPeriod? _cachedPeriod;
  DateTime? _cacheCreatedAt;
  Future<List<Map<String, dynamic>>>? _cachedSessions;

  final Map<String, _UserProfile> _profileCache = {};

  Future<List<Map<String, dynamic>>> _sessions(
    AnalyticsPeriod period,
  ) {
    final now = DateTime.now();

    final cacheIsValid = _cachedPeriod == period &&
        _cacheCreatedAt != null &&
        now.difference(_cacheCreatedAt!) < const Duration(seconds: 15) &&
        _cachedSessions != null;

    if (cacheIsValid) {
      return _cachedSessions!;
    }

    final start = Timestamp.fromDate(period.start(now));

    _cachedPeriod = period;
    _cacheCreatedAt = now;

    _cachedSessions = _db
        .collection('app_sessions')
        .where(
          'startedAt',
          isGreaterThanOrEqualTo: start,
        )
        .get()
        .then(
          (snapshot) =>
              snapshot.docs.map((document) => document.data()).toList(),
        );

    return _cachedSessions!;
  }

  Future<AnalyticsSummary> summary(
    AnalyticsPeriod period,
  ) async {
    final sessions = await _sessions(period);

    final visitors = <String>{};

    var registered = 0;
    var guests = 0;
    var totalDuration = 0;
    var completedSessions = 0;

    for (final data in sessions) {
      final visitorId = (data['visitorId'] ?? '').toString().trim();

      if (visitorId.isNotEmpty) {
        visitors.add(visitorId);
      }

      final isGuest = data['isGuest'] as bool? ?? true;

      if (isGuest) {
        guests++;
      } else {
        registered++;
      }

      final endedAt = data['endedAt'];
      final duration = (data['durationSeconds'] as num?)?.toInt() ?? 0;

      if (endedAt != null && duration >= 0) {
        totalDuration += duration;
        completedSessions++;
      }
    }

    return AnalyticsSummary(
      sessions: sessions.length,
      uniqueUsers: visitors.length,
      registeredUsers: registered,
      guests: guests,
      averageDurationSeconds:
          completedSessions == 0 ? 0 : totalDuration ~/ completedSessions,
    );
  }

  Stream<List<ActivityUser>> activeLast24Hours() {
    final start = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );

    return _db
        .collection('user_activity')
        .where(
          'lastSeen',
          isGreaterThanOrEqualTo: start,
        )
        .orderBy('lastSeen', descending: true)
        .limit(100)
        .snapshots()
        .asyncMap((snapshot) async {
      final activityUsers =
          snapshot.docs.map(ActivityUser.fromFirestore).toList();

      return _attachUserProfiles(activityUsers);
    });
  }

  Future<List<ActivityUser>> _attachUserProfiles(
    List<ActivityUser> activityUsers,
  ) async {
    final registeredUserIds = activityUsers
        .where(
          (user) =>
              !user.isGuest &&
              user.userId != null &&
              user.userId!.trim().isNotEmpty,
        )
        .map((user) => user.userId!.trim())
        .toSet();

    final missingUserIds = registeredUserIds
        .where((userId) => !_profileCache.containsKey(userId))
        .toList();

    for (var start = 0; start < missingUserIds.length; start += 30) {
      final end = (start + 30 < missingUserIds.length)
          ? start + 30
          : missingUserIds.length;

      final userIdsChunk = missingUserIds.sublist(start, end);

      for (final userId in userIdsChunk) {
        _profileCache[userId] = const _UserProfile();
      }

      final usersSnapshot = await _db
          .collection('users')
          .where(
            FieldPath.documentId,
            whereIn: userIdsChunk,
          )
          .get();

      for (final document in usersSnapshot.docs) {
        final data = document.data();

        final name = _firstNonEmpty([
          data['name'],
          data['displayName'],
          data['fullName'],
          data['userName'],
          data['username'],
          data['email'],
        ]);

        final photoUrl = _firstNonEmpty([
          data['photoUrl'],
          data['photo'],
          data['photoURL'],
          data['profileImageUrl'],
          data['profileImage'],
          data['imageUrl'],
        ]);

        _profileCache[document.id] = _UserProfile(
          name: name,
          photoUrl: photoUrl,
        );
      }
    }

    return activityUsers.map((activityUser) {
      if (activityUser.isGuest || activityUser.userId == null) {
        return activityUser;
      }

      final profile = _profileCache[activityUser.userId!.trim()];

      if (profile == null) {
        return activityUser;
      }

      return activityUser.withProfile(
        name: profile.name,
        imageUrl: profile.photoUrl,
      );
    }).toList();
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  Future<List<ChartPoint>> chart(
    AnalyticsPeriod period,
  ) async {
    final sessions = await _sessions(period);

    final hourly = period == AnalyticsPeriod.today ||
        period == AnalyticsPeriod.last24Hours;

    final values = <DateTime, int>{};

    for (final data in sessions) {
      final startedAt = data['startedAt'];

      if (startedAt is! Timestamp) continue;

      final date = startedAt.toDate();

      final bucket = hourly
          ? DateTime(
              date.year,
              date.month,
              date.day,
              date.hour,
            )
          : DateTime(
              date.year,
              date.month,
              date.day,
            );

      values[bucket] = (values[bucket] ?? 0) + 1;
    }

    final orderedEntries = values.entries.toList()
      ..sort(
        (first, second) => first.key.compareTo(second.key),
      );

    return orderedEntries.map((entry) {
      final date = entry.key;

      final label = hourly
          ? '${date.hour.toString().padLeft(2, '0')}:00'
          : '${date.month}/${date.day}';

      return ChartPoint(
        label,
        entry.value,
      );
    }).toList();
  }
}

class _UserProfile {
  const _UserProfile({
    this.name = '',
    this.photoUrl = '',
  });

  final String name;
  final String photoUrl;
}
