import 'package:flutter/material.dart';

import '../../../models/property_request_data.dart';
import '../widgets/request_glass_card.dart';

class Step1RequestType extends StatelessWidget {
  final PropertyRequestData request;
  final VoidCallback onChanged;

  const Step1RequestType({
    super.key,
    required this.request,
    required this.onChanged,
  });

  static const Color _gold = Color(0xffD4AF37);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        const Text(
          "ما نوع الطلب؟",
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "حدد ما إذا كنت تبحث عن عقار للشراء أو للإيجار",
          style: TextStyle(
            color: Colors.white60,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        _RequestTypeOption(
          title: "شراء عقار",
          subtitle: "أبحث عن عقار متوفر للبيع",
          icon: Icons.real_estate_agent_rounded,
          selected: request.requestType == "شراء",
          onTap: () {
            request.requestType = "شراء";
            onChanged();
          },
        ),
        const SizedBox(height: 14),
        _RequestTypeOption(
          title: "استئجار عقار",
          subtitle: "أبحث عن عقار متوفر للإيجار",
          icon: Icons.key_rounded,
          selected: request.requestType == "إيجار",
          onTap: () {
            request.requestType = "إيجار";
            onChanged();
          },
        ),
        const SizedBox(height: 24),
        RequestGlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: _gold,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "سيظهر طلبك لأصحاب العقارات بعد إرساله ومراجعته",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestTypeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RequestTypeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? _gold.withValues(alpha: 0.10)
                : const Color(0xff1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _gold : Colors.white.withValues(alpha: 0.06),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: selected ? _gold : _gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: selected ? _background : _gold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? _gold : Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _gold : Colors.transparent,
                  border: Border.all(
                    color: selected ? _gold : Colors.white38,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: _background,
                        size: 17,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
