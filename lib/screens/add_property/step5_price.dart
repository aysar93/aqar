import 'package:flutter/material.dart';
import '../../models/add_property_data.dart';
import '../../utils/currency.dart';

class Step5Price extends StatefulWidget {
  final AddPropertyData property;
  final VoidCallback onChanged;

  const Step5Price({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  State<Step5Price> createState() => _Step5PriceState();
}

class _Step5PriceState extends State<Step5Price> {
  final priceController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.property.price != null) {
      priceController.text = widget.property.price!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xff1E293B) : Colors.white;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "السعر",
              style: TextStyle(
                color: onSurface,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "أدخل سعر العقار بالدينار العراقي",
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  CurrencyInputFormatter(),
                ],
                onChanged: (value) {
                  final number = double.tryParse(
                    value.replaceAll(",", ""),
                  );

                  widget.property.price = number;

                  widget.onChanged();

                  setState(() {});
                },
                style: TextStyle(
                  color: onSurface,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  labelText: "السعر",
                  labelStyle: TextStyle(
                    color: onSurface.withValues(alpha: 0.60),
                  ),
                  prefixIcon: const Icon(
                    Icons.payments,
                    color: Color(0xffC5A16B),
                  ),
                  suffixText: "د.ع",
                  suffixStyle: const TextStyle(
                    color: Color(0xffC5A16B),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (priceController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  amountToArabicWords(priceController.text),
                  style: const TextStyle(
                    color: Color(0xffC5A16B),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SwitchListTile(
              value: widget.property.negotiable,
              onChanged: (value) {
                setState(() {
                  widget.property.negotiable = value;
                });

                widget.onChanged();
              },
              title: Text(
                "السعر قابل للتفاوض",
                style: TextStyle(
                  color: onSurface,
                ),
              ),
              activeThumbColor: const Color(0xffC5A16B),
            ),
          ],
        ),
      ),
    );
  }
}
