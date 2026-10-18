import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/property_request_data.dart';
import '../widgets/request_glass_card.dart';

class Step4Requirements extends StatefulWidget {
  final PropertyRequestData request;
  final VoidCallback onChanged;

  const Step4Requirements({
    super.key,
    required this.request,
    required this.onChanged,
  });

  @override
  State<Step4Requirements> createState() => _Step4RequirementsState();
}

class _Step4RequirementsState extends State<Step4Requirements> {
  static const Color _gold = Color(0xffD4AF37);

  late final TextEditingController _minAreaController;
  late final TextEditingController _maxAreaController;

  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;

  late final TextEditingController _roomsController;
  late final TextEditingController _bathroomsController;
  late final TextEditingController _livingRoomsController;
  late final TextEditingController _parkingController;

  late final TextEditingController _minFloorsController;
  late final TextEditingController _maxFloorsController;
  late final TextEditingController _apartmentFloorController;

  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();

    _minAreaController = TextEditingController(
      text: _doubleText(widget.request.minArea),
    );

    _maxAreaController = TextEditingController(
      text: _doubleText(widget.request.maxArea),
    );

    _minPriceController = TextEditingController(
      text: _priceText(widget.request.minPrice),
    );

    _maxPriceController = TextEditingController(
      text: _priceText(widget.request.maxPrice),
    );

    _roomsController = TextEditingController(
      text: _intText(widget.request.rooms),
    );

    _bathroomsController = TextEditingController(
      text: _intText(widget.request.bathrooms),
    );

    _livingRoomsController = TextEditingController(
      text: _intText(widget.request.livingRooms),
    );

    _parkingController = TextEditingController(
      text: _intText(widget.request.parking),
    );

    _minFloorsController = TextEditingController(
      text: _intText(widget.request.minFloors),
    );

    _maxFloorsController = TextEditingController(
      text: _intText(widget.request.maxFloors),
    );

    _apartmentFloorController = TextEditingController(
      text: _intText(widget.request.apartmentFloor),
    );

