import 'package:flutter/material.dart';

import '../models/office_model.dart';
import 'office_subscription_badge.dart';
import 'office_verified_badge.dart';

/// رأس صفحة المكتب.
///
/// يعرض:
/// - صورة المكتب.
/// - اسم المكتب.
/// - الشارة الموثقة.
/// - حالة الاشتراك.
/// - الوصف المختصر.
/// - عدد العقارات.
/// - عدد المتابعين.
/// - متوسط التقييم.
class OfficeHeader extends StatelessWidget {
  final OfficeModel office;

  /// عند الضغط على صورة المكتب.
  final VoidCallback? onImageTap;

  /// عند الضغط على زر المتابعة.
  final VoidCallback? onFollowTap;

  /// هل المستخدم يتابع المكتب حاليًا؟
  final bool isFollowing;

  /// هل يمكن للمستخدم متابعة المكتب؟
  final bool canFollow;

  const OfficeHeader({
    super.key,
    required this.office,
    this.onImageTap,
    this.onFollowTap,
    this.isFollowing = false,
    this.canFollow = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        18,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          _buildTopSection(
            context,
          ),
          const SizedBox(height: 18),
          _buildOfficeName(
            context,
          ),
          const SizedBox(height: 8),
          if (_description.isNotEmpty)
            _buildDescription(
              context,
            ),
          const SizedBox(height: 18),
          _buildStatistics(
            context,
          ),
          if (canFollow) ...[
            const SizedBox(height: 18),
            _buildFollowButton(
              context,
            ),
          ],
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // القسم العلوي
  // ═════════════════════════════════════════════

  Widget _buildTopSection(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOfficeImage(
          context,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (_isVerified) const OfficeVerifiedBadge(),
                  OfficeSubscriptionBadge(
                    office: office,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_location.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // صورة المكتب
  // ═════════════════════════════════════════════

  Widget _buildOfficeImage(
    BuildContext context,
  ) {
    final imageUrl = _imageUrl;

    return GestureDetector(
      onTap: onImageTap,
      child: Hero(
        tag: 'office_image_${office.id}',
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFD4AF37),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.18,
                ),
                blurRadius: 12,
                offset: const Offset(
                  0,
                  5,
                ),
              ),
            ],
          ),
          child: ClipOval(
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return _buildImagePlaceholder(
                        context,
                      );
                    },
                    loadingBuilder: (
                      context,
                      child,
                      loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return _buildImageLoading(
                        context,
                      );
                    },
                  )
                : _buildImagePlaceholder(
                    context,
                  ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // Placeholder الصورة
  // ═════════════════════════════════════════════

  Widget _buildImagePlaceholder(
    BuildContext context,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.business_rounded,
        size: 42,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ═════════════════════════════════════════════
  // تحميل الصورة
  // ═════════════════════════════════════════════

  Widget _buildImageLoading(
    BuildContext context,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // اسم المكتب
  // ═════════════════════════════════════════════

  Widget _buildOfficeName(
    BuildContext context,
  ) {
    return Text(
      _officeName,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Color(0xFFD4AF37),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // الوصف
  // ═════════════════════════════════════════════

  Widget _buildDescription(
    BuildContext context,
  ) {
    return Text(
      _description,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        height: 1.6,
        fontSize: 13.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ═════════════════════════════════════════════
  // الإحصائيات
  // ═════════════════════════════════════════════

  Widget _buildStatistics(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatisticItem(
              context,
              icon: Icons.home_work_outlined,
              value: _propertiesCount.toString(),
              label: 'عقار',
            ),
          ),
          _buildDivider(context),
          Expanded(
            child: _buildStatisticItem(
              context,
              icon: Icons.people_outline_rounded,
              value: _followersCount.toString(),
              label: 'متابع',
            ),
          ),
          _buildDivider(context),
          Expanded(
            child: _buildStatisticItem(
              context,
              icon: Icons.star_rounded,
              value: _ratingText,
              label: 'التقييم',
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════
  // عنصر إحصائية
  // ═════════════════════════════════════════════

  Widget _buildStatisticItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFD4AF37),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════
  // فاصل الإحصائيات
  // ═════════════════════════════════════════════

  Widget _buildDivider(
    BuildContext context,
  ) {
    return Container(
      width: 1,
      height: 38,
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }

  // ═════════════════════════════════════════════
  // زر المتابعة
  // ═════════════════════════════════════════════

  Widget _buildFollowButton(
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onFollowTap,
        icon: Icon(
          isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
          size: 20,
        ),
        label: Text(
          isFollowing ? 'متابَع' : 'متابعة المكتب',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isFollowing ? colorScheme.onSurface : const Color(0xFFD4AF37),
          side: BorderSide(
            color: isFollowing ? colorScheme.outline : const Color(0xFFD4AF37),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════
  // البيانات
  //
  // هذه getters تستخدم أسماء شائعة في OfficeModel.
  // إذا كانت أسماء الحقول في النموذج الأساسي مختلفة،
  // سنطابقها في مرحلة ربط النماذج.
  // ═════════════════════════════════════════════

  String get _officeName {
    return _stringValue(
      _readValue(
        'name',
      ),
    ).isNotEmpty
        ? _stringValue(
            _readValue('name'),
          )
        : _stringValue(
            _readValue('officeName'),
          );
  }

  String get _description {
    return _stringValue(
      _readValue('description'),
    );
  }

  String get _imageUrl {
    final value = _readValue('imageUrl');

    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }

    final logo = _readValue('logoUrl');

    return logo?.toString().trim() ?? '';
  }

  String get _location {
    final city = _stringValue(
      _readValue('city'),
    );

    final area = _stringValue(
      _readValue('areaName'),
    );

    if (city.isNotEmpty && area.isNotEmpty) {
      return '$city - $area';
    }

    if (city.isNotEmpty) {
      return city;
    }

    return area;
  }

  bool get _isVerified {
    final value = _readValue(
      'isVerified',
    );

    return value == true;
  }

  int get _propertiesCount {
    return _intValue(
      _readValue('propertiesCount'),
    );
  }

  int get _followersCount {
    return _intValue(
      _readValue('followersCount'),
    );
  }

  String get _ratingText {
    final rating = _doubleValue(
      _readValue('rating'),
    );

    if (rating <= 0) {
      return '—';
    }

    return rating.toStringAsFixed(1);
  }

  dynamic _readValue(
    String field,
  ) {
    final dynamic value = office;

    try {
      if (field == 'name') {
        return office.name;
      }

      if (field == 'description') {
        return office.description;
      }

      if (field == 'logoUrl') {
        return office.logoUrl;
      }

      if (field == 'city') {
        return office.city;
      }

      if (field == 'areaName') {
        return office.areaName;
      }

      if (field == 'isVerified') {
        return office.isVerified;
      }

      if (field == 'propertiesCount') {
        return office.propertiesCount;
      }

      if (field == 'followersCount') {
        return office.followersCount;
      }

      if (field == 'rating') {
        return office.rating;
      }
    } catch (_) {
      return null;
    }

    return value;
  }

  String _stringValue(
    dynamic value,
  ) {
    return value?.toString().trim() ?? '';
  }

  int _intValue(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  double _doubleValue(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}
