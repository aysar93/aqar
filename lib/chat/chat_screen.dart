import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/chat_model.dart';
import 'models/message_model.dart';

import 'services/chat_service.dart';

import 'widgets/chat_app_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/message_input.dart';
import 'widgets/date_separator.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ChatScreen({
    super.key,
    this.onBack,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();

  final ScrollController _scrollController = ScrollController();

  final TextEditingController _messageController = TextEditingController();

  final User? user = FirebaseAuth.instance.currentUser;

  String chatId = "";

  bool loading = true;

  bool canSend = true;

  bool chatEnabled = true;

  @override
  void initState() {
    super.initState();

    _initializeChat();
  }

  Future<void> _initializeChat() async {
    if (user == null) return;

    try {
      final settings = await FirebaseFirestore.instance
          .collection("settings")
          .doc("app_settings")
          .get();

      chatEnabled = settings.data()?["allowChat"] ?? true;

      chatId = await _chatService.getOrCreateChat(user!);

      await _chatService.markDelivered(
        chatId: chatId,
        currentUserId: user!.uid,
      );

      await _chatService.markRead(
        chatId: chatId,
        currentUserId: user!.uid,
      );

      await _chatService.markUserRead(chatId);
    } catch (e, s) {
      debugPrint("========== CHAT ERROR ==========");
      debugPrint(e.toString());
      debugPrintStack(stackTrace: s);
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();

    _messageController.dispose();

    super.dispose();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("chats")
          .doc(chatId)
          .snapshots(),
      builder: (context, chatSnapshot) {
        if (!chatSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final chat = ChatModel.fromFirestore(
          chatSnapshot.data!,
        );

        canSend = chatEnabled && !chat.isClosed && !chat.isBlocked;

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: ChatAppBar(
            isClosed: chat.isClosed,
            onBack: _handleBack,
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatService.messages(
                      chatId,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final messages = snapshot.data!.docs
                          .map(
                            (e) => MessageModel.fromFirestore(
                              e,
                            ),
                          )
                          .toList();

                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            "ابدأ المحادثة مع الإدارة",
                            style: TextStyle(
                              color: Colors.white54,
                            ),
                          ),
                        );
                      }

                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(
                                milliseconds: 250,
                              ),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      );

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];

                          final isMe = message.senderId == user!.uid;

                          final currentDate =
                              message.createdAt?.toDate() ?? DateTime.now();

                          bool showDate = true;

                          if (index > 0) {
                            final previousDate =
                                messages[index - 1].createdAt?.toDate() ??
                                    DateTime.now();

                            showDate = previousDate.day != currentDate.day ||
                                previousDate.month != currentDate.month ||
                                previousDate.year != currentDate.year;
                          }

                          return Column(
                            children: [
                              if (showDate)
                                DateSeparator(
                                  date: currentDate,
                                ),
                              MessageBubble(
                                message: message.message,
                                imageUrl: message.imageUrl,
                                type: message.type,
                                latitude: message.latitude,
                                longitude: message.longitude,
                                time: message.createdAt?.toDate(),
                                isMe: isMe,
                                status: message.status,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                if (chat.isBlocked)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: .22),
                      ),
                    ),
                    child: const Text(
                      "تم حظر حسابك من المحادثة. لا يمكنك إرسال رسائل جديدة حالياً",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (!chatEnabled)
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      "المحادثة متوقفة حالياً",
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                MessageInput(
                  controller: _messageController,
                  enabled: canSend,
                  chatId: chatId,
                  senderType: "user",
                  onSend: () async {
                    final text = _messageController.text.trim();

                    if (text.isEmpty) {
                      return;
                    }

                    await _chatService.sendMessage(
                      chatId: chatId,
                      message: text,
                      senderType: "user",
                    );

                    _messageController.clear();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
