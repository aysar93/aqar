import 'package:flutter/material.dart';

/// أزرار التواصل مع المكتب.
///
/// الأزرار:
/// - اتصال.
/// - واتساب.
/// - رسالة.
/// - الموقع.
/// - مشاركة.
///
/// لا تحتوي هذه الواجهة على منطق Firebase.
/// المنطق سيتم ربطه لاحقًا مع الخدمات الموجودة.
class OfficeContactButtons extends StatelessWidget {
  final VoidCallback? onCall;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onMessage;
  final VoidCallback? onLocation;
  final VoidCallback? onShare;

  final bool showCall;
  final bool showWhatsapp;
  final bool showMessage;
  final bool showLocation;
  final bool showShare;

  const OfficeContactButtons({
    super.key,
    this.onCall,
    this.onWhatsapp,
    this.onMessage,
    this.onLocation,
    this.onShare,
    this.showCall = true,
    this.showWhatsapp = true,
    this.showMessage = true,
    this.showLocation = true,
    this.showShare = true,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    if (showCall) {
      buttons.add(
        _buildButton(
          context,
          icon: Icons.phone_outlined,
          label: 'اتصال',
          onPressed: onCall,
          isPrimary: true,
        ),
      );
    }

    if (showWhatsapp) {
      buttons.add(
        _buildButton(
          context,
          icon: Icons.chat_outlined,
          label: 'واتساب',
          onPressed: onWhatsapp,
        ),
      );
    }

    if (showMessage) {
      buttons.add(
        _buildButton(
          context,
          icon: Icons.message_outlined,
          label: 'رسالة',
          onPressed: onMessage,
        ),
      );
    }

    if (showLocation) {
      buttons.add(
        _buildButton(
          context,
          icon: Icons.location_on_outlined,
          label: 'الموقع',
          onPressed: onLocation,
        ),
      );
    }

    if (showShare) {
      buttons.add(
        _buildButton(
          context,
          icon: Icons.share_outlined,
          label: 'مشاركة',
          onPressed: onShare,
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: buttons,
      ),
    );
  }

  // ═════════════════════════════════════════════
  // زر التواصل
  // ═════════════════════════════════════════════

  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final foregroundColor =
        isPrimary ? const Color(0xFF0F172A) : const Color(0xFFD4AF37);

    final backgroundColor =
        isPrimary ? const Color(0xFFD4AF37) : Colors.transparent;

    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 18,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          side: BorderSide(
            color: isPrimary
                ? const Color(0xFFD4AF37)
                : colorScheme.outline.withValues(alpha: 0.55),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}
