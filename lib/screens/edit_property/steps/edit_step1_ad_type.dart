import 'package:flutter/material.dart';

import '../models/edit_property_data.dart';
import '../widgets/edit_glass_card.dart';

class EditStep1AdType extends StatelessWidget {
  final EditPropertyData property;
  final VoidCallback onChanged;

  const EditStep1AdType({
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
                  child: EditGlassCard(
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
                  child: EditGlassCard(
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
