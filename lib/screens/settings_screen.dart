import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}


class _SettingsScreenState
    extends State<SettingsScreen> {
@override
void initState() {
  super.initState();
  loadSettings();
}

Future<void> pickImage() async {

  final picker = ImagePicker();

  final image = await picker.pickImage(
    source: ImageSource.gallery,
  );


  if (image == null) return;


  setState(() {

    selectedImage =
        File(image.path);

  });


  final user =
      FirebaseAuth.instance.currentUser;


  if (user == null) return;


  final ref =
      FirebaseStorage.instance
          .ref()
          .child(
            "users/${user.uid}/profile.jpg",
          );


  await ref.putFile(
    selectedImage!,
  );


  final imageUrl =
      await ref.getDownloadURL();


  await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .set({

    "photoUrl":
        imageUrl,

  },
  SetOptions(
    merge: true,
  ));


  if (mounted) {

    ScaffoldMessenger.of(context)
        .showSnackBar(

      const SnackBar(
        content:
            Text(
          "تم تحديث الصورة الشخصية",
        ),
      ),

    );

  }

}

Future<void> loadSettings() async {

  final user =
      FirebaseAuth.instance.currentUser;

  if (user == null) return;


  final doc = await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .get();


  if (doc.exists) {

  setState(() {

    notificationsEnabled =
        doc.data()?["notificationsEnabled"] ?? true;

    photoUrl =
        doc.data()?["photoUrl"] ?? "";

    loading = false;

  });

} else {

  setState(() {
    loading = false;
  });

}

}

  bool notificationsEnabled = true;
  bool loading = true;
  File? selectedImage;
  String photoUrl = "";


  Future<void> changePassword() async {

    final user =
        FirebaseAuth.instance.currentUser;


    if (user == null ||
        user.email == null) {
      return;
    }


    await FirebaseAuth.instance
        .sendPasswordResetEmail(
          email: user.email!,
        );


    if (mounted) {

      ScaffoldMessenger.of(context)
          .showSnackBar(

        const SnackBar(
          content:
              Text(
                "تم إرسال رابط تغيير كلمة المرور إلى البريد",
              ),
        ),

      );

    }

  }



  Future<void> deleteAccount() async {

    final user =
        FirebaseAuth.instance.currentUser;


    if (user == null) return;


    await user.delete();


    if (mounted) {

      Navigator.pop(context);

    }

  }



  @override
  Widget build(BuildContext context) {

    return Directionality(

      textDirection:
          TextDirection.rtl,

      child: Scaffold(

        backgroundColor:
            const Color(0xff0F172A),


        appBar: AppBar(

          backgroundColor:
              const Color(0xff0F172A),

          elevation: 0,

          centerTitle: true,

          title:
              const Text(
            "الإعدادات",
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

        ),


        body: Padding(

  padding:
      const EdgeInsets.all(16),


  child: Column(

    children: [

      const CircleAvatar(
        radius: 45,
        backgroundColor: Color(0xffD4AF37),
        child: Icon(
          Icons.person,
          size: 50,
          color: Colors.black,
        ),
      ),


      const SizedBox(height: 12),


      Text(
        FirebaseAuth.instance.currentUser?.email ??
            "مستخدم",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),


      const SizedBox(height: 25),

Center(
  child: CircleAvatar(
    radius: 45,
    backgroundImage: selectedImage != null
        ? FileImage(selectedImage!) as ImageProvider
        : photoUrl.isNotEmpty
            ? NetworkImage(photoUrl)
            : null,
    child: selectedImage == null && photoUrl.isEmpty
        ? const Icon(
            Icons.person,
            size: 50,
          )
        : null,
  ),
),

const SizedBox(
  height: 20,
),
              Card(

                color:
                    const Color(0xff1E293B),

                child:
                    SwitchListTile(

                  title:
                      const Text(
                    "الإشعارات",
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                    ),
                  ),


                  subtitle:
                      const Text(
                    "تشغيل أو إيقاف إشعارات التطبيق",
                    style:
                        TextStyle(
                      color:
                          Colors.white60,
                    ),
                  ),


                  value:
                      notificationsEnabled,


                  activeThumbColor:
                      const Color(
                        0xffD4AF37,
                      ),


                  onChanged:
    (value) async {

  setState(() {

    notificationsEnabled =
        value;

  });


  final user =
      FirebaseAuth.instance.currentUser;


  if (user != null) {

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .set({

      "notificationsEnabled":
          value,

    },
    SetOptions(
      merge: true,
    ));

  }

},

                ),

              ),



              const SizedBox(
                height: 12,
              ),



              settingsButton(

                icon:
                    Icons.lock,

                title:
                    "تغيير كلمة المرور",

                onTap:
                    changePassword,

              ),



              settingsButton(

  icon:
      Icons.person,

  title:
      "تغيير الصورة الشخصية",

  onTap: pickImage,

),



              settingsButton(

                icon:
                    Icons.delete_forever,

                title:
                    "حذف الحساب",

                color:
                    Colors.red,

                onTap:
                    deleteAccount,

              ),


            ],

          ),

        ),

      ),

    );

  }



  Widget settingsButton({

    required IconData icon,

    required String title,

    required VoidCallback onTap,

    Color color =
        const Color(0xffD4AF37),

  }) {


    return Card(

      color:
          const Color(0xff1E293B),

      margin:
          const EdgeInsets.only(
            bottom: 12,
          ),


      child:
          ListTile(

        leading:
            Icon(
          icon,
          color:
              color,
        ),


        title:
            Text(
          title,
          style:
              const TextStyle(
            color:
                Colors.white,
          ),
        ),


        trailing:
            const Icon(
          Icons.arrow_forward_ios,
          color:
              Colors.white54,
          size:
              16,
        ),


        onTap:
            onTap,

      ),

    );

  }

}