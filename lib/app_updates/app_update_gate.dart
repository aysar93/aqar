import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_update_dialog.dart';
import 'app_update_service.dart';

class AppUpdateGate extends StatefulWidget {
  final Widget child;

  const AppUpdateGate({
    super.key,
    required this.child,
  });

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  bool _checked = false;
  bool _showingDialog = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCheck();
    });
  }

  Future<void> _startCheck() async {
    // ننتظر حتى تستقر الصفحة الرئيسية بعد الانتقال إليها.
    await Future<void>.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted || _checked || _showingDialog) {
      return;
    }

    await _check();
  }

  Future<void> _check() async {
    if (!mounted || _checked || _showingDialog) {
      return;
    }

    _checked = true;

    try {
      final update = await AppUpdateService.instance.getAvailableUpdate();

      if (!mounted || update == null) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      final hiddenKey = 'app_update_never_${update.buildNumber}';

      final hidden = prefs.getBool(hiddenKey) ?? false;

      if (hidden && !update.isMandatory) {
        return;
      }

      if (!mounted || _showingDialog) {
        return;
      }

      _showingDialog = true;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) {
          return AppUpdateDialog(
            update: update,
          );
        },
      );

      if (mounted) {
        _showingDialog = false;
      }
    } catch (e) {
      debugPrint(
        'App update check failed: $e',
      );

      if (mounted) {
        _showingDialog = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
