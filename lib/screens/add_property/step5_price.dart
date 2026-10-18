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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "السعر",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "أدخل سعر العقار بالدينار العراقي",
              style: TextStyle(
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xff1E293B),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                decoration: const InputDecoration(
                  labelText: "السعر",
                  labelStyle: TextStyle(
                    color: Colors.white60,
                  ),
                  prefixIcon: Icon(
                    Icons.payments,
                    color: Color(0xffD4AF37),
                  ),
                  suffixText: "د.ع",
                  suffixStyle: TextStyle(
                    color: Color(0xffD4AF37),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (priceController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xff1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  amountToArabicWords(priceController.text),
                  style: const TextStyle(
                    color: Color(0xffD4AF37),
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
              title: const Text(
                "السعر قابل للتفاوض",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              activeThumbColor: const Color(0xffD4AF37),
            ),
          ],
        ),
      ),
    );
  }
}
