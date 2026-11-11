import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'booking_admin_theme.dart';
import 'tabs/booking_admin_overview_tab.dart';
import 'tabs/booking_admin_bookings_tab.dart';
import 'tabs/booking_admin_venues_tab.dart';
import 'tabs/booking_admin_reels_tab.dart';
import 'tabs/booking_admin_payments_tab.dart';
import 'tabs/booking_admin_reports_tab.dart';
import 'tabs/booking_admin_audit_tab.dart';

class BookingAdminDashboardScreen extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? bookingsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? venuesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? reelsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? reportsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? auditStream;

  const BookingAdminDashboardScreen({
    super.key,
    this.bookingsStream,
    this.venuesStream,
    this.reelsStream,
    this.reportsStream,
    this.auditStream,
  });

  @override
  State<BookingAdminDashboardScreen> createState() => _BookingAdminDashboardScreenState();
}

class _BookingAdminDashboardScreenState extends State<BookingAdminDashboardScreen> {
  int _currentTabIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _pillScrollController = ScrollController();
  final List<GlobalKey> _tabKeys = List.generate(7, (_) => GlobalKey());

  final List<Map<String, dynamic>> _tabs = const [
    {
      'title': 'الرئيسية والإحصائيات',
      'icon': Icons.dashboard_outlined,
      'badgeKey': 'overview',
    },
    {
      'title': 'إدارة الحجوزات',
      'icon': Icons.calendar_month_outlined,
      'badgeKey': 'bookings',
    },
    {
      'title': 'إدارة الأماكن',
      'icon': Icons.villa_outlined,
      'badgeKey': 'venues',
    },
    {
      'title': 'إدارة ريلز الحجوزات',
      'icon': Icons.video_library_outlined,
      'badgeKey': 'reels',
    },
    {
      'title': 'إدارة المدفوعات',
      'icon': Icons.account_balance_wallet_outlined,
      'badgeKey': 'payments',
    },
    {
      'title': 'التقارير والتحليل',
      'icon': Icons.bar_chart_outlined,
      'badgeKey': 'reports',
    },
    {
      'title': 'الصلاحيات وسجل العمليات',
      'icon': Icons.shield_outlined,
      'badgeKey': 'audit',
    },
  ];

  @override
  void dispose() {
    _pillScrollController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() => _currentTabIndex = index);
    _scrollToActivePill(index);
  }

  void _scrollToActivePill(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _tabKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = BookingAdminTheme.isDark(context);

    return PopScope(
      canPop: true,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: BookingAdminTheme.bg(context),
          appBar: _buildAppBar(dark),
          drawer: _buildNavigationDrawer(dark),
          body: IndexedStack(
            index: _currentTabIndex,
            children: [
              BookingAdminOverviewTab(
                bookingsStream: widget.bookingsStream,
                venuesStream: widget.venuesStream,
                onNavigateToTab: _onTabSelected,
              ),
              BookingAdminBookingsTab(bookingsStream: widget.bookingsStream),
              BookingAdminVenuesTab(venuesStream: widget.venuesStream),
              BookingAdminReelsTab(reelsStream: widget.reelsStream, reportsStream: widget.reportsStream),
              BookingAdminPaymentsTab(bookingsStream: widget.bookingsStream),
              BookingAdminReportsTab(bookingsStream: widget.bookingsStream),
              BookingAdminAuditTab(auditStream: widget.auditStream),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool dark) {
    return AppBar(
      backgroundColor: dark ? BookingAdminTheme.surfaceHeader : Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: dark ? BookingAdminTheme.iconColor : const Color(0xFF0F172A),
        ),
        tooltip: 'الرجوع للوحة الإدارة العامة',
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _tabs[_currentTabIndex]['title'] as String,
            style: TextStyle(
              color: dark ? BookingAdminTheme.textPrimary : const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const Text(
            'لوحة إدارة الحجوزات · Staging',
            style: TextStyle(
              color: BookingAdminTheme.gold,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: dark ? BookingAdminTheme.iconColor : const Color(0xFF0F172A),
          ),
          tooltip: 'أقسام لوحة الإدارة',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: Column(
          children: [
            Container(color: BookingAdminTheme.border(context), height: 1),
            Container(
              height: 52,
              width: double.infinity,
              color: dark ? BookingAdminTheme.surfaceHeader : Colors.white,
              child: ListView.builder(
                controller: _pillScrollController,
                scrollDirection: Axis.horizontal,
                cacheExtent: 1200,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                itemCount: _tabs.length,
                itemBuilder: (context, i) {
                  final isSelected = _currentTabIndex == i;
                  final item = _tabs[i];
                  final title = item['title'] as String;
                  final icon = item['icon'] as IconData;

                  return Padding(
                    key: _tabKeys[i],
                    padding: EdgeInsets.only(left: i == _tabs.length - 1 ? 0 : 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      avatar: Icon(
                        icon,
                        size: 15,
                        color: isSelected
                            ? BookingAdminTheme.gold
                            : (dark ? BookingAdminTheme.iconMuted : const Color(0xFF64748B)),
                      ),
                      label: Text(title),
                      onSelected: (s) {
                        if (s) _onTabSelected(i);
                      },
                      selectedColor: BookingAdminTheme.goldSubtle,
                      backgroundColor: dark ? BookingAdminTheme.surfaceAlt : const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? BookingAdminTheme.gold
                            : (dark ? BookingAdminTheme.textSecondary : const Color(0xFF334155)),
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontFamily: 'Cairo',
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? BookingAdminTheme.gold
                            : BookingAdminTheme.border(context),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                },
              ),
            ),
            Container(color: BookingAdminTheme.border(context), height: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer(bool dark) {
    return Drawer(
      backgroundColor: dark ? BookingAdminTheme.surfaceHeader : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ترويسة القائمة الجانبية (SaaS Brand Bar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: BookingAdminTheme.border(context))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: BookingAdminTheme.goldSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BookingAdminTheme.gold.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.event_available, color: BookingAdminTheme.gold, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'عقارات الأنبار',
                          style: TextStyle(
                            color: dark ? BookingAdminTheme.textPrimary : const Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          'وحدة إدارة الحجوزات المعتمدة',
                          style: TextStyle(
                            color: dark ? BookingAdminTheme.textMuted : const Color(0xFF64748B),
                            fontSize: 11,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // قائمة الأقسام السبعة
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final item = _tabs[index];
                  final isSelected = _currentTabIndex == index;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: BookingAdminTheme.gold.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Material(
                      color: isSelected ? BookingAdminTheme.goldSubtle : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Icon(
                          item['icon'] as IconData,
                          size: 20,
                          color: isSelected
                              ? BookingAdminTheme.gold
                              : (dark ? BookingAdminTheme.iconMuted : const Color(0xFF64748B)),
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            color: isSelected
                                ? BookingAdminTheme.gold
                                : (dark ? BookingAdminTheme.textSecondary : const Color(0xFF334155)),
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        onTap: () {
                          _onTabSelected(index);
                          Navigator.pop(context); // إغلاق الـ Drawer
                        },
                      ),
                    ),
                  );
                },
              ),
            ),

            // تذييل القائمة للرجوع للوحة الإدارة العامة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: BookingAdminTheme.border(context))),
              ),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.arrow_back, color: dark ? BookingAdminTheme.iconMuted : const Color(0xFF64748B)),
                title: Text(
                  'الرجوع للوحة الإدارة العامة',
                  style: TextStyle(
                    color: dark ? BookingAdminTheme.textMuted : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context); // إغلاق القائمة
                  Navigator.pop(context); // الرجوع للوحة الإدارة العامة
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
