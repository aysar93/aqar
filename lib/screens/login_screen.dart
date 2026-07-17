import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_shell.dart';
import 'register_screen.dart';
import '../services/fcm_service.dart';
import '../services/google_auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/facebook_auth_service.dart';
import '../services/user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscure = true;

  String error = "";


  Future<void> loginWithGoogle() async {

    setState(() {
      loading = true;
      error = "";
    });


    final result =
        await GoogleAuthService.signInWithGoogle();


    if (!mounted) return;


    if (result != null) {

  await UserService.createUserIfNotExists(result.user!);

  await FCMService.initialize();

  await FCMService.saveTokens();

  Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainShell(),
        ),
      );


    } else {

      setState(() {
        error = "فشل تسجيل الدخول بواسطة Google";
      });

    }


    setState(() {
      loading = false;
    });

  }

  Future<void> loginWithFacebook() async {

  setState(() {
    loading = true;
    error = "";
  });

  final result =
      await FacebookAuthService.signInWithFacebook();

  if (!mounted) return;

  if (result != null) {

  await UserService.createUserIfNotExists(result.user!);

  await FCMService.initialize();
    await FCMService.saveTokens();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const MainShell(),
      ),
    );

  } else {

    setState(() {
      error = "فشل تسجيل الدخول بواسطة Facebook";
    });

  }

  setState(() {
    loading = false;
  });

}



  Future<void> login() async {

    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {

      setState(() {
        error = "يرجى إدخال البريد الإلكتروني وكلمة المرور";
      });

      return;
    }


    setState(() {
      loading = true;
      error = "";
    });


    try {

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FCMService.initialize();

      await FCMService.saveTokens();


      if (!mounted) return;


      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainShell(),
        ),
      );


    } on FirebaseAuthException catch(e) {

      setState(() {
        error = e.message ?? "حدث خطأ أثناء تسجيل الدخول";
      });

    }


    setState(() {
      loading = false;
    });

  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xff0F172A),

      body: Stack(

        children: [


          Container(

            height: 350,

            decoration: const BoxDecoration(

              gradient: LinearGradient(

                colors: [

                  Color(0xff1E293B),
                  Color(0xff0F172A),

                ],

                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,

              ),

            ),

          ),



          SafeArea(

            child: SingleChildScrollView(

              child: Column(

                children: [


                  const SizedBox(height: 40),



                  Container(

                    height: 130,
                    width: 130,

                    padding:
                    const EdgeInsets.all(15),

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius:
                      BorderRadius.circular(35),

                      boxShadow: [

                        BoxShadow(

                          color:
                          Colors.black.withOpacity(.4),

                          blurRadius: 25,

                          offset:
                          const Offset(0,10),

                        )

                      ],

                    ),


                    child: Image.asset(
                      'assets/images/logo.png',
                    ),

                  ),



                  const SizedBox(height: 25),



                  const Text(

                    "عقارات الانبار",

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 32,

                      fontWeight:
                      FontWeight.bold,

                    ),

                  ),



                  const Text(

                    "المكان المناسب لجميع احتياجاتك العقارية",

                    style: TextStyle(

                      color:
                      Color(0xffD4AF37),

                      fontSize: 18,

                      fontWeight:
                      FontWeight.bold,

                    ),

                  ),



                  const SizedBox(height: 35),



                  Container(

                    margin:
                    const EdgeInsets.symmetric(
                      horizontal:20,
                    ),

                    padding:
                    const EdgeInsets.all(25),


                    decoration: BoxDecoration(

                      color:
                      const Color(0xff1E293B),

                      borderRadius:
                      BorderRadius.circular(30),

                      boxShadow: [

                        BoxShadow(

                          color:
                          Colors.black.withOpacity(.25),

                          blurRadius:25,

                        )

                      ],

                    ),



                    child: Column(

                      children: [


                        const Text(

                          "تسجيل الدخول",

                          style: TextStyle(

                            color:
                            Color(0xffD4AF37),

                            fontSize:28,

                            fontWeight:
                            FontWeight.bold,

                          ),

                        ),

                        
                        const SizedBox(height:30),



                        TextField(

                          controller:
                          emailController,

                          style:
                          const TextStyle(
                            color: Colors.white,
                          ),


                          decoration:
                          inputDecoration(

                            "البريد الإلكتروني",

                            Icons.email_outlined,

                          ),

                        ),



                        const SizedBox(height:20),



                        TextField(

                          controller:
                          passwordController,

                          obscureText:
                          obscure,

                          style:
                          const TextStyle(
                            color: Colors.white,
                          ),



                          decoration:
                          inputDecoration(

                            "كلمة المرور",

                            Icons.lock_outline,

                            suffix:
                            IconButton(

                              icon: Icon(

                                obscure

                                    ? Icons.visibility_off

                                    : Icons.visibility,

                                color:
                                Colors.white70,

                              ),

                              onPressed:(){

                                setState(() {

                                  obscure =
                                  !obscure;

                                });

                              },

                            ),

                          ),

                        ),



                        const SizedBox(height:15),



                        if(error.isNotEmpty)

                          Text(

                            error,

                            style:
                            const TextStyle(

                              color:
                              Colors.redAccent,

                            ),

                          ),



                        const SizedBox(height:20),



                        SizedBox(

                          width:double.infinity,

                          height:60,


                          child:
                          ElevatedButton(

                            onPressed:
                            loading
                                ? null
                                : login,


                            style:
                            ElevatedButton.styleFrom(

                              backgroundColor:
                              const Color(0xffD4AF37),

                              shape:
                              RoundedRectangleBorder(

                                borderRadius:
                                BorderRadius.circular(18),

                              ),

                            ),



                            child:
                            loading

                                ? const CircularProgressIndicator(
                              color: Colors.black,
                            )

                                : const Text(

                              "تسجيل الدخول",

                              style: TextStyle(

                                color:
                                Colors.black,

                                fontSize:20,

                                fontWeight:
                                FontWeight.bold,

                              ),

                            ),

                          ),

                        ),
                                                const SizedBox(height:18),


                        // إنشاء حساب
                        SizedBox(

                          width: double.infinity,

                          height:60,


                          child: OutlinedButton(

                            onPressed: () {

                              Navigator.push(

                                context,

                                MaterialPageRoute(

                                  builder: (_) =>
                                  const RegisterScreen(),

                                ),

                              );

                            },


                            style:
                            OutlinedButton.styleFrom(

                              side:
                              const BorderSide(

                                color:
                                Color(0xffD4AF37),

                                width:2,

                              ),


                              shape:
                              RoundedRectangleBorder(

                                borderRadius:
                                BorderRadius.circular(18),

                              ),

                            ),



                            child:
                            const Text(

                              "إنشاء حساب",

                              style:
                              TextStyle(

                                color:
                                Color(0xffD4AF37),

                                fontSize:20,

                                fontWeight:
                                FontWeight.bold,

                              ),

                            ),

                          ),

                        ),



                        const SizedBox(height:15),



                        // الدخول كضيف
                        SizedBox(

                          width: double.infinity,

                          height:55,


                          child: TextButton.icon(

                            onPressed: () {


                              Navigator.pushReplacement(

                                context,

                                MaterialPageRoute(

                                  builder: (_) =>
                                  const MainShell(),

                                ),

                              );


                            },


                            icon:
                            const Icon(

                              Icons.person_outline,

                              color:
                              Colors.white70,

                            ),



                            label:
                            const Text(

                              "الدخول كضيف",

                              style:
                              TextStyle(

                                color:
                                Colors.white70,

                                fontSize:17,

                              ),

                            ),

                          ),

                        ),



                        const SizedBox(height:25),



                        const Text(
  "او سجل دخولك عبر",
  style: TextStyle(
    color: Colors.white54,
    fontSize: 14,
  ),
),

const SizedBox(height: 15),

Row(
  children: [

    Expanded(
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: loginWithGoogle,
          icon: const FaIcon(
            FontAwesomeIcons.google,
            color: Colors.red,
            size: 18,
          ),
          label: const Text(
            "Google",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(
              color: Color(0xffD4AF37),
            ),
            backgroundColor: const Color(0xff1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    ),

    const SizedBox(width: 12),

    Expanded(
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: loginWithFacebook,
          icon: const FaIcon(
            FontAwesomeIcons.facebook,
            color: Color(0xFF1877F2),
            size: 18,
          ),
          label: const Text(
            "Facebook",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(
              color: Color(0xffD4AF37),
            ),
            backgroundColor: const Color(0xff1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    ),

  ],
),

const SizedBox(height: 20),

                      ],

                    ),

                  ),



                  const SizedBox(height:40),


                ],

              ),

            ),

          ),

        ],

      ),

    );

  }



  InputDecoration inputDecoration(

      String hint,

      IconData icon,

      {Widget? suffix}

      ) {


    return InputDecoration(

      hintText: hint,

      hintStyle:
      const TextStyle(

        color:
        Colors.white54,

      ),


      prefixIcon:
      Icon(

        icon,

        color:
        const Color(0xffD4AF37),

      ),


      suffixIcon:
      suffix,


      filled:true,


      fillColor:
      const Color(0xff0F172A),



      border:
      OutlineInputBorder(

        borderRadius:
        BorderRadius.circular(18),

        borderSide:
        BorderSide.none,

      ),

    );

  }

}