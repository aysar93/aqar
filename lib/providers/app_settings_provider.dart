import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsProvider extends ChangeNotifier {
  String appName = "عقارات الأنبار";

  String officeName = "مكتب الأندلس للعقارات";

  String logoUrl = "";

  Future<void> loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection("settings")
        .doc("app_settings")
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    appName = data["appName"] ?? appName;

    officeName = data["officeName"] ?? officeName;

    logoUrl = data["logoUrl"] ?? "";

    notifyListeners();
  }
}
