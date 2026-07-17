import 'package:flutter/material.dart';
import '../../models/add_property_data.dart';
import 'widgets/glass_card.dart';

class Step2PropertyType extends StatelessWidget {

  final AddPropertyData property;
  final VoidCallback onChanged;

  const Step2PropertyType({
    super.key,
    required this.property,
    required this.onChanged,
  });


  @override
  Widget build(BuildContext context) {

    final types = [

      {
        "name": "بيت",
        "icon": Icons.home_rounded,
      },

      {
        "name": "شقة",
        "icon": Icons.apartment_rounded,
      },

      {
        "name": "أرض",
        "icon": Icons.landscape_rounded,
      },

      {
        "name": "محل",
        "icon": Icons.storefront_rounded,
      },

      {
        "name": "عمارة",
        "icon": Icons.business_rounded,
      },

      {
        "name": "مزرعة",
        "icon": Icons.agriculture_rounded,
      },

    ];


    return Padding(

      padding: const EdgeInsets.all(20),

      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          const Text(
            "نوع العقار",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),


          const SizedBox(height: 10),


          const Text(
            "اختر نوع العقار",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
            ),
          ),


          const SizedBox(height: 25),


          Expanded(

            child: GridView.builder(

              itemCount: types.length,

              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(

                crossAxisCount: 2,

                crossAxisSpacing: 15,

                mainAxisSpacing: 15,

                childAspectRatio: 1.2,

              ),


              itemBuilder: (context, index) {

                final item = types[index];

                final name =
                    item["name"] as String;


                return GlassCard(

                  selected:
                      property.propertyType ==
                          name,


                  onTap: () {

                    property.propertyType =
                        name;

                    onChanged();

                  },


                  child: Column(

                    mainAxisAlignment:
                        MainAxisAlignment.center,


                    children: [

                      Icon(

                        item["icon"]
                            as IconData,

                        size: 45,

                        color:
                            const Color(
                              0xffD4AF37,
                            ),

                      ),


                      const SizedBox(
                        height: 12,
                      ),


                      Text(

                        name,

                        style:
                            const TextStyle(

                          color:
                              Colors.white,

                          fontSize: 20,

                          fontWeight:
                              FontWeight.bold,

                        ),

                      ),

                    ],

                  ),

                );

              },

            ),

          ),

        ],

      ),

    );

  }

}