import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/office_model.dart';
import '../../services/office_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../features/property_map/screens/location_picker_screen.dart';
import '../../../features/property_map/models/property_location.dart';

/// شاشة تعديل بيانات المكتب.
///
/// صاحب المكتب هو المسؤول عن إدخال وتعديل معلومات مكتبه.
/// لا يوجد في هذا النظام مفهوم "موظف مكتب".
///
class EditOfficeScreen extends StatefulWidget {
  final String officeId;
  final String ownerUid;

  const EditOfficeScreen({
    super.key,
    required this.officeId,
    required this.ownerUid,
  });

  @override
  State<EditOfficeScreen> createState() => _EditOfficeScreenState();
}

enum _ExitChoice { cancel, discard, save }

class _EditOfficeScreenState extends State<EditOfficeScreen> {
  final _formKey = GlobalKey<FormState>();
  OfficeModel? _office;
  String? _loadError;
  bool _isLoading = true;

  // ═════════════════════════════════════════════
  // معلومات المكتب الأساسية
  // ═════════════════════════════════════════════

  final _officeNameController = TextEditingController();

  final _descriptionController = TextEditingController();

  final _phoneController = TextEditingController();

  final _whatsappController = TextEditingController();

  final _emailController = TextEditingController();

  final _websiteController = TextEditingController();

  // روابط التواصل الاجتماعي
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _telegramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _youtubeController = TextEditingController();

  // ═════════════════════════════════════════════
  // الموقع
  // ═════════════════════════════════════════════

  final _areaController = TextEditingController();

  final _addressController = TextEditingController();

  // ═════════════════════════════════════════════
  // معلومات إضافية
  // ═════════════════════════════════════════════

  final _licenseNumberController = TextEditingController();

  final _foundedYearController = TextEditingController();

  final _servicesController = TextEditingController();

  // ═════════════════════════════════════════════
  // بيانات مؤقتة للواجهة
  // ═════════════════════════════════════════════

  String? _selectedCity;

  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();
  String _logoUrl = '';
  String _coverImageUrl = '';
  // معرض صور المكتب
  final List<String> _galleryImages = [];
  bool _isUploadingGallery = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  final Map<String, String> _workingHours = {
    'السبت': '09:00 - 17:00',
    'الأحد': '09:00 - 17:00',
    'الاثنين': '09:00 - 17:00',
    'الثلاثاء': '09:00 - 17:00',
    'الأربعاء': '09:00 - 17:00',
    'الخميس': '09:00 - 17:00',
    'الجمعة': 'مغلق',
  };

  final List<String> _cities = [
    'الرمادي',
    'الفلوجة',
    'هيت',
    'حديثة',
    'عانة',
    'راوة',
    'القائم',
    'الرطبة',
    'الحبانية',
    'الصقلاوية',
    'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    _loadOffice();
  }

