import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ===== Luxury Gold Brand Colors =====
  static const Color primaryColor = Color(0xFFC5A16B); // ذهبي موحد معتمد
  static const Color secondaryColor = Color(0xFFD8BD95);

  // ===== Luxury Dark Colors =====
  static const Color backgroundColor = Color(0xFF0F172A); // كحلي ملكي داكن
  static const Color cardColor = Color(0xFF1E293B); // بطاقات كحلية
  static const Color textDark = Colors.white;
  static const Color textGrey = Color(0xFFCBD5E1);

  // ===== Professional Light Colors =====
  static const Color lightBackgroundColor = Color(0xFFF8FAFC); // خلفية نهارية ناعمة مريحة للعين
  static const Color lightCardColor = Colors.white; // بطاقات بيضاء
  static const Color lightTextDark = Color(0xFF0F172A); // نصوص داكنة بتباين عالي
  static const Color lightTextGrey = Color(0xFF475569); // نصوص ثانوية متباينة
  static const Color lightBorderColor = Color(0xFFE2E8F0); // حدود ناعمة متناسقة

  // ==========================================
  // الوضع الداكن (Luxury Dark Theme)
  // ==========================================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      fontFamily: GoogleFonts.cairo().fontFamily,

      scaffoldBackgroundColor: backgroundColor,

      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardColor,
        onSurface: textDark,
        onSurfaceVariant: textGrey,
        outline: Colors.white24,
      ),

      // ===== AppBar =====
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),

      // ===== Cards =====
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ===== Buttons =====
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          elevation: 0,
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      // ===== Inputs =====
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: const TextStyle(
          color: textGrey,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Colors.white24,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Colors.white24,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),
      ),

      // ===== Text =====
      textTheme: GoogleFonts.cairoTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
          headlineMedium: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: textDark,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: textGrey,
          ),
        ),
      ),

      // ===== Icons =====
      iconTheme: const IconThemeData(
        color: primaryColor,
        size: 24,
      ),

      // ===== Bottom Navigation =====
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textGrey,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      // ===== Divider =====
      dividerColor: Colors.white12,
    );
  }

  // ==========================================
  // الوضع النهاري (Professional Light Theme)
  // ==========================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      fontFamily: GoogleFonts.cairo().fontFamily,

      scaffoldBackgroundColor: lightBackgroundColor,

      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: lightCardColor,
        onSurface: lightTextDark,
        onSurfaceVariant: lightTextGrey,
        outline: lightBorderColor,
      ),

      // ===== AppBar =====
      appBarTheme: AppBarTheme(
        backgroundColor: lightCardColor,
        foregroundColor: lightTextDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          color: lightTextDark,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: primaryColor),
      ),

      // ===== Cards =====
      cardTheme: CardThemeData(
        color: lightCardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorderColor, width: 1),
        ),
      ),

      // ===== Buttons =====
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      // ===== Inputs =====
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        hintStyle: const TextStyle(
          color: lightTextGrey,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: lightBorderColor,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: lightBorderColor,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),
      ),

      // ===== Text =====
      textTheme: GoogleFonts.cairoTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: lightTextDark,
          ),
          headlineMedium: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: lightTextDark,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: lightTextDark,
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: lightTextDark,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: lightTextDark,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: lightTextGrey,
          ),
        ),
      ),

      // ===== Icons =====
      iconTheme: const IconThemeData(
        color: primaryColor,
        size: 24,
      ),

      // ===== Bottom Navigation =====
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightTextGrey,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // ===== Divider =====
      dividerColor: lightBorderColor,
    );
  }
}
