import 'package:flutter/material.dart';

class AppUpdateIcons {
  AppUpdateIcons._();

  static const Map<String, IconData> values = {
    'speed': Icons.speed_rounded,
    'bug': Icons.bug_report_rounded,
    'star': Icons.star_rounded,
    'security': Icons.shield_rounded,
    'rocket': Icons.rocket_launch_rounded,
    'design': Icons.auto_awesome_rounded,
    'search': Icons.search_rounded,
    'home': Icons.home_work_rounded,
    'favorite': Icons.favorite_rounded,
    'notification': Icons.notifications_active_rounded,
    'person': Icons.person_rounded,
    'chat': Icons.chat_rounded,
    'photo': Icons.photo_library_rounded,
    'location': Icons.location_on_rounded,
    'money': Icons.payments_rounded,
    'build': Icons.build_rounded,
  };

  static IconData fromKey(String key) => values[key] ?? Icons.star_rounded;
}
