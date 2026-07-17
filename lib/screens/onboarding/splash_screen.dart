import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart';
import '../main_shell.dart';
import 'onboarding_screen.dart';
import 'package:audioplayers/audioplayers.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}


class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {


  late AnimationController _controller;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();


  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );


    
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _pulseAnimation = Tween<double>(
  begin: 1.0,
  end: 1.08,
).animate(
  CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ),
);


    _controller.repeat(reverse: true);

    playWelcomeSound();


    Timer(
  const Duration(seconds: 4),
  checkIntro,
);

  }



  Future<void> checkIntro() async {

    final prefs = await SharedPreferences.getInstance();

    final seen =
        prefs.getBool("onboarding_seen") ?? false;


    if (!mounted) return;


    if (seen) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthGate(),
        ),
      );


    } else {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        ),
      );

    }

  }


  Future<void> playWelcomeSound() async {

  try {

    await _audioPlayer.play(
      AssetSource(
        'audio/logo_intro.mp3'
      ),
    );

  } catch (e) {

    debugPrint(
      "Welcome sound not found: $e",
    );

  }

}



  @override
  void dispose() {

    _controller.dispose();

    _audioPlayer.dispose();

    super.dispose();

  }



  @override
  Widget build(BuildContext context) {


    return Scaffold(

      backgroundColor:
      const Color(0xff0F172A),


      body: Center(

        child: FadeTransition(

          opacity: _fadeAnimation,


          child: ScaleTransition(

            scale: _pulseAnimation,


            child: Column(

              mainAxisAlignment:
              MainAxisAlignment.center,


              children: [


                Container(

                  height:150,

                  width:150,


                  padding:
                  const EdgeInsets.all(15),


                  decoration:
                  BoxDecoration(

                    color: Colors.white,

                    borderRadius:
                    BorderRadius.circular(35),

                    boxShadow: [

                      BoxShadow(

                        color:
                        Colors.black.withOpacity(.4),

                        blurRadius:25,

                        offset:
                        const Offset(0,10),

                      )

                    ],

                  ),


                  child: Image.asset(
                    "assets/images/logo.png",
                  ),

                ),


                const SizedBox(height:25),


                const Text(

                  "عقارات الأنبار",

                  style: TextStyle(

                    color: Colors.white,

                    fontSize:32,

                    fontWeight:
                    FontWeight.bold,

                  ),

                ),


                const SizedBox(height:10),


                const Text(

                  "المكان المناسب لجميع احتياجاتكم العقارية",

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    color:
                    Color(0xffD4AF37),

                    fontSize:16,

                    fontWeight:
                    FontWeight.bold,

                  ),

                ),


              ],

            ),

          ),

        ),

      ),

    );

  }

}


// بوابة الدخول الحالية
class AuthGate extends StatelessWidget {

  const AuthGate({super.key});


  @override
  Widget build(BuildContext context) {

    return StreamBuilder<User?>(

      stream:
      FirebaseAuth.instance.authStateChanges(),


      builder:
      (context, snapshot) {


        if(snapshot.connectionState ==
            ConnectionState.waiting){

          return const Scaffold(

            body:
            Center(

              child:
              CircularProgressIndicator(),

            ),

          );

        }


        if(snapshot.hasData){

          return const MainShell();

        }


        return const LoginScreen();


      },

    );

  }

}