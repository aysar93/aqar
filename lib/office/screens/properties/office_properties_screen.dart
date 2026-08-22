import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../models/property_model.dart';
import '../../../services/property_service.dart';
import '../../models/office_subscription_model.dart';
import '../../services/office_subscription_service.dart';
import '../../../screens/property_details.dart';
import '../../../screens/edit_property/edit_property_screen.dart';
import '../../../utils/property_default_images.dart';

class OfficePropertiesScreen extends StatefulWidget {
  const OfficePropertiesScreen({
    super.key,
    required this.officeId,
    required this.ownerUid,
  });

  final String officeId;
  final String ownerUid;

  @override
  State<OfficePropertiesScreen> createState() => _OfficePropertiesScreenState();
}

class _OfficePropertiesScreenState extends State<OfficePropertiesScreen> {
  final OfficeSubscriptionService _subscriptionService =
      OfficeSubscriptionService();

  String _query = '';
  String _filter = 'الكل';
  String? _processingPropertyId;

  late final Stream<List<PropertyModel>> _propertiesStream;
  late final Stream<OfficeSubscriptionModel?> _subscriptionStream;

  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _queryNotifier = ValueNotifier<String>('');

  int _lastFeaturedUsed = 0;
  int _lastMaxFeatured = 0;
  bool _hasLocalFeaturedUpdate = false;

