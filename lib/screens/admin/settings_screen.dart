import '../../widgets/media_image.dart';
import '../../services/media_store.dart';
import 'payment_account_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'admin_chat_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController appNameController = TextEditingController(
    text: "عقارات الانبار",
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
      final uploadedUrl = await uploadAppLogo(
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

  Future<String?> uploadAppLogo(File image) =>
      uploadMediaImage(image, purpose: MediaPurpose.appLogo);

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final bgColor = isDark ? const Color(0xff0F172A) : const Color(0xFFF8FAFC);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
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
              ListTile(
                  title: const Text('حسابات الدفع (كي وزين كاش)'),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const PaymentAccountSettingsScreen()))),
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
                                  ? MediaImage(
                                      logoUrl,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(
                                          18,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo,
                                        color: Color(
                                          0xffC5A16B,
                                        ),
                                        size: 40,
                                      ),
                                    ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Text(
                          "اختيار شعار التطبيق",
                          style: TextStyle(
                            color: onSurface,
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
                      title: Text(
                        "تفعيل الإشعارات",
                        style: TextStyle(
                          color: onSurface,
                        ),
                      ),
                      value: allowNotifications,
                      activeThumbColor: const Color(
                        0xffC5A16B,
                      ),
                      onChanged: (value) {
                        setState(() {
                          allowNotifications = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text(
                        "السماح بالتعليقات",
                        style: TextStyle(
                          color: onSurface,
                        ),
                      ),
                      value: allowComments,
                      activeThumbColor: const Color(
                        0xffC5A16B,
                      ),
                      onChanged: (value) {
                        setState(() {
                          allowComments = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text(
                        "تفعيل الدردشة",
                        style: TextStyle(
                          color: onSurface,
                        ),
                      ),
                      value: allowChat,
                      activeThumbColor: const Color(0xffC5A16B),
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
                        color: Color(0xffC5A16B),
                      ),
                      title: Text(
                        "إدارة المحادثات",
                        style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "عرض والرد على محادثات المستخدمين",
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.60),
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: onSurface.withValues(alpha: 0.54),
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
                      0xffC5A16B,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: onSurface,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: onSurface.withValues(alpha: 0.60),
          ),
          prefixIcon: Icon(
            icon,
            color: const Color(
              0xffC5A16B,
            ),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xff0F172A) : const Color(0xFFF8FAFC),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff1E293B) : Colors.white,
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
                  0xffC5A16B,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Text(
                title,
                style: TextStyle(
                  color: onSurface,
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
