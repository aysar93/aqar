import 'booking_access_guard.dart';
import 'booking_state_view.dart';
import 'package:flutter/material.dart';

/// Only a server snapshot for the current account can authorize the ledger.
class BookingLedgerPermission {
  const BookingLedgerPermission(
      {required this.allowed, required this.fromCache});
  final bool allowed;
  final bool fromCache;
}

class BookingLedgerAccess extends StatelessWidget {
  const BookingLedgerAccess(
      {super.key,
      required this.sessions,
      required this.currentUid,
      required this.permissions,
      required this.builder});
  final Stream<String?> sessions;
  final String? Function() currentUid;
  final Stream<BookingLedgerPermission> Function(String) permissions;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
      stream: sessions,
      builder: (context, session) {
        final uid = session.data;
        if (session.hasError) {
          final errInfo = BookingAccessGuard.classifyError(session.error!);
          return _Denied(
            title: errInfo.title,
            detail: errInfo.detail,
            icon: errInfo.icon,
          );
        }
        if (uid == null || uid != currentUid()) {
          return const _Denied(
            title: 'دفتر المالية محمي',
            detail: 'يلزم تسجيل الدخول بحساب مالي مخول لعرض دفتر المالية.',
            icon: Icons.lock_outline,
          );
        }
        return StreamBuilder<BookingLedgerPermission>(
            // Discard the previous account's permission and private subtree.
            key: ValueKey(uid),
            stream: permissions(uid),
            builder: (context, permission) {
              final value = permission.data;
              if (uid != currentUid()) {
                return const _Denied(
                  title: 'دفتر المالية محمي',
                  detail: 'يتم الآن التحقق من الحساب النشط...',
                  icon: Icons.lock_outline,
                );
              }
              return BookingVerifiedGate(
                hasData: permission.hasData,
                hasError: permission.hasError,
                error: permission.error,
                isFromCache: value?.fromCache ?? false,
                hasPendingWrites: false,
                cachedTitle: 'دفتر المالية محمي',
                cachedDetail: 'يلزم اتصال وتحقق من صلاحية الحساب لعرض دفتر المالية',
                permissionDetail: 'دفتر المالية مخصص للإدارة والمراجع المالي المخول فقط.',
                child: (value != null && value.allowed)
                    ? builder(context)
                    : const _Denied(
                        title: 'دفتر المالية محمي',
                        detail: 'دفتر المالية مخصص للإدارة والمراجع المالي المخول فقط.',
                        icon: Icons.lock_outline,
                      ),
              );
            });
      });
}

class _Denied extends StatelessWidget {
  const _Denied({
    this.title = 'دفتر المالية محمي',
    this.detail = 'يلزم اتصال وتحقق من صلاحية الحساب لعرض دفتر المالية',
    this.icon = Icons.lock_outline,
  });

  final String title;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => BookingStateView(
      title: title,
      detail: detail,
      icon: icon);
}
