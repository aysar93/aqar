import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String) onChanged;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: onSurface,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: onSurface.withValues(alpha: 0.60),
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xffC5A16B),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xff1E293B) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
