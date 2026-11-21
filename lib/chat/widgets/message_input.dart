import 'dart:io';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/chat_image_service.dart';
import '../services/chat_service.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final FutureOr<void> Function() onSend;
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
  bool _busy = false;

  Future<void> _perform(FutureOr<void> Function() action) async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'تعذر الإرسال. تحقق من الاتصال والصلاحيات ثم حاول مجدداً')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فعّل خدمة الموقع لإرسال موقعك')));
      }
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('السماح بالوصول إلى الموقع مطلوب لمشاركته')));
      }
      return;
    }

    final position = await Geolocator.getCurrentPosition()
        .timeout(const Duration(seconds: 20));

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: isDark
              ? null
              : const Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                enabled: widget.enabled && !_busy,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: widget.enabled
                      ? "اكتب رسالتك"
                      : "الإرسال غير متاح حالياً",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  filled: true,
                  fillColor: fieldBg,
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
                      color: Color(0xFFC5A16B),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: fieldBg,
              child: IconButton(
                tooltip: 'مشاركة الموقع',
                onPressed: widget.enabled && !_busy
                    ? () => _perform(sendLocation)
                    : null,
                icon: const Icon(
                  Icons.location_on,
                  color: Color(0xFFC5A16B),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: fieldBg,
              child: IconButton(
                tooltip: 'إرسال صورة',
                onPressed:
                    widget.enabled && !_busy ? () => _perform(pickImage) : null,
                icon: const Icon(
                  Icons.photo,
                  color: Color(0xFFC5A16B),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  widget.enabled ? const Color(0xFFC5A16B) : Colors.grey,
              child: IconButton(
                tooltip: 'إرسال الرسالة',
                onPressed: widget.enabled && !_busy
                    ? () => _perform(widget.onSend)
                    : null,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(
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
