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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              const Expanded(
                child: Text(
                  'صور العقار',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white,
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
                  color: const Color(0xff1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white10,
                  ),
                ),
                child: Text(
                  '$totalImages / 10',
                  style: const TextStyle(
                    color: Color(0xffD4AF37),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'يمكنك الاحتفاظ بالصور الحالية أو حذفها وإضافة صور جديدة',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white60,
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
                backgroundColor: const Color(0xffD4AF37),
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white38,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
                      color: Colors.white.withValues(alpha: .15),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'لا توجد صور للعقار',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'يمكنك إضافة صور جديدة من جهازك',
                      style: TextStyle(
                        color: Colors.white38,
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
      child: Image.network(
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
