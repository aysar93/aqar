import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {

  final TextEditingController controller;
  final String hintText;
  final Function(String) onChanged;


  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });



  @override
  Widget build(BuildContext context) {

    return Directionality(
      textDirection: TextDirection.rtl,

      child: TextField(

        controller: controller,

        onChanged: onChanged,

        style: const TextStyle(
          color: Colors.white,
        ),


        decoration: InputDecoration(

          hintText: hintText,

          hintStyle: const TextStyle(
            color: Colors.white60,
          ),


          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xffD4AF37),
          ),


          filled: true,

          fillColor: const Color(0xff1E293B),


          border: OutlineInputBorder(

            borderRadius:
                BorderRadius.circular(15),

            borderSide:
                BorderSide.none,

          ),

        ),

      ),

    );

  }

}