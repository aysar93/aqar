import 'package:flutter/material.dart';
import '../../models/add_property_data.dart';

class Step3Details extends StatefulWidget {
  final AddPropertyData property;
  final VoidCallback onChanged;

  const Step3Details({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  State<Step3Details> createState() => _Step3DetailsState();
}

class _Step3DetailsState extends State<Step3Details> {
  late final TextEditingController titleController;
  late final TextEditingController roomsController;
  late final TextEditingController bathroomsController;
  late final TextEditingController livingRoomsController;
  late final TextEditingController parkingController;
  late final TextEditingController areaController;
  late final TextEditingController frontageController;
  late final TextEditingController depthController;
  late final TextEditingController floorsController;
  late final TextEditingController apartmentFloorController;
  late final TextEditingController unitsCountController;
  late final TextEditingController buildYearController;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.property.title,
    );

    roomsController = TextEditingController(
      text: widget.property.rooms?.toString() ?? "",
    );

    bathroomsController = TextEditingController(
      text: widget.property.bathrooms?.toString() ?? "",
    );

    livingRoomsController = TextEditingController(
      text: widget.property.livingRooms?.toString() ?? "",
    );

    parkingController = TextEditingController(
      text: widget.property.parking?.toString() ?? "",
    );

    areaController = TextEditingController(
      text: _numberText(widget.property.area),
    );

    frontageController = TextEditingController(
      text: _numberText(widget.property.frontage),
    );

    depthController = TextEditingController(
      text: _numberText(widget.property.depth),
    );

    floorsController = TextEditingController(
      text: widget.property.floors?.toString() ?? "",
    );

    apartmentFloorController = TextEditingController(
      text: widget.property.apartmentFloor?.toString() ?? "",
    );

    unitsCountController = TextEditingController(
      text: widget.property.unitsCount?.toString() ?? "",
    );

    buildYearController = TextEditingController(
      text: widget.property.buildYear?.toString() ?? "",
    );
  }

