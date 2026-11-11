import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'booking_state_view.dart';

enum BookingAccessStatus {
  verified,
  unauthenticated,
  verifyingCache,
  offlineCache,
  pendingSync,
  permissionDenied,
  backendError,
  networkError,
}

class BookingAccessClassification {
  const BookingAccessClassification({
    required this.status,
    required this.title,
    required this.detail,
    required this.icon,
    this.canRetry = false,
  });

  final BookingAccessStatus status;
  final String title;
  final String detail;
  final IconData icon;
  final bool canRetry;

  bool get isVerified => status == BookingAccessStatus.verified;
}

/// Classifies Firestore stream states and Firebase errors cleanly without
/// conflating permission errors, index/backend errors, unauthenticated sessions,
/// initial server-verification cache snapshots, and true offline states.
class BookingAccessGuard {
  BookingAccessGuard._();

  static BookingAccessClassification classifySnapshot<T>({
    required AsyncSnapshot<T> snapshot,
    required bool isFromCache,
    required bool hasPendingWrites,
    bool cacheGraceElapsed = false,
    String? currentUid,
    String cachedTitle = 'يلزم اتصال للتحقق من الصلاحية',
    String cachedDetail =
        'أعد الاتصال ليتم التحقق من الحساب وتحديث البيانات الخاصة بأمان.',
    String permissionDetail =
        'هذا القسم مخصص للحسابات المخوّلة فقط. إذا تمت ترقية حسابك مؤخراً اضغط إعادة التحقق.',
  }) {
    if (snapshot.hasError) {
      return classifyError(
        snapshot.error!,
        permissionDetail: permissionDetail,
      );
    }

    if (!snapshot.hasData) {
      if (currentUid != null && currentUid.trim().isEmpty) {
        return const BookingAccessClassification(
          status: BookingAccessStatus.unauthenticated,
          title: 'يلزم تسجيل الدخول',
          detail: 'سجّل الدخول بحسابك للمتابعة.',
          icon: Icons.login_rounded,
          canRetry: false,
        );
      }
      return const BookingAccessClassification(
        status: BookingAccessStatus.verifyingCache,
        title: 'جاري التحقق من الصلاحية',
        detail: 'يتم الآن مطابقة الصلاحيات والبيانات مع الخادم...',
        icon: Icons.verified_user_outlined,
        canRetry: false,
      );
    }

    if (hasPendingWrites) {
      return const BookingAccessClassification(
        status: BookingAccessStatus.pendingSync,
        title: 'جاري مزامنة التغييرات',
        detail: 'يتم الآن تأكيد آخر التحديثات مع الخادم بأمان.',
        icon: Icons.cloud_upload_outlined,
        canRetry: true,
      );
    }

    if (isFromCache) {
      if (!cacheGraceElapsed) {
        return const BookingAccessClassification(
          status: BookingAccessStatus.verifyingCache,
          title: 'جاري التحقق من الصلاحية',
          detail: 'يتم الآن جلب النسخة الموثقة من الخادم...',
          icon: Icons.cloud_sync_outlined,
          canRetry: true,
        );
      }
      return BookingAccessClassification(
        status: BookingAccessStatus.offlineCache,
        title: cachedTitle,
        detail: cachedDetail,
        icon: Icons.wifi_off_rounded,
        canRetry: true,
      );
    }

    return const BookingAccessClassification(
      status: BookingAccessStatus.verified,
      title: '',
      detail: '',
      icon: Icons.check_circle_outline,
    );
  }

  static BookingAccessClassification classifyError(
    Object error, {
    String permissionDetail =
        'هذا القسم مخصص للحسابات المخوّلة فقط. إذا تمت ترقية حسابك مؤخراً اضغط إعادة التحقق.',
  }) {
    final code = error is FirebaseException ? error.code.toLowerCase() : '';
    final msg = error.toString().toLowerCase();

    if (code == 'unauthenticated' || msg.contains('unauthenticated')) {
      return const BookingAccessClassification(
        status: BookingAccessStatus.unauthenticated,
        title: 'انتهت جلسة تسجيل الدخول',
        detail: 'يرجى تسجيل الدخول مجدداً للتحقق من حسابك.',
        icon: Icons.login_rounded,
        canRetry: true,
      );
    }

    if (code == 'permission-denied' ||
        msg.contains('permission-denied') ||
        msg.contains('permission denied') ||
        msg.contains('permission revoked') ||
        msg.contains('unauthorized')) {
      return BookingAccessClassification(
        status: BookingAccessStatus.permissionDenied,
        title: 'لا تتوفر صلاحية الوصول',
        detail: permissionDetail,
        icon: Icons.lock_outline,
        canRetry: true,
      );
    }

    if (code == 'failed-precondition' || msg.contains('failed-precondition')) {
      return const BookingAccessClassification(
        status: BookingAccessStatus.backendError,
        title: 'الخدمة قيد التهيئة على الخادم',
        detail: 'تعذر إتمام الاستعلام حالياً. يرجى المحاولة بعد لحظات.',
        icon: Icons.cloud_sync_outlined,
        canRetry: true,
      );
    }

    return const BookingAccessClassification(
      status: BookingAccessStatus.networkError,
      title: 'تعذر التحقق من الاتصال بالخادم',
      detail: 'تأكد من استقرار الإنترنت واضغط إعادة المحاولة لتحديث البيانات بأمان.',
      icon: Icons.wifi_off_rounded,
      canRetry: true,
    );
  }
}

