import 'package:flutter/material.dart';
import '../../models/add_property_data.dart';

class Step7Contact extends StatefulWidget {
  final AddPropertyData property;
  final VoidCallback onChanged;

  const Step7Contact({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  State<Step7Contact> createState() => _Step7ContactState();
}

class _Step7ContactState extends State<Step7Contact> {
  final phoneController = TextEditingController();

  final whatsappController = TextEditingController();

  @override
  void initState() {
    super.initState();

    phoneController.text = widget.property.phone;

    whatsappController.text = widget.property.whatsapp;
  }

  @override
  void dispose() {
    phoneController.dispose();
    whatsappController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Text(
            "معلومات التواصل",
            style: TextStyle(
              color: onSurface,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "أدخل معلومات التواصل مع صاحب العقار",
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.60),
            ),
          ),
          const SizedBox(height: 30),
          contactField(
            "رقم الهاتف *",
            phoneController,
            Icons.phone,
            (value) {
              widget.property.phone = value;

              widget.onChanged();
            },
          ),
          contactField(
            "رقم الواتساب (اختياري)",
            whatsappController,
            Icons.chat,
            (value) {
              widget.property.whatsapp = value;

              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget contactField(
    String title,
    TextEditingController controller,
    IconData icon,
    Function(String) onChange,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Container(
      margin: const EdgeInsets.only(
        bottom: 15,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        onChanged: onChange,
        style: TextStyle(
          color: onSurface,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: const Color(
              0xffC5A16B,
            ),
          ),
          labelText: title,
          labelStyle: TextStyle(
            color: onSurface.withValues(alpha: 0.60),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }
}
