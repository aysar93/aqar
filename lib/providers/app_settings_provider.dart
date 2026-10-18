import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsProvider extends ChangeNotifier {
  final FirebaseFirestore? _firestore;
  AppSettingsProvider({FirebaseFirestore? firestore}) : _firestore = firestore;
  String appName = "عقارات الانبار";

  String officeName = "مكتب الأندلس للعقارات";

  String logoUrl = "";

  Future<void> loadSettings() async {
    try {
      final doc = await (_firestore ?? FirebaseFirestore.instance)
          .collection('settings').doc('app_settings').get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      if (data['appName'] is String) appName = data['appName'] as String;
      if (data['officeName'] is String) officeName = data['officeName'] as String;
      if (data['logoUrl'] is String) logoUrl = data['logoUrl'] as String;
      notifyListeners();
    } catch (_) {
      // Optional branding must not break startup when offline or denied.
      debugPrint('App settings unavailable; keeping existing defaults');
    }
  }
}
