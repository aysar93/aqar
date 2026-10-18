import 'package:flutter/material.dart';

import '../../data/anbar_locations.dart';
import '../../models/statistics/statistics_filter.dart';
import '../../theme/statistics_text_styles.dart';

class StatisticsFilterSheet extends StatefulWidget {
  final StatisticsFilter initialFilter;

  const StatisticsFilterSheet({
    super.key,
    required this.initialFilter,
  });

  /// فتح نافذة الفلاتر وإرجاع الفلتر الجديد بعد الضغط على "تطبيق".
  static Future<StatisticsFilter?> show(
    BuildContext context, {
    required StatisticsFilter initialFilter,
  }) {
    return showModalBottomSheet<StatisticsFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatisticsFilterSheet(
          initialFilter: initialFilter,
        );
      },
    );
  }

  @override
  State<StatisticsFilterSheet> createState() => _StatisticsFilterSheetState();
}

class _StatisticsFilterSheetState extends State<StatisticsFilterSheet> {
  static const Color _background = Color(0xFF0F172A);
  static const Color _cardColor = Color(0xFF1E293B);
  static const Color _gold = Color(0xFFD4AF37);

  late String? _adType;
  late String? _propertyType;
  late String? _city;
  late String? _areaName;
  late StatisticsPeriod _period;

  static const List<String> _adTypes = [
    'للبيع',
    'للإيجار',
  ];

  static const List<String> _propertyTypes = [
    'بيت',
    'أرض',
    'شقة',
    'محل',
    'عمارة',
    'مزرعة',
  ];

