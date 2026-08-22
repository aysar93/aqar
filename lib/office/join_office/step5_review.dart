import 'package:flutter/material.dart';
import 'dart:io';
import '../models/join_office_data.dart';

class Step5Review extends StatelessWidget {
  final JoinOfficeData data;

  const Step5Review({
    super.key,
    required this.data,
  });

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
            _buildBasicInfo(context),
            const SizedBox(height: 14),
            _buildContactInfo(context),
            const SizedBox(height: 14),
            _buildLocationInfo(context),
            const SizedBox(height: 14),
            _buildDescriptionInfo(context),
            const SizedBox(height: 18),
            _buildFinalNotice(context),
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
          'مراجعة الطلب',
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'راجع بيانات المكتب قبل إرسال طلب الانضمام',
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  // =========================================================
  // معلومات المكتب
  // =========================================================

  Widget _buildBasicInfo(BuildContext context) {
    return _buildSection(
      context,
      title: 'معلومات المكتب',
      icon: Icons.business_rounded,
      children: [
        _buildInfoRow(
          context,
          label: 'اسم المكتب',
          value: _value(data.name),
          icon: Icons.business_outlined,
        ),

        // النبذة تظهر هنا للمراجعة فقط.
        // لا يوجد حقل إدخال لها في هذه الخطوة.
        _buildInfoRow(
          context,
          label: 'النبذة',
          value: _value(data.description),
          icon: Icons.description_outlined,
        ),
      ],
    );
  }

  // =========================================================
  // معلومات التواصل
  // =========================================================

  Widget _buildContactInfo(BuildContext context) {
    return _buildSection(
      context,
      title: 'معلومات التواصل',
      icon: Icons.contact_phone_outlined,
      children: [
        _buildInfoRow(
          context,
          label: 'الهاتف',
          value: _value(data.phone),
          icon: Icons.phone_outlined,
          direction: TextDirection.ltr,
        ),
        _buildInfoRow(
          context,
          label: 'واتساب',
          value: _value(data.whatsapp),
          icon: Icons.chat_outlined,
          direction: TextDirection.ltr,
        ),
        _buildInfoRow(
          context,
          label: 'البريد',
          value: _value(data.email),
          icon: Icons.email_outlined,
          direction: TextDirection.ltr,
        ),
        _buildInfoRow(
          context,
          label: 'الموقع الإلكتروني',
          value: _value(data.website),
          icon: Icons.language_outlined,
          direction: TextDirection.ltr,
        ),
      ],
    );
  }

  // =========================================================
  // موقع المكتب
  // =========================================================

  Widget _buildLocationInfo(BuildContext context) {
    return _buildSection(
      context,
      title: 'موقع المكتب',
      icon: Icons.location_on_outlined,
      children: [
        _buildInfoRow(
          context,
          label: 'المدينة',
          value: _value(data.city),
          icon: Icons.location_city_outlined,
        ),
        _buildInfoRow(
          context,
          label: 'القضاء / المنطقة',
          value: _value(data.district),
          icon: Icons.map_outlined,
        ),
        _buildInfoRow(
          context,
          label: 'الحي',
          value: _value(data.areaName),
          icon: Icons.place_outlined,
        ),
        _buildInfoRow(
          context,
          label: 'العنوان',
          value: _value(data.address),
          icon: Icons.home_work_outlined,
        ),
        if (data.latitude != 0 || data.longitude != 0)
          _buildInfoRow(
            context,
            label: 'الإحداثيات',
            value: '${data.latitude.toStringAsFixed(6)}, '
                '${data.longitude.toStringAsFixed(6)}',
            icon: Icons.gps_fixed_rounded,
            direction: TextDirection.ltr,
          ),
      ],
    );
  }

  // =========================================================
  // الخدمات والترخيص
  // =========================================================

  Widget _buildDescriptionInfo(BuildContext context) {
    return _buildSection(
      context,
      title: 'الخدمات والترخيص',
      icon: Icons.fact_check_outlined,
      children: [
        _buildInfoRow(
          context,
          label: 'الخدمات',
          value: data.services.isEmpty
              ? 'لم تتم إضافة خدمات'
              : data.services.join('، '),
          icon: Icons.home_repair_service_outlined,
        ),
        _buildInfoRow(
          context,
          label: 'رقم الترخيص',
          value: _value(data.licenseNumber),
          icon: Icons.badge_outlined,
          direction: TextDirection.ltr,
        ),
        if (data.establishedYear != null)
          _buildInfoRow(
            context,
            label: 'سنة التأسيس',
            value: data.establishedYear.toString(),
            icon: Icons.calendar_today_outlined,
          ),
        const SizedBox(height: 4),
        _buildLicenseImage(context),
      ],
    );
  }

  // =========================================================
  // صورة الترخيص
  // =========================================================

  Widget _buildLicenseImage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = data.licenseImageUrl.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.image_outlined,
              size: 19,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'صورة الترخيص',
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (imageUrl.isEmpty)
          _buildNoLicenseImage(context)
        else
          _buildLicenseImagePreview(
            context,
            imageUrl,
          ),
      ],
    );
  }

  // =========================================================
  // معاينة صورة الترخيص
  // =========================================================

  Widget _buildLicenseImagePreview(
    BuildContext context,
    String imageUrl,
  ) {
    final isNetworkImage =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          maxHeight: 260,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: isNetworkImage
            ? Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return _buildLicenseImageError(context);
                },
              )
            : Image.file(
                File(imageUrl),
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return _buildLicenseImageError(context);
                },
              ),
      ),
    );
  }

  // =========================================================
  // لا توجد صورة
  // =========================================================

  Widget _buildNoLicenseImage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 42,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'لم تتم إضافة صورة الترخيص',
            textDirection: TextDirection.rtl,
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
  // خطأ تحميل الصورة
  // =========================================================

  Widget _buildLicenseImageError(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              'تعذر تحميل صورة الترخيص',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // القسم
  // =========================================================

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // =========================================================
  // صف معلومات
  // =========================================================

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    TextDirection direction = TextDirection.rtl,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 95,
            child: Text(
              label,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textDirection: direction,
              textAlign: TextAlign.right,
              style: const TextStyle(
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // التنبيه النهائي
  // =========================================================

  Widget _buildFinalNotice(
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 23,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'بعد إرسال الطلب، سيتم مراجعته من قبل '
              'إدارة التطبيق. ستظهر حالة الطلب في حسابك '
              'حتى يتم اتخاذ القرار',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // قيمة افتراضية
  // =========================================================

  String _value(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'غير مضاف';
    }

    return trimmed;
  }
}
