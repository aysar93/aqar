import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../booking_admin_theme.dart';
import 'booking_admin_bookings_tab.dart' show BookingAdminDetailsSheet;
import '../../booking_widgets.dart' show bookingMoney;
import '../../../screens/admin/payment_account_settings_screen.dart' show paymentSettingsCall;

class BookingAdminPaymentsTab extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? bookingsStream;

  const BookingAdminPaymentsTab({super.key, this.bookingsStream});

  @override
  State<BookingAdminPaymentsTab> createState() => _BookingAdminPaymentsTabState();
}

class _BookingAdminPaymentsTabState extends State<BookingAdminPaymentsTab> with AutomaticKeepAliveClientMixin {
  final _qiCtrl = TextEditingController();
  final _zainCtrl = TextEditingController();
  bool _qiEnabled = false;
  bool _zainEnabled = false;
  int _revision = 0;
  bool _loadingSettings = false;
  bool _savingSettings = false;
  String? _settingsError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
  }

  @override
  void dispose() {
    _qiCtrl.dispose();
    _zainCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentSettings() async {
    if (Firebase.apps.isEmpty) {
      if (mounted) setState(() => _loadingSettings = false);
      return;
    }
    setState(() {
      _loadingSettings = true;
      _settingsError = null;
    });
    try {
      final res = await paymentSettingsCall('getPaymentAccountSettings', {});
      if (!mounted) return;
      final methods = res['methods'] as Map? ?? {};
      _qiCtrl.text = methods['qicard']?['number']?.toString() ?? '';
      _qiEnabled = methods['qicard']?['enabled'] == true;
      _zainCtrl.text = methods['zaincash']?['number']?.toString() ?? '';
      _zainEnabled = methods['zaincash']?['enabled'] == true;
      _revision = res['revision'] ?? 0;
    } catch (e) {
      try {
        final doc = await FirebaseFirestore.instance.doc('payment_accounts/shared').get();
        if (doc.exists && mounted) {
          final data = doc.data() ?? {};
          final methods = data['methods'] as Map? ?? {};
          _qiCtrl.text = methods['qicard']?['number']?.toString() ?? '';
          _qiEnabled = methods['qicard']?['enabled'] == true;
          _zainCtrl.text = methods['zaincash']?['number']?.toString() ?? '';
          _zainEnabled = methods['zaincash']?['enabled'] == true;
          _revision = data['revision'] ?? 0;
          return;
        }
      } catch (_) {}
      if (mounted) {
        setState(
          () => _settingsError = 'تنبيه: يلزم ترقية صلاحيات الحساب لتعديل أرقام التحويل عبر الدوال السحابية.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSettings = false);
    }
  }

  Future<void> _savePaymentSettings() async {
    if (_savingSettings) return;
    setState(() {
      _savingSettings = true;
      _settingsError = null;
    });
    try {
      await paymentSettingsCall('savePaymentAccountSettings', {
        'revision': _revision,
        'methods': {
          'qicard': {'number': _qiCtrl.text.trim(), 'enabled': _qiEnabled},
          'zaincash': {
            'number': _zainCtrl.text.trim(),
            'enabled': _zainEnabled,
          },
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ إعدادات وسائل الدفع بنجاح',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
        _loadPaymentSettings();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _settingsError = 'فشل حفظ الإعدادات: $e');
      }
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.bookingsStream ?? FirebaseFirestore.instance.collection('bookings').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs.map((d) => d.data()).toList() ?? [];

        num totalDeposits = 0;
        num totalRemaining = 0;
        int pendingReceipts = 0;
        int confirmedPayments = 0;

        for (final b in docs) {
          final s = (b['status'] ?? '').toString();
          if (s == 'payment_review') pendingReceipts++;
          if (s == 'confirmed' || s == 'completed' || s == 'arrived') {
            confirmedPayments++;
            totalDeposits += (b['deposit'] as num?) ?? (b['paid'] as num?) ?? 0;
            totalRemaining += (b['remaining'] as num?) ?? 0;
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
          children: [
            // بطاقات الملخص المالي بتخطيط متجاوب خالٍ تماماً من IntrinsicHeight
            _buildResponsiveFinancialGrid(
              totalDeposits: totalDeposits,
              totalRemaining: totalRemaining,
              pendingReceipts: pendingReceipts,
              confirmedPayments: confirmedPayments,
            ),
            const SizedBox(height: 20),

            // إعدادات وسائل الدفع اليدوي (K Card & Zain Cash)
            _buildPaymentMethodsSettingsCard(),
            const SizedBox(height: 20),

            // سجل المعاملات والإيصالات
            _buildTransactionsLedger(docs),
          ],
        );
      },
    );
  }

  Widget _buildResponsiveFinancialGrid({
    required num totalDeposits,
    required num totalRemaining,
    required int pendingReceipts,
    required int confirmedPayments,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: BookingAdminStatCard(
                  title: 'إجمالي العربون المعتمد',
                  value: bookingMoney(totalDeposits),
                  subtitle: '$confirmedPayments دفعات معتمدة بالمحفظة',
                  icon: Icons.account_balance_wallet_outlined,
                  badgeText: 'محصل',
                  badgeColor: BookingAdminTheme.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BookingAdminStatCard(
                  title: 'إجمالي المتبقي للمالك',
                  value: bookingMoney(totalRemaining),
                  subtitle: 'يسدد مباشرة عند تسجيل الوصول',
                  icon: Icons.payments_outlined,
                  badgeText: 'مستحق',
                  badgeColor: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BookingAdminStatCard(
                  title: 'إيصالات بانتظار التدقيق',
                  value: '$pendingReceipts',
                  subtitle: 'تحتاج تدقيق رقم الحوالة والإشعار',
                  icon: Icons.receipt_long_outlined,
                  badgeText: pendingReceipts > 0 ? 'مراجعة' : null,
                  badgeColor: const Color(0xFFEAB308),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BookingAdminStatCard(
                    title: 'إجمالي العربون',
                    value: bookingMoney(totalDeposits),
                    subtitle: '$confirmedPayments دفعات معتمدة',
                    icon: Icons.account_balance_wallet_outlined,
                    badgeText: 'محصل',
                    badgeColor: BookingAdminTheme.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BookingAdminStatCard(
                    title: 'المتبقي للمالك',
                    value: bookingMoney(totalRemaining),
                    subtitle: 'تُدفع عند تسجيل الوصول',
                    icon: Icons.payments_outlined,
                    badgeText: 'مستحق',
                    badgeColor: const Color(0xFF38BDF8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BookingAdminStatCard(
              title: 'إيصالات بانتظار المراجعة والتدقيق المالي',
              value: '$pendingReceipts',
              subtitle: 'تحتاج مطابقة رقم الحوالة مع الحساب المعتمد',
              icon: Icons.receipt_long_outlined,
              badgeText: pendingReceipts > 0 ? 'يتطلب إجراء' : null,
              badgeColor: const Color(0xFFEAB308),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentMethodsSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BookingAdminTheme.goldSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.credit_card_outlined, size: 20, color: BookingAdminTheme.gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة حسابات الدفع الإلكتروني (كي كارد وزين كاش)',
                      style: TextStyle(
                        color: BookingAdminTheme.text(context),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      'حدد أرقام التحويل المعتمدة لاستلام العربون وتفعيل/تعطيل كل وسيلة للجمهور.',
                      style: TextStyle(
                        color: BookingAdminTheme.textMute(context),
                        fontSize: 11,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 20, color: BookingAdminTheme.icon(context)),
                tooltip: 'تحديث الإعدادات',
                onPressed: _loadPaymentSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_loadingSettings)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: BookingAdminTheme.gold)))
          else ...[
            if (_settingsError != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x1FEF4444),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x44EF4444)),
                ),
                child: Text(
                  _settingsError!,
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 12,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // وسيلة Qi Card / K
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BookingAdminTheme.surfaceSecondary(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BookingAdminTheme.border(context)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.payment, size: 18, color: BookingAdminTheme.icon(context)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'بطاقة كي كارد / Qi Card (K)',
                                style: TextStyle(
                                  color: BookingAdminTheme.text(context),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _qiEnabled,
                        activeThumbColor: BookingAdminTheme.gold,
                        activeTrackColor: BookingAdminTheme.goldSubtle,
                        onChanged: (v) => setState(() => _qiEnabled = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qiCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo'),
                    decoration: InputDecoration(
                      hintText: 'أدخل رقم بطاقة Qi Card (10 إلى 16 رقماً)...',
                      hintStyle: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
                      filled: true,
                      fillColor: BookingAdminTheme.surface(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: BookingAdminTheme.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: BookingAdminTheme.border(context)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // وسيلة Zain Cash
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BookingAdminTheme.surfaceSecondary(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BookingAdminTheme.border(context)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.phone_android, size: 18, color: BookingAdminTheme.icon(context)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'محفظة زين كاش (Zain Cash)',
                                style: TextStyle(
                                  color: BookingAdminTheme.text(context),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _zainEnabled,
                        activeThumbColor: BookingAdminTheme.gold,
                        activeTrackColor: BookingAdminTheme.goldSubtle,
                        onChanged: (v) => setState(() => _zainEnabled = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _zainCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: BookingAdminTheme.text(context), fontFamily: 'Cairo'),
                    decoration: InputDecoration(
                      hintText: 'أدخل رقم زين كاش (07xxxxxxxxx - 11 رقماً)...',
                      hintStyle: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
                      filled: true,
                      fillColor: BookingAdminTheme.surface(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: BookingAdminTheme.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: BookingAdminTheme.border(context)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // زر الحفظ
            Align(
              alignment: Alignment.centerLeft,
              child: BookingAdminButton(
                isPrimary: true,
                isLoading: _savingSettings,
                icon: Icons.save_outlined,
                label: 'حفظ إعدادات وسائل الدفع',
                onPressed: _savePaymentSettings,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionsLedger(List<Map<String, dynamic>> all) {
    final paidTransactions = all.where((b) {
      final s = (b['status'] ?? '').toString();
      final hasDeposit = ((b['deposit'] as num?) ?? (b['paid'] as num?) ?? 0) > 0;
      return hasDeposit && (s == 'confirmed' || s == 'completed' || s == 'arrived' || s == 'payment_review');
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BookingAdminTheme.cardDecoration(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'سجل المعاملات والتحصيلات الأخيرة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BookingAdminTheme.text(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${paidTransactions.length} مسجلة',
                style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (paidTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'لا توجد حركات مالية مسجلة بعد في المنظومة.',
                  style: TextStyle(color: BookingAdminTheme.textMute(context), fontSize: 12, fontFamily: 'Cairo'),
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < paidTransactions.take(8).length; i++) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      final b = paidTransactions[i];
                      final bookingId = (b['_id'] ?? 'booking_$i').toString();
                      BookingAdminDetailsSheet.show(
                        context: context,
                        bookingId: bookingId,
                        initialData: b,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: BookingAdminTheme.surfaceSecondary(context),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: BookingAdminTheme.border(context)),
                            ),
                            child: const Icon(Icons.arrow_downward_rounded, size: 18, color: BookingAdminTheme.gold),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  BookingAdminDataSanitizer.cleanVenueName(
                                    (paidTransactions[i]['venueSnapshot']?['name'] ?? paidTransactions[i]['venueName'])?.toString(),
                                    index: i,
                                  ),
                                  softWrap: true,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: BookingAdminTheme.text(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                Text(
                                  '${BookingAdminDataSanitizer.cleanCustomerName((paidTransactions[i]['customerSnapshot']?['name'] ?? paidTransactions[i]['customerName'])?.toString(), index: i)} · ${BookingAdminDataSanitizer.formatPaymentMethod(paidTransactions[i]['paymentMethod'])}',
                                  softWrap: true,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: BookingAdminTheme.textMute(context),
                                    fontSize: 11,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${bookingMoney((paidTransactions[i]['deposit'] as num?) ?? (paidTransactions[i]['paid'] as num?) ?? 0)}',
                                style: const TextStyle(
                                  color: BookingAdminTheme.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              BookingAdminStatusBadge(status: (paidTransactions[i]['status'] ?? 'unknown').toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < paidTransactions.take(8).length - 1)
                    Divider(color: BookingAdminTheme.border(context), height: 1),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
