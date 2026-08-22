import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../chat/services/chat_service.dart';
import '../../chat/widgets/message_bubble.dart';
import '../../chat/widgets/message_input.dart';

class AdminChatScreen extends StatefulWidget {
  final String userId;

  final Map<String, dynamic> chatData;

  const AdminChatScreen({
    super.key,
    required this.userId,
    required this.chatData,
  });

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final ChatService _chatService = ChatService();

  final TextEditingController controller = TextEditingController();

  final String adminId = "admin";

  bool _markedRead = false;

  @override
  void initState() {
    super.initState();

    _markMessagesRead();
  }

  Future<void> _markMessagesRead() async {
    if (_markedRead) return;

    _markedRead = true;

    await _chatService.markRead(
      chatId: widget.userId,
      currentUserId: adminId,
    );

    await _chatService.markAdminRead(
      widget.userId,
    );
  }

  Future<void> sendMessage() async {
    if (widget.chatData["isClosed"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "المحادثة مغلقة حالياً",
          ),
        ),
      );

      return;
    }

    final text = controller.text.trim();

    if (text.isEmpty) return;

    await _chatService.sendMessage(
      chatId: widget.userId,
      message: text,
      senderType: "admin",
    );

    controller.clear();
  }

  Future<void> toggleChatStatus() async {
    final current = widget.chatData["isClosed"] ?? false;

    await _chatService.setClosed(
      widget.userId,
      !current,
    );

    setState(() {
      widget.chatData["isClosed"] = !current;
    });
  }

  Future<void> deleteChat() async {
    await _chatService.deleteChat(
      widget.userId,
    );

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "تم حذف المحادثة",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chatData["userName"] ?? "مستخدم",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.chatData["userPhone"] ?? "",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete,
              color: Colors.redAccent,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text(
                      "حذف المحادثة",
                    ),
                    content: const Text(
                      "هل تريد حذف المحادثة نهائياً؟",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "إلغاء",
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);

                          deleteChat();
                        },
                        child: const Text(
                          "حذف",
                          style: TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(
              widget.chatData["isClosed"] == true
                  ? Icons.lock_open
                  : Icons.lock,
              color: const Color(0xffD4AF37),
            ),
            onPressed: toggleChatStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.messages(
                widget.userId,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;

                    return MessageBubble(
                      message: data["message"] ?? "",
                      imageUrl: data["imageUrl"] ?? "",
                      type: data["type"] ?? "text",
                      latitude: data["latitude"]?.toDouble(),
                      longitude: data["longitude"]?.toDouble(),
                      isMe: data["senderId"] == adminId,
                      status: data["status"] ?? "sent",
                      time: data["createdAt"] != null
                          ? (data["createdAt"] as Timestamp).toDate()
                          : DateTime.now(),
                    );
                  },
                );
              },
            ),
          ),
          MessageInput(
            controller: controller,
            chatId: widget.userId,
            senderType: "admin",
            onSend: sendMessage,
            enabled: widget.chatData["isClosed"] != true,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }
}
