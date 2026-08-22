import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'admin_chat_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController appNameController = TextEditingController(
    text: "عقارات الأنبار",
  );

  final TextEditingController officeNameController = TextEditingController(
    text: "مكتب الأندلس للعقارات",
  );

  final TextEditingController phoneController = TextEditingController(
    text: "07xxxxxxxxx",
  );

  final TextEditingController whatsappController = TextEditingController(
    text: "07xxxxxxxxx",
  );

  final TextEditingController emailController = TextEditingController(
    text: "example@email.com",
  );

  bool allowNotifications = true;

  bool allowComments = true;
  bool allowChat = true;

  File? selectedLogo;
  String logoUrl = "";

  Future<void> loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection("settings")
        .doc("app_settings")
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    appNameController.text = data["appName"] ?? "";

    officeNameController.text = data["officeName"] ?? "";
    phoneController.text = data["phone"] ?? "";
    whatsappController.text = data["whatsapp"] ?? "";
    emailController.text = data["email"] ?? "";
    logoUrl = data["logoUrl"] ?? "";

    setState(() {
      allowNotifications = data["allowNotifications"] ?? true;

      allowComments = data["allowComments"] ?? true;

      allowChat = data["allowChat"] ?? true;
    });
  }

  Future<void> saveSettings() async {
    if (selectedLogo != null) {
      final uploadedUrl = await uploadLogoToCloudinary(
        selectedLogo!,
      );

      if (uploadedUrl != null) {
        logoUrl = uploadedUrl;
      }
    }

    await FirebaseFirestore.instance
        .collection("settings")
        .doc("app_settings")
        .set({
      "appName": appNameController.text.trim(),
      "officeName": officeNameController.text.trim(),
      "phone": phoneController.text.trim(),
      "whatsapp": whatsappController.text.trim(),
      "email": emailController.text.trim(),
      "logoUrl": logoUrl,
      "allowNotifications": allowNotifications,
      "allowComments": allowComments,
      "allowChat": allowChat,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "تم حفظ الإعدادات",
          ),
        ),
      );
    }
  }

  Future<void> pickLogo() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      selectedLogo = File(image.path);
    });
  }

  Future<String?> uploadLogoToCloudinary(File image) async {
    const cloudName = "hwxcrlcj";
    const uploadPreset = "pmlhhqdd";

    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    final request = http.MultipartRequest(
      "POST",
      url,
    );

    request.fields["upload_preset"] = uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        image.path,
      ),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();

      final data = json.decode(responseData);

      return data["secure_url"];
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xff0F172A),
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "إعدادات التطبيق",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _settingsCard(
                title: "بيانات المكتب",
                icon: Icons.business,
                child: Column(
                  children: [
                    _textField(
                      controller: appNameController,
                      label: "اسم التطبيق",
                      icon: Icons.apps,
                    ),
                    _textField(
                      controller: officeNameController,
                      label: "اسم المكتب",
                      icon: Icons.home_work,
                    ),
                    _textField(
                      controller: phoneController,
                      label: "رقم الهاتف",
                      icon: Icons.phone,
                    ),
                    _textField(
                      controller: whatsappController,
                      label: "رقم الواتساب",
                      icon: Icons.chat,
                    ),
                    _textField(
                      controller: emailController,
                      label: "البريد الإلكتروني",
                      icon: Icons.email,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              _settingsCard(
                title: "شعار التطبيق",
                icon: Icons.image,
                child: Center(
                  child: GestureDetector(
                    onTap: pickLogo,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: selectedLogo != null
                              ? Image.file(
                                  selectedLogo!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                )
                              : logoUrl.isNotEmpty
                                  ? Image.network(
                                      logoUrl,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xff0F172A,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          18,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo,
                                        color: Color(
                                          0xffD4AF37,
                                        ),
                                        size: 40,
                                      ),
                                    ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        const Text(
                          "اختيار شعار التطبيق",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _settingsCard(
                title: "إعدادات التطبيق",
                icon: Icons.settings,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        "تفعيل الإشعارات",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      value: allowNotifications,
                      activeThumbColor: const Color(
                        0xffD4AF37,
                      ),
                      onChanged: (value) {
                        setState(() {
                          allowNotifications = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        "السماح بالتعليقات",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      value: allowComments,
                      activeThumbColor: const Color(
                        0xffD4AF37,
                      ),
                      onChanged: (value) {
                        setState(() {
                          allowComments = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        "تفعيل الدردشة",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      value: allowChat,
                      activeThumbColor: const Color(0xffD4AF37),
                      onChanged: (value) {
                        setState(() {
                          allowChat = value;
                        });
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.chat,
                        color: Color(0xffD4AF37),
                      ),
                      title: const Text(
                        "إدارة المحادثات",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        "عرض والرد على محادثات المستخدمين",
                        style: TextStyle(
                          color: Colors.white60,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminChatListScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xffD4AF37,
                    ),
                    padding: const EdgeInsets.all(
                      15,
                    ),
                  ),
                  onPressed: () {
                    saveSettings();
                  },
                  child: const Text(
                    "حفظ الإعدادات",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.white60,
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(
              0xffD4AF37,
            ),
          ),
          filled: true,
          fillColor: const Color(
            0xff0F172A,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(
          0xff1E293B,
        ),
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(
                  0xffD4AF37,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 15,
          ),
          Material(
            color: Colors.transparent,
            child: child,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    appNameController.dispose();

    officeNameController.dispose();

    phoneController.dispose();

    whatsappController.dispose();

    emailController.dispose();

    super.dispose();
  }
}
