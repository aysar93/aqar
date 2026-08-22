import 'package:flutter/material.dart';

import '../models/office_model.dart';
import '../services/office_service.dart';
import '../widgets/office_card.dart';
import 'office_profile_screen.dart';

class OfficesScreen extends StatefulWidget {
  const OfficesScreen({super.key});

  @override
  State<OfficesScreen> createState() => _OfficesScreenState();
}

class _OfficesScreenState extends State<OfficesScreen> {
  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  bool _matchesSearch(
    OfficeModel office,
    String query,
  ) {
    if (query.isEmpty) {
      return true;
    }

    final values = <String>[
      office.name,
      office.city,
      office.district,
      office.areaName,
      office.description,
    ];

    return values.any(
      (value) => value.toLowerCase().contains(query),
    );
  }

  void _onSearchChanged(String value) {
    _searchQuery.value = value.trim().toLowerCase();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery.value = '';

    // يبقى الكيبورد مفتوحًا بعد مسح البحث.
    if (!_searchFocusNode.hasFocus) {
      _searchFocusNode.requestFocus();
    }
  }

  void _openOffice(
    BuildContext context,
    OfficeModel office,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficeProfileScreen(
          officeId: office.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0F172A);
    const cardColor = Color(0xFF1E293B);
    const goldColor = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'المكاتب العقارية',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<OfficeModel>>(
        stream: OfficeService.approvedOffices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: goldColor,
              ),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: 'حدث خطأ أثناء تحميل المكاتب',
              onRetry: () {
                setState(() {});
              },
            );
          }

          final offices = snapshot.data ?? [];

          return RefreshIndicator(
            color: goldColor,
            backgroundColor: cardColor,
            onRefresh: () async {
              setState(() {});
            },
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      8,
                    ),
                    child: _buildHeader(goldColor),
                  ),
                ),

                // مهم:
                // حقل البحث خارج ValueListenableBuilder.
                // لذلك لن تتم إعادة إنشائه عند كل حرف.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      14,
                    ),
                    child: _SearchField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      goldColor: goldColor,
                      cardColor: cardColor,
                      onChanged: _onSearchChanged,
                      onClear: _clearSearch,
                    ),
                  ),
                ),

                // النتائج فقط تتغير أثناء البحث.
                ValueListenableBuilder<String>(
                  valueListenable: _searchQuery,
                  builder: (
                    context,
                    query,
                    child,
                  ) {
                    final filteredOffices = offices
                        .where(
                          (office) => _matchesSearch(
                            office,
                            query,
                          ),
                        )
                        .toList();

                    if (filteredOffices.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyOfficesView(
                          searchQuery: query,
                          goldColor: goldColor,
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        24,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final office = filteredOffices[index];

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: 14,
                              ),
                              child: OfficeCard(
                                office: office,
                                onTap: () {
                                  _openOffice(
                                    context,
                                    office,
                                  );
                                },
                              ),
                            );
                          },
                          childCount: filteredOffices.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Color goldColor) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: goldColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: goldColor.withValues(alpha: 0.20),
            ),
          ),
          child: Icon(
            Icons.business_rounded,
            color: goldColor,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المكاتب العقارية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'اكتشف المكاتب العقارية المعتمدة',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color goldColor;
  final Color cardColor;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.goldColor,
    required this.cardColor,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (
        context,
        value,
        child,
      ) {
        final hasText = value.text.isNotEmpty;

        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textDirection: TextDirection.rtl,
          textInputAction: TextInputAction.search,
          keyboardType: TextInputType.text,
          style: const TextStyle(
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: 'ابحث عن مكتب، مدينة أو منطقة',
            hintTextDirection: TextDirection.rtl,
            hintStyle: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.white60,
            ),
            suffixIcon: hasText
                ? IconButton(
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white60,
                    ),
                  )
                : null,
            filled: true,
            fillColor: cardColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: goldColor.withValues(alpha: 0.60),
                width: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyOfficesView extends StatelessWidget {
  final String searchQuery;
  final Color goldColor;

  const _EmptyOfficesView({
    required this.searchQuery,
    required this.goldColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasSearch = searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch ? Icons.search_off_rounded : Icons.business_outlined,
                color: goldColor,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch ? 'لا توجد نتائج' : 'لا توجد مكاتب متاحة حاليًا',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'جرّب البحث باسم مكتب أو مدينة أخرى'
                  : 'ستظهر هنا المكاتب العقارية المعتمدة',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text(
                'إعادة المحاولة',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
