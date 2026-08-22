import 'package:flutter/material.dart';

import '../models/analytics_models.dart';
import '../services/analytics_service.dart';

class ActivityUsersScreen extends StatefulWidget {
  const ActivityUsersScreen({super.key});

  @override
  State<ActivityUsersScreen> createState() => _ActivityUsersScreenState();
}

class _ActivityUsersScreenState extends State<ActivityUsersScreen> {
  late final AnalyticsService _analyticsService;
  late final Stream<List<ActivityUser>> _usersStream;

  @override
  void initState() {
    super.initState();

    _analyticsService = AnalyticsService();
    _usersStream = _analyticsService.activeLast24Hours();
  }

  String _lastSeen(DateTime? value) {
    if (value == null) {
      return 'وقت النشاط غير معروف';
    }

    final difference = DateTime.now().difference(value);

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'نشط الآن';
    }

    if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقيقة';
    }

    if (difference.inHours == 1) {
      return 'منذ ساعة';
    }

    return 'منذ ${difference.inHours} ساعات';
  }

  String _platformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iPhone';
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      default:
        return 'جهاز غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xff0F172A),
          elevation: 0,
          centerTitle: true,
          title: const Text('نشطون آخر 24 ساعة'),
        ),
        body: StreamBuilder<List<ActivityUser>>(
          stream: _usersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _MessageView(
                icon: Icons.error_outline,
                message: 'تعذر تحميل نشاط المستخدمين',
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final users = snapshot.data!;

            if (users.isEmpty) {
              return const _MessageView(
                icon: Icons.people_outline,
                message: 'لا يوجد مستخدمون نشطون مؤخرًا',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final user = users[index];

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff1E293B),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: _UserAvatar(user: user),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _UserTypeBadge(isGuest: user.isGuest),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${_lastSeen(user.lastSeen)}'
                        ' • '
                        '${_platformName(user.platform)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.user,
  });

  final ActivityUser user;

  @override
  Widget build(BuildContext context) {
    final imageUrl = user.photoUrl.trim();

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.withValues(alpha: 0.15),
        border: Border.all(
          color: user.isGuest
              ? Colors.white24
              : Colors.blue.withValues(alpha: 0.45),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty || user.isGuest
          ? _fallbackIcon()
          : Image.network(
              imageUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackIcon(),
              loadingBuilder: (
                context,
                child,
                loadingProgress,
              ) {
                if (loadingProgress == null) {
                  return child;
                }

                return const Padding(
                  padding: EdgeInsets.all(15),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                );
              },
            ),
    );
  }

  Widget _fallbackIcon() {
    return Icon(
      user.isGuest ? Icons.person_outline_rounded : Icons.person_rounded,
      color: user.isGuest ? Colors.white54 : Colors.blue,
      size: 29,
    );
  }
}

class _UserTypeBadge extends StatelessWidget {
  const _UserTypeBadge({
    required this.isGuest,
  });

  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final color = isGuest ? Colors.orange : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isGuest ? 'زائر' : 'مسجل',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white38,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
