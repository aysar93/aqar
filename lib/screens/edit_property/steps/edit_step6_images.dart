import '../../../widgets/media_image.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/edit_property_data.dart';

class EditStep6Images extends StatefulWidget {
  final EditPropertyData property;
  final VoidCallback onChanged;

  const EditStep6Images({
    super.key,
    required this.property,
    required this.onChanged,
  });

  @override
  State<EditStep6Images> createState() => _EditStep6ImagesState();
}

class _EditStep6ImagesState extends State<EditStep6Images> {
  final ImagePicker picker = ImagePicker();

  int get totalImages =>
      widget.property.existingImages.length + widget.property.newImages.length;

  Future<void> pickImages() async {
    final remaining = 10 - totalImages;

    if (remaining <= 0) {
      _showMessage(
        'يمكن إضافة 10 صور كحد أقصى',
      );
      return;
    }

    final pickedImages = await picker.pickMultiImage();

    if (pickedImages.isEmpty) return;

    final imagesToAdd = pickedImages.take(remaining).toList();

    setState(() {
      widget.property.newImages.addAll(
        imagesToAdd.map(
          (image) => File(image.path),
        ),
      );
    });

    widget.onChanged();

    if (pickedImages.length > remaining) {
      _showMessage(
        'تمت إضافة $remaining صور فقط لأن الحد الأقصى هو 10 صور',
      );
    }
  }

  void removeExistingImage(int index) {
    setState(() {
      widget.property.existingImages.removeAt(index);
    });

    widget.onChanged();
  }

  void removeNewImage(int index) {
    setState(() {
      widget.property.newImages.removeAt(index);
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
        _showMessage('حجم الفيديو كبير جداً. الحد الأقصى 100 ميغابايت');
        return;
      }
      setState(() {
        widget.property.newVideo = file;
        widget.property.removeVideo = false;
      });
      widget.onChanged();
    } catch (e) {
      _showMessage('تعذر اختيار الفيديو: $e');
    }
  }

  void removeVideo() {
    setState(() {
      widget.property.newVideo = null;
      widget.property.videoUrl = null;
      widget.property.removeVideo = true;
    });
    widget.onChanged();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.right,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xff1E293B) : Colors.white;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  'صور العقار',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: onSurface.withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  '$totalImages / 10',
                  style: const TextStyle(
                    color: Color(0xffC5A16B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'يمكنك الاحتفاظ بالصور الحالية أو حذفها وإضافة صور جديدة',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.60),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: totalImages >= 10 ? null : pickImages,
              icon: const Icon(
                Icons.add_photo_alternate_rounded,
              ),
              label: Text(
                totalImages >= 10 ? 'وصلت إلى الحد الأقصى' : 'إضافة صور',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffC5A16B),
                foregroundColor: Colors.black,
                disabledBackgroundColor: onSurface.withValues(alpha: 0.10),
                disabledForegroundColor: onSurface.withValues(alpha: 0.38),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // فيديو العقار (اختياري)
          if (widget.property.newVideo != null)
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
                      'فيديو جديد جاهز للرفع (${(widget.property.newVideo!.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} ميغابايت)',
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
                    tooltip: 'إلغاء الفيديو',
                  ),
                ],
              ),
            )
          else if (widget.property.videoUrl != null && !widget.property.removeVideo)
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
                      'العقار يحتوي على فيديو حالي',
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    onPressed: removeVideo,
                    tooltip: 'حذف الفيديو',
                  ),
                ],
              ),
            )
          else
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
                  'إضافة / تعديل فيديو العقار (اختياري)',
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
            ),
          const SizedBox(height: 22),
          if (totalImages == 0)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 70,
                      color: onSurface.withValues(alpha: .15),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'لا توجد صور للعقار',
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.54),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'يمكنك إضافة صور جديدة من جهازك',
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.38),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                itemCount: totalImages,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final existingCount = widget.property.existingImages.length;

                  if (index < existingCount) {
                    return _existingImageCard(
                      widget.property.existingImages[index],
                      index,
                    );
                  }

                  final newIndex = index - existingCount;

                  return _newImageCard(
                    widget.property.newImages[newIndex],
                    newIndex,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _existingImageCard(
    String imageUrl,
    int index,
  ) {
    return _imageContainer(
      child: MediaImage(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white38,
              size: 35,
            ),
          );
        },
      ),
      onDelete: () {
        removeExistingImage(index);
      },
      label: 'حالية',
    );
  }

  Widget _newImageCard(
    File image,
    int index,
  ) {
    return _imageContainer(
      child: Image.file(
        image,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      ),
      onDelete: () {
        removeNewImage(index);
      },
      label: 'جديدة',
    );
  }

  Widget _imageContainer({
    required Widget child,
    required VoidCallback onDelete,
    required String label,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: const Color(0xff1E293B),
            child: child,
          ),
          Positioned(
            top: 6,
            left: 6,
            child: Material(
              color: Colors.black.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(50),
              child: InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(50),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
