import '../../widgets/media_image.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deleted = data['deletedAt'] != null;
    final time = (data['createdAt'] as Timestamp?)?.toDate();
    final color = isMe
        ? (isDark ? const Color(0xFF293449) : const Color(0xFFFBF7F0))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    Widget content;
    if (deleted) {
      content = Text('تم حذف هذه الرسالة',
          style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontStyle: FontStyle.italic));
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
              child: MediaImage(data['imageUrl'] ?? '',
                  width: 240,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Icon(Icons.broken_image_outlined,
                          color: isDark ? Colors.white54 : Colors.black45)))));
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
              TextButton.styleFrom(foregroundColor: const Color(0xFFC5A16B)));
    } else {
      content = Text(data['message'] ?? '',
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              height: 1.5,
              fontSize: 15));
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
                        ? const Color(0xFFC5A16B)
                        : isMe
                            ? const Color(0xFFC5A16B)
                                .withValues(alpha: isDark ? .22 : .40)
                            : (isDark ? Colors.white10 : Colors.black12))),
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
                        style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black45,
                            fontSize: 10)),
                    if (isMe) ...[
                      const SizedBox(width: 5),
                      Icon(
                          data['status'] == 'sent'
                              ? Icons.done
                              : Icons.done_all,
                          size: 14,
                          color: data['status'] == 'read'
                              ? const Color(0xFFC5A16B)
                              : (isDark ? Colors.white38 : Colors.black45))
                    ],
                  ]),
                ]),
          ),
        ));
  }
}