/// Fail-closed gate that hides private data when cached/pending/errored while
/// avoiding false-positive offline banners during initial online server fetch
/// and surfacing honest permission vs offline states with a token-refresh retry.
class BookingVerifiedGate extends StatefulWidget {
  const BookingVerifiedGate({
    super.key,
    required this.hasData,
    required this.hasError,
    this.error,
    required this.isFromCache,
    required this.hasPendingWrites,
    required this.child,
    this.onRetry,
    this.graceDuration = const Duration(milliseconds: 1400),
    this.cachedTitle = 'يلزم اتصال للتحقق من الصلاحية',
    this.cachedDetail =
        'أعد الاتصال ليتم التحقق من الحساب وتحديث البيانات الخاصة بأمان.',
    this.permissionDetail =
        'هذا القسم مخصص للحسابات المخوّلة فقط. إذا تمت ترقية حسابك مؤخراً اضغط إعادة التحقق.',
  });

  final bool hasData;
  final bool hasError;
  final Object? error;
  final bool isFromCache;
  final bool hasPendingWrites;
  final Widget child;
  final VoidCallback? onRetry;
  final Duration graceDuration;
  final String cachedTitle;
  final String cachedDetail;
  final String permissionDetail;

  @override
  State<BookingVerifiedGate> createState() => _BookingVerifiedGateState();
}

class _BookingVerifiedGateState extends State<BookingVerifiedGate> {
  Timer? _graceTimer;
  bool _graceElapsed = false;
  bool _retrying = false;

  bool get _isWaitingOnCache =>
      !widget.hasError &&
      widget.hasData &&
      widget.isFromCache &&
      !widget.hasPendingWrites;

  @override
  void initState() {
    super.initState();
    _syncGraceTimer();
  }

  @override
  void didUpdateWidget(covariant BookingVerifiedGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isFromCache || widget.hasError || !widget.hasData) {
      _graceTimer?.cancel();
      _graceTimer = null;
      _graceElapsed = false;
    } else if (!oldWidget.isFromCache && widget.isFromCache) {
      _graceElapsed = false;
      _syncGraceTimer();
    } else if (_isWaitingOnCache && _graceTimer == null && !_graceElapsed) {
      _syncGraceTimer();
    }
  }

  void _syncGraceTimer() {
    if (!_isWaitingOnCache || _graceElapsed) return;
    _graceTimer?.cancel();
    if (widget.graceDuration <= Duration.zero) {
      _graceElapsed = true;
      return;
    }
    _graceTimer = Timer(widget.graceDuration, () {
      if (mounted) setState(() => _graceElapsed = true);
    });
  }

  Future<void> _handleRetry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _graceElapsed = false;
    });
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (_) {}
    if (!mounted) return;
    _syncGraceTimer();
    widget.onRetry?.call();
    setState(() => _retrying = false);
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnap = widget.hasError
        ? AsyncSnapshot<Object>.withError(
            ConnectionState.active,
            widget.error ?? StateError('stream error'),
          )
        : widget.hasData
            ? const AsyncSnapshot<Object>.withData(
                ConnectionState.active,
                true,
              )
            : const AsyncSnapshot<Object>.nothing();

    final info = BookingAccessGuard.classifySnapshot<Object>(
      snapshot: asyncSnap,
      isFromCache: widget.isFromCache,
      hasPendingWrites: widget.hasPendingWrites,
      cacheGraceElapsed: _graceElapsed,
      cachedTitle: widget.cachedTitle,
      cachedDetail: widget.cachedDetail,
      permissionDetail: widget.permissionDetail,
    );

    if (info.isVerified) return widget.child;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BookingStateView(
          title: info.title,
          detail: info.detail,
          icon: info.icon,
        ),
        if (info.canRetry && widget.onRetry != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _retrying ? null : _handleRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_retrying ? 'جاري التحقق...' : 'إعادة التحقق'),
          ),
        ],
      ],
    );
  }
}
