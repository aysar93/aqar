import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../banners/banner_model.dart';
import '../../banners/banner_service.dart';
import 'add_banner_screen.dart';

class BannerManagementScreen extends StatelessWidget {
  const BannerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة البنرات'),
          centerTitle: true,
        ),
        body: StreamBuilder<List<BannerModel>>(
          stream: BannerService.banners(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return const _EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'تعذر تحميل البنرات',
                subtitle: 'تحقق من الاتصال وحاول مرة أخرى',
              );
            }

            final banners = snapshot.data ?? const <BannerModel>[];

            if (banners.isEmpty) {
              return const _EmptyState(
                icon: Icons.campaign_outlined,
                title: 'لا توجد بنرات',
                subtitle: 'أضف أول بنر ليظهر في التطبيق',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                100,
              ),
              itemCount: banners.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _BannerManagementCard(
                  banner: banners[index],
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AddBannerScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة بنر'),
        ),
      ),
    );
  }
}

class _BannerManagementCard extends StatelessWidget {
  const _BannerManagementCard({
    required this.banner,
  });

  final BannerModel banner;

  Color _statusColor(BuildContext context) {
    return banner.isActive
        ? Colors.green
        : Theme.of(context).colorScheme.outline;
  }

  String _typeLabel() {
    switch (banner.type) {
      case 'office':
        return 'مكتب';
      case 'external':
        return 'رابط خارجي';
      case 'property':
      default:
        return 'عقار';
    }
  }

  IconData _typeIcon() {
    switch (banner.type) {
      case 'office':
        return Icons.business_outlined;
      case 'external':
        return Icons.open_in_new_rounded;
      case 'property':
      default:
        return Icons.home_work_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                banner.imageUrl,
                width: 96,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    width: 96,
                    height: 76,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          banner.title.isEmpty
                              ? 'بنر بدون عنوان'
                              : banner.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _StatusBadge(
                        active: banner.isActive,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        _typeIcon(),
                        size: 16,
                        color: primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _typeLabel(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'الترتيب ${banner.order}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  if (banner.type == 'property' || banner.type == 'office')
                    _TargetName(
                      type: banner.type,
                      targetId: banner.targetId,
                    )
                  else
                    _ExternalTarget(
                      targetId: banner.targetId,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        banner.isActive
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        size: 16,
                        color: _statusColor(context),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        banner.isActive ? 'يظهر للمستخدمين' : 'متوقف مؤقتًا',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _BannerMenu(
              banner: banner,
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetName extends StatelessWidget {
  const _TargetName({
    required this.type,
    required this.targetId,
  });

  final String type;
  final String targetId;

  @override
  Widget build(BuildContext context) {
    if (targetId.trim().isEmpty) {
      return const _TargetLine(
        icon: Icons.link_off_rounded,
        text: 'لم يتم تحديد الوجهة',
        muted: true,
      );
    }

    final collection = type == 'office' ? 'offices' : 'properties';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection(collection).doc(targetId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TargetLine(
            icon: Icons.sync_rounded,
            text: 'جاري تحميل الوجهة',
            muted: true,
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return _TargetLine(
            icon: Icons.warning_amber_rounded,
            text: type == 'office'
                ? 'المكتب المرتبط غير موجود'
                : 'العقار المرتبط غير موجود',
            muted: true,
          );
        }

        final data = snapshot.data!.data() ?? {};

        String value;
        String? secondary;

        if (type == 'office') {
          value = _firstText(
            data,
            const ['name', 'officeName', 'title'],
            fallback: 'مكتب بدون اسم',
          );

          secondary = _joinLocation(
            data['city'],
            data['areaName'],
          );
        } else {
          value = _firstText(
            data,
            const ['title'],
            fallback: 'عقار بدون عنوان',
          );

          final number = data['propertyNumber']?.toString().trim();

          secondary = _joinValues([
            if (number != null && number.isNotEmpty) 'رقم الإعلان: $number',
            _joinLocation(
              data['city'],
              data['areaName'],
            ),
          ]);
        }

        return _TargetLine(
          icon: type == 'office'
              ? Icons.business_outlined
              : Icons.home_work_outlined,
          text: value,
          secondary: secondary,
        );
      },
    );
  }

  static String _firstText(
    Map<String, dynamic> data,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  static String? _joinLocation(
    dynamic city,
    dynamic area,
  ) {
    return _joinValues([
      city?.toString().trim() ?? '',
      area?.toString().trim() ?? '',
    ]);
  }

  static String? _joinValues(
    List<String?> values,
  ) {
    final filtered = values
        .where(
          (value) => value != null && value.trim().isNotEmpty,
        )
        .map((value) => value!.trim())
        .toList();

    if (filtered.isEmpty) return null;

    return filtered.join(' • ');
  }
}

class _ExternalTarget extends StatelessWidget {
  const _ExternalTarget({
    required this.targetId,
  });

  final String targetId;

  @override
  Widget build(BuildContext context) {
    return _TargetLine(
      icon: Icons.link_rounded,
      text: targetId.isEmpty ? 'لم يتم تحديد الرابط' : targetId,
      muted: targetId.isEmpty,
    );
  }
}

class _TargetLine extends StatelessWidget {
  const _TargetLine({
    required this.icon,
    required this.text,
    this.secondary,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final String? secondary;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: muted
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
              if (secondary != null && secondary!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    secondary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.active,
  });

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'مفعل' : 'متوقف',
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BannerMenu extends StatelessWidget {
  const _BannerMenu({
    required this.banner,
  });

  final BannerModel banner;

  Future<void> _toggle(BuildContext context) async {
    try {
      await BannerService.update(
        banner.id,
        {
          'isActive': !banner.isActive,
        },
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              banner.isActive ? 'تم إيقاف البنر.' : 'تم تفعيل البنر',
            ),
          ),
        );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'تعذر تحديث البنر: $error',
            ),
          ),
        );
    }
  }

  Future<void> _edit(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBannerScreen(
          banner: banner,
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف البنر'),
          content: Text(
            'هل تريد حذف بنر "${banner.title}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await BannerService.delete(banner.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('تم حذف البنر بنجاح.'),
          ),
        );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'تعذر حذف البنر: $error',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'خيارات البنر',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        switch (value) {
          case 'toggle':
            _toggle(context);
            break;
          case 'edit':
            _edit(context);
            break;
          case 'delete':
            _delete(context);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'toggle',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              banner.isActive
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            title: Text(
              banner.isActive ? 'إيقاف البنر' : 'تفعيل البنر',
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('تعديل البنر'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Colors.red,
            ),
            title: Text('حذف البنر'),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: .10),
              ),
              child: Icon(
                icon,
                size: 32,
                color: primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
