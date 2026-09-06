import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/fcm_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  //---------------------------------------
  // Controllers
  //---------------------------------------
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  String contactEmail = "";

  //---------------------------------------
  // State
  //---------------------------------------

  bool loading = true;
  bool saving = false;
  bool uploadingImage = false;
  double uploadProgress = 0;

  bool notificationsEnabled = true;

  File? selectedImage;

  String photoUrl = "";

  final picker = ImagePicker();

  User? get currentUser => FirebaseAuth.instance.currentUser;

  bool get canEditPhone {
    return phoneController.text.trim().isEmpty;
  }

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }
  //-----------------------------------------------------
  // Load User Data
  //-----------------------------------------------------

  Future<void> loadUserData() async {
    final user = currentUser;

    if (user == null) {
      setState(() => loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        nameController.text = data["name"] ?? "";

        phoneController.text = data["phone"] ?? "";
        contactEmail = data["email"] ?? "";

        photoUrl = data["photoUrl"] ?? "";

        notificationsEnabled = data["notificationsEnabled"] ?? true;
      }
    } catch (e) {
      debugPrint("Load User Error: $e");
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }
  //-----------------------------------------------------
  // Pick Profile Image
  //-----------------------------------------------------

  Future<void> pickImage(ImageSource source) async {
    try {
      final image = await picker.pickImage(source: source, imageQuality: 85);

      if (image == null) return;

      final compressedImage = await compressImage(File(image.path));

      setState(() {
        selectedImage = compressedImage;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ أثناء اختيار الصورة\n$e")),
      );
    }
  }
  //-----------------------------------------------------
  // Compress Image
  //-----------------------------------------------------

  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();

    final targetPath =
        "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 1080,
      minHeight: 1080,
    );

    if (compressed == null) {
      return file;
    }

    return File(compressed.path);
  }
  //-----------------------------------------------------
  // Select Image Source
  //-----------------------------------------------------

  Future<void> showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "تغيير الصورة الشخصية",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xffD4AF37),
                  ),
                  title: const Text(
                    "التقاط صورة",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xffD4AF37),
                  ),
                  title: const Text(
                    "اختيار من المعرض",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleNotifications(bool value) async {
    if (saving) return;

    final previousValue = notificationsEnabled;

    setState(() {
      notificationsEnabled = value;
    });

    bool success = false;

    if (value) {
      success = await FCMService.enableNotifications();
    } else {
      success = await FCMService.disableNotifications();
    }

    if (!mounted) return;

    if (!success) {
      setState(() {
        notificationsEnabled = previousValue;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? "لم يتم تفعيل الإشعارات. تحقق من صلاحية الإشعارات في إعدادات الهاتف."
                : "تعذر إيقاف الإشعارات. حاول مرة أخرى",
          ),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? "تم تشغيل الإشعارات" : "تم إيقاف الإشعارات"),
      ),
    );
  }
  //-----------------------------------------------------
  // Save Changes
  //-----------------------------------------------------

  Future<void> saveChanges() async {
    final user = currentUser;

    if (user == null) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      String imageUrl = photoUrl;

      //-------------------------------------------------
      // Upload new image if selected
      //-------------------------------------------------

      if (selectedImage != null) {
        setState(() {
          uploadingImage = true;
        });

        final uploadedUrl = await uploadToCloudinary(selectedImage!);

        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        }

        if (mounted) {
          setState(() {
            uploadingImage = false;
          });
        }
      }

      //-------------------------------------------------
      // Save user data
      //-------------------------------------------------

      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "photoUrl": imageUrl,
        "notificationsEnabled": notificationsEnabled,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      photoUrl = imageUrl;

      if (!mounted) return;

      await context.read<UserProvider>().refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("تم حفظ التغييرات بنجاح ✅")));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("حدث خطأ أثناء الحفظ\n$e")));
      }
    }

    if (mounted) {
      setState(() {
        saving = false;
      });
    }
  }

  //-----------------------------------------------------
  // Change Password
  //-----------------------------------------------------

  Future<void> changePassword() async {
    final user = currentUser;
    if (user == null) return;

    final supportsPassword = user.providerData.any(
      (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
    );

    if (!supportsPassword || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "هذا الحساب لا يستخدم كلمة مرور محلية. استخدم طريقة تسجيل الدخول الأصلية.",
          ),
        ),
      );
      return;
    }

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangePasswordDialog(user: user),
    );

    if (!mounted) return;

    if (changed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم تغيير كلمة المرور بنجاح ✅"),
        ),
      );
    }
  }

  Future<String?> askPassword() async {
    final controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("تأكيد حذف الحساب"),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "كلمة المرور",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text("متابعة"),
            ),
          ],
        );
      },
    );
  }
  //-----------------------------------------------------
  // Delete Account
  //-----------------------------------------------------

  Future<void> deleteAccount() async {
    final user = currentUser;

    if (user == null) return;

    final password = await askPassword();

    if (password == null || password.isEmpty) {
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .delete();

      await user.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("تم حذف الحساب بنجاح")));

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = "حدث خطأ.";

      switch (e.code) {
        case "wrong-password":
        case "invalid-credential":
          message = "كلمة المرور غير صحيحة.";
          break;

        case "requires-recent-login":
          message = "يرجى تسجيل الدخول مرة أخرى ثم إعادة المحاولة.";
          break;

        default:
          message = e.message ?? "حدث خطأ.";
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("حدث خطأ:\n$e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xff0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xffD4AF37)),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0F172A),

        appBar: AppBar(
          backgroundColor: const Color(0xff0F172A),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "الملف الشخصي",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  //--------------------------------
                  // Profile Image
                  //--------------------------------
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xff0F172A),
                          border: Border.all(
                            color: const Color(0xffD4AF37),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xffD4AF37,
                              ).withValues(alpha: .22),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: const Color(0xff1E293B),
                          backgroundImage: selectedImage != null
                              ? FileImage(selectedImage!)
                                  as ImageProvider<Object>
                              : photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                          child: selectedImage == null && photoUrl.isEmpty
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 55,
                                  color: Color(0xffD4AF37),
                                )
                              : null,
                        ),
                      ),
                      if (uploadingImage)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(60),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    value: uploadProgress,
                                    color: const Color(0xffD4AF37),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "${(uploadProgress * 100).toStringAsFixed(0)}%",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: showImageSourceDialog,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xffD4AF37),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xff0F172A),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .30),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  //--------------------------------
                  // Name
                  //--------------------------------
                  TextFormField(
                    controller: nameController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "الرجاء إدخال الاسم";
                      }

                      if (value.trim().length < 3) {
                        return "الاسم قصير جداً";
                      }

                      return null;
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "الاسم",
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      fillColor: const Color(0xff1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  //--------------------------------
                  // Phone
                  //--------------------------------
                  TextFormField(
                    controller: phoneController,
                    readOnly: !canEditPhone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "أدخل رقم الهاتف";
                      }

                      if (value.length < 11) {
                        return "رقم الهاتف غير صحيح";
                      }

                      return null;
                    },
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "رقم الهاتف",
                      helperText: canEditPhone
                          ? "أدخل رقم الهاتف لإكمال بيانات الحساب"
                          : "لتغيير رقم تسجيل الدخول تواصل مع الإدارة",
                      prefixIcon: const Icon(Icons.phone),
                      filled: true,
                      fillColor: const Color(0xff1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  //--------------------------------
                  // Email
                  //--------------------------------
                  TextFormField(
                    initialValue: contactEmail,
                    enabled: false,
                    style: const TextStyle(color: Colors.white70),
                    decoration: InputDecoration(
                      labelText: "البريد الإلكتروني",
                      prefixIcon: const Icon(Icons.email),
                      filled: true,
                      fillColor: const Color(0xff26354D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  //--------------------------------
                  // Notifications
                  //--------------------------------
                  Card(
                    color: const Color(0xff1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      value: notificationsEnabled,
                      activeThumbColor: const Color(0xffD4AF37),
                      title: const Text(
                        "الإشعارات",
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        "تشغيل أو إيقاف إشعارات التطبيق",
                        style: TextStyle(color: Colors.white60),
                      ),
                      onChanged: _toggleNotifications,
                    ),
                  ),

                  const SizedBox(height: 20),

                  //--------------------------------
                  // Change Password
                  //--------------------------------
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_outline),
                      label: const Text("تغيير كلمة المرور"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xffD4AF37),
                        side: const BorderSide(color: Color(0xffD4AF37)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: changePassword,
                    ),
                  ),

                  const SizedBox(height: 15),

                  //--------------------------------
                  // Save Button
                  //--------------------------------
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      icon: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(saving ? "جاري الحفظ..." : "حفظ التغييرات"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffD4AF37),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: saving ? null : saveChanges,
                    ),
                  ),

                  const SizedBox(height: 30),

                  //--------------------------------
                  // Delete Account
                  //--------------------------------
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        "حذف الحساب",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () async {
                        final result = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: const Color(0xff1E293B),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                          ),
                          builder: (context) {
                            return SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  28,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircleAvatar(
                                      radius: 34,
                                      backgroundColor: Color(0xff3A1D1D),
                                      child: Icon(
                                        Icons.delete_forever_rounded,
                                        color: Colors.redAccent,
                                        size: 38,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      "حذف الحساب",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "سيتم حذف حسابك نهائياً مع جميع البيانات المرتبطة به",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        height: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: .08),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              Colors.red.withValues(alpha: .25),
                                        ),
                                      ),
                                      child: const Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.redAccent,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              "لا يمكن استعادة الحساب أو البيانات بعد تنفيذ عملية الحذف",
                                              style: TextStyle(
                                                color: Colors.white70,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 55,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xffB71C1C,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.delete_forever_rounded,
                                        ),
                                        label: const Text(
                                          "حذف الحساب نهائياً",
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context, true);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context, false);
                                      },
                                      child: const Text(
                                        "إلغاء",
                                        style: TextStyle(
                                          color: Color(0xffD4AF37),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        if (result == true) {
                          await deleteAccount();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 25),
                ],
              ), // Column
            ), // Form
          ), // SingleChildScrollView
        ), // SafeArea
      ), // Scaffold
    ); // Directionality
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final User user;

  const _ChangePasswordDialog({
    required this.user,
  });

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback toggle,
    double labelFontSize = 12,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: labelFontSize,
        color: Colors.white60,
      ),
      floatingLabelStyle: TextStyle(
        fontSize: labelFontSize,
        color: const Color(0xffD4AF37),
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xffD4AF37),
        size: 21,
      ),
      suffixIcon: IconButton(
        onPressed: toggle,
        icon: Icon(
          obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          size: 21,
          color: Colors.white60,
        ),
      ),
      filled: true,
      fillColor: const Color(0xff0F172A),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: .10),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xffD4AF37),
          width: 1.5,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final credential = EmailAuthProvider.credential(
        email: widget.user.email!,
        password: _oldPasswordController.text,
      );

      await widget.user.reauthenticateWithCredential(credential);
      await widget.user.updatePassword(_newPasswordController.text);

      if (!mounted) return;

      // نغلق النافذة فقط، ورسالة النجاح تظهر من الصفحة الأم
      // بعد انتهاء إغلاق الـ Dialog بالكامل.
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case "wrong-password":
        case "invalid-credential":
          message = "كلمة المرور القديمة غير صحيحة.";
          break;
        case "weak-password":
          message = "كلمة المرور الجديدة ضعيفة.";
          break;
        case "requires-recent-login":
          message = "يرجى تسجيل الدخول مجددًا ثم إعادة المحاولة.";
          break;
        case "too-many-requests":
          message = "محاولات كثيرة. حاول بعد قليل.";
          break;
        default:
          message = e.message ?? "تعذر تغيير كلمة المرور.";
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      setState(() {
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("تعذر تغيير كلمة المرور\n$e"),
        ),
      );

      setState(() {
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xff1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: const Color(0xffD4AF37).withValues(alpha: .35),
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
        contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: const Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xff0F172A),
              child: Icon(
                Icons.lock_reset_rounded,
                color: Color(0xffD4AF37),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "تغيير كلمة المرور",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "أدخل كلمة المرور الحالية ثم كلمة المرور الجديدة.",
                    style: TextStyle(
                      color: Colors.white60,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _oldPasswordController,
                  obscureText: _obscureOld,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  decoration: _fieldDecoration(
                    label: "كلمة المرور القديمة",
                    labelFontSize: 12,
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscureOld,
                    toggle: () {
                      setState(() {
                        _obscureOld = !_obscureOld;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "يرجى إدخال كلمة المرور القديمة";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  decoration: _fieldDecoration(
                    label: "كلمة المرور الجديدة",
                    labelFontSize: 12,
                    icon: Icons.password_rounded,
                    obscure: _obscureNew,
                    toggle: () {
                      setState(() {
                        _obscureNew = !_obscureNew;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "يرجى إدخال كلمة المرور الجديدة";
                    }

                    if (value.length < 6) {
                      return "يجب أن تكون 6 أحرف على الأقل";
                    }

                    if (value == _oldPasswordController.text) {
                      return "اختر كلمة مرور مختلفة عن القديمة";
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  decoration: _fieldDecoration(
                    label: "تأكيد كلمة المرور الجديدة",
                    labelFontSize: 12,
                    icon: Icons.verified_user_outlined,
                    obscure: _obscureConfirm,
                    toggle: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "يرجى تأكيد كلمة المرور الجديدة";
                    }

                    if (value != _newPasswordController.text) {
                      return "كلمتا المرور غير متطابقتين";
                    }

                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                _submitting ? null : () => Navigator.of(context).pop(false),
            child: const Text(
              "إلغاء",
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(
              _submitting ? "جاري الحفظ..." : "حفظ كلمة المرور",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
