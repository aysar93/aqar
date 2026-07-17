import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/image_viewer_screen.dart';
import 'package:url_launcher/url_launcher.dart';
class MessageBubble extends StatelessWidget {
  final String message;
  final String imageUrl;
  final String type;

  final double? latitude;
  final double? longitude;

  final DateTime? time;
  final bool isMe;
  final String status;

  const MessageBubble({
  super.key,
  required this.message,
  required this.imageUrl,
  required this.type,

this.latitude,
this.longitude,

  required this.time,
  required this.isMe,
  required this.status,
});

Future<void> _openLocation() async {
  if (latitude == null || longitude == null) return;

  final uri = Uri.parse(
    "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude",
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final timeText = time == null
        ? ""
        : DateFormat("hh:mm a").format(time!);

    return Align(
      alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),

        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),

        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * .75,
        ),

        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xffD4AF37)
              : const Color(0xff1E293B),

          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft:
                Radius.circular(isMe ? 18 : 0),
            bottomRight:
                Radius.circular(isMe ? 0 : 18),
          ),
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.end,

          children: [

            if (type == "image" && imageUrl.isNotEmpty)

  GestureDetector(

    onTap: () {

      Navigator.push(

        context,

        MaterialPageRoute(

          builder: (_) =>
              ImageViewerScreen(
                imageUrl: imageUrl,
              ),

        ),

      );

    },

    child: ClipRRect(

      borderRadius:
          BorderRadius.circular(14),

      child: Image.network(

        imageUrl,

        width: 220,

        fit: BoxFit.cover,

      ),

    ),

  )

else if (type == "location")

GestureDetector(

  onTap: _openLocation,

  child: Container(

    padding: const EdgeInsets.all(12),

    decoration: BoxDecoration(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(12),
    ),

    child: Row(

      mainAxisSize: MainAxisSize.min,

      children: [

        const Icon(
          Icons.location_on,
          color: Colors.red,
        ),

        const SizedBox(width: 8),

        Text(
          "فتح الموقع",
          style: TextStyle(
            color: isMe ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

      ],

    ),

  ),

)

else

  Text(

    message,

    style: TextStyle(

      color:
          isMe
              ? Colors.black
              : Colors.white,

      fontSize: 15,

    ),

  ),

            const SizedBox(height: 6),

            Row(
  mainAxisSize: MainAxisSize.min,
  children: [

    Text(
      timeText,
      style: TextStyle(
        color: isMe
            ? Colors.black54
            : Colors.white54,
        fontSize: 11,
      ),
    ),

    if (isMe) ...[

      const SizedBox(width: 4),

      Icon(

        status == "sent"
            ? Icons.done
            : Icons.done_all,

        size: 16,

        color: status == "read"
            ? Colors.blue
            : (isMe
                ? Colors.black54
                : Colors.white54),

      ),

    ],

  ],
),
          ],
        ),
      ),
    );
  }
}