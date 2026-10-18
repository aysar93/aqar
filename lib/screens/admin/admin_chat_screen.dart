import 'package:flutter/material.dart';
import '../../chat/conversation_screen.dart';

class AdminChatScreen extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> chatData;
  const AdminChatScreen(
      {super.key, required this.userId, required this.chatData});
  @override
  Widget build(BuildContext context) => ConversationScreen(
      chatId: userId,
      admin: true,
      title: (chatData['userName'] ?? 'مستخدم').toString());
}
