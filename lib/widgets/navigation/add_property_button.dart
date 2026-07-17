import 'package:flutter/material.dart';


class AddPropertyButton extends StatefulWidget {

  final VoidCallback onTap;


  const AddPropertyButton({
    super.key,
    required this.onTap,
  });


  @override
  State<AddPropertyButton> createState() =>
      _AddPropertyButtonState();

}


class _AddPropertyButtonState
    extends State<AddPropertyButton> {


  bool pressed = false;


  @override
  Widget build(BuildContext context) {

    return GestureDetector(

      onTapDown: (_) {

        setState(() {
          pressed = true;
        });

      },


      onTapUp: (_) {

        setState(() {
          pressed = false;
        });

        widget.onTap();

      },


      onTapCancel: () {

        setState(() {
          pressed = false;
        });

      },


      child: AnimatedScale(

        scale: pressed ? 0.92 : 1,

        duration:
            const Duration(milliseconds: 120),


        child: Column(

          mainAxisAlignment:
              MainAxisAlignment.center,


          children: [


            Container(

              width: 34,

              height: 34,


              decoration: BoxDecoration(

                color: const Color(0xffD4AF37),

                borderRadius:
                    BorderRadius.circular(12),

              ),


              child: const Icon(

                Icons.add_rounded,

                color: Colors.black,

                size: 24,

              ),

            ),



            const SizedBox(height: 4),



            Text(

              "اعرض",

              style: TextStyle(

                color:
                    Colors.white70,

                fontSize: 12,

                fontWeight:
                    FontWeight.bold,

              ),

            ),


          ],

        ),

      ),

    );

  }

}