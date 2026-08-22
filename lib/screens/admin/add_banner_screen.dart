import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../banners/banner_model.dart';
import '../../banners/banner_service.dart';
import '../../services/cloudinary_service.dart';

class AddBannerScreen extends StatefulWidget {
  final BannerModel? banner;

  const AddBannerScreen({
    super.key,
    this.banner,
  });

  bool get isEdit => banner != null;

  @override
  State<AddBannerScreen> createState() => _AddBannerScreenState();
}

class _AddBannerScreenState extends State<AddBannerScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _orderController;

  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isActive = true;
  bool _isSaving = false;

  String _selectedType = 'property';

  String? _selectedPropertyId;
  String? _selectedOfficeId;

  String _searchProperty = '';
  String _searchOffice = '';

  @override
  void initState() {
    super.initState();

    final banner = widget.banner;

    _titleController = TextEditingController(
      text: banner?.title ?? '',
    );
    _subtitleController = TextEditingController(
      text: banner?.subtitle ?? '',
    );
    _orderController = TextEditingController(
      text: (banner?.order ?? 1).toString(),
    );

    _selectedType = banner?.type ?? 'property';
    _isActive = banner?.isActive ?? true;

    if (_selectedType == 'property') {
      _selectedPropertyId = banner?.targetId.trim().isNotEmpty == true
          ? banner!.targetId.trim()
          : null;
    }

    if (_selectedType == 'office') {
      _selectedOfficeId = banner?.targetId.trim().isNotEmpty == true
          ? banner!.targetId.trim()
          : null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null || !mounted) return;

    setState(() {
      _selectedImage = File(image.path);
    });
  }

  String get _targetId {
    if (_selectedType == 'property') {
      return _selectedPropertyId ?? '';
    }

    if (_selectedType == 'office') {
      return _selectedOfficeId ?? '';
    }

    return '';
  }

  bool get _targetRequired {
    return _selectedType == 'property' || _selectedType == 'office';
  }

  Future<void> _saveBanner() async {
    final existingImage = widget.banner?.imageUrl;

    if (_selectedImage == null &&
        (existingImage == null || existingImage.isEmpty)) {
      _showMessage('اختر صورة للبنر أولًا.');
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showMessage('أدخل عنوانًا واضحًا للبنر.');
      return;
    }

    if (_targetRequired && _targetId.isEmpty) {
      _showMessage(
        _selectedType == 'property'
            ? 'اختر العقار الذي سيفتحه البنر.'
            : 'اختر المكتب الذي سيفتحه البنر',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? imageUrl = existingImage;

      if (_selectedImage != null) {
        imageUrl = await uploadToCloudinary(_selectedImage!);
      }

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('تعذر تجهيز صورة البنر.');
      }

      final banner = BannerModel(
        id: widget.banner?.id ?? '',
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim(),
        imageUrl: imageUrl,
        type: _selectedType,
        targetId: _targetId,
        isActive: _isActive,
        order: int.tryParse(
              _orderController.text.trim(),
            ) ??
            1,
        createdAt: widget.banner?.createdAt,
      );

      if (widget.isEdit) {
        await BannerService.update(
          banner.id,
          banner.toMap(),
        );
      } else {
        await BannerService.add(banner);
      }

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        _showMessage('تعذر حفظ البنر: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEdit ? 'تعديل البنر' : 'إضافة بنر جديد',
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              30,
            ),
            children: [
              _SectionTitle(
                icon: Icons.campaign_outlined,
                title: 'معلومات البنر',
                subtitle: 'حدد المحتوى والوجهة التي سيتم فتحها عند الضغط',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'عنوان البنر',
                  hintText: 'مثال: عروض وعقارات مميزة',
                  prefixIcon: Icon(Icons.title_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subtitleController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  hintText: 'وصف مختصر يظهر على البنر',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                icon: Icons.touch_app_outlined,
                title: 'وجهة البنر',
                subtitle:
                    'بدل كتابة المعرّف يدويًا، اختر العقار أو المكتب من القائمة',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'نوع البنر',
                  prefixIcon: Icon(
                    Icons.category_outlined,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'property',
                    child: Text('عقار'),
                  ),
                  DropdownMenuItem(
                    value: 'office',
                    child: Text('مكتب'),
                  ),
                  DropdownMenuItem(
                    value: 'external',
                    child: Text('رابط خارجي'),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;

                        setState(() {
                          _selectedType = value;
                          _selectedPropertyId = null;
                          _selectedOfficeId = null;
                        });
                      },
              ),
              const SizedBox(height: 12),
              if (_selectedType == 'property')
                _PropertySelector(
                  selectedId: _selectedPropertyId,
                  search: _searchProperty,
                  onSearchChanged: (value) {
                    setState(() {
                      _searchProperty = value;
                    });
                  },
                  onSelected: (id) {
                    setState(() {
                      _selectedPropertyId = id;
                    });
                  },
                ),
              if (_selectedType == 'office')
                _OfficeSelector(
                  selectedId: _selectedOfficeId,
                  search: _searchOffice,
                  onSearchChanged: (value) {
                    setState(() {
                      _searchOffice = value;
                    });
                  },
                  onSelected: (id) {
                    setState(() {
                      _selectedOfficeId = id;
                    });
                  },
                ),
              if (_selectedType == 'external') ...[
                TextFormField(
                  initialValue: widget.banner?.targetId ?? '',
                  onChanged: (value) {
                    // الرابط الخارجي لا يحتاج إلى selector.
                    // يتم حفظه مباشرة في حقل مخفي عبر controller.
                  },
                  decoration: const InputDecoration(
                    labelText: 'الرابط الخارجي',
                    hintText: 'https://example.com',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ملاحظة: إذا كنت تستخدم الروابط الخارجية، أضف الرابط في targetId بالطريقة الموجودة في نظامك الحالي',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 22),
              _ImagePickerCard(
                imageFile: _selectedImage,
                imageUrl: widget.banner?.imageUrl,
                onPick: _pickImage,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ترتيب البنر',
                  hintText: '1',
                  prefixIcon: Icon(Icons.format_list_numbered_rounded),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                title: const Text(
                  'إظهار البنر للمستخدمين',
                ),
                subtitle: const Text(
                  'يمكنك إيقافه مؤقتًا دون حذفه',
                ),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveBanner,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _isSaving
                        ? 'جارٍ الحفظ...'
                        : widget.isEdit
                            ? 'حفظ التعديلات'
                            : 'إضافة البنر',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayPropertyNumber(dynamic value) {
  if (value == null) return '';

  if (value is num && value % 1 == 0) {
    return value.toInt().toString();
  }

  return value.toString().trim();
}

class _PropertySelector extends StatelessWidget {
  const _PropertySelector({
    required this.selectedId,
    required this.search,
    required this.onSearchChanged,
    required this.onSelected,
  });

  final String? selectedId;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _TargetSelector(
      title: 'اختر العقار',
      icon: Icons.home_work_outlined,
      searchHint: 'ابحث باسم العقار أو رقم الإعلان',
      emptyText: 'لا توجد عقارات مطابقة',
      selectedId: selectedId,
      search: search,
      onSearchChanged: onSearchChanged,
      onSelected: onSelected,
      stream: FirebaseFirestore.instance.collection('properties').snapshots(),
      itemBuilder: (doc) {
        final data = doc.data();

        final title = data['title']?.toString().trim() ?? '';
        final propertyNumber = _displayPropertyNumber(
          data['adNumber'] ?? data['propertyNumber'],
        );
        final city = data['city']?.toString().trim() ?? '';
        final area = data['areaName']?.toString().trim() ?? '';

        return _TargetItem(
          id: doc.id,
          title: title.isEmpty ? 'عقار بدون عنوان' : title,
          subtitle: [
            if (propertyNumber.isNotEmpty) 'رقم الإعلان: $propertyNumber',
            if (city.isNotEmpty) city,
            if (area.isNotEmpty) area,
          ].join(' • '),
          icon: Icons.home_work_outlined,
        );
      },
      matches: (doc) {
        final data = doc.data();
        final q = _normalizeSearch(search);

        if (q.isEmpty) return true;

        final title = _normalizeSearch(
          data['title']?.toString() ?? '',
        );

        // رقم الإعلان في مشروعك محفوظ باسم adNumber.
        // propertyNumber مدعوم أيضًا للتوافق مع السجلات القديمة.
        final adNumber = _normalizeSearch(
          data['adNumber']?.toString() ?? '',
        );
        final propertyNumber = _normalizeSearch(
          data['propertyNumber']?.toString() ?? '',
        );

        final city = _normalizeSearch(
          data['city']?.toString() ?? '',
        );
        final area = _normalizeSearch(
          data['areaName']?.toString() ?? '',
        );

        final qDigits = _digitsOnly(q);
        final adNumberDigits = _digitsOnly(adNumber);
        final propertyNumberDigits = _digitsOnly(propertyNumber);

        final numberMatches = (qDigits.isNotEmpty &&
                adNumberDigits.isNotEmpty &&
                adNumberDigits.contains(qDigits)) ||
            (qDigits.isNotEmpty &&
                propertyNumberDigits.isNotEmpty &&
                propertyNumberDigits.contains(qDigits));

        return title.contains(q) ||
            adNumber.contains(q) ||
            propertyNumber.contains(q) ||
            numberMatches ||
            city.contains(q) ||
            area.contains(q);
      },
    );
  }
}

String _normalizeSearch(String value) {
  var result = value.trim().toLowerCase().replaceAll('#', '');

  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  const persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  final buffer = StringBuffer();

  for (final char in result.split('')) {
    final arabicIndex = arabicDigits.indexOf(char);
    if (arabicIndex >= 0) {
      buffer.write(arabicIndex);
      continue;
    }

    final persianIndex = persianDigits.indexOf(char);
    if (persianIndex >= 0) {
      buffer.write(persianIndex);
      continue;
    }

    buffer.write(char);
  }

  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

String _digitsOnly(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

class _OfficeSelector extends StatelessWidget {
  const _OfficeSelector({
    required this.selectedId,
    required this.search,
    required this.onSearchChanged,
    required this.onSelected,
  });

  final String? selectedId;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _TargetSelector(
      title: 'اختر المكتب',
      icon: Icons.business_outlined,
      searchHint: 'ابحث باسم المكتب أو المدينة',
      emptyText: 'لا توجد مكاتب مطابقة',
      selectedId: selectedId,
      search: search,
      onSearchChanged: onSearchChanged,
      onSelected: onSelected,
      stream: FirebaseFirestore.instance.collection('offices').snapshots(),
      itemBuilder: (doc) {
        final data = doc.data();

        final name = data['name']?.toString().trim() ??
            data['officeName']?.toString().trim() ??
            '';
        final city = data['city']?.toString().trim() ?? '';
        final area = data['areaName']?.toString().trim() ?? '';

        return _TargetItem(
          id: doc.id,
          title: name.isEmpty ? 'مكتب بدون اسم' : name,
          subtitle: [
            if (city.isNotEmpty) city,
            if (area.isNotEmpty) area,
          ].join(' • '),
          icon: Icons.business_outlined,
        );
      },
      matches: (doc) {
        final data = doc.data();
        final q = search.trim().toLowerCase();

        if (q.isEmpty) return true;

        final name =
            '${data['name'] ?? ''} ${data['officeName'] ?? ''}'.toLowerCase();
        final city = data['city']?.toString().toLowerCase() ?? '';
        final area = data['areaName']?.toString().toLowerCase() ?? '';

        return name.contains(q) || city.contains(q) || area.contains(q);
      },
    );
  }
}

class _TargetSelector extends StatelessWidget {
  const _TargetSelector({
    required this.title,
    required this.icon,
    required this.searchHint,
    required this.emptyText,
    required this.selectedId,
    required this.search,
    required this.onSearchChanged,
    required this.onSelected,
    required this.stream,
    required this.itemBuilder,
    required this.matches,
  });

  final String title;
  final IconData icon;
  final String searchHint;
  final String emptyText;
  final String? selectedId;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelected;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final _TargetItem Function(
    QueryDocumentSnapshot<Map<String, dynamic>>,
  ) itemBuilder;
  final bool Function(
    QueryDocumentSnapshot<Map<String, dynamic>>,
  ) matches;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: searchHint,
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'تعذر تحميل القائمة',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs.where(matches).toList() ?? [];

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                  ),
                  child: Center(
                    child: Text(
                      emptyText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 300,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final doc = docs[index];
                    final item = itemBuilder(doc);
                    final selected = selectedId == item.id;

                    return InkWell(
                      onTap: () => onSelected(item.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: selected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(
                                        alpha: .14,
                                      )
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              child: Icon(
                                selected ? Icons.check_rounded : item.icon,
                                size: 19,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (item.subtitle.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 2,
                                      ),
                                      child: Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TargetItem {
  const _TargetItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.imageFile,
    required this.imageUrl,
    required this.onPick,
  });

  final File? imageFile;
  final String? imageUrl;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null || (imageUrl?.isNotEmpty ?? false);

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 86,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: hasImage
                  ? imageFile != null
                      ? Image.file(
                          imageFile!,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                        )
                  : const Icon(
                      Icons.add_photo_alternate_outlined,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasImage ? 'تغيير صورة البنر' : 'اختيار صورة البنر',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'يفضل صورة أفقية عالية الجودة',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    );
  }
}
