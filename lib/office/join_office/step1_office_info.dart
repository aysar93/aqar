import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/join_office_data.dart';

class Step1OfficeInfo extends StatefulWidget {
  final JoinOfficeData data;
  final VoidCallback? onChanged;

  const Step1OfficeInfo({
    super.key,
    required this.data,
    this.onChanged,
  });

  @override
  State<Step1OfficeInfo> createState() => _Step1OfficeInfoState();
}

class _Step1OfficeInfoState extends State<Step1OfficeInfo> {
  late final TextEditingController _nameController;
  late final TextEditingController _licenseController;

  final ImagePicker _picker = ImagePicker();

  bool _isPickingLicenseImage = false;

  final List<String> _availableServices = const [
    'بيع العقارات',
    'شراء العقارات',
    'تأجير العقارات',
    'إدارة العقارات',
    'تقييم العقارات',
    'تسويق العقارات',
    'إدارة الأملاك',
    'الاستشارات العقارية',
  ];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.data.name,
    );

    _licenseController = TextEditingController(
      text: widget.data.licenseNumber,
    );

    _nameController.addListener(_updateData);
    _licenseController.addListener(_updateData);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_updateData)
      ..dispose();

    _licenseController
      ..removeListener(_updateData)
      ..dispose();

    super.dispose();
  }

  void _updateData() {
    widget.data.name = _nameController.text.trim();
    widget.data.licenseNumber = _licenseController.text.trim();

    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitle(context),
            const SizedBox(height: 24),
            _buildNameField(context),
            const SizedBox(height: 18),
            _buildServicesSection(context),
            const SizedBox(height: 18),
            _buildEstablishedYearField(context),
            const SizedBox(height: 18),
            _buildLicenseNumberField(context),
            const SizedBox(height: 18),
            _buildLicenseImageSection(context),
            const SizedBox(height: 18),
            _buildHint(context),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // العنوان
  // =========================================================

  Widget _buildTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'معلومات المكتب',
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'أدخل المعلومات الأساسية للمكتب العقاري',
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  // =========================================================
  // اسم المكتب
  // =========================================================

  Widget _buildNameField(BuildContext context) {
    return TextFormField(
      controller: _nameController,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      textInputAction: TextInputAction.next,
      maxLength: 80,
      decoration: _inputDecoration(
        context,
        label: 'اسم المكتب',
        hint: 'مثال: مكتب الأندلس للعقارات',
        icon: Icons.business_rounded,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال اسم المكتب';
        }

        if (value.trim().length < 3) {
          return 'اسم المكتب قصير جدًا';
        }

        return null;
      },
    );
  }

  // =========================================================
  // الخدمات
  // =========================================================

  Widget _buildServicesSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.home_repair_service_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'خدمات المكتب',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'اختر الخدمات التي يقدمها مكتبك',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: _availableServices.map((service) {
              final selected = widget.data.services.contains(service);

              return FilterChip(
                label: Text(service),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      if (!widget.data.services.contains(service)) {
                        widget.data.services.add(service);
                      }
                    } else {
                      widget.data.services.remove(service);
                    }
                  });

                  widget.onChanged?.call();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // سنة التأسيس
  // =========================================================

  Widget _buildEstablishedYearField(BuildContext context) {
    final currentYear = DateTime.now().year;

    return DropdownButtonFormField<int>(
      initialValue: widget.data.establishedYear,
      isExpanded: true,
      alignment: Alignment.centerRight,
      decoration: _inputDecoration(
        context,
        label: 'سنة التأسيس',
        hint: 'اختر سنة تأسيس المكتب',
        icon: Icons.calendar_today_outlined,
      ),
      items: List.generate(
        currentYear - 1949,
        (index) {
          final year = currentYear - index;

          return DropdownMenuItem<int>(
            value: year,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                year.toString(),
                textDirection: TextDirection.ltr,
              ),
            ),
          );
        },
      ),
      onChanged: (value) {
        setState(() {
          widget.data.establishedYear = value;
        });

        widget.onChanged?.call();
      },
    );
  }

  // =========================================================
  // رقم الترخيص
  // =========================================================

  Widget _buildLicenseNumberField(BuildContext context) {
    return TextFormField(
      controller: _licenseController,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      textInputAction: TextInputAction.done,
      maxLength: 50,
      decoration: _inputDecoration(
        context,
        label: 'رقم الترخيص',
        hint: 'أدخل رقم ترخيص المكتب',
        icon: Icons.badge_outlined,
      ),
    );
  }

  // =========================================================
  // صورة الترخيص
  // =========================================================

  Widget _buildLicenseImageSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final imagePath = widget.data.licenseImageUrl.trim();

    final hasLocalImage = imagePath.isNotEmpty &&
        !imagePath.startsWith('http://') &&
        !imagePath.startsWith('https://');

    final hasRemoteImage =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'صورة الترخيص',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'أضف صورة واضحة للترخيص العقاري ليتم مراجعتها من الإدارة',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 14),
          if (hasLocalImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(imagePath),
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _licensePlaceholder(context);
                },
              ),
            )
          else if (hasRemoteImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imagePath,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return _licensePlaceholder(context);
                },
              ),
            )
          else
            _licensePlaceholder(context),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isPickingLicenseImage ? null : _pickLicenseImage,
            icon: _isPickingLicenseImage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    imagePath.isEmpty
                        ? Icons.add_photo_alternate_outlined
                        : Icons.change_circle_outlined,
                  ),
            label: Text(
              imagePath.isEmpty ? 'إضافة صورة الترخيص' : 'تغيير صورة الترخيص',
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // اختيار صورة الترخيص
  // =========================================================

  Future<void> _pickLicenseImage() async {
    try {
      setState(() {
        _isPickingLicenseImage = true;
      });

      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      final compressedImage = await _compressImage(
        File(image.path),
      );

      widget.data.licenseImageUrl = compressedImage.path;

      widget.onChanged?.call();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حدث خطأ أثناء اختيار صورة الترخيص',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingLicenseImage = false;
        });
      }
    }
  }

  // =========================================================
  // ضغط الصورة - نفس فكرة نظام الصورة الشخصية
  // =========================================================

  Future<File> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();

    final targetPath =
        '${dir.path}/license_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 1080,
      minHeight: 1080,
    );

    if (compressed == null) {
      return file;
    }

    return File(compressed.path);
  }

  // =========================================================
  // الصورة الافتراضية
  // =========================================================

  Widget _licensePlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 52,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'لم تتم إضافة صورة الترخيص',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // الملاحظة
  // =========================================================

  Widget _buildHint(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 21,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'أدخل البيانات الرسمية للمكتب بدقة، '
              'لأنها ستظهر ضمن معلومات المكتب بعد اعتماده',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // تصميم الحقول
  // =========================================================

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.2,
        ),
      ),
    );
  }
}
