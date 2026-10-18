import '../../core/data/paged_query.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'widgets/property_card.dart';
import 'widgets/search_bar_widget.dart';

class PropertyManagementScreen extends StatefulWidget {
  const PropertyManagementScreen({super.key});

  @override
  State<PropertyManagementScreen> createState() =>
      _PropertyManagementScreenState();
}

class _PropertyManagementScreenState extends State<PropertyManagementScreen> {
  final TextEditingController searchController = TextEditingController();

  static const int _pageSize = 10;

  late final Query<Map<String, dynamic>> _completeQuery;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _properties;
  PagedQueryController<Map<String, dynamic>>? _page;
  Map<String, int>? _counts;
  bool _countLoading = false;
  bool _countAgain = false;
  String? _membership;
  @override
  void initState() {
    super.initState();
    _completeQuery = FirebaseFirestore.instance
        .collection('properties')
        .orderBy('createdAt', descending: true);
    _properties = _completeQuery.snapshots();
    _configurePage();
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    if (_countLoading) {
      _countAgain = true;
      return;
    }
    _countLoading = true;
    try {
      final statuses = ['total', 'approved', 'pending', 'rejected'];
      final counts = await Future.wait(statuses.map((status) =>
          (status == 'total'
                  ? _completeQuery
                  : _completeQuery.where('status', isEqualTo: status))
              .count()
              .get()));
      if (mounted) {
        setState(() => _counts = {
              for (var i = 0; i < statuses.length; i++)
                statuses[i]: counts[i].count ?? 0
            });
      }
    } catch (e) {
      debugPrint('Admin properties summary: $e');
    } finally {
      _countLoading = false;
      if (_countAgain && mounted) {
        _countAgain = false;
        _refreshCounts();
      }
    }
  }

  void _pageChanged() {
    if (!mounted) return;
    final signature = _page?.headDocuments
        .map((d) => '${d.id}:${d.data()['status']}')
        .join('|');
    if (_membership != null && _membership != signature) _refreshCounts();
    _membership = signature;
    setState(() {});
  }

  void _configurePage() {
    if (_search.isNotEmpty) {
      _page?.dispose();
      _page = null;
      return;
    }
    var query = _completeQuery;
    final status = _statusForFilter(_selectedFilter);
    if (status != null) query = query.where('status', isEqualTo: status);
    if (_page?.query == query) return;
    _page?.dispose();
    _membership = null;
    _page = PagedQueryController(query, pageSize: _pageSize)
      ..addListener(_pageChanged)
      ..start();
  }

  Widget _propertiesBuilder(
          Widget Function(BuildContext,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>)
              builder) =>
      _page == null
          ? StreamBuilder(stream: _properties, builder: builder)
          : builder(context, _page!.snapshot);
  String _search = '';
  String _selectedFilter = 'الكل';
  int _visibleCount = _pageSize;

