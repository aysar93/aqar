import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PaymentAccountSettingsScreen extends StatefulWidget {
  const PaymentAccountSettingsScreen({super.key});
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
      final result = await FirebaseFunctions.instance
          .httpsCallable('getPaymentAccountSettings')
          .call();
      if (!mounted) return;
      for (final m in controllers.keys) {
        controllers[m]!.text = result.data['methods'][m]['number'];
        enabled[m] = result.data['methods'][m]['enabled'] == true;
      }
      setState(() {
        revision = result.data['revision'];
        loaded = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = 'تعذر تحميل الحسابات؛ يلزم مدير مخوّل.');
      }
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FirebaseFunctions.instance
          .httpsCallable('savePaymentAccountSettings')
          .call({
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
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(title: const Text('حسابات الدفع المشتركة')),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            const Text(
                'تُستخدم للاشتراكات والحجوزات. كي: 10–16 رقمًا. زين كاش: 11 رقمًا تبدأ بـ07. الرقم الفارغ يخفي الوسيلة عند إيقافها.'),
            if (error != null) Text(error!),
            for (final m in controllers.keys) ...[
              TextField(
                  controller: controllers[m],
                  enabled: loaded && !busy,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: m == 'qicard' ? 'رقم كي' : 'رقم زين كاش')),
              SwitchListTile(
                  title: const Text('تفعيل'),
                  value: enabled[m]!,
                  onChanged: loaded && !busy
                      ? (v) => setState(() => enabled[m] = v)
                      : null),
            ],
            FilledButton(
                onPressed: loaded && !busy ? save : null,
                child: const Text('حفظ')),
          ])));
}
