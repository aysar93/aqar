import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/edit_property_data.dart';

class EditStep3Details extends StatefulWidget {
  final EditPropertyData property;
  final VoidCallback onChanged;

  const EditStep3Details({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  State<EditStep3Details> createState() => _EditStep3DetailsState();
}

class _EditStep3DetailsState extends State<EditStep3Details> {
  late final TextEditingController titleController;
  late final TextEditingController areaController;
  late final TextEditingController roomsController;
  late final TextEditingController bathroomsController;
  late final TextEditingController livingRoomsController;
  late final TextEditingController parkingController;
  late final TextEditingController buildYearController;

  static const List<String> documentTypes = [
    'طابو',
    'عقد',
    'زراعي',
    'أخرى',
  ];

  static const List<String> furnitureStatuses = [
    'مفروش',
    'نصف مفروش',
    'غير مفروش',
  ];

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.property.title,
    );

    areaController = TextEditingController(
      text: _doubleText(widget.property.area),
    );

    roomsController = TextEditingController(
      text: _intText(widget.property.rooms),
    );

    bathroomsController = TextEditingController(
      text: _intText(widget.property.bathrooms),
    );

    livingRoomsController = TextEditingController(
      text: _intText(widget.property.livingRooms),
    );

    parkingController = TextEditingController(
      text: _intText(widget.property.parking),
    );

    buildYearController = TextEditingController(
      text: _intText(widget.property.buildYear),
    );
  }

  String _intText(int? value) {
    if (value == null || value == 0) return '';
    return value.toString();
  }

  String _doubleText(double? value) {
    if (value == null || value == 0) return '';

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  bool get hideRoomDetails {
    return widget.property.propertyType == 'أرض' ||
        widget.property.propertyType == 'محل';
  }

  @override
  void dispose() {
    titleController.dispose();
    areaController.dispose();
    roomsController.dispose();
    bathroomsController.dispose();
    livingRoomsController.dispose();
    parkingController.dispose();
    buildYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'تفاصيل العقار',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'راجع معلومات العقار وعدّل ما تحتاج إليه',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 28),
        _textField(
          controller: titleController,
          label: 'عنوان العقار',
          icon: Icons.title_rounded,
          onChanged: (value) {
            widget.property.title = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 15),
        _textField(
          controller: areaController,
          label: 'المساحة بالمتر المربع',
          icon: Icons.square_foot_rounded,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d*\.?\d*'),
            ),
          ],
          suffixText: 'م²',
          onChanged: (value) {
            widget.property.area = double.tryParse(value);
            widget.onChanged();
          },
        ),
        if (!hideRoomDetails) ...[
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: roomsController,
                  label: 'الغرف',
                  icon: Icons.bed_rounded,
                  onChanged: (value) {
                    widget.property.rooms = int.tryParse(value) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  controller: bathroomsController,
                  label: 'الحمامات',
                  icon: Icons.bathtub_rounded,
                  onChanged: (value) {
                    widget.property.bathrooms = int.tryParse(value) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _numberField(
            controller: livingRoomsController,
            label: 'الصالات',
            icon: Icons.weekend_rounded,
            onChanged: (value) {
              widget.property.livingRooms = int.tryParse(value) ?? 0;
              widget.onChanged();
            },
          ),
        ],
        const SizedBox(height: 15),
        _numberField(
          controller: parkingController,
          label: 'مواقف السيارات',
          icon: Icons.local_parking_rounded,
          onChanged: (value) {
            widget.property.parking = int.tryParse(value) ?? 0;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 15),
        _numberField(
          controller: buildYearController,
          label: 'سنة البناء',
          icon: Icons.calendar_month_rounded,
          maxLength: 4,
          onChanged: (value) {
            widget.property.buildYear = int.tryParse(value);
            widget.onChanged();
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'نوع السند',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _choiceWrap(
          values: documentTypes,
          selected: widget.property.documentType,
          onSelected: (value) {
            setState(() {
              widget.property.documentType = value;
            });
            widget.onChanged();
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'حالة التأثيث',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _choiceWrap(
          values: furnitureStatuses,
          selected: widget.property.furnitureStatus,
          onSelected: (value) {
            setState(() {
              widget.property.furnitureStatus = value;
            });
            widget.onChanged();
          },
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
    int? maxLength,
  }) {
    return _textField(
      controller: controller,
      label: label,
      icon: icon,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: onChanged,
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
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
        onChanged: onChanged,
        textAlign: TextAlign.right,
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
          suffixText: suffixText,
          suffixStyle: const TextStyle(
            color: Color(0xffD4AF37),
          ),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _choiceWrap({
    required List<String> values,
    required String? selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: values.map((value) {
        final isSelected = selected == value;

        return ChoiceChip(
          label: Text(value),
          selected: isSelected,
          onSelected: (_) => onSelected(value),
          showCheckmark: false,
          backgroundColor: const Color(0xff1E293B),
          selectedColor: const Color(0xffD4AF37),
          side: BorderSide(
            color: isSelected ? const Color(0xffD4AF37) : Colors.white10,
          ),
          labelStyle: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
      }).toList(),
    );
  }
}