  Future<void> _loadOffice() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || currentUser.uid != widget.ownerUid) {
      if (mounted) {
        setState(() {
          _loadError = 'ليس لديك صلاحية لتعديل هذا المكتب.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final isOwner = await OfficeService.isOfficeOwner(
        widget.officeId,
        currentUser.uid,
      );
      if (!isOwner) {
        throw StateError('ليس لديك صلاحية لتعديل هذا المكتب.');
      }

      final office = await OfficeService.getOffice(widget.officeId);
      if (office == null) {
        throw StateError('تعذر العثور على المكتب المطلوب.');
      }
      if (office.ownerId != currentUser.uid) {
        throw StateError('ليس لديك صلاحية لتعديل هذا المكتب.');
      }

      if (!mounted) return;
      _populateForm(office);
      setState(() {
        _office = office;
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error is StateError
              ? error.message.toString()
              : 'تعذر تحميل بيانات المكتب. حاول مرة أخرى.';
          _isLoading = false;
        });
      }
    }
  }

  void _populateForm(OfficeModel office) {
    _selectedLatitude = office.latitude != 0 ? office.latitude : null;
    _selectedLongitude = office.longitude != 0 ? office.longitude : null;
    _logoUrl = office.logoUrl;
    _coverImageUrl = office.coverImageUrl;
    _galleryImages
      ..clear()
      ..addAll(office.galleryImages);
    _officeNameController.text = office.name;
    _descriptionController.text = office.description;
    _phoneController.text = office.phone;
    _whatsappController.text = office.whatsapp;
    _emailController.text = office.email;
    _websiteController.text = office.website;
    _facebookController.text = office.facebook;
    _instagramController.text = office.instagram;
    _telegramController.text = office.telegram;
    _tiktokController.text = office.tiktok;
    _youtubeController.text = office.youtube;
    _selectedCity = _cities.contains(office.city) ? office.city : null;
    _areaController.text = office.areaName;
    _addressController.text = office.address;
    _licenseNumberController.text = office.licenseNumber;
    _foundedYearController.text = office.establishedYear?.toString() ?? '';
    _servicesController.text = office.services.join('، ');
    _workingHours
      ..clear()
      ..addAll(office.workingHours.isEmpty
          ? {
              'السبت': '09:00 - 17:00',
              'الأحد': '09:00 - 17:00',
              'الاثنين': '09:00 - 17:00',
              'الثلاثاء': '09:00 - 17:00',
              'الأربعاء': '09:00 - 17:00',
              'الخميس': '09:00 - 17:00',
              'الجمعة': 'مغلق',
            }
          : office.workingHours);
  }

  // ═════════════════════════════════════════════
  // التغييرات غير المحفوظة
  // ═════════════════════════════════════════════

  bool get _hasUnsavedChanges {
    final office = _office;
    if (office == null) return false;

    final establishedYear = int.tryParse(
      _foundedYearController.text.trim(),
    );

    final services = _servicesController.text
        .split(RegExp(r'[,،]'))
        .map((service) => service.trim())
        .where((service) => service.isNotEmpty)
        .toList();

    return _officeNameController.text.trim() != office.name ||
        _descriptionController.text.trim() != office.description ||
        _logoUrl != office.logoUrl ||
        _coverImageUrl != office.coverImageUrl ||
        !_listEquals(_galleryImages, office.galleryImages) ||
        _phoneController.text.trim() != office.phone ||
        _whatsappController.text.trim() != office.whatsapp ||
        _emailController.text.trim() != office.email ||
        _websiteController.text.trim() != office.website ||
        _facebookController.text.trim() != office.facebook ||
        _instagramController.text.trim() != office.instagram ||
        _telegramController.text.trim() != office.telegram ||
        _tiktokController.text.trim() != office.tiktok ||
        _youtubeController.text.trim() != office.youtube ||
        (_selectedCity ?? office.city) != office.city ||
        _areaController.text.trim() != office.areaName ||
        _addressController.text.trim() != office.address ||
        (_selectedLatitude ?? office.latitude) != office.latitude ||
        (_selectedLongitude ?? office.longitude) != office.longitude ||
        !_mapEquals(_workingHours, office.workingHours) ||
        establishedYear != office.establishedYear ||
        _licenseNumberController.text.trim() != office.licenseNumber ||
        !_listEquals(services, office.services);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<bool> _handleBackNavigation() async {
    if (_isSaving || !_hasUnsavedChanges) {
      return !_isSaving;
    }

    final result = await showDialog<_ExitChoice>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final scheme = theme.colorScheme;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
            contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
            actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            title: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: scheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'لديك تعديلات غير محفوظة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'قمت بتعديل بيانات المكتب ولم يتم حفظها بعد. اختر الإجراء المناسب:',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.55,
                color: scheme.onSurfaceVariant,
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(_ExitChoice.save);
                  },
                  icon: const Icon(Icons.save_outlined, size: 19),
                  label: const Text(
                    'حفظ وخروج',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(_ExitChoice.discard);
                  },
                  icon: const Icon(Icons.logout_outlined, size: 19),
                  label: const Text(
                    'خروج بدون حفظ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(_ExitChoice.cancel);
                  },
                  child: const Text(
                    'متابعة التعديل',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || result == null || result == _ExitChoice.cancel) {
      return false;
    }

    if (result == _ExitChoice.discard) {
      return true;
    }

    await _saveOffice();
    return mounted && !_hasUnsavedChanges && !_isSaving;
  }

  @override
  void dispose() {
    _officeNameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _telegramController.dispose();
    _tiktokController.dispose();
    _youtubeController.dispose();

    _areaController.dispose();
    _addressController.dispose();

    _licenseNumberController.dispose();
    _foundedYearController.dispose();
    _servicesController.dispose();

    super.dispose();
  }

  // ═════════════════════════════════════════════
  // الحفظ
  // ═════════════════════════════════════════════

  String _normalizedAreaName() {
    final city = (_selectedCity ?? '').trim();
    var area = _areaController.text.trim();

    if (city.isEmpty || area.isEmpty) {
      return area;
    }

    final repeatedPrefix = RegExp(
      '^${RegExp.escape(city)}\s*[-–—]\s*',
    );

    while (repeatedPrefix.hasMatch(area)) {
      area = area.replaceFirst(repeatedPrefix, '').trim();
    }

    return area;
  }

  Future<void> _saveOffice() async {
    FocusScope.of(context).unfocus();

    final office = _office;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (office == null ||
        currentUser == null ||
        currentUser.uid != widget.ownerUid) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final isOwner = await OfficeService.isOfficeOwner(
        office.id,
        currentUser.uid,
      );
      if (!isOwner) {
        throw StateError('ليس لديك صلاحية لتعديل هذا المكتب.');
      }

      final establishedYear = int.tryParse(_foundedYearController.text.trim());
      final services = _servicesController.text
          .split(RegExp(r'[,،]'))
          .map((service) => service.trim())
          .where((service) => service.isNotEmpty)
          .toList();

      // نستخدم النسخة المحمّلة من Firestore ثم نغيّر فقط الحقول المسموح بها
      // لصاحب المكتب. تبقى حقول الملكية والإدارة والإحصاءات كما هي.
      final changes = <String, dynamic>{
        'name': _officeNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'logoUrl': _logoUrl,
        'coverImageUrl': _coverImageUrl,
        'galleryImages': List<String>.from(_galleryImages),
        'phone': _phoneController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'email': _emailController.text.trim(),
        'website': _websiteController.text.trim(),
        'facebook': _facebookController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'telegram': _telegramController.text.trim(),
        'tiktok': _tiktokController.text.trim(),
        'youtube': _youtubeController.text.trim(),
        'city': _selectedCity ?? office.city,
        'district': '',
        'areaName': _normalizedAreaName(),
        'address': _addressController.text.trim(),
        'latitude': _selectedLatitude ?? office.latitude,
        'longitude': _selectedLongitude ?? office.longitude,
        'services': services,
        'workingHours': Map<String, String>.from(_workingHours),
        'establishedYear': establishedYear,
        'licenseNumber': _licenseNumberController.text.trim(),
      };
      await OfficeService.updateOfficeByOwner(
        officeId: office.id,
        ownerId: currentUser.uid,
        changes: changes,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ بيانات المكتب بنجاح',
          ),
        ),
      );
      setState(() {
        _office = office.copyWith(
          name: changes['name'] as String,
          description: changes['description'] as String,
          logoUrl: _logoUrl,
          coverImageUrl: _coverImageUrl,
          galleryImages: List<String>.from(_galleryImages),
          phone: changes['phone'] as String,
          whatsapp: changes['whatsapp'] as String,
          email: changes['email'] as String,
          website: changes['website'] as String,
          facebook: changes['facebook'] as String,
          instagram: changes['instagram'] as String,
          telegram: changes['telegram'] as String,
          tiktok: changes['tiktok'] as String,
          youtube: changes['youtube'] as String,
          city: changes['city'] as String,
          district: changes['district'] as String,
          areaName: changes['areaName'] as String,
          address: changes['address'] as String,
          latitude: changes['latitude'] as double,
          longitude: changes['longitude'] as double,
          services: services,
          workingHours: Map<String, String>.from(_workingHours),
          establishedYear: establishedYear,
          licenseNumber: changes['licenseNumber'] as String,
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'تعذر حفظ التعديلات. حاول مرة أخرى',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ═════════════════════════════════════════════
  // اختيار الصورة
  // ═════════════════════════════════════════════

  Future<void> _selectLogo() async {
    final url = await _pickAndUploadImage();
    if (url != null && mounted) setState(() => _logoUrl = url);
  }

  Future<void> _selectCover() async {
    final url = await _pickAndUploadImage();
    if (url != null && mounted) setState(() => _coverImageUrl = url);
  }

  Future<void> _selectGalleryImages() async {
    if (_isUploadingGallery) return;

    try {
      final selectedImages = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (selectedImages.isEmpty) return;

      setState(() {
        _isUploadingGallery = true;
      });

      var uploadedCount = 0;

      for (final selected in selectedImages) {
        try {
          final url = await uploadToCloudinary(
            File(selected.path),
          );

          if (url != null && url.trim().isNotEmpty) {
            _galleryImages.add(url.trim());
            uploadedCount++;
          }
        } catch (_) {
          // نكمل رفع بقية الصور حتى لو فشلت صورة واحدة
        }

        if (mounted) {
          setState(() {});
        }
      }

      if (!mounted) return;

      if (uploadedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر رفع صور المعرض.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تمت إضافة $uploadedCount صورة إلى المعرض',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر اختيار صور المعرض.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingGallery = false;
        });
      }
    }
  }

  void _removeGalleryImage(int index) {
    if (index < 0 || index >= _galleryImages.length) return;

    setState(() {
      _galleryImages.removeAt(index);
    });
  }

  Future<String?> _pickAndUploadImage() async {
    try {
      final selected = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (selected == null) return null;
      final url = await uploadToCloudinary(File(selected.path));
      if (url == null || url.trim().isEmpty)
        throw StateError('تعذر رفع الصورة.');
      return url;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر اختيار أو رفع الصورة.')),
        );
      }
      return null;
    }
  }

  // ═════════════════════════════════════════════
  // البناء
  // ═════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('تعديل المكتب'), centerTitle: true),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _loadError!,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackNavigation();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: scheme.surface,
          appBar: AppBar(
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'تعديل بيانات المكتب',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: IconButton(
                  tooltip: 'حفظ التعديلات',
                  onPressed: _isSaving ? null : _saveOffice,
                  icon: const Icon(Icons.save_outlined),
                ),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                32,
              ),
              children: [
                _buildPageIntro(),
                const SizedBox(height: 16),
                _buildImagesSection(),
                const SizedBox(height: 12),
                _buildBasicInfoSection(),
                const SizedBox(height: 12),
                _buildContactSection(),
                const SizedBox(height: 12),
                _buildSocialMediaSection(),
                const SizedBox(height: 12),
                _buildLocationSection(),
                const SizedBox(height: 12),
                _buildWorkingHoursSection(),
                const SizedBox(height: 12),
                _buildProfessionalInfoSection(),
                const SizedBox(height: 12),
                _buildServicesSection(),
                const SizedBox(height: 12),
                const SizedBox(height: 28),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageIntro() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.business_outlined,
              color: scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'حدّث بيانات مكتبك وصورك ووسائل التواصل ليظهر المكتب بصورة احترافية للزوار',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // الصور
  // ═════════════════════════════════════════════

  Widget _buildImagesSection() {
    return _buildSectionCard(
      title: 'صور المكتب',
      icon: Icons.photo_library_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildImagePicker(
                icon: Icons.person_outline,
                title: 'شعار المكتب',
                subtitle: 'Logo',
                onTap: _selectLogo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildImagePicker(
                icon: Icons.image_outlined,
                title: 'غلاف المكتب',
                subtitle: 'Cover',
                onTap: _selectCover,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // عنوان المعرض
        Row(
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'معرض صور المكتب',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${_galleryImages.length} صورة',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'أضف صورًا للمكتب من الداخل والخارج والموقع والخدمات لعرضها للزوار',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // زر إضافة الصور
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isUploadingGallery ? null : _selectGalleryImages,
            icon: _isUploadingGallery
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.add_photo_alternate_outlined,
                  ),
            label: Text(
              _isUploadingGallery
                  ? 'جارٍ رفع الصور...'
                  : 'إضافة صور إلى المعرض',
            ),
          ),
        ),

        if (_galleryImages.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 105,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _galleryImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final imageUrl = _galleryImages[index];

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 125,
                      height: 105,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(
                          imageUrl,
                          width: 125,
                          height: 105,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              width: 125,
                              height: 105,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                              ),
                            );
                          },
                          loadingBuilder: (
                            context,
                            child,
                            progress,
                          ) {
                            if (progress == null) {
                              return child;
                            }

                            return Container(
                              width: 125,
                              height: 105,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 7,
                      left: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    // زر حذف الصورة
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Material(
                        color: Colors.red,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _removeGalleryImage(index),
                          child: const SizedBox(
                            width: 28,
                            height: 28,
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],

        if (_galleryImages.isEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 22,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 38,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'لا توجد صور في المعرض حاليًا',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImagePicker({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final imageUrl = title == 'شعار المكتب' ? _logoUrl : _coverImageUrl;
    final hasImage = imageUrl.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: scheme.surfaceContainerHighest,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.58),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            if (hasImage)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.50),
                    ],
                  ),
                ),
              ),
            if (!hasImage)
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: scheme.primary),
                ),
              ),

            // عنوان الصورة في شارة صغيرة حتى لا يتداخل مع الصورة.
            PositionedDirectional(
              top: 10,
              start: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasImage
                      ? Colors.black.withValues(alpha: 0.42)
                      : scheme.surface.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: hasImage ? Colors.white : scheme.onSurface,
                  ),
                ),
              ),
            ),

            PositionedDirectional(
              start: 10,
              end: 10,
              bottom: 10,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasImage ? Icons.edit_outlined : icon,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      hasImage ? 'اضغط لتغيير الصورة' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // المعلومات الأساسية
  // ═════════════════════════════════════════════

  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      title: 'المعلومات الأساسية',
      icon: Icons.business_outlined,
      children: [
        _buildTextField(
          controller: _officeNameController,
          label: 'اسم المكتب',
          hint: 'مثال: مكتب الأندلس للعقارات',
          icon: Icons.business_outlined,
          requiredField: true,
        ),
        _buildTextField(
          controller: _descriptionController,
          label: 'نبذة عن المكتب',
          hint: 'اكتب وصفًا احترافيًا عن المكتب وخدماته وخبرته',
          icon: Icons.description_outlined,
          maxLines: 5,
          requiredField: true,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // الاتصال
  // ═════════════════════════════════════════════

  Widget _buildContactSection() {
    return _buildSectionCard(
      title: 'معلومات التواصل',
      icon: Icons.contact_phone_outlined,
      children: [
        _buildTextField(
          controller: _phoneController,
          label: 'رقم الهاتف',
          hint: '07XXXXXXXXX',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          requiredField: true,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _whatsappController,
          label: 'رقم واتساب',
          hint: '07XXXXXXXXX',
          icon: Icons.chat_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _emailController,
          label: 'البريد الإلكتروني',
          hint: 'office@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _websiteController,
          label: 'الموقع الإلكتروني',
          hint: 'https://example.com',
          icon: Icons.language_outlined,
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // التواصل الاجتماعي
  // ═════════════════════════════════════════════

  Widget _buildSocialMediaSection() {
    return _buildSectionCard(
      title: 'التواصل الاجتماعي',
      icon: Icons.share_outlined,
      children: [
        _buildTextField(
          controller: _facebookController,
          label: 'Facebook',
          hint: 'https://facebook.com/...',
          icon: Icons.facebook_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _instagramController,
          label: 'Instagram',
          hint: 'https://instagram.com/...',
          icon: Icons.camera_alt_outlined,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _telegramController,
          label: 'Telegram',
          hint: 'https://t.me/...',
          icon: Icons.send_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _tiktokController,
          label: 'TikTok',
          hint: 'https://www.tiktok.com/@...',
          icon: Icons.music_note_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _youtubeController,
          label: 'YouTube',
          hint: 'https://youtube.com/...',
          icon: Icons.play_circle_outline_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        Text(
          'أدخل الرابط الكامل للحساب. اترك الحقل فارغًا إذا لم يكن للمكتب حساب',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // الموقع
  // ═════════════════════════════════════════════

  Widget _buildFixedGovernorateField() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 20,
            color: scheme.primary,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المحافظة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'الأنبار',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _buildSectionCard(
      title: 'موقع المكتب',
      icon: Icons.location_on_outlined,
      children: [
        _buildFixedGovernorateField(),
        const SizedBox(height: 12),
        _buildDropdown(
          value: _selectedCity,
          label: 'المدينة',
          icon: Icons.location_city_outlined,
          items: _cities,
          onChanged: (value) {
            setState(() {
              _selectedCity = value;
            });
          },
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _areaController,
          label: 'المنطقة / الحي',
          hint: 'اسم المنطقة أو الحي',
          icon: Icons.map_outlined,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _addressController,
          label: 'العنوان',
          hint: 'العنوان التفصيلي للمكتب',
          icon: Icons.home_work_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _openLocationPicker,
          icon: const Icon(Icons.map_rounded),
          label: const Text('تحديد موقع المكتب على الخريطة'),
        ),
        if ((_selectedLatitude ?? 0) != 0 &&
            (_selectedLongitude ?? 0) != 0) ...[
          const SizedBox(height: 8),
          Text(
            'تم تحديد الموقع: ${_selectedLatitude!.toStringAsFixed(6)}, '
            '${_selectedLongitude!.toStringAsFixed(6)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _openLocationPicker() async {
    final office = _office;
    if (office == null) {
      return;
    }

    final initialLocation = PropertyLocation(
      governorate: 'الأنبار',
      city: _selectedCity ?? office.city,
      district: _areaController.text.trim().isNotEmpty
          ? _areaController.text.trim()
          : (office.district.isNotEmpty ? office.district : office.areaName),
      landmark: '',
      latitude: _selectedLatitude ?? office.latitude,
      longitude: _selectedLongitude ?? office.longitude,
    );

    final result = await Navigator.of(context).push<PropertyLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: initialLocation,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final city = result.city.trim();
    var district = result.district.trim();

    if (city.isNotEmpty && district.isNotEmpty) {
      final repeatedPrefix = RegExp(
        '^${RegExp.escape(city)}\s*[-–—]\s*',
      );

      while (repeatedPrefix.hasMatch(district)) {
        district = district.replaceFirst(repeatedPrefix, '').trim();
      }
    }

    setState(() {
      _selectedCity = city.isEmpty ? _selectedCity : city;
      _areaController.text = district;
      _selectedLatitude = result.latitude;
      _selectedLongitude = result.longitude;
    });
  }

  // ═════════════════════════════════════════════
  // أوقات العمل
  // ═════════════════════════════════════════════

  Widget _buildWorkingHoursSection() {
    return _buildSectionCard(
      title: 'أوقات العمل',
      icon: Icons.access_time_outlined,
      children: [
        _buildWorkingDay(
          day: 'السبت',
        ),
        _buildWorkingDay(
          day: 'الأحد',
        ),
        _buildWorkingDay(
          day: 'الاثنين',
        ),
        _buildWorkingDay(
          day: 'الثلاثاء',
        ),
        _buildWorkingDay(
          day: 'الأربعاء',
        ),
        _buildWorkingDay(
          day: 'الخميس',
        ),
        _buildWorkingDay(
          day: 'الجمعة',
          defaultClosed: true,
        ),
      ],
    );
  }

  Widget _buildWorkingDay({
    required String day,
    bool defaultClosed = false,
  }) {
    final hours =
        _workingHours[day] ?? (defaultClosed ? 'مغلق' : '09:00 - 17:00');
    final isClosed = hours.trim().toLowerCase() == 'مغلق' ||
        hours.trim().toLowerCase() == 'closed';
    final parts = hours.split(' - ');
    final openingTime = !isClosed && parts.isNotEmpty ? parts.first : '09:00';
    final closingTime = !isClosed && parts.length > 1 ? parts.last : '17:00';

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              day,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: OutlinedButton(
              onPressed: () {
                _selectTime(
                  day,
                  isOpening: true,
                );
              },
              child: Text(
                openingTime,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 6,
            ),
            child: Text(
              '—',
            ),
          ),
          Expanded(
            flex: 3,
            child: OutlinedButton(
              onPressed: () {
                _selectTime(
                  day,
                  isOpening: false,
                );
              },
              child: Text(
                closingTime,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'إغلاق اليوم',
            onPressed: () {
              setState(() {
                _workingHours[day] = isClosed ? '09:00 - 17:00' : 'مغلق';
              });
            },
            icon: Icon(
              isClosed ? Icons.lock_outline : Icons.lock_open_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(
    String day, {
    required bool isOpening,
  }) async {
    final currentHours = _workingHours[day] ?? '09:00 - 17:00';
    final parts = currentHours.split(' - ');
    final fallback = isOpening ? '09:00' : '17:00';
    final selectedTime = isOpening
        ? (parts.isNotEmpty ? parts.first : fallback)
        : (parts.length > 1 ? parts.last : fallback);
    final timeParts = selectedTime.split(':');
    final initialHour = int.tryParse(timeParts.first) ?? (isOpening ? 9 : 17);
    final initialMinute =
        timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;

    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialHour,
        minute: initialMinute,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    final current = _workingHours[day] ?? '09:00 - 17:00';
    final currentParts = current.split(' - ');
    final opening = isOpening
        ? _formatTime(selected)
        : (currentParts.isNotEmpty ? currentParts.first : '09:00');
    final closing = isOpening
        ? (currentParts.length > 1 ? currentParts.last : '17:00')
        : _formatTime(selected);

    setState(() {
      _workingHours[day] = '$opening - $closing';
    });
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ═════════════════════════════════════════════
  // المعلومات المهنية
  // ═════════════════════════════════════════════

  Widget _buildProfessionalInfoSection() {
    return _buildSectionCard(
      title: 'المعلومات المهنية',
      icon: Icons.verified_user_outlined,
      children: [
        _buildTextField(
          controller: _licenseNumberController,
          label: 'رقم الترخيص',
          hint: 'رقم الترخيص إن وجد',
          icon: Icons.badge_outlined,
        ),
        _buildTextField(
          controller: _foundedYearController,
          label: 'سنة التأسيس',
          hint: 'مثال: 2015',
          icon: Icons.calendar_today_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.verified_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'توثيق المكتب يتم من خلال الإدارة، ولا يستطيع صاحب المكتب منح نفسه شارة التوثيق',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // الخدمات
  // ═════════════════════════════════════════════

  Widget _buildServicesSection() {
    return _buildSectionCard(
      title: 'خدمات المكتب',
      icon: Icons.miscellaneous_services_outlined,
      children: [
        _buildTextField(
          controller: _servicesController,
          label: 'الخدمات',
          hint: 'اكتب الخدمات التي يقدمها المكتب، وافصل بينها بفاصلة',
          icon: Icons.list_alt_outlined,
          maxLines: 4,
        ),
        const SizedBox(height: 8),
        Text(
          'مثال: بيع العقارات، إيجار العقارات، إدارة الأملاك، التسويق العقاري',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // الخصوصية والظهور
  // ═════════════════════════════════════════════

  // ═════════════════════════════════════════════
  // زر الحفظ
  // ═════════════════════════════════════════════

  Widget _buildSaveButton() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _saveOffice,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.save_outlined,
                ),
          label: Text(
            _isSaving ? 'جارٍ الحفظ...' : 'حفظ بيانات المكتب',
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Widgets مساعدة
  // ═════════════════════════════════════════════

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(
          dividerColor: Colors.transparent,
          splashColor: scheme.primary.withValues(alpha: 0.06),
          highlightColor: scheme.primary.withValues(alpha: 0.04),
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsetsDirectional.fromSTEB(
            16,
            8,
            12,
            8,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            18,
          ),
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          iconColor: scheme.primary,
          collapsedIconColor: scheme.onSurfaceVariant,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: 21,
              color: scheme.primary,
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 25,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          children: [
            ..._withVerticalSpacing(children),
          ],
        ),
      ),
    );
  }

  List<Widget> _withVerticalSpacing(List<Widget> children) {
    if (children.isEmpty) return const [];

    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        result.add(const SizedBox(height: 12));
      }
      result.add(children[i]);
    }
    return result;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textDirection: TextDirection.rtl,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: scheme.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: scheme.error,
            width: 1.5,
          ),
        ),
      ),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'هذا الحقل مطلوب';
              }

              return null;
            }
          : null,
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 1.6,
          ),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
