import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/chat_image_service.dart';
import '../services/chat_service.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  final String chatId;
  final String senderType;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.enabled,
    required this.chatId,
    required this.senderType,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final ImagePicker picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    final url = await ChatImageService.uploadImage(
      File(image.path),
    );

    await ChatService().sendMessage(
      chatId: widget.chatId,
      message: "",
      imageUrl: url,
      senderType: widget.senderType,
      type: "image",
    );
  }

  Future<void> sendLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();

    await ChatService().sendMessage(
      chatId: widget.chatId,
      senderType: widget.senderType,
      type: "location",
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: widget.enabled
                      ? "اكتب رسالتك"
                      : "تم إغلاق المحادثة من قبل الإدارة",
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                      color: Color(0xFFD4AF37),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF0F172A),
              child: IconButton(
                onPressed: widget.enabled ? sendLocation : null,
                icon: const Icon(
                  Icons.location_on,
                  color: Color(0xFFD4AF37),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF0F172A),
              child: IconButton(
                onPressed: widget.enabled ? pickImage : null,
                icon: const Icon(
                  Icons.photo,
                  color: Color(0xFFD4AF37),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  widget.enabled ? const Color(0xFFD4AF37) : Colors.grey,
              child: IconButton(
                onPressed: widget.enabled ? widget.onSend : null,
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
