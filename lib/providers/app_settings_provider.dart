import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  final FirebaseFirestore? _firestore;
  AppSettingsProvider({FirebaseFirestore? firestore}) : _firestore = firestore;

  String appName = "عقارات الانبار";
  String officeName = "مكتب الأندلس للعقارات";
  String logoUrl = "";

  // الافتراضي هو الوضع الداكن للحفاظ على السلوك الحالي والهوية المعتمدة
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadSettings() async {
    // 1. استعادة اختيار المظهر المحفوظ محلياً
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('app_theme_mode');
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved theme: $e');
    }

    // 2. تحميل إعدادات التطبيق من السحابة
    try {
      final doc = await (_firestore ?? FirebaseFirestore.instance)
          .collection('settings')
          .doc('app_settings')
          .get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      if (data['appName'] is String) appName = data['appName'] as String;
      if (data['officeName'] is String) {
        officeName = data['officeName'] as String;
      }
      if (data['logoUrl'] is String) logoUrl = data['logoUrl'] as String;
      notifyListeners();
    } catch (_) {
      // Optional branding must not break startup when offline or denied.
      debugPrint('App settings unavailable; keeping existing defaults');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'app_theme_mode',
        mode == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (e) {
      debugPrint('Error persisting theme mode: $e');
    }
  }

  Future<void> toggleTheme() async {
    final next =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}
