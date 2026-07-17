import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fcm_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
final phoneController = TextEditingController();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController =
      TextEditingController();

  bool loading = false;
  bool obscure = true;
  String error = '';

  Future<void> register() async {
if (nameController.text.isEmpty) {
  setState(() {
    error = "يرجى إدخال الاسم";
  });
  return;
}
    // التسجيل بالبريد الإلكتروني
  if (emailController.text.isEmpty ||
    passwordController.text.isEmpty ||
    phoneController.text.isEmpty) {

  setState(() {
    error =
        "يرجى إدخال البريد الإلكتروني وكلمة المرور ورقم الهاتف";
  });

  return;
}

  setState(() {
    loading = true;
    error = '';
  });

  try {

    final credential =
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
      email:
          emailController.text.trim(),
      password:
          passwordController.text.trim(),
    );

    await FirebaseFirestore.instance
    .collection('users')
    .doc(credential.user!.uid)
    .set({

  'uid': credential.user!.uid,

  'name': nameController.text.trim(),

  'email': emailController.text.trim(),

  'phone': phoneController.text.trim(),

  'photo': '',

  'provider': 'password',

  // للتوافق مع النظام الحالي
  'isAdmin': false,

  // النظام الجديد
  'accountType': 'user',

  'officeId': '',

  'isVerified': true,

  'isBlocked': false,

  'createdAt': FieldValue.serverTimestamp(),

  'lastLogin': FieldValue.serverTimestamp(),

});

await FCMService.initialize();
await FCMService.saveTokens();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content:
            Text("تم إنشاء الحساب بنجاح"),
      ),
    );

    Navigator.pop(context);

  } on FirebaseAuthException catch (e) {

    setState(() {
      error =
          e.message ??
          "حدث خطأ أثناء إنشاء الحساب";
    });

  } finally {

    setState(() {
      loading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
  elevation: 0,
  centerTitle: true,
  backgroundColor: const Color(0xff0F172A),
  foregroundColor: Colors.white,
  title: const Text(
    "إنشاء حساب",
    style: TextStyle(
      fontWeight: FontWeight.bold,
    ),
  ),
),

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          children: [

            const SizedBox(height: 30),
            TextField(
  controller: nameController,
  style: const TextStyle(
    color: Colors.white,
  ),
  decoration: InputDecoration(
    hintText: "الاسم الكامل",
    hintStyle: const TextStyle(
      color: Colors.white54,
    ),
    prefixIcon: const Icon(
      Icons.person,
      color: Color(0xffD4AF37),
    ),
    filled: true,
    fillColor: const Color(0xff1E293B),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(
        color: Color(0xffD4AF37),
        width: 2,
      ),
    ),
  ),
),

            const SizedBox(height: 20),

  TextField(
  controller: emailController,
  style: const TextStyle(
    color: Colors.white,
  ),
  decoration: InputDecoration(
    hintText: "البريد الإلكتروني",
    hintStyle: const TextStyle(
      color: Colors.white54,
    ),
    prefixIcon: const Icon(
      Icons.email,
      color: Color(0xffD4AF37),
    ),
    filled: true,
    fillColor: const Color(0xff1E293B),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(
        color: Color(0xffD4AF37),
        width: 2,
      ),
    ),
  ),
),

const SizedBox(height: 20),

Container(
  decoration: BoxDecoration(
    color: const Color(0xff1E293B),
    borderRadius: BorderRadius.circular(18),
  ),
  child: Row(
    children: [

      const SizedBox(width: 15),

      const Text(
        "🇮🇶",
        style: TextStyle(fontSize: 24),
      ),

      const SizedBox(width: 10),

      const Text(
  "+964",
  style: TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

      Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        width: 1,
        height: 30,
        color: Colors.grey,
      ),

      Expanded(
        child: TextField(
          controller: phoneController,
          style: const TextStyle(
  color: Colors.white,
),
          keyboardType: TextInputType.phone,
          maxLength: 11,
          decoration: const InputDecoration(
            hintText: "7801234567",
hintStyle: const TextStyle(
  color: Colors.white54,
),
border: InputBorder.none,
counterText: "",
          ),
        ),
      ),
    ],
  ),
),

const SizedBox(height: 20),

             TextField(
  controller: passwordController,
  obscureText: obscure,
  style: const TextStyle(
    color: Colors.white,
  ),
  decoration: InputDecoration(
    hintText: "كلمة المرور",
    hintStyle: const TextStyle(
      color: Colors.white54,
    ),
    prefixIcon: const Icon(
      Icons.lock,
      color: Color(0xffD4AF37),
    ),
    suffixIcon: IconButton(
      icon: Icon(
        obscure
            ? Icons.visibility_off
            : Icons.visibility,
        color: const Color(0xffD4AF37),
      ),
      onPressed: () {
        setState(() {
          obscure = !obscure;
        });
      },
    ),
    filled: true,
    fillColor: const Color(0xff1E293B),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(
        color: Color(0xffD4AF37),
        width: 2,
      ),
    ),
  ),
),

            const SizedBox(height: 20),

            if (error.isNotEmpty)
              Text(
                error,
                style:
                    const TextStyle(
                  color: Colors.red,
                ),
              ),

            const SizedBox(height: 25),

            SizedBox(
              width:
                  double.infinity,
              height: 60,
              child:
                  ElevatedButton(
                onPressed: loading
                    ? null
                    : register,
                style:
                    ElevatedButton
                        .styleFrom(
                  backgroundColor: const Color(0xffD4AF37),
foregroundColor: Colors.white,
elevation: 8,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                                18),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(
                        color:
                            Colors
                                .white,
                      )
                    : const Text(
                        "إنشاء الحساب",
                        style:
                            TextStyle(
                          fontSize:
                              20,
                          color:
                              Colors
                                  .white,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}