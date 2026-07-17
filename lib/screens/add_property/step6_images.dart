import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/add_property_data.dart';


class Step6Images extends StatefulWidget {

  final AddPropertyData property;
  final VoidCallback onChanged;

  const Step6Images({
    super.key,
    required this.property,
    required this.onChanged,
  });


  @override
  State<Step6Images> createState() =>
      _Step6ImagesState();
}



class _Step6ImagesState
    extends State<Step6Images> {


  final ImagePicker picker =
      ImagePicker();





  Future<void> pickImages() async {


    final images =
        await picker.pickMultiImage();



    if(images.isEmpty) return;



    if(images.length > 10){

      images.removeRange(
        10,
        images.length,
      );

    }



    setState(() {

      widget.property.selectedImages =
    images.map(
      (e) => File(e.path),
    ).toList();

    });



    widget.onChanged();

  }



  @override
  Widget build(BuildContext context) {


    return Padding(

      padding:
          const EdgeInsets.all(20),


      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment.start,


        children: [


          const Text(
            "صور العقار",
            style: TextStyle(
              color: Colors.white,
              fontSize:26,
              fontWeight:
                  FontWeight.bold,
            ),
          ),



          const SizedBox(height:10),



          const Text(
            "يمكنك إضافة حتى 10 صور",
            style: TextStyle(
              color:
                  Colors.white60,
            ),
          ),



          const SizedBox(height:30),




          SizedBox(

            width:
                double.infinity,


            height:55,


            child: ElevatedButton.icon(

              onPressed:
                  pickImages,


              icon:
                  const Icon(
                Icons.photo_library,
              ),


              label:
                  const Text(
                "اختيار الصور",
              ),


              style:
                  ElevatedButton.styleFrom(

                backgroundColor:
                    const Color(
                      0xffD4AF37,
                    ),

                foregroundColor:
                    Colors.white,


                shape:
                    RoundedRectangleBorder(

                  borderRadius:
                      BorderRadius.circular(
                        18,
                      ),

                ),

              ),

            ),

          ),



          const SizedBox(height:25),




          Expanded(

            child:

            widget.property.selectedImages.isEmpty

            ?

            const Center(

              child: Text(

                "لم يتم اختيار صور بعد",

                style:
                    TextStyle(
                  color:
                      Colors.white54,
                ),

              ),

            )


            :

            GridView.builder(

              itemCount:
    widget.property.selectedImages.length,


gridDelegate:
    const SliverGridDelegateWithFixedCrossAxisCount(

                crossAxisCount:3,

                crossAxisSpacing:10,

                mainAxisSpacing:10,

              ),


              itemBuilder:
                  (context,index){


                return ClipRRect(

                  borderRadius:
                      BorderRadius.circular(
                        15,
                      ),


                  child:
    Image.file(

  widget.property.selectedImages[index],

  fit:
      BoxFit.cover,

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