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
        if (session.hasError || uid == null || uid != currentUid()) {
          return const _Denied();
        }
        return StreamBuilder<BookingLedgerPermission>(
            // Discard the previous account's permission and private subtree.
            key: ValueKey(uid),
            stream: permissions(uid),
            builder: (context, permission) {
              final value = permission.data;
              if (uid != currentUid() ||
                  permission.hasError ||
                  value == null ||
                  value.fromCache ||
                  !value.allowed) return const _Denied();
              return builder(context);
            });
      });
}

class _Denied extends StatelessWidget {
  const _Denied();
  @override
  Widget build(BuildContext context) => const BookingStateView(
      title: 'دفتر المالية محمي',
      detail: 'يلزم اتصال وتحقق من صلاحية الحساب لعرض دفتر المالية',
      icon: Icons.lock_outline);
}
