import 'package:flutter/material.dart';
import 'conversation_screen.dart';

class ChatScreen extends StatelessWidget {
  final VoidCallback? onBack;
  final Map<String, dynamic>? initialProperty;
  const ChatScreen({super.key, this.onBack, this.initialProperty});
  @override
  Widget build(BuildContext context) =>
      ConversationScreen(onBack: onBack, initialProperty: initialProperty);
}