  @override
  void dispose() {
    _page?.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _changeSearch(String value) {
    setState(() {
      _search = value.trim();
      _configurePage();
      _visibleCount = _pageSize;
    });
  }

  void _changeFilter(String value) {
    setState(() {
      _selectedFilter = value;
      _configurePage();
      _visibleCount = _pageSize;
    });
  }

  void _showMore() {
    setState(() {
      _visibleCount += _pageSize;
      _page?.loadMore();
    });
  }

  String? _statusForFilter(String filter) {
    switch (filter) {
      case 'منشور':
        return 'approved';
      case 'قيد المراجعة':
        return 'pending';
      case 'مرفوض':
        return 'rejected';
      default:
        return null;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final status = _statusForFilter(_selectedFilter);
    final query = _normalize(_search);

    final result = docs.where((doc) {
      final data = doc.data();

      if (status != null &&
          data['status']?.toString().toLowerCase() != status) {
        return false;
      }

      if (query.isEmpty) return true;

      final title = _normalize(
        data['title']?.toString() ?? '',
      );
      final city = _normalize(
        data['city']?.toString() ?? '',
      );
      final district = _normalize(
        data['district']?.toString() ?? '',
      );
      final area = _normalize(
        data['areaName']?.toString() ?? '',
      );
      final adNumber = _normalize(
        data['adNumber']?.toString() ??
            data['propertyNumber']?.toString() ??
            '',
      );

      return title.contains(query) ||
          city.contains(query) ||
          district.contains(query) ||
          area.contains(query) ||
          adNumber.contains(query);
    }).toList();

    return result;
  }

  String _normalize(String value) {
    var result = value.trim().toLowerCase();

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

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 900
        ? 28.0
        : width >= 600
            ? 20.0
            : 14.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xff0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xff0F172A),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: const Text(
            'إدارة العقارات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: _propertiesBuilder(
          (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(
                message: 'تعذر تحميل العقارات حاليًا',
                onRetry: () => setState(() {}),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final allDocs = snapshot.data?.docs ?? [];
            final docs = _filterDocs(allDocs);

            final visibleDocs = docs.take(_visibleCount).toList();
            final hasMore =
                (_page?.hasMore ?? false) || visibleDocs.length < docs.length;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      0,
                    ),
                    child: Column(
                      children: [
                        _HeaderSummary(
                          total: _counts?['total'],
                          shown: _page == null
                              ? docs.length
                              : (_counts?[_statusForFilter(_selectedFilter) ??
                                      'total'] ??
                                  docs.length),
                          documents: allDocs,
                          counters: _counts,
                        ),
                        const SizedBox(height: 12),
                        SearchBarWidget(
                          controller: searchController,
                          hintText:
                              'ابحث باسم العقار أو المدينة أو رقم الإعلان',
                          onChanged: _changeSearch,
                        ),
                        const SizedBox(height: 12),
                        _ResponsiveFilters(
                          selected: _selectedFilter,
                          onChanged: _changeFilter,
                        ),
                      ],
                    ),
                  ),
                ),
                if (docs.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      10,
                      horizontalPadding,
                      0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final document = visibleDocs[index];

                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 7,
                            ),
                            child: _CompactPropertyCard(
                              document: document,
                            ),
                          );
                        },
                        childCount: visibleDocs.length,
                      ),
                    ),
                  ),
                if (docs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _LoadMoreSection(
                      shown: visibleDocs.length,
                      total: _page == null
                          ? docs.length
                          : (_counts?[_statusForFilter(_selectedFilter) ??
                                  'total'] ??
                              docs.length),
                      hasMore: hasMore,
                      onPressed: _showMore,
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompactPropertyCard extends StatelessWidget {
  const _CompactPropertyCard({
    required this.document,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PropertyCard(document: document),
    );
  }
}

class _ResponsiveFilters extends StatelessWidget {
  const _ResponsiveFilters({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  static const filters = [
    'الكل',
    'منشور',
    'قيد المراجعة',
    'مرفوض',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 12) / 4;

          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: filters.map((filter) {
              final isSelected = filter == selected;

              return SizedBox(
                width: itemWidth.clamp(68.0, 180.0),
                child: Material(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: () => onChanged(filter),
                    borderRadius: BorderRadius.circular(11),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                      child: Text(
                        filter,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: .72),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  const _HeaderSummary({
    required this.total,
    required this.shown,
    required this.documents,
    this.counters,
  });

  final int? total;
  final int shown;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents;

  final Map<String, int>? counters;
  int? _count(String status) {
    if (total == null) return null;
    if (counters != null) return counters![status];
    return documents.where((doc) {
      return doc.data()['status']?.toString().toLowerCase() == status;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final published = _count('approved');
    final pending = _count('pending');
    final rejected = _count('rejected');

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xff1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: .05),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.home_work_outlined,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'إدارة العقارات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                total == null
                    ? '—'
                    : shown == total
                        ? '$total عقار'
                        : '$shown من $total',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .55),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.apps_rounded,
                label: 'الإجمالي',
                value: total,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _MiniStat(
                icon: Icons.check_circle_outline_rounded,
                label: 'منشور',
                value: published,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _MiniStat(
                icon: Icons.pending_outlined,
                label: 'مراجعة',
                value: pending,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _MiniStat(
                icon: Icons.cancel_outlined,
                label: 'مرفوض',
                value: rejected,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: .045),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .58),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value?.toString() ?? '—',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreSection extends StatelessWidget {
  const _LoadMoreSection({
    required this.shown,
    required this.total,
    required this.hasMore,
    required this.onPressed,
  });

  final int shown;
  final int? total;
  final bool hasMore;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 4,
        ),
        child: Text(
          'تم عرض جميع العقارات',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .45),
            fontSize: 11,
          ),
        ),
      );
    }

    final remaining = (total ?? shown) - shown;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        4,
        14,
        8,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(
            Icons.expand_more_rounded,
            size: 20,
          ),
          label: Text(
            'عرض المزيد  •  متبقٍ $remaining',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            side: BorderSide(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: .45),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_work_outlined,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'لا توجد عقارات',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'جرّب تغيير الفلتر أو تعديل عبارة البحث',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .55),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: Colors.white54,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
