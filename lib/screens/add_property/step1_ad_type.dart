import 'package:flutter/material.dart';
import '../../models/add_property_data.dart';
import 'widgets/glass_card.dart';

class Step1AdType extends StatelessWidget {
  final AddPropertyData property;
  final VoidCallback onChanged;

  const Step1AdType({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "نوع الإعلان",
            style: TextStyle(
              color: onSurface,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "اختر نوع الإعلان",
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.60),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GlassCard(
                    selected: property.adType == "للبيع",
                    onTap: () {
                      property.adType = "للبيع";

                      onChanged();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.sell_rounded,
                          size: 55,
                          color: Color(0xffC5A16B),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "للبيع",
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GlassCard(
                    selected: property.adType == "للإيجار",
                    onTap: () {
                      property.adType = "للإيجار";

                      onChanged();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.key_rounded,
                          size: 55,
                          color: Color(0xffC5A16B),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "للإيجار",
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
