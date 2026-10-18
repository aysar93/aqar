import 'package:flutter/material.dart';

import '../models/join_office_data.dart';

class Step4Description extends StatefulWidget {
  final JoinOfficeData data;
  final VoidCallback? onChanged;

  const Step4Description({
    super.key,
    required this.data,
    this.onChanged,
  });

  @override
  State<Step4Description> createState() => _Step4DescriptionState();
}

class _Step4DescriptionState extends State<Step4Description> {
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();

    _descriptionController = TextEditingController(
      text: widget.data.description,
    );

    _descriptionController.addListener(_updateData);
  }

  @override
  void dispose() {
    _descriptionController
      ..removeListener(_updateData)
      ..dispose();

    super.dispose();
  }

  void _updateData() {
    widget.data.description = _descriptionController.text.trim();

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
            _buildDescriptionField(context),
            const SizedBox(height: 18),
            _buildSuggestions(context),
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
          'وصف المكتب',
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'اكتب نبذة واضحة ومختصرة عن المكتب وخبرته '
          'والخدمات العقارية التي يقدمها',
          textDirection: TextDirection.rtl,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField(
    BuildContext context,
  ) {
    return TextFormField(
      controller: _descriptionController,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      textInputAction: TextInputAction.newline,
      minLines: 8,
      maxLines: 12,
      maxLength: 1500,
      decoration: InputDecoration(
        labelText: 'نبذة عن المكتب',
        hintText: 'مثال:\n'
            'مكتب عقاري متخصص في بيع وشراء وتأجير '
            'العقارات، ونقدم خدمات عقارية موثوقة '
            'لعملائنا',
        alignLabelWithHint: true,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(
            bottom: 125,
          ),
          child: Icon(
            Icons.description_outlined,
          ),
        ),
        filled: true,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(context),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';

        if (text.isEmpty) {
          return 'يرجى كتابة وصف المكتب';
        }

        if (text.length < 20) {
          return 'يفضل أن يكون الوصف أكثر تفصيلًا';
        }

        return null;
      },
    );
  }

  Widget _buildSuggestions(
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    const suggestions = [
      'خبرة المكتب في المجال العقاري',
      'أنواع العقارات التي يتعامل بها المكتب',
      'الخدمات التي يقدمها للعملاء',
      'المناطق التي يغطيها المكتب',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 21,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'نصائح لكتابة وصف جيد',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(
                bottom: 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
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
