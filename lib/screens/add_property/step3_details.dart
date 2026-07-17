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
  State<Step3Details> createState() =>
      _Step3DetailsState();
}


class _Step3DetailsState
    extends State<Step3Details> {


  late final TextEditingController titleController;

late final TextEditingController roomsController;

late final TextEditingController bathroomsController;

late final TextEditingController livingRoomsController;

late final TextEditingController parkingController;

late final TextEditingController areaController;

late final TextEditingController buildYearController;

@override
void initState() {
  super.initState();

  titleController =
      TextEditingController(text: widget.property.title);

  roomsController =
      TextEditingController(
    text: widget.property.rooms?.toString() ?? "",
  );

  bathroomsController =
      TextEditingController(
    text: widget.property.bathrooms?.toString() ?? "",
  );

  livingRoomsController =
      TextEditingController(
    text: widget.property.livingRooms?.toString() ?? "",
  );

  parkingController =
      TextEditingController(
    text: widget.property.parking?.toString() ?? "",
  );

  areaController =
      TextEditingController(
    text: widget.property.area?.toString() ?? "",
  );

  buildYearController =
      TextEditingController(
    text: widget.property.buildYear?.toString() ?? "",
  );
}

@override
void dispose() {
  titleController.dispose();
  roomsController.dispose();
  bathroomsController.dispose();
  livingRoomsController.dispose();
  parkingController.dispose();
  areaController.dispose();
  buildYearController.dispose();
  super.dispose();
}


  @override
  Widget build(BuildContext context) {


    final type =
        widget.property.propertyType;


    final isLand =
        type == "أرض";


    final isShop =
        type == "محل";


    return Padding(

      padding:
          const EdgeInsets.all(20),

      child: ListView(

        children: [


          const Text(
            "تفاصيل العقار",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight:
                  FontWeight.bold,
            ),
          ),


          const SizedBox(height:25),

field(
  title: "عنوان الإعلان",
  controller: titleController,
  icon: Icons.title,
  keyboardType: TextInputType.text,
  onChanged: (value) {
    widget.property.title = value;
    widget.onChanged();
  },
),

const SizedBox(height:15),

if (!isLand && !isShop) ...[


            field(
  title: "عدد الغرف",
  controller: roomsController,
  icon: Icons.meeting_room,
  onChanged: (value) {
    widget.property.rooms = int.tryParse(value);
    widget.onChanged();
  },
),


            field(
  title: "عدد الحمامات",
  controller: bathroomsController,
  icon: Icons.bathtub,
  onChanged: (value) {
    widget.property.bathrooms = int.tryParse(value);
    widget.onChanged();
  },
),


            field(
  title: "المجالس",
  controller: livingRoomsController,
  icon: Icons.weekend,
  onChanged: (value) {
    widget.property.livingRooms = int.tryParse(value);
    widget.onChanged();
  },
),


          ],



          field(
  title: "المساحة",
  controller: areaController,
  icon: Icons.square_foot,
  onChanged: (value) {
    widget.property.area = double.tryParse(value);
    widget.onChanged();
  },
),

field(
  title: "عدد مواقف السيارات",
  controller: parkingController,
  icon: Icons.directions_car,
  onChanged: (value) {
    widget.property.parking = int.tryParse(value);
    widget.onChanged();
  },
),

field(
  title: "سنة البناء",
  controller: buildYearController,
  icon: Icons.calendar_month,
  onChanged: (value) {
    widget.property.buildYear = int.tryParse(value);
    widget.onChanged();
  },
),

const SizedBox(height: 15),

DropdownButtonFormField<String>(
  initialValue: widget.property.documentType,
  dropdownColor: const Color(0xff1E293B),
  decoration: InputDecoration(
    labelText: "نوع السند",
    labelStyle: const TextStyle(color: Colors.white60),
    prefixIcon: const Icon(
      Icons.description,
      color: Color(0xffD4AF37),
    ),
    filled: true,
    fillColor: const Color(0xff1E293B),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
  ),
  style: const TextStyle(color: Colors.white),
  items: const [
    DropdownMenuItem(value: "طابو", child: Text("طابو")),
    DropdownMenuItem(value: "زراعي", child: Text("زراعي")),
    DropdownMenuItem(value: "استثماري", child: Text("استثماري")),
    DropdownMenuItem(value: "تجاري", child: Text("تجاري")),
  ],
  onChanged: (value) {
    widget.property.documentType = value;
    widget.onChanged();
  },
),

const SizedBox(height: 15),

DropdownButtonFormField<String>(
  initialValue: widget.property.furnitureStatus,
  dropdownColor: const Color(0xff1E293B),
  decoration: InputDecoration(
    labelText: "حالة الأثاث",
    labelStyle: const TextStyle(color: Colors.white60),
    prefixIcon: const Icon(
      Icons.chair,
      color: Color(0xffD4AF37),
    ),
    filled: true,
    fillColor: const Color(0xff1E293B),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
  ),
  style: const TextStyle(color: Colors.white),
  items: const [
    DropdownMenuItem(value: "مفروش", child: Text("مفروش")),
    DropdownMenuItem(value: "نصف مفروش", child: Text("نصف مفروش")),
    DropdownMenuItem(value: "غير مفروش", child: Text("غير مفروش")),
  ],
  onChanged: (value) {
    widget.property.furnitureStatus = value;
    widget.onChanged();
  },
),
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

      margin:
          const EdgeInsets.only(
            bottom:15,
          ),

      decoration:
          BoxDecoration(

        color:
            const Color(0xff1E293B),

        borderRadius:
            BorderRadius.circular(20),

      ),


      child: TextField(

        controller:
            controller,

        keyboardType: keyboardType,
        onChanged: onChanged,

        style:
            const TextStyle(
              color:
                  Colors.white,
            ),


        decoration:
            InputDecoration(

          prefixIcon:
              Icon(
                icon,
                color:
                    const Color(
                      0xffD4AF37,
                    ),
              ),

          labelText:
              title,


          labelStyle:
              const TextStyle(
                color:
                    Colors.white60,
              ),


          border:
              InputBorder.none,

          contentPadding:
              const EdgeInsets.all(18),

        ),

      ),

    );

  }



  Widget infoBox(String text){

    return Container(

      padding:
          const EdgeInsets.all(20),

      decoration:
          BoxDecoration(

        color:
            const Color(0xff1E293B),

        borderRadius:
            BorderRadius.circular(20),

      ),

      child: Text(

        text,

        style:
            const TextStyle(

          color:
              Colors.white70,

          fontSize:16,

        ),

      ),

    );

  }

}