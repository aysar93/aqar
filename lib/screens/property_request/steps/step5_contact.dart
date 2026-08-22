import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/property_request_data.dart';
import '../widgets/request_glass_card.dart';

class Step5Contact extends StatefulWidget {
  final PropertyRequestData request;
  final VoidCallback onChanged;

  const Step5Contact({
    super.key,
    required this.request,
    required this.onChanged,
  });

  @override
  State<Step5Contact> createState() => _Step5ContactState();
}

class _Step5ContactState extends State<Step5Contact> {
  static const Color _gold = Color(0xffD4AF37);

  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;

  @override
  void initState() {
    super.initState();

    _phoneController = TextEditingController(
      text: widget.request.phone,
    );

    _whatsappController = TextEditingController(
      text: widget.request.whatsapp,
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        const Text(
          "كيف يمكن التواصل معك؟",
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "أدخل معلومات التواصل ليتمكن أصحاب العقارات المناسبة من التواصل معك",
          style: TextStyle(
            color: Colors.white60,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        RequestGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.phone_rounded,
                title: "رقم الهاتف",
              ),
              const SizedBox(height: 6),
              const Text(
                "رقم الهاتف مطلوب لنشر الطلب",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9٠-٩۰-۹+\s]'),
                  ),
                ],
                onChanged: (value) {
                  widget.request.phone = _normalizePhone(value);
                  widget.onChanged();
                  setState(() {});
                },
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                decoration: _inputDecoration(
                  label: "رقم الهاتف",
                  icon: Icons.phone_rounded,
                  hint: "مثال: 07XXXXXXXXX",
                ),
              ),
              if (_phoneController.text.trim().isNotEmpty &&
                  !_isValidPhone(widget.request.phone)) ...[
                const SizedBox(height: 10),
                const _ValidationMessage(
                  text: "يرجى إدخال رقم هاتف صحيح",
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        RequestGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.chat_rounded,
                title: "واتساب",
              ),
              const SizedBox(height: 6),
              const Text(
                "اختياري — اتركه فارغًا إذا كان رقم واتساب هو نفس رقم الهاتف",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9٠-٩۰-۹+\s]'),
                  ),
                ],
                onChanged: (value) {
                  widget.request.whatsapp = _normalizePhone(value);
                  widget.onChanged();
                  setState(() {});
                },
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                decoration: _inputDecoration(
                  label: "رقم واتساب",
                  icon: Icons.chat_rounded,
                  hint: "مثال: 07XXXXXXXXX",
                ),
              ),
              if (_whatsappController.text.trim().isNotEmpty &&
                  !_isValidPhone(widget.request.whatsapp)) ...[
                const SizedBox(height: 10),
                const _ValidationMessage(
                  text: "يرجى إدخال رقم واتساب صحيح",
                ),
              ],
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    final phone = widget.request.phone.trim();

                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "أدخل رقم الهاتف أولًا",
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      widget.request.whatsapp = phone;
                      _whatsappController.text = phone;
                      _whatsappController.selection = TextSelection.collapsed(
                        offset: _whatsappController.text.length,
                      );
                    });

                    widget.onChanged();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.20),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.content_copy_rounded,
                          color: _gold,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "استخدام رقم الهاتف للواتساب",
                          style: TextStyle(
                            color: _gold,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
                  Icons.verified_user_outlined,
                  color: _gold,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "تأكد من صحة معلومات التواصل قبل إرسال الطلب للمراجعة",
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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: Colors.white60,
        fontSize: 14,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: _gold,
        size: 21,
      ),
      filled: true,
      fillColor: const Color(0xff0F172A).withValues(
        alpha: 0.55,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: _gold,
          width: 1.2,
        ),
      ),
    );
  }

  String _normalizePhone(String value) {
    const arabicDigits = "٠١٢٣٤٥٦٧٨٩";
    const persianDigits = "۰۱۲۳۴۵۶۷۸۹";
    const englishDigits = "0123456789";

    var result = value.trim();

    for (var i = 0; i < 10; i++) {
      result = result
          .replaceAll(arabicDigits[i], englishDigits[i])
          .replaceAll(persianDigits[i], englishDigits[i]);
    }

    result = result.replaceAll(
      RegExp(r'\s+'),
      "",
    );

    return result;
  }

  bool _isValidPhone(String value) {
    final phone = value.trim();

    if (phone.isEmpty) {
      return false;
    }

    // رقم عراقي محلي:
    // 07XXXXXXXXX
    if (RegExp(r'^07\d{9}$').hasMatch(phone)) {
      return true;
    }

    // رقم عراقي دولي:
    // +9647XXXXXXXXX
    if (RegExp(r'^\+9647\d{9}$').hasMatch(phone)) {
      return true;
    }

    return false;
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  static const Color _gold = Color(0xffD4AF37);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: _gold,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  final String text;

  const _ValidationMessage({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFF59E0B),
          size: 17,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
