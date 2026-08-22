import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_shell.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;

  const OtpScreen({
    super.key,
    required this.verificationId,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final codeController = TextEditingController();

  bool loading = false;
  String error = '';

  Future<void> verify() async {
    if (codeController.text.length < 6) {
      return;
    }

    setState(() {
      loading = true;
      error = '';
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: codeController.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const MainShell(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        error = e.message ?? "رمز غير صحيح";
      });
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("رمز التحقق"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const SizedBox(
              height: 50,
            ),
            const Icon(
              Icons.sms,
              size: 90,
              color: Color(0xff0D47A1),
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              "أدخل رمز التحقق",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "******",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            if (error.isNotEmpty)
              Text(
                error,
                style: const TextStyle(
                  color: Colors.red,
                ),
              ),
            const SizedBox(
              height: 20,
            ),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : verify,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        "تأكيد",
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
