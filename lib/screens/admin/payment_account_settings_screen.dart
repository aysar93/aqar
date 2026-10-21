import '../../bookings/booking_widgets.dart';
import '../../bookings/booking_experience.dart';
import '../../bookings/booking_decision_ui.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

Future<Map<String, dynamic>> paymentSettingsCall(
    String name, Map<String, dynamic> data) async {
  final result =
      await FirebaseFunctions.instance.httpsCallable(name).call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

class PaymentAccountSettingsScreen extends StatefulWidget {
  const PaymentAccountSettingsScreen(
      {super.key, this.call = paymentSettingsCall});
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
      call;
  @override
  State<PaymentAccountSettingsScreen> createState() =>
      _PaymentAccountSettingsScreenState();
}

class _PaymentAccountSettingsScreenState
    extends State<PaymentAccountSettingsScreen> {
  final controllers = {
    for (final m in ['qicard', 'zaincash']) m: TextEditingController()
  };
  final enabled = {'qicard': false, 'zaincash': false};
  int revision = 0;
  bool loaded = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.call('getPaymentAccountSettings', {});
      if (!mounted) return;
      for (final m in controllers.keys) {
        controllers[m]!.text = result['methods'][m]['number'];
        enabled[m] = result['methods'][m]['enabled'] == true;
      }
      setState(() {
        revision = result['revision'];
        loaded = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = 'تعذر تحميل الحسابات؛ يلزم مدير مخوّل.');
      }
    }
  }

  Future<void> save() async {
    if (!loaded || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.call('savePaymentAccountSettings', {
        'revision': revision,
        'methods': {
          for (final m in controllers.keys)
            m: {'number': controllers[m]!.text.trim(), 'enabled': enabled[m]}
        }
      });
      if (!mounted) return;
      revision++;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ حسابات الدفع')));
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => error = e.message ?? 'تعذر الحفظ');
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر الحفظ');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BookingScaffold(
      appBar: AppBar(title: const Text('حسابات الدفع المشتركة')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const BookingSection(
            title: 'المستلم المعتمد للتحويل اليدوي',
            subtitle:
                'هذه الحسابات مشتركة بين الاشتراكات والحجوزات. راجع الرقم قبل الحفظ؛ يتطلب التعديل صلاحية الخادم.',
            child: Text(
                'لا تتضمن الإعدادات الحالية اسم صاحب الحساب. لا يعرض التطبيق اسم مستلم مفترض.',
                style: TextStyle(height: 1.8))),
        if (!loaded && error == null) const LinearProgressIndicator(),
        if (error != null) BookingActionReason(reason: error!),
        if (error != null && !loaded)
          OutlinedButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() => error = null);
                      load();
                    },
              child: const Text('إعادة تحميل الحسابات')),
        for (final method in controllers.keys)
          BookingSection(
              title: method == 'qicard' ? 'Ki / Qi' : 'Zain Cash',
              subtitle: method == 'qicard'
                  ? 'رقم مكون من 10–16 رقمًا.'
                  : 'رقم من 11 رقمًا يبدأ بـ07.',
              child: Column(children: [
                TextField(
                    controller: controllers[method],
                    enabled: loaded && !busy,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                        labelText: 'رقم حساب المستلم',
                        prefixIcon:
                            Icon(Icons.account_balance_wallet_outlined))),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('إتاحة الوسيلة للمستخدمين'),
                    value: enabled[method]!,
                    onChanged: loaded && !busy
                        ? (value) => setState(() => enabled[method] = value)
                        : null),
              ])),
        if (!loaded)
          const BookingActionReason(
              reason:
                  'الحفظ معطل حتى تحميل الأرقام والإصدار المعتمد من الخادم.')
        else if (busy)
          const BookingActionReason(
              reason: 'الحفظ معطل أثناء تنفيذ الطلب السابق.'),
        FilledButton.icon(
            onPressed: loaded && !busy ? save : null,
            icon: const Icon(Icons.save_outlined),
            label: Text(busy ? 'جارٍ الحفظ' : 'حفظ حسابات الدفع')),
        const BookingActionReason(
            reason:
                'إيقاف وسيلة يخفيها من خيارات الدفع. لا يحذف ذلك بيانات التحويل المحفوظة مع الحجوزات السابقة.'),
      ]));
}
