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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "نوع الإعلان",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "اختر نوع الإعلان",
            style: TextStyle(
              color: Colors.white60,
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
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sell_rounded,
                          size: 55,
                          color: Color(0xffD4AF37),
                        ),
                        SizedBox(height: 15),
                        Text(
                          "للبيع",
                          style: TextStyle(
                            color: Colors.white,
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
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.key_rounded,
                          size: 55,
                          color: Color(0xffD4AF37),
                        ),
                        SizedBox(height: 15),
                        Text(
                          "للإيجار",
                          style: TextStyle(
                            color: Colors.white,
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