  @override
  void initState() {
    super.initState();

    _propertiesStream = PropertyService.officePropertiesForOwner(
      widget.officeId,
    );

    _subscriptionStream = _subscriptionService.watchOfficeSubscription(
      widget.officeId,
    );
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    _queryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = FirebaseAuth.instance.currentUser?.uid == widget.ownerUid;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'عقارات المكتب',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        body: !isOwner
            ? const _Message('ليس لديك صلاحية لإدارة عقارات هذا المكتب.')
            : StreamBuilder<List<PropertyModel>>(
                stream: _propertiesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return _Message(
                      'تعذر تحميل عقارات المكتب.\n${snapshot.error}',
                    );
                  }

                  final allProperties = snapshot.data ?? const [];

                  return StreamBuilder<OfficeSubscriptionModel?>(
                    stream: _subscriptionStream,
                    builder: (context, subscriptionSnapshot) {
                      final subscription = subscriptionSnapshot.data;

                      if (subscription != null && !_hasLocalFeaturedUpdate) {
                        _lastFeaturedUsed = subscription.featuredPropertiesUsed;
                        _lastMaxFeatured = subscription.maxFeaturedProperties;
                      }
                      if (subscription != null) {
                        _lastMaxFeatured = subscription.maxFeaturedProperties;
                      }

                      final featuredUsed = _lastFeaturedUsed;
                      final maxFeatured = _lastMaxFeatured;

                      return ValueListenableBuilder<String>(
                        valueListenable: _queryNotifier,
                        builder: (context, query, _) {
                          final properties = _filtered(allProperties);

                          final publishedCount = allProperties
                              .where(
                                (item) =>
                                    item.status == 'approved' ||
                                    item.status == 'active',
                              )
                              .length;
                          final pendingCount = allProperties
                              .where((item) => item.status == 'pending')
                              .length;
                          final featuredCount = allProperties
                              .where((item) => item.isFeatured)
                              .length;

                          return Column(
                            children: [
                              _OfficePropertiesSummary(
                                total: allProperties.length,
                                published: publishedCount,
                                pending: pendingCount,
                                featured: featuredCount,
                                used: featuredUsed,
                                max: maxFeatured,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: _PremiumSearchField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  query: query,
                                  total: allProperties.length,
                                  onChanged: (value) {
                                    _query = value.trim().toLowerCase();
                                    _queryNotifier.value = value;
                                  },
                                  onClear: () {
                                    _searchController.clear();
                                    _query = '';
                                    _queryNotifier.value = '';
                                    _searchFocusNode.requestFocus();
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    for (int i = 0; i < 4; i++) ...[
                                      if (i > 0) const SizedBox(width: 5),
                                      Expanded(
                                        child: _FilterButton(
                                          label: const [
                                            'الكل',
                                            'منشور',
                                            'قيد المراجعة',
                                            'مرفوض',
                                          ][i],
                                          icon: const [
                                            Icons.grid_view_rounded,
                                            Icons.check_circle_rounded,
                                            Icons.pending_rounded,
                                            Icons.cancel_rounded,
                                          ][i],
                                          selected: _filter ==
                                              const [
                                                'الكل',
                                                'منشور',
                                                'قيد المراجعة',
                                                'مرفوض',
                                              ][i],
                                          onTap: () {
                                            setState(() {
                                              _filter = const [
                                                'الكل',
                                                'منشور',
                                                'قيد المراجعة',
                                                'مرفوض',
                                              ][i];
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: properties.isEmpty
                                    ? _Message(
                                        query.trim().isEmpty &&
                                                allProperties.isEmpty
                                            ? 'لا توجد عقارات في المكتب بعد.'
                                            : 'لا توجد عقارات مطابقة للبحث أو الفلتر الحالي',
                                      )
                                    : ListView.separated(
                                        keyboardDismissBehavior:
                                            ScrollViewKeyboardDismissBehavior
                                                .manual,
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          10,
                                          16,
                                          32,
                                        ),
                                        itemCount: properties.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 14),
                                        itemBuilder: (_, index) {
                                          final property = properties[index];

                                          return _PropertyTile(
                                            property: property,
                                            isProcessing:
                                                _processingPropertyId ==
                                                    property.id,
                                            onFeature: () =>
                                                _toggleFeaturedProperty(
                                              property: property,
                                              allProperties: allProperties,
                                            ),
                                            onOpen: () =>
                                                _openProperty(property),
                                            onEdit: () =>
                                                _editProperty(property),
                                            onDelete: () =>
                                                _deleteProperty(property.id),
                                            featuredCount: featuredUsed,
                                            maxFeatured: maxFeatured,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  List<PropertyModel> _filtered(List<PropertyModel> items) {
    final query = _queryNotifier.value.trim().toLowerCase();

    return items.where((property) {
      final text =
          '${property.title} ${property.propertyNumber} ${property.city} ${property.areaName}'
              .toLowerCase();

      final filterMatches = _filter == 'الكل' ||
          (_filter == 'منشور' &&
              (property.status == 'approved' || property.status == 'active')) ||
          (_filter == 'قيد المراجعة' && property.status == 'pending') ||
          (_filter == 'مرفوض' && property.status == 'rejected');

      return filterMatches && text.contains(query);
    }).toList();
  }

  Future<void> _openProperty(PropertyModel property) async {
    if (property.id.trim().isEmpty) {
      _showError('تعذر تحديد العقار.');
      return;
    }

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PropertyDetails(
            property: property,
            imageUrl: property.imageUrl,
            title: property.title,
            location: property.location,
            price: property.price.toString(),
            rooms: property.rooms,
            bathrooms: property.bathrooms,
            area: property.area,
            livingRooms: property.livingRooms,
            parking: property.parking,
            description: property.description,
            ownerPhone: property.ownerPhone,
            ownerWhatsapp: property.ownerWhatsapp,
            publisherUid: property.publisherUid,
            publisherName: property.publisherName,
            publisherEmail: property.publisherEmail,
            publisherPhone: property.publisherPhone,
            publisherWhatsapp: property.publisherWhatsapp,
            images: property.images,
            features: property.features,
            documentType: property.documentType,
            furnitureStatus: property.furnitureStatus,
            propertyType: property.propertyType,
            adType: property.adType,
            city: property.city,
            areaName: property.areaName,
            landmark: property.landmark,
            latitude: property.latitude,
            longitude: property.longitude,
            isVerified: property.isVerified,
            isFeatured: property.isFeatured,
            availabilityStatus: property.availabilityStatus,
            views: property.views,
            createdAt: property.createdAt,
            buildYear: property.buildYear,
            propertyNumber: property.propertyNumber,
            docId: property.id,
            isFavorite: property.isFavorite,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showError('تعذر فتح العقار: $error');
      }
    }
  }

  Future<void> _toggleFeaturedProperty({
    required PropertyModel property,
    required List<PropertyModel> allProperties,
  }) async {
    if (_processingPropertyId != null) {
      return;
    }

    final isPublished =
        property.status == 'approved' || property.status == 'active';

    if (!isPublished) {
      _showError('يمكن تمييز العقارات المنشورة فقط.');
      return;
    }

    if (property.id.trim().isEmpty) {
      _showError('تعذر تحديد العقار.');
      return;
    }

    if (property.isFeatured) {
      final confirmed = await _confirm(
        title: 'إلغاء تمييز العقار',
        message:
            'سيتم إلغاء تمييز العقار واستهلاك محاولة وفق نظام باقتك الحالية. هل تريد المتابعة؟',
        confirmText: 'إلغاء التمييز',
      );

      if (confirmed != true) {
        return;
      }

      await _setFeatured(
        property: property,
        value: false,
      );
      return;
    }

    final subscription =
        await _subscriptionService.getOfficeSubscription(widget.officeId);

    if (!mounted) return;

    if (!_isSubscriptionUsable(subscription)) {
      await _showUpgradeDialog(
        title: 'التمييز غير متاح',
        message:
            'لا يوجد اشتراك فعّال يسمح بتمييز العقارات حاليًا. اختر باقة مناسبة من صفحة الاشتراكات',
      );
      return;
    }

    if (subscription!.canFeatureProperties == false) {
      await _showUpgradeDialog(
        title: 'ميزة التمييز غير مشمولة',
        message:
            'باقتك الحالية لا تتضمن ميزة تمييز العقارات. قم بترقية الباقة لتفعيلها',
      );
      return;
    }

    final maxFeatured = subscription.maxFeaturedProperties;
    final usedAttempts = subscription.featuredPropertiesUsed;

    // صفر = غير محدود.
    final remainingAttempts = maxFeatured <= 0
        ? -1
        : (maxFeatured - usedAttempts).clamp(0, maxFeatured);

    if (maxFeatured > 0 && remainingAttempts <= 0) {
      await _showUpgradeDialog(
        title: 'انتهت محاولات التمييز',
        message: 'لقد استنفدت جميع محاولات تمييز العقارات في باقتك الحالية. '
            'يمكنك ترقية الباقة للحصول على محاولات إضافية',
      );
      return;
    }

    final confirmed = await _confirm(
      title: 'تمييز العقار',
      message: maxFeatured > 0
          ? 'سيتم تمييز هذا العقار. المتبقي لديك $remainingAttempts '
              'من أصل $maxFeatured محاولة تمييز.'
          : 'لديك محاولات تمييز غير محدودة ضمن باقتك الحالية. هل تريد المتابعة؟',
      confirmText: 'تمييز العقار',
    );

    if (confirmed != true) {
      return;
    }

    await _setFeatured(
      property: property,
      value: true,
    );
  }

  bool _isSubscriptionUsable(OfficeSubscriptionModel? subscription) {
    if (subscription == null || subscription.status != 'active') {
      return false;
    }

    final endDate = subscription.endDate;

    if (endDate == null || !endDate.isAfter(DateTime.now())) {
      return false;
    }

    return true;
  }

  Future<void> _setFeatured({
    required PropertyModel property,
    required bool value,
  }) async {
    setState(() {
      _processingPropertyId = property.id;
    });

    try {
      // التمييز واستهلاك المحاولة يتمان من خلال الخدمة داخل Transaction.
      await _subscriptionService.setFeaturedProperty(
        officeId: widget.officeId,
        ownerUid: widget.ownerUid,
        propertyId: property.id,
        isFeatured: value,
      );

      // حدّث الرصيد محليًا فور نجاح العملية، دون انتظار إعادة فتح الصفحة.
      final freshSubscription =
          await _subscriptionService.getOfficeSubscription(widget.officeId);
      if (freshSubscription != null) {
        _lastFeaturedUsed = freshSubscription.featuredPropertiesUsed;
        _lastMaxFeatured = freshSubscription.maxFeaturedProperties;
        _hasLocalFeaturedUpdate = true;
      } else {
        _lastFeaturedUsed =
            value ? _lastFeaturedUsed + 1 : _lastFeaturedUsed + 1;
        _hasLocalFeaturedUpdate = true;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              value ? 'تم تمييز العقار بنجاح.' : 'تم إلغاء تمييز العقار',
            ),
          ),
        );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      final raw = (error.message ?? '').toLowerCase();
      final exhausted = raw.contains('استنفذت') ||
          raw.contains('محاولات') ||
          raw.contains('featured') && raw.contains('limit');

      if (exhausted) {
        await _showUpgradeDialog(
          title: 'انتهت محاولات التمييز',
          message:
              'لا يمكن تمييز هذا العقار لأن جميع محاولات التمييز في باقتك الحالية قد استُنفدت. '
              'قم بترقية الباقة للحصول على محاولات إضافية',
        );
      } else {
        _showError(
          error.message?.isNotEmpty == true
              ? error.message!
              : 'تعذر تحديث حالة تمييز العقار. حاول مرة أخرى',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        'خطأ أثناء تحديث العقار:\n$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingPropertyId = null;
        });
      }
    }
  }

  Future<void> _editProperty(PropertyModel property) async {
    if (property.id.trim().isEmpty) {
      _showError('تعذر تحديد العقار.');
      return;
    }

    try {
      final data = await FirebaseFirestore.instance
          .collection('properties')
          .doc(property.id)
          .get();

      if (!data.exists || data.data() == null) {
        _showError('تعذر العثور على بيانات العقار.');
        return;
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditPropertyScreen(
            docId: property.id,
            data: data.data()!,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showError('تعذر فتح تعديل العقار: $error');
      }
    }
  }

  Future<void> _deleteProperty(String propertyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف العقار'),
            content: const Text(
              'هل أنت متأكد من حذف هذا العقار؟ لا يمكن التراجع بعد الحذف',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('تم حذف العقار بنجاح.')),
          );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        _showError(
          error.message?.isNotEmpty == true
              ? error.message!
              : 'تعذر حذف العقار',
        );
      }
    } catch (error) {
      if (mounted) {
        _showError('تعذر حذف العقار: $error');
      }
    }
  }

  Future<void> _showUpgradeDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmText),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }
}

class _PropertyTile extends StatelessWidget {
  const _PropertyTile({
    required this.property,
    required this.onFeature,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.featuredCount,
    required this.maxFeatured,
    required this.isProcessing,
  });

  final PropertyModel property;
  final VoidCallback onFeature;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int featuredCount;
  final int maxFeatured;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPublished =
        property.status == 'approved' || property.status == 'active';

    final title = property.title.trim().isEmpty
        ? 'عقار بدون عنوان'
        : property.title.trim();
    final location = [
      property.city.trim(),
      property.areaName.trim(),
    ].where((e) => e.isNotEmpty).join(' • ');

    final rawImage = property.imageUrl.trim();
    final defaultImage = PropertyDefaultImages.getImage(property.propertyType);
    final displayImage = rawImage.isNotEmpty ? rawImage : defaultImage;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: property.isFeatured
              ? scheme.primary.withValues(alpha: .42)
              : scheme.outlineVariant.withValues(alpha: .28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // قائمة إدارة العقار في أعلى البطاقة.
          SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'إدارة العقار',
                    padding: EdgeInsets.zero,
                    iconSize: 21,
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 19),
                            SizedBox(width: 9),
                            Text('تعديل'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 19),
                            SizedBox(width: 9),
                            Text('حذف'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 112,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PropertyImage(
                  image: displayImage,
                  defaultImage: defaultImage,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _StatusBadge(status: property.status),
                ),
                if (property.isFeatured)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 14),
                          SizedBox(width: 3),
                          Text(
                            'مميز',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 7,
                  right: 9,
                  left: 9,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          location.isEmpty ? 'الموقع غير محدد' : location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                      if (property.views > 0) ...[
                        const SizedBox(width: 7),
                        _OverlayInfo(
                          icon: Icons.visibility_rounded,
                          text: '${property.views}',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${property.price.toStringAsFixed(0)} د.ع',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        property.propertyType.isEmpty
                            ? 'عقار'
                            : property.propertyType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    if (property.rooms > 0)
                      _MiniInfo(
                          icon: Icons.bed_outlined,
                          text: '${property.rooms} غرف'),
                    if (property.area > 0) ...[
                      const SizedBox(width: 6),
                      _MiniInfo(
                        icon: Icons.square_foot_rounded,
                        text: '${property.area} م²',
                      ),
                    ],
                    const Spacer(),
                    if (maxFeatured > 0)
                      Text(
                        property.isFeatured
                            ? 'مميز حاليًا'
                            : 'المستهلك $featuredCount/$maxFeatured',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isProcessing ? null : onOpen,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'معاينة',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    if (isPublished) ...[
                      const SizedBox(width: 7),
                      Expanded(
                        child: FilledButton(
                          onPressed: isProcessing ? null : onFeature,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  property.isFeatured
                                      ? 'إلغاء التمييز'
                                      : 'تمييز',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyImage extends StatelessWidget {
  const _PropertyImage({
    required this.image,
    required this.defaultImage,
  });

  final String image;
  final String defaultImage;

  @override
  Widget build(BuildContext context) {
    if (image.startsWith('assets/')) {
      return Image.asset(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          defaultImage,
          fit: BoxFit.cover,
        ),
      );
    }

    return Image.network(
      image,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        defaultImage,
        fit: BoxFit.cover,
      ),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Image.asset(defaultImage, fit: BoxFit.cover),
    );
  }
}

class _OfficePropertiesSummary extends StatelessWidget {
  const _OfficePropertiesSummary({
    required this.total,
    required this.published,
    required this.pending,
    required this.featured,
    required this.used,
    required this.max,
  });

  final int total;
  final int published;
  final int pending;
  final int featured;
  final int used;
  final int max;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = max <= 0 ? -1 : (max - used).clamp(0, max);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.home_work_rounded,
                  label: 'الإجمالي',
                  value: total,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.check_circle_rounded,
                  label: 'منشور',
                  value: published,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.pending_rounded,
                  label: 'مراجعة',
                  value: pending,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.star_rounded,
                  label: 'مميز',
                  value: featured,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          if (max > 0) ...[
            const SizedBox(height: 8),
            _FeaturedQuota(
              used: used,
              max: max,
              remaining: remaining,
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: .14)
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: .55)
                  : scheme.outline.withValues(alpha: .12),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 3),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9.5,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value',
              maxLines: 1,
              style: const TextStyle(
                fontSize: 15,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedQuota extends StatelessWidget {
  const _FeaturedQuota({
    required this.used,
    required this.max,
    required this.remaining,
  });

  final int used;
  final int max;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: .14)),
      ),
      child: Row(
        children: [
          Icon(Icons.stars_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'رصيد التمييز',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'متبقٍ $remaining من $max',
                      style: TextStyle(
                        fontSize: 11,
                        color: remaining == 0 ? scheme.error : scheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumSearchField extends StatelessWidget {
  const _PremiumSearchField({
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.total,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final int total;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: Theme.of(context).cardColor,
          prefixIcon:
              Icon(Icons.search_rounded, color: scheme.primary, size: 19),
          suffixIcon: query.isEmpty
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(end: 14),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '$total',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
          hintText: 'ابحث باسم العقار أو الرقم أو المنطقة',
          hintStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: .35),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: scheme.primary.withValues(alpha: .70),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .38),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageProgress extends StatelessWidget {
  const _UsageProgress({
    required this.used,
    required this.max,
    required this.isFeatured,
  });

  final int used;
  final int max;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          isFeatured ? Icons.star_rounded : Icons.stars_outlined,
          size: 17,
          color: scheme.primary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            isFeatured
                ? 'العقار مميز حاليًا'
                : max > 0
                    ? 'المحاولات المستهلكة: $used من $max'
                    : 'المحاولات المستهلكة: $used',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isPublished = status == 'approved' || status == 'active';
    final isPending = status == 'pending';

    final color = isPublished
        ? Colors.green
        : isPending
            ? Colors.orange
            : Theme.of(context).colorScheme.error;

    final label = isPublished
        ? 'منشور'
        : isPending
            ? 'قيد المراجعة'
            : status == 'rejected'
                ? 'مرفوض'
                : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .52),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withValues(alpha: .65),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayInfo extends StatelessWidget {
  const _OverlayInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingNotice extends StatelessWidget {
  const _PendingNotice({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRejected = status == 'rejected';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: (isRejected ? scheme.error : Colors.orange).withValues(
          alpha: .08,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isRejected ? Icons.cancel_outlined : Icons.hourglass_empty_rounded,
            size: 19,
            color: isRejected ? scheme.error : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isRejected
                  ? 'العقار مرفوض ولا يمكن تمييزه حاليًا.'
                  : 'العقار قيد المراجعة ولا يمكن تمييزه حتى يتم نشره',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyStatus extends StatelessWidget {
  const _PropertyStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        status == 'approved' || status == 'active'
            ? 'منشور'
            : status == 'pending'
                ? 'قيد المراجعة'
                : status == 'rejected'
                    ? 'مرفوض'
                    : status,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: .30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.home_work_outlined,
                size: 38,
                color: scheme.primary.withValues(alpha: .72),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
