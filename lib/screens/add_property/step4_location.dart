import 'package:flutter/material.dart';
import '../../models/add_property_data.dart';

class Step4Location extends StatefulWidget {

  final AddPropertyData property;
  final VoidCallback onChanged;

  const Step4Location({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  State<Step4Location> createState() =>
      _Step4LocationState();
}


class _Step4LocationState
    extends State<Step4Location> {


  late final TextEditingController cityController;

late final TextEditingController districtController;

late final TextEditingController landmarkController;

late final TextEditingController descriptionController;

final List<String> allFeatures = [
  "حديقة",
  "مسبح",
  "مصعد",
  "كراج",
  "كاميرات مراقبة",
  "مولدة",
  "بئر ماء",
  "سياج",
  "مكيفات",
  "طاقة شمسية",
];
@override
void initState() {
  super.initState();

  cityController = TextEditingController(
    text: widget.property.city,
  );

  districtController = TextEditingController(
    text: widget.property.district,
  );

  landmarkController = TextEditingController(
    text: widget.property.landmark,
  );
  descriptionController = TextEditingController(
  text: widget.property.description,
);
}

@override
void dispose() {
  cityController.dispose();
  districtController.dispose();
  landmarkController.dispose();
  descriptionController.dispose();
  super.dispose();
}


  @override
  Widget build(BuildContext context) {


    return Padding(

      padding:
          const EdgeInsets.all(20),


      child: ListView(

        children: [


          const Text(
            "موقع العقار",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight:
                  FontWeight.bold,
            ),
          ),


          const SizedBox(height:10),


          const Text(
            "حدد موقع العقار",
            style: TextStyle(
              color:
                  Colors.white60,
            ),
          ),


          const SizedBox(height:25),



          locationField(
  title: "المدينة",
  controller: cityController,
  icon: Icons.location_city,
  onChanged: (value) {
    widget.property.city = value;
    widget.onChanged();
  },
),


          locationField(
  title: "المنطقة / الحي",
  controller: districtController,
  icon: Icons.location_on,
  onChanged: (value) {
    widget.property.district = value;
    widget.onChanged();
  },
),



          locationField(
  title: "أقرب نقطة دالة",
  controller: landmarkController,
  icon: Icons.place,
  onChanged: (value) {
    widget.property.landmark = value;
    widget.onChanged();
  },
),



          const SizedBox(height:20),
          const Text(
  "وصف العقار",
  style: TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 15),

Container(
  decoration: BoxDecoration(
    color: const Color(0xff1E293B),
    borderRadius: BorderRadius.circular(20),
  ),
  child: TextField(
    controller: descriptionController,
    maxLines: 5,
    onChanged: (value) {
      widget.property.description = value;
      widget.onChanged();
    },
    style: const TextStyle(color: Colors.white),
    decoration: const InputDecoration(
      labelText: "اكتب وصف العقار",
      labelStyle: TextStyle(color: Colors.white60),
      prefixIcon: Icon(
        Icons.description,
        color: Color(0xffD4AF37),
      ),
      border: InputBorder.none,
      contentPadding: EdgeInsets.all(18),
    ),
  ),
),

const SizedBox(height: 25),

const Text(
  "المميزات",
  style: TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 15),

Wrap(
  spacing: 10,
  runSpacing: 10,
  children: allFeatures.map((feature) {

    final selected =
        widget.property.features.contains(feature);

    return FilterChip(
      label: Text(feature),
      selected: selected,
      selectedColor: const Color(0xffD4AF37),
      backgroundColor: const Color(0xff1E293B),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
      ),
      onSelected: (value) {

        setState(() {

          if (value) {
            widget.property.features.add(feature);
          } else {
            widget.property.features.remove(feature);
          }

        });

        widget.onChanged();
      },
    );

  }).toList(),
),

        ],

      ),

    );

  }



  Widget locationField({
  required String title,
  required TextEditingController controller,
  required IconData icon,
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
            const Color(
              0xff1E293B,
            ),

        borderRadius:
            BorderRadius.circular(20),

      ),


      child: TextField(

        controller:
            controller,
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

}