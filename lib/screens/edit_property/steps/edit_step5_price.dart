import 'package:flutter/material.dart';

import '../../../utils/currency.dart';
import '../models/edit_property_data.dart';

class EditStep5Price extends StatefulWidget {
  final EditPropertyData property;
  final VoidCallback onChanged;

  const EditStep5Price({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  State<EditStep5Price> createState() => _EditStep5PriceState();
}

class _EditStep5PriceState extends State<EditStep5Price> {
  late final TextEditingController priceController;

  @override
  void initState() {
    super.initState();

    priceController = TextEditingController();

    if (widget.property.price != null) {
      final rawPrice = widget.property.price!.toStringAsFixed(0);

      priceController.text = _formatInitialPrice(rawPrice);
    }
  }

  String _formatInitialPrice(String value) {
    if (value.isEmpty) return '';

    final number = int.tryParse(value);

    if (number == null) return value;

    final text = number.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final positionFromEnd = text.length - i;

      buffer.write(text[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }

  void _updatePrice(String value) {
    final cleanValue = value.replaceAll(',', '').trim();

    widget.property.price = double.tryParse(cleanValue);

    widget.onChanged();

    setState(() {});
  }

  @override
  void dispose() {
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'السعر',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'راجع سعر العقار وعدّله عند الحاجة',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 30),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xff1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              CurrencyInputFormatter(),
            ],
            onChanged: _updatePrice,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              labelText: 'السعر',
              labelStyle: TextStyle(
                color: Colors.white60,
              ),
              prefixIcon: Icon(
                Icons.payments_rounded,
                color: Color(0xffD4AF37),
              ),
              suffixText: 'د.ع',
              suffixStyle: TextStyle(
                color: Color(0xffD4AF37),
                fontWeight: FontWeight.bold,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (priceController.text.replaceAll(',', '').trim().isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xffD4AF37).withValues(alpha: .20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'السعر كتابةً',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  amountToArabicWords(
                    priceController.text,
                  ),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xffD4AF37),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 25),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xff1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.property.negotiable
                  ? const Color(0xffD4AF37).withValues(alpha: .35)
                  : Colors.white10,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: SwitchListTile(
              value: widget.property.negotiable,
              onChanged: (value) {
                setState(() {
                  widget.property.negotiable = value;
                });

                widget.onChanged();
              },
              title: const Text(
                'السعر قابل للتفاوض',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                widget.property.negotiable
                    ? 'سيظهر للمستخدم أن السعر قابل للتفاوض'
                    : 'السعر المعروض غير محدد كقابل للتفاوض',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              activeThumbColor: const Color(0xffD4AF37),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
