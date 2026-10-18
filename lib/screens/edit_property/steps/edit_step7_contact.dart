import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/edit_property_data.dart';

class EditStep7Contact extends StatefulWidget {
  final EditPropertyData property;
  final VoidCallback onChanged;

  const EditStep7Contact({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  State<EditStep7Contact> createState() => _EditStep7ContactState();
}

class _EditStep7ContactState extends State<EditStep7Contact> {
  late final TextEditingController descriptionController;
  late final TextEditingController phoneController;
  late final TextEditingController whatsappController;

  @override
  void initState() {
    super.initState();

    descriptionController = TextEditingController(
      text: widget.property.description,
    );

    phoneController = TextEditingController(
      text: widget.property.phone,
    );

    whatsappController = TextEditingController(
      text: widget.property.whatsapp,
    );
  }

  @override
  void dispose() {
    descriptionController.dispose();
    phoneController.dispose();
    whatsappController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'الوصف والتواصل',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'راجع وصف العقار ومعلومات التواصل',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 28),
        _field(
          controller: descriptionController,
          label: 'وصف العقار',
          icon: Icons.description_outlined,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          onChanged: (value) {
            widget.property.description = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 18),
        _field(
          controller: phoneController,
          label: 'رقم الهاتف',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'[0-9+]'),
            ),
          ],
          onChanged: (value) {
            widget.property.phone = value.trim();
            widget.onChanged();
          },
        ),
        const SizedBox(height: 18),
        _field(
          controller: whatsappController,
          label: 'رقم واتساب',
          icon: Icons.chat_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'[0-9+]'),
            ),
          ],
          onChanged: (value) {
            widget.property.whatsapp = value.trim();
            widget.onChanged();
          },
        ),
        const SizedBox(height: 25),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xff1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xffD4AF37).withValues(alpha: .20),
            ),
          ),
          child: const Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xffD4AF37),
                size: 21,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'بعد حفظ التعديلات سيعود العقار إلى قيد المراجعة حتى تتم الموافقة على التعديلات',
                  textAlign: TextAlign.right,
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
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        onChanged: onChanged,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.white60,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(0xffD4AF37),
          ),
          alignLabelWithHint: maxLines > 1,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}