  String _numberText(double? value) {
    if (value == null) return "";

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  @override
  void dispose() {
    titleController.dispose();
    roomsController.dispose();
    bathroomsController.dispose();
    livingRoomsController.dispose();
    parkingController.dispose();
    areaController.dispose();
    frontageController.dispose();
    depthController.dispose();
    floorsController.dispose();
    apartmentFloorController.dispose();
    unitsCountController.dispose();
    buildYearController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.property.propertyType;

    final isHouse = type == "بيت";
    final isApartment = type == "شقة";
    final isLand = type == "أرض";
    final isShop = type == "محل";
    final isBuilding = type == "عمارة";
    final isFarm = type == "مزرعة";

    final showResidentialDetails = isHouse || isApartment || isFarm;

    final showFrontageAndDepth =
        isHouse || isLand || isShop || isBuilding || isFarm;

    final showFloors = isHouse || isShop || isBuilding || isFarm;

    final showApartmentFloor = isApartment;

    final showUnitsCount = isBuilding;

    final showParking = !isLand;

    final showBuildYear = !isLand;

    final showFurniture = isHouse || isApartment || isFarm;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text(
            "تفاصيل العقار",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            type == null
                ? "أدخل تفاصيل العقار"
                : "أدخل التفاصيل المناسبة لـ $type",
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 25),
          field(
            title: "عنوان الإعلان",
            controller: titleController,
            icon: Icons.title_rounded,
            keyboardType: TextInputType.text,
            onChanged: (value) {
              widget.property.title = value.trim();
              widget.onChanged();
            },
          ),
          if (showResidentialDetails) ...[
            field(
              title: "عدد الغرف",
              controller: roomsController,
              icon: Icons.meeting_room_rounded,
              onChanged: (value) {
                widget.property.rooms = int.tryParse(value);
                widget.onChanged();
              },
            ),
            field(
              title: "عدد الحمامات",
              controller: bathroomsController,
              icon: Icons.bathtub_rounded,
              onChanged: (value) {
                widget.property.bathrooms = int.tryParse(value);
                widget.onChanged();
              },
            ),
            field(
              title: "عدد المجالس",
              controller: livingRoomsController,
              icon: Icons.weekend_rounded,
              onChanged: (value) {
                widget.property.livingRooms = int.tryParse(value);
                widget.onChanged();
              },
            ),
          ],
          field(
            title: "المساحة الكلية (م²)",
            controller: areaController,
            icon: Icons.square_foot_rounded,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            onChanged: (value) {
              widget.property.area = double.tryParse(value);
              widget.onChanged();
            },
          ),
          if (showFrontageAndDepth) ...[
            field(
              title: "الواجهة (م)",
              controller: frontageController,
              icon: Icons.swap_horiz_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) {
                widget.property.frontage = double.tryParse(value);
                widget.onChanged();
              },
            ),
            field(
              title: "النزال / العمق (م)",
              controller: depthController,
              icon: Icons.straighten_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) {
                widget.property.depth = double.tryParse(value);
                widget.onChanged();
              },
            ),
          ],
          if (showFloors)
            field(
              title: isBuilding
                  ? "عدد طوابق العمارة"
                  : isFarm
                      ? "عدد طوابق البناء"
                      : "عدد الطوابق",
              controller: floorsController,
              icon: Icons.layers_rounded,
              onChanged: (value) {
                widget.property.floors = int.tryParse(value);
                widget.onChanged();
              },
            ),
          if (showApartmentFloor)
            field(
              title: "الطابق الذي تقع فيه الشقة",
              controller: apartmentFloorController,
              icon: Icons.stairs_rounded,
              onChanged: (value) {
                widget.property.apartmentFloor = int.tryParse(value);
                widget.onChanged();
              },
            ),
          if (showUnitsCount)
            field(
              title: "عدد الشقق / الوحدات",
              controller: unitsCountController,
              icon: Icons.apartment_rounded,
              onChanged: (value) {
                widget.property.unitsCount = int.tryParse(value);
                widget.onChanged();
              },
            ),
          if (showParking)
            field(
              title: "عدد مواقف السيارات",
              controller: parkingController,
              icon: Icons.directions_car_rounded,
              onChanged: (value) {
                widget.property.parking = int.tryParse(value);
                widget.onChanged();
              },
            ),
          if (showBuildYear)
            field(
              title: "سنة البناء",
              controller: buildYearController,
              icon: Icons.calendar_month_rounded,
              onChanged: (value) {
                widget.property.buildYear = int.tryParse(value);
                widget.onChanged();
              },
            ),
          const SizedBox(height: 2),
          DropdownButtonFormField<String>(
            key: ValueKey(
              "document_${widget.property.documentType ?? 'none'}",
            ),
            initialValue: widget.property.documentType,
            isExpanded: true,
            dropdownColor: const Color(0xff1E293B),
            decoration: inputDecoration(
              label: "نوع السند",
              icon: Icons.description_rounded,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
            items: const [
              DropdownMenuItem(
                value: "طابو",
                child: Text("طابو"),
              ),
              DropdownMenuItem(
                value: "زراعي",
                child: Text("زراعي"),
              ),
              DropdownMenuItem(
                value: "استثماري",
                child: Text("استثماري"),
              ),
              DropdownMenuItem(
                value: "تجاري",
                child: Text("تجاري"),
              ),
            ],
            onChanged: (value) {
              widget.property.documentType = value;
              widget.onChanged();
            },
          ),
          if (showFurniture) ...[
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              key: ValueKey(
                "furniture_${widget.property.furnitureStatus ?? 'none'}",
              ),
              initialValue: widget.property.furnitureStatus,
              isExpanded: true,
              dropdownColor: const Color(0xff1E293B),
              decoration: inputDecoration(
                label: "حالة الأثاث",
                icon: Icons.chair_rounded,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
              items: const [
                DropdownMenuItem(
                  value: "مفروش",
                  child: Text("مفروش"),
                ),
                DropdownMenuItem(
                  value: "نصف مفروش",
                  child: Text("نصف مفروش"),
                ),
                DropdownMenuItem(
                  value: "غير مفروش",
                  child: Text("غير مفروش"),
                ),
              ],
              onChanged: (value) {
                widget.property.furnitureStatus = value;
                widget.onChanged();
              },
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget field({
    required String title,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.number,
    required Function(String) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 15,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: const Color(0xffD4AF37),
          ),
          labelText: title,
          labelStyle: const TextStyle(
            color: Colors.white60,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.white60,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xffD4AF37),
      ),
      filled: true,
      fillColor: const Color(0xff1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xffD4AF37),
        ),
      ),
      contentPadding: const EdgeInsets.all(18),
    );
  }
}
