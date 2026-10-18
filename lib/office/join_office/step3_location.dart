import 'package:flutter/material.dart';

import '../models/join_office_data.dart';

class Step3Location extends StatefulWidget {
  final JoinOfficeData data;
  final VoidCallback? onChanged;

  const Step3Location({
    super.key,
    required this.data,
    this.onChanged,
  });

  @override
  State<Step3Location> createState() => _Step3LocationState();
}

class _Step3LocationState extends State<Step3Location> {
  late final TextEditingController _cityController;
  late final TextEditingController _districtController;
  late final TextEditingController _areaController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();

    _cityController = TextEditingController(
      text: widget.data.city,
    );

    _districtController = TextEditingController(
      text: widget.data.district,
    );

    _areaController = TextEditingController(
      text: widget.data.areaName,
    );

    _addressController = TextEditingController(
      text: widget.data.address,
    );

    _cityController.addListener(_updateData);
    _districtController.addListener(_updateData);
    _areaController.addListener(_updateData);
    _addressController.addListener(_updateData);
  }

  @override
  void dispose() {
    _cityController
      ..removeListener(_updateData)
      ..dispose();

    _districtController
      ..removeListener(_updateData)
      ..dispose();

    _areaController
      ..removeListener(_updateData)
      ..dispose();

    _addressController
      ..removeListener(_updateData)
      ..dispose();

    super.dispose();
  }

  void _updateData() {
    widget.data.city = _cityController.text.trim();

    widget.data.district = _districtController.text.trim();

    widget.data.areaName = _areaController.text.trim();

    widget.data.address = _addressController.text.trim();

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
            _buildCityField(context),
            const SizedBox(height: 16),
            _buildDistrictField(context),
            const SizedBox(height: 16),
            _buildAreaField(context),
            const SizedBox(height: 16),
            _buildAddressField(context),
            const SizedBox(height: 18),
            _buildMapHint(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'موقع المكتب',
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'حدد موقع المكتب بالتفصيل ليسهل على العملاء العثور عليه',
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  Widget _buildCityField(BuildContext context) {
    return TextFormField(
      controller: _cityController,
      textDirection: TextDirection.rtl,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'المحافظة / المدينة',
        hintText: 'مثال: الأنبار - الرمادي',
        prefixIcon: const Icon(
          Icons.location_city_outlined,
        ),
        filled: true,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(context),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال المحافظة أو المدينة';
        }

        return null;
      },
    );
  }

  Widget _buildDistrictField(BuildContext context) {
    return TextFormField(
      controller: _districtController,
      textDirection: TextDirection.rtl,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'القضاء / المنطقة',
        hintText: 'مثال: الرمادي',
        prefixIcon: const Icon(
          Icons.map_outlined,
        ),
        filled: true,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(context),
      ),
    );
  }

  Widget _buildAreaField(BuildContext context) {
    return TextFormField(
      controller: _areaController,
      textDirection: TextDirection.rtl,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'الحي / المنطقة',
        hintText: 'مثال: التأميم',
        prefixIcon: const Icon(
          Icons.place_outlined,
        ),
        filled: true,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(context),
      ),
    );
  }

  Widget _buildAddressField(BuildContext context) {
    return TextFormField(
      controller: _addressController,
      textDirection: TextDirection.rtl,
      textInputAction: TextInputAction.done,
      minLines: 2,
      maxLines: 4,
      maxLength: 250,
      decoration: InputDecoration(
        labelText: 'العنوان التفصيلي',
        hintText: 'أدخل عنوان المكتب بالتفصيل',
        alignLabelWithHint: true,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(
            bottom: 25,
          ),
          child: Icon(
            Icons.home_work_outlined,
          ),
        ),
        filled: true,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(context),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال عنوان المكتب';
        }

        return null;
      },
    );
  }

  Widget _buildMapHint(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 22,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'يمكن تحديد الإحداثيات لاحقًا من الخريطة. '
              'حاليًا تأكد من كتابة موقع المكتب بشكل واضح',
              textDirection: TextDirection.rtl,
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

  OutlineInputBorder _border() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    );
  }

  OutlineInputBorder _focusedBorder(
    BuildContext context,
  ) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.2,
      ),
    );
  }
}
