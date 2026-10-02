import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';
import '../services/app_activity_service.dart';

class ActivityUsersScreen extends StatefulWidget {
  const ActivityUsersScreen({super.key, this.service, this.serverNow});
  final AnalyticsService? service;
  final Future<DateTime> Function()? serverNow;

  @override
  State<ActivityUsersScreen> createState() => _ActivityUsersScreenState();
}

class _ActivityUsersScreenState extends State<ActivityUsersScreen> {
  late final AnalyticsService _service;
  final List<ActivityUser> _users = [];
  ActivityPage? _page;
  DateTime? _windowEnd;
  bool _loading = false;
  Object? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AnalyticsService();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      if (refresh) {
        _users.clear();
        _page = null;
        _windowEnd = null;
      }
    });
    try {
      final windowEnd = _windowEnd ??
          await (widget.serverNow?.call() ??
              AppActivityService.instance.presence.serverNow());
      final page = await _service.activeLast24Hours(
        windowEnd: windowEnd,
        after: _page?.cursor,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _windowEnd = windowEnd;
        _page = page;
        final known = _users.map((user) => user.id).toSet();
        _users.addAll(page.users.where((user) => known.add(user.id)));
      });
    } catch (error, stack) {
      debugPrint('Active users failed: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted && request == _request) setState(() => _error = error);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    ++_request;
    // One-shot paginated queries: no Firebase listener survives this page.
    super.dispose();
  }

  String _lastSeen(DateTime? value) {
    if (value == null) return 'وقت النشاط غير معروف';
    // Compare with the same server-adjusted clock used for the query window.
    final now = _windowEnd ?? DateTime.now();
    final elapsed = now.difference(value);
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'منذ أقل من دقيقة';
    if (elapsed.inHours < 1) return 'منذ ${elapsed.inMinutes} دقيقة';
    if (elapsed.inHours == 1) return 'منذ ساعة';
    return 'منذ ${elapsed.inHours} ساعات';
  }

  String _platform(String value) => switch (value.toLowerCase()) {
        'android' => 'Android',
        'ios' => 'iOS',
        _ => 'المنصة غير معروفة',
      };

  String _provider(String value) => switch (value.toLowerCase()) {
        'google.com' => 'Google',
        'apple.com' => 'Apple',
        'facebook.com' => 'Facebook',
        'phone' => 'Phone',
        'password' => 'Email / Phone',
        _ => '',
      };

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(title: const Text('نشطون آخر 24 ساعة')),
          body: RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Text('المستخدمون المسجلون • مرتّبون حسب آخر نشاط',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 16),
                if (_users.isEmpty && !_loading && _error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Column(children: [
                      Icon(Icons.people_outline_rounded,
                          color: AppTheme.primaryColor, size: 38),
                      SizedBox(height: 14),
                      Text('لا يوجد مستخدمون نشطون خلال آخر 24 ساعة',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textGrey)),
                    ]),
                  ),
                ..._users.map((user) {
                  final provider = _provider(user.provider);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        _UserAvatar(user: user),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            Text(_lastSeen(user.lastSeen),
                                style: const TextStyle(
                                    color: AppTheme.textGrey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                                [
                                  _platform(user.platform),
                                  if (provider.isNotEmpty) provider
                                ].join(' • '),
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                          ],
                        )),
                      ]),
                    ),
                  );
                }),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(children: [
                      const Text('تعذر تحميل المستخدمين. حاول مرة أخرى.',
                          style: TextStyle(color: AppTheme.textGrey)),
                      TextButton(
                          onPressed: () => _load(),
                          child: const Text('إعادة المحاولة')),
                    ]),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_error == null && _page?.hasMore == true)
                  TextButton.icon(
                    onPressed: () => _load(),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: const Text('تحميل 30 مستخدمًا إضافيًا'),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});
  final ActivityUser user;

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryColor.withValues(alpha: 0.10),
        ),
        child: user.photoUrl.trim().isEmpty
            ? _fallback()
            : Image.network(user.photoUrl,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback()),
      );

  Widget _fallback() => const Icon(Icons.person_outline_rounded,
      color: AppTheme.primaryColor, size: 27);
}
