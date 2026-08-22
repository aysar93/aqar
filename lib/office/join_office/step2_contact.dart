import 'package:flutter/material.dart';

import '../models/join_office_data.dart';

class Step2Contact extends StatefulWidget {
  final JoinOfficeData data;
  final VoidCallback? onChanged;

  const Step2Contact({
    super.key,
    required this.data,
    this.onChanged,
  });

  @override
  State<Step2Contact> createState() => _Step2ContactState();
}

class _Step2ContactState extends State<Step2Contact> {
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;

  @override
  void initState() {
    super.initState();

    _phoneController = TextEditingController(
      text: widget.data.phone,
    );

    _whatsappController = TextEditingController(
      text: widget.data.whatsapp,
    );

    _emailController = TextEditingController(
      text: widget.data.email,
    );

    _websiteController = TextEditingController(
      text: widget.data.website,
    );

    _phoneController.addListener(_updateData);
    _whatsappController.addListener(_updateData);
    _emailController.addListener(_updateData);
    _websiteController.addListener(_updateData);
  }

  @override
  void dispose() {
    _phoneController
      ..removeListener(_updateData)
      ..dispose();

    _whatsappController
      ..removeListener(_updateData)
      ..dispose();

    _emailController
      ..removeListener(_updateData)
      ..dispose();

    _websiteController
      ..removeListener(_updateData)
      ..dispose();

    super.dispose();
  }

  void _updateData() {
    widget.data.phone = _phoneController.text.trim();

    widget.data.whatsapp = _whatsappController.text.trim();

    widget.data.email = _emailController.text.trim();

    widget.data.website = _websiteController.text.trim();

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
            _buildPhoneField(context),
            const SizedBox(height: 16),
            _buildWhatsappField(context),
            const SizedBox(height: 16),
            _buildEmailField(context),
            const SizedBox(height: 16),
            _buildWebsiteField(context),
            const SizedBox(height: 18),
            _buildHint(context),
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
          'معلومات التواصل',
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'أدخل وسائل التواصل التي يمكن للعملاء '
          'استخدامها للتواصل مع المكتب',
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return TextFormField(
      controller: _phoneController,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'رقم الهاتف',
        hintText: '07XXXXXXXXX',
        prefixIcon: const Icon(
          Icons.phone_outlined,
        ),
        filled: true,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(context),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'يرجى إدخال رقم الهاتف';
        }

        return null;
      },
    );
  }

  Widget _buildWhatsappField(BuildContext context) {
    return TextFormField(
      controller: _whatsappController,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'رقم واتساب',
        hintText: '07XXXXXXXXX',
        prefixIcon: const Icon(
          Icons.chat_outlined,
        ),
        filled: true,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(context),
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return TextFormField(
      controller: _emailController,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'البريد الإلكتروني',
        hintText: 'office@example.com',
        prefixIcon: const Icon(
          Icons.email_outlined,
        ),
        filled: true,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(context),
      ),
      validator: (value) {
        final email = value?.trim() ?? '';

        if (email.isEmpty) {
          return null;
        }

        if (!email.contains('@')) {
          return 'أدخل بريدًا إلكترونيًا صحيحًا';
        }

        return null;
      },
    );
  }

  Widget _buildWebsiteField(BuildContext context) {
    return TextFormField(
      controller: _websiteController,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'الموقع الإلكتروني',
        hintText: 'https://example.com',
        prefixIcon: const Icon(
          Icons.language_outlined,
        ),
        filled: true,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(context),
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

  Widget _buildHint(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
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
              'سيتم استخدام بيانات التواصل التي تدخلها '
              'لعرض وسائل التواصل الخاصة بالمكتب للعملاء',
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
}
