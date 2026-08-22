import 'package:flutter/material.dart';

import 'app_update_banner_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_icons.dart';
import 'app_update_model.dart';

/// نافذة تحديث التطبيق للمستخدم + معاينة مطابقة تقريباً للشكل النهائي.
class AppUpdateDialog extends StatefulWidget {
  final AppUpdateModel update;
  final bool preview;

  const AppUpdateDialog({
    super.key,
    required this.update,
    this.preview = false,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  static const _gold = Color(0xffD4AF37);
  static const _bg = Color(0xff08111F);
  static const _surface = Color(0xff111C2E);

  bool _dontShowAgain = false;
  bool _openingStore = false;

  Future<void> _updateNow() async {
    if (_openingStore) return;
    if (widget.preview) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final uri = Uri.tryParse(widget.update.storeUrl.trim());
    if (uri == null || !uri.hasScheme) return;

    setState(() => _openingStore = true);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!widget.preview && mounted && !widget.update.isMandatory) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _openingStore = false);
    }
  }

  Future<void> _dismiss() async {
    if (widget.preview) {
      Navigator.of(context).pop();
      return;
    }

    if (_dontShowAgain && !widget.update.isMandatory) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hiddenKey(widget.update), true);
    }

    if (mounted) Navigator.of(context).pop();
  }

  static String _hiddenKey(AppUpdateModel update) =>
      'app_update_never_${update.buildNumber}';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxHeight = (size.height - 28).clamp(470.0, 700.0).toDouble();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: maxHeight,
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _gold.withValues(alpha: .35)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 50,
                  offset: Offset(0, 22),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _hero(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
                    child: Column(
                      children: [
                        Text(
                          widget.update.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          widget.update.description,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _versionPill(),
                        if (widget.update.features.isNotEmpty) ...[
                          const SizedBox(height: 13),
                          _features(),
                        ],
                        if (!widget.update.isMandatory) ...[
                          const SizedBox(height: 16),
                          _neverShowRow(),
                        ],
                        const SizedBox(height: 12),
                        _actions(),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                color: Colors.white30, size: 14),
                            SizedBox(width: 5),
                            Text(
                              'سيتم الانتقال إلى متجر Google Play',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 10.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return SizedBox(
      height: 168,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            appUpdateBannerBytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  _bg.withValues(alpha: .12),
                  _bg.withValues(alpha: .45),
                ],
                stops: const [0, .72, 1],
              ),
            ),
          ),
          Positioned(top: 14, right: 14, child: _badge()),
        ],
      ),
    );
  }

  Widget _versionPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: 'الإصدار الجديد  ',
              style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: widget.update.version,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _gold.withValues(alpha: .45),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: _gold,
            size: 17,
          ),
          SizedBox(width: 6),
          Text(
            'تحديث جديد',
            style: TextStyle(
              color: _gold,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _features() {
    final features = widget.update.features.take(4).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        children: [
          const Text('في هذا التحديث',
              style: TextStyle(
                  color: _gold, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: .10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppUpdateIcons.fromKey(feature.iconKey),
                          color: _gold, size: 18),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(feature.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          if (feature.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(feature.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10.5,
                                    height: 1.2)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _neverShowRow() {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: _dontShowAgain
                ? _gold.withValues(alpha: .35)
                : Colors.white.withValues(alpha: .05),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _dontShowAgain,
              onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
              activeColor: _gold,
              checkColor: Colors.black,
              side: const BorderSide(color: Colors.white54, width: 1.4),
            ),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('لا تعرض هذا التنبيه مرة أخرى',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('لن يظهر لهذا الإصدار بعد اختيار هذا الخيار',
                      style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                ],
              ),
            ),
            const Icon(Icons.shield_outlined, color: Colors.white30, size: 21),
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        if (!widget.update.isMandatory) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _dismiss,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: Colors.white,
                side: BorderSide(color: _gold.withValues(alpha: .65)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('إلغاء',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _openingStore ? null : _updateNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _openingStore
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.black),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded),
                      SizedBox(width: 7),
                      Text('تحديث الآن',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