  @override
  void initState() {
    super.initState();

    _adType = widget.initialFilter.adType;
    _propertyType = widget.initialFilter.propertyType;
    _city = AnbarLocations.normalizeCity(
      widget.initialFilter.city,
    );

    final initialArea = widget.initialFilter.areaName;

    if (_city != null && initialArea != null && initialArea.trim().isNotEmpty) {
      _areaName = AnbarLocations.normalizeArea(
        city: _city,
        area: initialArea,
      );

      if (_areaName!.isEmpty) {
        _areaName = null;
      }
    } else {
      _areaName = null;
    }

    _period = widget.initialFilter.period;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        top: mediaQuery.padding.top + 20,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            _buildTopHandle(),
            _buildHeader(),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(
                alpha: 0.06,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  20,
                  18,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(
                      icon: Icons.sell_outlined,
                      title: 'نوع الإعلان',
                    ),
                    const SizedBox(height: 10),
                    _buildChoiceWrap(
                      values: _adTypes,
                      selectedValue: _adType,
                      allLabel: 'الكل',
                      onChanged: (value) {
                        setState(() {
                          _adType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      icon: Icons.home_work_outlined,
                      title: 'نوع العقار',
                    ),
                    const SizedBox(height: 10),
                    _buildChoiceWrap(
                      values: _propertyTypes,
                      selectedValue: _propertyType,
                      allLabel: 'كل العقارات',
                      onChanged: (value) {
                        setState(() {
                          _propertyType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      icon: Icons.location_city_outlined,
                      title: 'المدينة',
                    ),
                    const SizedBox(height: 10),
                    _buildCitySelector(),
                    if (_city != null) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        icon: Icons.location_on_outlined,
                        title: 'المنطقة',
                      ),
                      const SizedBox(height: 10),
                      _buildAreaSelector(),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      icon: Icons.calendar_month_outlined,
                      title: 'الفترة الزمنية',
                    ),
                    const SizedBox(height: 10),
                    _buildPeriodSelector(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHandle() {
    return Padding(
      padding: const EdgeInsets.only(
        top: 10,
        bottom: 4,
      ),
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: 0.18,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        18,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _gold.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: _gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تصفية الإحصائيات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'خصص بيانات السوق التي تريد تحليلها',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.55,
                    ),
                    fontSize: StatisticsTextStyles.sectionSubtitleSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إغلاق',
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(
                alpha: 0.72,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: _gold,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: StatisticsTextStyles.cardTitleSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceWrap({
    required List<String> values,
    required String? selectedValue,
    required String allLabel,
    required ValueChanged<String?> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ChoiceItem(
          label: allLabel,
          selected: selectedValue == null,
          onTap: () => onChanged(null),
        ),
        ...values.map(
          (value) => _ChoiceItem(
            label: value,
            selected: selectedValue == value,
            onTap: () => onChanged(value),
          ),
        ),
      ],
    );
  }

  Widget _buildCitySelector() {
    return _DropdownContainer(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _city,
          isExpanded: true,
          dropdownColor: _cardColor,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _gold,
          ),
          hint: Text(
            'كل المدن',
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.72,
              ),
              fontSize: StatisticsTextStyles.cardTitleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: StatisticsTextStyles.cardTitleSize,
            fontWeight: FontWeight.w600,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('كل المدن'),
            ),
            ...AnbarLocations.cities.map(
              (city) => DropdownMenuItem<String?>(
                value: city,
                child: Text(city),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _city = value;

              // عند تغيير المدينة يجب إلغاء المنطقة
              // لأن المنطقة القديمة قد لا تتبع المدينة الجديدة.
              _areaName = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildAreaSelector() {
    final areas = AnbarLocations.areasForCity(
      _city,
    );

    final selectedArea =
        _areaName != null && areas.contains(_areaName) ? _areaName : null;

    return _DropdownContainer(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedArea,
          isExpanded: true,
          dropdownColor: _cardColor,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _gold,
          ),
          hint: Text(
            'كل المناطق',
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.72,
              ),
              fontSize: StatisticsTextStyles.cardTitleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: StatisticsTextStyles.cardTitleSize,
            fontWeight: FontWeight.w600,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('كل المناطق'),
            ),
            ...areas.map(
              (area) => DropdownMenuItem<String?>(
                value: area,
                child: Text(area),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _areaName = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Column(
      children: StatisticsPeriod.values.map(
        (period) {
          final selected = _period == period;

          return Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _period = period;
                  });
                },
                borderRadius: BorderRadius.circular(15),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color:
                        selected ? _gold.withValues(alpha: 0.10) : _cardColor,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: selected
                          ? _gold.withValues(alpha: 0.40)
                          : Colors.white.withValues(
                              alpha: 0.06,
                            ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? _gold
                                : Colors.white.withValues(
                                    alpha: 0.28,
                                  ),
                            width: 1.7,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: selected
                            ? Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: _gold,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          _periodLabel(period),
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(
                                    alpha: 0.75,
                                  ),
                            fontSize: StatisticsTextStyles.cardTitleSize,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_rounded,
                          color: _gold,
                          size: 19,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: _background,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(
              alpha: 0.06,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'تطبيق الفلاتر',
                  style: TextStyle(
                    fontSize: StatisticsTextStyles.cardTitleSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _resetFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(
                      alpha: 0.14,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'إعادة تعيين',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: StatisticsTextStyles.sectionSubtitleSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    Navigator.of(context).pop(
      StatisticsFilter(
        adType: _adType,
        propertyType: _propertyType,
        city: _city,
        areaName: _city == null ? null : _areaName,
        period: _period,
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _adType = null;
      _propertyType = null;
      _city = null;
      _areaName = null;
      _period = StatisticsPeriod.last30Days;
    });
  }

  String _periodLabel(
    StatisticsPeriod period,
  ) {
    switch (period) {
      case StatisticsPeriod.last7Days:
        return 'آخر 7 أيام';

      case StatisticsPeriod.last30Days:
        return 'آخر 30 يوم';

      case StatisticsPeriod.last90Days:
        return 'آخر 90 يوم';

      case StatisticsPeriod.last6Months:
        return 'آخر 6 أشهر';

      case StatisticsPeriod.lastYear:
        return 'آخر سنة';

      case StatisticsPeriod.allTime:
        return 'كل الوقت';
    }
  }
}

class _ChoiceItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cardColor = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected ? _gold.withValues(alpha: 0.12) : _cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? _gold.withValues(alpha: 0.38)
                  : Colors.white.withValues(
                      alpha: 0.06,
                    ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: _gold,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? _gold
                      : Colors.white.withValues(
                          alpha: 0.78,
                        ),
                  fontSize: StatisticsTextStyles.bodySize,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownContainer extends StatelessWidget {
  final Widget child;

  const _DropdownContainer({
    required this.child,
  });

  static const Color _cardColor = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),
      child: child,
    );
  }
}
