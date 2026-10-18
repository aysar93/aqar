import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'chat_message_tile.dart';

class ChatReplyPreview extends StatefulWidget {
  final String? chatId;
  final String messageId;
  final Map<String, dynamic>? message;
  final VoidCallback? onTap;
  const ChatReplyPreview(
      {super.key,
      this.chatId,
      required this.messageId,
      this.message,
      this.onTap});
  @override
  State<ChatReplyPreview> createState() => _ChatReplyPreviewState();
}

class _ChatReplyPreviewState extends State<ChatReplyPreview> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;
  void _setup() {
    _stream = widget.chatId == null || widget.message != null
        ? null
        : FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .doc(widget.messageId)
            .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant ChatReplyPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId ||
        oldWidget.messageId != widget.messageId ||
        (oldWidget.message == null) != (widget.message == null)) {
      _setup();
    }
  }

  Widget _content(String text) => InkWell(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
            border: const Border(
                right: BorderSide(color: Color(0xFFD4AF37), width: 2))),
        child: Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ));
  @override
  Widget build(BuildContext context) {
    if (widget.message != null) {
      return _content(ChatMessageTile.summary(widget.message!));
    }
    if (_stream == null) return _content('الرسالة الأصلية غير متاحة');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (_, snapshot) => _content(
              snapshot.hasError
                  ? 'تعذر تحميل الرسالة الأصلية'
                  : !snapshot.hasData
                      ? 'جارٍ تحميل الرسالة الأصلية…'
                      : snapshot.data!.exists
                          ? ChatMessageTile.summary(snapshot.data!.data()!)
                          : 'الرسالة الأصلية غير متاحة',
            ));
  }
}
