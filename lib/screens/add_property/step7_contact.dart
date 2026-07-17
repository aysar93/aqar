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
  State<Step7Contact> createState() =>
      _Step7ContactState();

}



class _Step7ContactState
    extends State<Step7Contact> {


  final phoneController =
      TextEditingController();


  final whatsappController =
      TextEditingController();



  @override
  void initState() {

    super.initState();


    phoneController.text =
        widget.property.phone;


    whatsappController.text =
        widget.property.whatsapp;

  }
@override
void dispose() {
  phoneController.dispose();
  whatsappController.dispose();
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

            "معلومات التواصل",

            style:
                TextStyle(

              color:
                  Colors.white,

              fontSize:
                  26,

              fontWeight:
                  FontWeight.bold,

            ),

          ),



          const SizedBox(height:10),



          const Text(

            "أدخل معلومات التواصل مع صاحب العقار",

            style:
                TextStyle(

              color:
                  Colors.white60,

            ),

          ),



          const SizedBox(height:30),




          contactField(

            "رقم الهاتف",

            phoneController,

            Icons.phone,

            (value){

              widget.property.phone =
                  value;

              widget.onChanged();

            },

          ),




          contactField(

            "رقم الواتساب",

            whatsappController,

            Icons.chat,

            (value){

              widget.property.whatsapp =
                  value;

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

  ){


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


      child:
          TextField(

        controller:
            controller,


        keyboardType:
            TextInputType.phone,


        onChanged:
            onChange,


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