import 'package:flutter/material.dart';

class AdvertiseOptionsSheet extends StatelessWidget {
  final VoidCallback onOfferProperty;
  final VoidCallback onRequestProperty;

  const AdvertiseOptionsSheet({
    super.key,
    required this.onOfferProperty,
    required this.onRequestProperty,
  });

  static const Color _gold = Color(0xffD4AF37);
  static const Color _background = Color(0xff0F172A);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ==========================================
              // مقبض النافذة
              // ==========================================

              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.18,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              const SizedBox(height: 22),

              // ==========================================
              // العنوان
              // ==========================================

              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _gold.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: _gold.withValues(
                      alpha: 0.22,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: _gold,
                  size: 28,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "ماذا تريد أن تعلن؟",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "اختر نوع الإعلان الذي تريد نشره",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 22),

              // ==========================================
              // اعرض عقارًا
              // ==========================================

              _AdvertiseOptionCard(
                title: "اعرض عقارًا",
                subtitle: "لدي عقار للبيع أو الإيجار",
                icon: Icons.add_home_work_rounded,
                onTap: onOfferProperty,
              ),

              const SizedBox(height: 13),

              // ==========================================
              // اطلب عقارًا
              // ==========================================

              _AdvertiseOptionCard(
                title: "اطلب عقارًا",
                subtitle: "أبحث عن عقار للشراء أو الإيجار",
                icon: Icons.manage_search_rounded,
                onTap: onRequestProperty,
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvertiseOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdvertiseOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  static const Color _gold = Color(0xffD4AF37);

  static const Color _card = Color(0xff1E293B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.06,
              ),
            ),
          ),
          child: Row(
            children: [
              // ==========================================
              // الأيقونة
              // ==========================================

              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _gold.withValues(
                    alpha: 0.11,
                  ),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: _gold.withValues(
                      alpha: 0.18,
                    ),
                  ),
                ),
                child: Icon(
                  icon,
                  color: _gold,
                  size: 29,
                ),
              ),

              const SizedBox(width: 15),

              // ==========================================
              // النص
              // ==========================================

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
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

              // ==========================================
              // السهم
              // ==========================================

              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _gold.withValues(
                    alpha: 0.08,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _gold,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
