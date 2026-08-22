import 'package:flutter/material.dart';

/// زر متابعة المكتب.
///
/// هذا Widget مسؤول عن الواجهة فقط.
/// عملية المتابعة وإلغاء المتابعة سيتم ربطها لاحقًا
/// مع OfficeFollowerService و Firebase.
class OfficeFollowButton extends StatelessWidget {
  final bool isFollowing;

  /// هل يمكن الضغط على الزر؟
  final bool enabled;

  /// هل تظهر عبارة "متابع" أو "متابعة"؟
  final bool showLabel;

  /// عند الضغط.
  final VoidCallback? onPressed;

  const OfficeFollowButton({
    super.key,
    this.isFollowing = false,
    this.enabled = true,
    this.showLabel = true,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: AnimatedSwitcher(
          duration: const Duration(
            milliseconds: 180,
          ),
          child: Icon(
            isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
            key: ValueKey(isFollowing),
            size: 18,
          ),
        ),
        label: showLabel
            ? AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 180,
                ),
                child: Text(
                  isFollowing ? 'متابع' : 'متابعة المكتب',
                  key: ValueKey(isFollowing),
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : const SizedBox.shrink(),
        style: OutlinedButton.styleFrom(
          foregroundColor: isFollowing
              ? Theme.of(context).colorScheme.onSurface
              : const Color(0xFFD4AF37),
          side: BorderSide(
            color: isFollowing
                ? Theme.of(context).colorScheme.outline
                : const Color(0xFFD4AF37),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}