    _descriptionController = TextEditingController(
      text: widget.request.description,
    );
  }

  @override
  void dispose() {
    _minAreaController.dispose();
    _maxAreaController.dispose();

    _minPriceController.dispose();
    _maxPriceController.dispose();

    _roomsController.dispose();
    _bathroomsController.dispose();
    _livingRoomsController.dispose();
    _parkingController.dispose();

    _minFloorsController.dispose();
    _maxFloorsController.dispose();
    _apartmentFloorController.dispose();

    _descriptionController.dispose();

    super.dispose();
  }

  String get _propertyType {
    return widget.request.propertyType ?? "";
  }

  bool get _showRooms {
    return _propertyType == "بيت" ||
        _propertyType == "شقة" ||
        _propertyType == "مزرعة";
  }

  bool get _showBathrooms {
    return _propertyType == "بيت" ||
        _propertyType == "شقة" ||
        _propertyType == "مزرعة";
  }

  bool get _showLivingRooms {
    return _propertyType == "بيت" ||
        _propertyType == "شقة" ||
        _propertyType == "مزرعة";
  }

  bool get _showParking {
    return _propertyType == "بيت" ||
        _propertyType == "شقة" ||
        _propertyType == "محل" ||
        _propertyType == "عمارة" ||
        _propertyType == "مزرعة";
  }

  bool get _showFloors {
    return _propertyType == "بيت" ||
        _propertyType == "محل" ||
        _propertyType == "عمارة" ||
        _propertyType == "مزرعة";
  }

  bool get _showApartmentFloor {
    return _propertyType == "شقة";
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        const Text(
          "ما مواصفات العقار المطلوب؟",
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _propertyType.isEmpty
              ? "حدد المساحة والميزانية والمواصفات التي تبحث عنها"
              : "حدد مواصفات $_propertyType الذي تبحث عنه",
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 26),

        // ==================================================
        // المساحة
        // ==================================================

        RequestGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.square_foot_rounded,
                title: "المساحة المطلوبة",
              ),
              const SizedBox(height: 6),
              const Text(
                "يمكنك تحديد أقل وأعلى مساحة مناسبة لك",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      controller: _minAreaController,
                      label: "من",
                      icon: Icons.compress_rounded,
                      suffix: "م²",
                      decimal: true,
                      onChanged: (value) {
                        widget.request.minArea = _parseDouble(value);
                        widget.onChanged();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _numberField(
                      controller: _maxAreaController,
                      label: "إلى",
                      icon: Icons.expand_rounded,
                      suffix: "م²",
                      decimal: true,
                      onChanged: (value) {
                        widget.request.maxArea = _parseDouble(value);
                        widget.onChanged();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
              if (!widget.request.hasValidAreaRange) ...[
                const SizedBox(height: 10),
                const _ValidationMessage(
                  text: "المساحة القصوى يجب أن تكون أكبر من أو تساوي الدنيا",
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ==================================================
        // الميزانية
        // ==================================================

        RequestGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.payments_rounded,
                title: "الميزانية",
              ),
              const SizedBox(height: 6),
              Text(
                widget.request.requestType == "إيجار"
                    ? "حدد نطاق الإيجار الذي تبحث عنه"
                    : "حدد نطاق السعر المناسب لك",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              _numberField(
                controller: _minPriceController,
                label: widget.request.requestType == "إيجار"
                    ? "أقل إيجار"
                    : "أقل سعر",
                icon: Icons.arrow_downward_rounded,
                suffix: "د.ع",
                formatter: _ThousandsFormatter(),
                onChanged: (value) {
                  widget.request.minPrice = _parsePrice(value);
                  widget.onChanged();
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              _numberField(
                controller: _maxPriceController,
                label: widget.request.requestType == "إيجار"
                    ? "أعلى إيجار"
                    : "أعلى سعر",
                icon: Icons.arrow_upward_rounded,
                suffix: "د.ع",
                formatter: _ThousandsFormatter(),
                onChanged: (value) {
                  widget.request.maxPrice = _parsePrice(value);
                  widget.onChanged();
                  setState(() {});
                },
              ),
              if (!widget.request.hasValidPriceRange) ...[
                const SizedBox(height: 10),
                const _ValidationMessage(
                  text:
                      "الحد الأعلى للميزانية يجب أن يكون أكبر من أو يساوي الحد الأدنى",
                ),
              ],
            ],
          ),
        ),

        // ==================================================
        // المواصفات حسب نوع العقار
        // ==================================================

        if (_showRooms ||
            _showBathrooms ||
            _showLivingRooms ||
            _showParking ||
            _showFloors ||
            _showApartmentFloor) ...[
          const SizedBox(height: 16),
          RequestGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.tune_rounded,
                  title: "المواصفات المطلوبة",
                ),
                const SizedBox(height: 6),
                const Text(
                  "اترك أي حقل فارغًا إذا لم يكن شرطًا بالنسبة لك",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                if (_showRooms) ...[
                  _numberField(
                    controller: _roomsController,
                    label: "عدد الغرف",
                    icon: Icons.bed_rounded,
                    onChanged: (value) {
                      widget.request.rooms = _parseInt(value);
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showBathrooms) ...[
                  _numberField(
                    controller: _bathroomsController,
                    label: "عدد الحمامات",
                    icon: Icons.bathtub_rounded,
                    onChanged: (value) {
                      widget.request.bathrooms = _parseInt(value);
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showLivingRooms) ...[
                  _numberField(
                    controller: _livingRoomsController,
                    label: "عدد المجالس",
                    icon: Icons.weekend_rounded,
                    onChanged: (value) {
                      widget.request.livingRooms = _parseInt(value);
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showParking) ...[
                  _numberField(
                    controller: _parkingController,
                    label: "عدد مواقف السيارات",
                    icon: Icons.local_parking_rounded,
                    onChanged: (value) {
                      widget.request.parking = _parseInt(value);
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showFloors) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          controller: _minFloorsController,
                          label: "أقل طوابق",
                          icon: Icons.layers_rounded,
                          labelFontSize: 10,
                          onChanged: (value) {
                            widget.request.minFloors = _parseInt(value);
                            widget.onChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _numberField(
                          controller: _maxFloorsController,
                          label: "أعلى طوابق",
                          icon: Icons.layers_outlined,
                          labelFontSize: 10,
                          onChanged: (value) {
                            widget.request.maxFloors = _parseInt(value);
                            widget.onChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showApartmentFloor)
                  _numberField(
                    controller: _apartmentFloorController,
                    label: "الطابق المطلوب",
                    icon: Icons.stairs_rounded,
                    onChanged: (value) {
                      widget.request.apartmentFloor = _parseInt(value);
                      widget.onChanged();
                    },
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ==================================================
        // تفاصيل إضافية
        // ==================================================

        RequestGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.notes_rounded,
                title: "تفاصيل إضافية",
              ),
              const SizedBox(height: 6),
              const Text(
                "اكتب أي شروط أو مواصفات أخرى مهمة بالنسبة لك",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 7,
                maxLength: 1000,
                textInputAction: TextInputAction.newline,
                onChanged: (value) {
                  widget.request.description = value.trim();
                  widget.onChanged();
                },
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.6,
                ),
                decoration: _inputDecoration(
                  label: "وصف الطلب",
                  icon: Icons.edit_note_rounded,
                  hint: "مثال: أفضل بيتًا على شارع رئيسي وقريبًا من المدارس",
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
    String? suffix,
    bool decimal = false,
    TextInputFormatter? formatter,
    double labelFontSize = 12,
  }) {
    final formatters = <TextInputFormatter>[
      if (formatter != null)
        formatter
      else if (decimal)
        FilteringTextInputFormatter.allow(
          RegExp(r'^\d*\.?\d{0,2}'),
        )
      else
        FilteringTextInputFormatter.digitsOnly,
    ];

    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: decimal,
      ),
      inputFormatters: formatters,
      onChanged: onChanged,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
      ),
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        labelFontSize: labelFontSize,
      ).copyWith(
        suffixText: suffix,
        suffixStyle: const TextStyle(
          color: _gold,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    double labelFontSize = 12,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: Colors.white60,
        fontSize: labelFontSize,
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

  static String _doubleText(double? value) {
    if (value == null) return "";

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  static String _intText(int? value) {
    return value?.toString() ?? "";
  }

  static String _priceText(double? value) {
    if (value == null) return "";

    final number = value.round().toString();

    return number.replaceAllMapped(
      RegExp(r'(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  static double? _parseDouble(String value) {
    final cleaned = _normalizeDigits(
      value.replaceAll(",", "").trim(),
    );

    if (cleaned.isEmpty) return null;

    return double.tryParse(cleaned);
  }

  static double? _parsePrice(String value) {
    final cleaned = _normalizeDigits(
      value.replaceAll(",", "").trim(),
    );

    if (cleaned.isEmpty) return null;

    return double.tryParse(cleaned);
  }

  static int? _parseInt(String value) {
    final cleaned = _normalizeDigits(
      value.replaceAll(",", "").trim(),
    );

    if (cleaned.isEmpty) return null;

    return int.tryParse(cleaned);
  }

  static String _normalizeDigits(String value) {
    const arabicDigits = "٠١٢٣٤٥٦٧٨٩";
    const persianDigits = "۰۱۲۳۴۵۶۷۸۹";
    const englishDigits = "0123456789";

    var result = value;

    for (var i = 0; i < 10; i++) {
      result = result
          .replaceAll(arabicDigits[i], englishDigits[i])
          .replaceAll(persianDigits[i], englishDigits[i]);
    }

    return result;
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

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = _normalizeDigits(
      newValue.text,
    ).replaceAll(",", "");

    text = text.replaceAll(
      RegExp(r'[^0-9]'),
      "",
    );

    if (text.isEmpty) {
      return const TextEditingValue();
    }

    // إزالة الأصفار الزائدة من بداية الرقم،
    // مع الإبقاء على صفر واحد إذا كان الرقم صفرًا.
    text = text.replaceFirst(
      RegExp(r'^0+(?=\d)'),
      "",
    );

    final formatted = text.replaceAllMapped(
      RegExp(r'(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }

  static String _normalizeDigits(String value) {
    const arabicDigits = "٠١٢٣٤٥٦٧٨٩";
    const persianDigits = "۰۱۲۳۴۵۶۷۸۹";
    const englishDigits = "0123456789";

    var result = value;

    for (var i = 0; i < 10; i++) {
      result = result
          .replaceAll(arabicDigits[i], englishDigits[i])
          .replaceAll(persianDigits[i], englishDigits[i]);
    }

    return result;
  }
}
