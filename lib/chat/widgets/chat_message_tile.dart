import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/image_viewer_screen.dart';
import 'audio_message.dart';
import 'chat_reply_preview.dart';
import 'property_chat_card.dart';

class ChatMessageTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  final String? chatId;
  final bool highlighted;
  final Map<String, dynamic>? reply;
  final VoidCallback onActions;
  final VoidCallback? onReplyTap;
  const ChatMessageTile(
      {super.key,
      required this.data,
      required this.isMe,
      this.reply,
      this.chatId,
      this.highlighted = false,
      required this.onActions,
      this.onReplyTap});

  static String summary(Map<String, dynamic> d) {
    if (d['deletedAt'] != null) return 'تم حذف هذه الرسالة';
    switch (d['type']) {
      case 'property':
        return 'عقار: ${d['property']?['title'] ?? ''}';
      case 'image':
        return 'صورة';
      case 'audio':
        return 'رسالة صوتية';
      case 'location':
        return 'موقع';
      default:
        return (d['message'] ?? '').toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final deleted = data['deletedAt'] != null;
    final time = (data['createdAt'] as Timestamp?)?.toDate();
    final color = isMe ? const Color(0xFF293449) : const Color(0xFF1E293B);
    Widget content;
    if (deleted) {
      content = const Text('تم حذف هذه الرسالة',
          style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic));
    } else if (data['type'] == 'property' && data['property'] is Map) {
      content = PropertyChatCard(
          property: Map<String, dynamic>.from(data['property']));
    } else if (data['type'] == 'audio') {
      content = AudioMessage(
          url: data['audioUrl'] ?? '',
          seconds: (data['audioSeconds'] as num?)?.toInt() ?? 0);
    } else if (data['type'] == 'image') {
      content = InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ImageViewerScreen(imageUrl: data['imageUrl'] ?? ''))),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(data['imageUrl'] ?? '',
                  width: 240,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white54)))));
    } else if (data['type'] == 'location') {
      content = TextButton.icon(
          onPressed: () async {
            final success = await launchUrl(
                Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${data['latitude']},${data['longitude']}'),
                mode: LaunchMode.externalApplication);
            if (!success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تعذر فتح الموقع')));
            }
          },
          icon: const Icon(Icons.location_on_outlined),
          label: const Text('عرض الموقع'),
          style:
              TextButton.styleFrom(foregroundColor: const Color(0xFFD4AF37)));
    } else {
      content = Text(data['message'] ?? '',
          style:
              const TextStyle(color: Colors.white, height: 1.5, fontSize: 15));
    }
    return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: onActions,
          onLongPress: onActions,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .82),
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: highlighted
                        ? const Color(0xFFD4AF37)
                        : isMe
                            ? const Color(0xFFD4AF37).withValues(alpha: .22)
                            : Colors.white10)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!deleted &&
                      (data['replyToId'] ?? '').toString().isNotEmpty)
                    ChatReplyPreview(
                        chatId: chatId,
                        messageId: data['replyToId'],
                        message: reply,
                        onTap: onReplyTap),
                  content,
                  const SizedBox(height: 5),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        time == null
                            ? 'جارٍ الإرسال'
                            : DateFormat('HH:mm').format(time),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                    if (isMe) ...[
                      const SizedBox(width: 5),
                      Icon(
                          data['status'] == 'sent'
                              ? Icons.done
                              : Icons.done_all,
                          size: 14,
                          color: data['status'] == 'read'
                              ? const Color(0xFFD4AF37)
                              : Colors.white38)
                    ],
                  ]),
                ]),
          ),
        ));
  }
}
