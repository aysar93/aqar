import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/add_property_data.dart';

class Step6Images extends StatefulWidget {
  final AddPropertyData property;
  final VoidCallback onChanged;

  const Step6Images({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  State<Step6Images> createState() => _Step6ImagesState();
}

class _Step6ImagesState extends State<Step6Images> {
  final ImagePicker picker = ImagePicker();

  Future<void> pickImages() async {
    final images = await picker.pickMultiImage();

    if (images.isEmpty) return;

    if (images.length > 10) {
      images.removeRange(
        10,
        images.length,
      );
    }

    setState(() {
      widget.property.selectedImages = images
          .map(
            (e) => File(e.path),
          )
          .toList();
    });

    widget.onChanged();
  }

  Future<void> pickVideo() async {
    try {
      final picked = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked == null) return;
      final file = File(picked.path);
      final size = await file.length();
      if (size > 100 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("حجم الفيديو كبير جداً. الحد الأقصى هو 100 ميغابايت"),
          ),
        );
        return;
      }
      setState(() {
        widget.property.selectedVideo = file;
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تعذر اختيار الفيديو: $e")),
      );
    }
  }

  void removeVideo() {
    setState(() {
      widget.property.selectedVideo = null;
      widget.property.videoUrl = null;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "صور العقار",
            style: TextStyle(
              color: onSurface,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "يمكنك إضافة حتى 10 صور",
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.60),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: pickImages,
              icon: const Icon(
                Icons.photo_library,
              ),
              label: const Text(
                "اختيار الصور",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xffC5A16B,
                ),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // زر وواجهة اختيار فيديو العقار (اختياري)
          if (widget.property.selectedVideo == null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: pickVideo,
                icon: const Icon(
                  Icons.videocam_outlined,
                  color: Color(0xffC5A16B),
                ),
                label: const Text(
                  "إضافة فيديو للعقار (اختياري)",
                  style: TextStyle(
                    color: Color(0xffC5A16B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Color(0xffC5A16B),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xffC5A16B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffC5A16B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam_rounded, color: Color(0xffC5A16B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "تم اختيار فيديو للعقار (${(widget.property.selectedVideo!.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} ميغابايت)",
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.red),
                    onPressed: removeVideo,
                    tooltip: "إلغاء الفيديو",
                  ),
                ],
              ),
            ),
          const SizedBox(height: 25),
          Expanded(
            child: widget.property.selectedImages.isEmpty
                ? Center(
                    child: Text(
                      "لم يتم اختيار صور بعد",
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  )
                : GridView.builder(
                    itemCount: widget.property.selectedImages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(
                          15,
                        ),
                        child: Image.file(
                          widget.property.selectedImages[index],
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
