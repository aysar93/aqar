import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _navy = Color(0xFF0F172A);
const Color _surface = Color(0xFF172033);
const Color _gold = Color(0xFFD4AF37);
const Color _whatsAppGreen = Color(0xFF25D366);

Future<void> _openContactUrl(BuildContext context, Uri uri) async {
  try {
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      _showOpenError(context);
    }
  } catch (_) {
    if (context.mounted) {
      _showOpenError(context);
    }
  }
}

void _showOpenError(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB42318),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Text(
          'عذرًا، تعذّر فتح التطبيق المطلوب. يرجى المحاولة مرة أخرى.',
          textAlign: TextAlign.right,
        ),
      ),
    );
}

Future<void> showContactSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (BuildContext sheetContext) {
      return const _ContactSheet();
    },
  );
}

class _ContactSheet extends StatelessWidget {
  const _ContactSheet();

  static final Uri _whatsAppUri = Uri.parse(
    'https://wa.me/9647838081677?text='
    '${Uri.encodeComponent('مرحبًا، أود الاستفسار عن عقار.')}',
  );
  static final Uri _phoneUri = Uri(scheme: 'tel', path: '07838081677');

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: Color(0x33D4AF37))),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _HeaderIcon(),
                  const SizedBox(height: 16),
                  const Text(
                    'تواصل معنا',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'فريق عقارات الانبار جاهز لمساعدتك والإجابة عن استفساراتك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.66),
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      final bool stackButtons = constraints.maxWidth < 350;
                      final List<Widget> buttons = <Widget>[
                        _ContactButton(
                          label: 'تواصل عبر واتساب',
                          backgroundColor: _whatsAppGreen,
                          foregroundColor: Colors.white,
                          icon: const _WhatsAppIcon(),
                          onPressed: () =>
                              _openContactUrl(context, _whatsAppUri),
                        ),
                        _ContactButton(
                          label: 'اتصل بنا',
                          backgroundColor: _gold,
                          foregroundColor: const Color(0xFF211B07),
                          icon: const Icon(Icons.call_rounded, size: 22),
                          onPressed: () => _openContactUrl(context, _phoneUri),
                        ),
                      ];

                      if (stackButtons) {
                        return Column(
                          children: <Widget>[
                            buttons.first,
                            const SizedBox(height: 12),
                            buttons.last,
                          ],
                        );
                      }

                      return Row(
                        children: <Widget>[
                          Expanded(child: buttons.first),
                          const SizedBox(width: 12),
                          Expanded(child: buttons.last),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const _DetailsCard(),
                  const SizedBox(height: 18),
                  Text(
                    '© 2026 جميع الحقوق محفوظة — عقارات الانبار',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 11.5,
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
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: _gold.withOpacity(0.30)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: _gold.withOpacity(0.10), blurRadius: 24),
        ],
      ),
      child: const Icon(Icons.support_agent_rounded, color: _gold, size: 34),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Column(
        children: <Widget>[
          _InfoRow(
            icon: Icons.location_on_outlined,
            title: 'موقعنا',
            value: 'الأنبار — الرمادي',
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0x14FFFFFF)),
          ),
          _InfoRow(
            icon: Icons.schedule_rounded,
            title: 'ساعات العمل',
            value: 'السبت إلى الخميس  •  9:00 ص — 11:00 م',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _gold.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _gold, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.52),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// WhatsApp-style mark drawn locally so this file needs no extra icon package.
class _WhatsAppIcon extends StatelessWidget {
  const _WhatsAppIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 23,
      height: 23,
      child: CustomPaint(painter: _WhatsAppIconPainter()),
    );
  }
}

class _WhatsAppIconPainter extends CustomPainter {
  const _WhatsAppIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Rect bubble = Rect.fromLTWH(
      2.1,
      1.8,
      size.width - 4.2,
      size.height - 4.5,
    );
    canvas.drawOval(bubble, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(5.0, size.height - 5.8)
        ..lineTo(3.2, size.height - 1.8)
        ..lineTo(7.5, size.height - 3.4),
      stroke,
    );

    final Path handset = Path()
      ..moveTo(7.6, 7.0)
      ..cubicTo(8.2, 11.4, 11.6, 14.7, 16.1, 15.4)
      ..cubicTo(17.0, 15.5, 17.7, 14.0, 17.0, 13.4)
      ..lineTo(14.8, 12.2)
      ..cubicTo(14.3, 11.9, 13.8, 13.0, 13.2, 12.7)
      ..cubicTo(11.8, 12.0, 10.7, 10.9, 10.1, 9.5)
      ..cubicTo(9.8, 8.8, 10.9, 8.4, 10.5, 7.7)
      ..lineTo(9.4, 5.7)
      ..cubicTo(8.9, 4.9, 7.5, 6.0, 7.6, 7.0);
    canvas.drawPath(handset, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
