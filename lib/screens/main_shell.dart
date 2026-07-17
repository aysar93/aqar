import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_screen.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import 'add_property/add_property_screen.dart';
import 'notifications_screen.dart';

import '../chat/chat_screen.dart';
import '../widgets/navigation/custom_bottom_bar.dart';


class MainShell extends StatefulWidget {

  final int initialIndex;

  const MainShell({
    super.key,
    this.initialIndex = 0,
  });


  @override
  State<MainShell> createState() => _MainShellState();

}



class _MainShellState extends State<MainShell> {


  late int currentIndex;



  @override
  void initState() {

    super.initState();

    currentIndex = widget.initialIndex;

  }



  final List<Widget> pages = const [

    HomeScreen(),

    FavoritesScreen(),

    SizedBox(),

    NotificationsScreen(),

    ChatScreen(),

  ];



  void openAddProperty() {

    final user =
        FirebaseAuth.instance.currentUser;


    if (user == null) {

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );

      return;

    }



    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddPropertyScreen(),
      ),
    );

  }





  @override
  Widget build(BuildContext context) {


    final bool hideBottomBar =
        currentIndex == 4;



    return Scaffold(


      body: pages[currentIndex],



      bottomNavigationBar: AnimatedSlide(

        duration:
            const Duration(milliseconds: 250),

        offset: hideBottomBar
            ? const Offset(0, 1)
            : Offset.zero,


        child: AnimatedOpacity(

          duration:
              const Duration(milliseconds: 250),


          opacity: hideBottomBar
              ? 0
              : 1,


          child: CustomBottomBar(

            currentIndex: currentIndex,


            onTap: (index) {

              setState(() {

                currentIndex = index;

              });

            },


            onAddTap: openAddProperty,

          ),

        ),

      ),


    );

  }

}