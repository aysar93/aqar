import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../office/models/office_subscription_model.dart';
import '../../office/services/office_subscription_gift_service.dart';
import '../../subscription/models/subscription_package_model.dart';

class OfficeGiftSubscriptionDialog extends StatefulWidget {
  const OfficeGiftSubscriptionDialog({super.key, required this.officeId});
  final String officeId;

  @override
  State<OfficeGiftSubscriptionDialog> createState() =>
      _OfficeGiftSubscriptionDialogState();
}

class _GiftData {
  const _GiftData(this.office, this.packages, this.current);
  final Map<String, dynamic> office;
  final List<SubscriptionPackageModel> packages;
  final OfficeSubscriptionModel? current;
}

class _OfficeGiftSubscriptionDialogState
    extends State<OfficeGiftSubscriptionDialog> {
  late Future<_GiftData> _data;
  String? _selectedPackageId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_GiftData> _load() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait<Object>([
      db.collection('offices').doc(widget.officeId).get(),
      db.collection('subscription_packages').get(),
      db
          .collection('office_subscriptions')
          .where('officeId', isEqualTo: widget.officeId)
          .get(),
    ]);
    final office = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    if (!office.exists) throw StateError('المكتب غير موجود');
    final packages = (results[1] as QuerySnapshot<Map<String, dynamic>>)
        .docs
        .map(SubscriptionPackageModel.fromFirestore)
        .where((package) => package.isActive && package.durationDays > 0)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final records = (results[2] as QuerySnapshot<Map<String, dynamic>>)
        .docs
        .map(OfficeSubscriptionModel.fromFirestore)
        .where((sub) => sub.status == 'active' || sub.status == 'suspended')
        .toList()
      ..sort((a, b) =>
          (b.endDate ?? DateTime(1970)).compareTo(a.endDate ?? DateTime(1970)));
    final data = office.data()!;
    OfficeSubscriptionModel? current;
    for (final sub in records) {
      if (sub.id == data['subscriptionId']) current = sub;
    }
    return _GiftData(
        data, packages, current ?? (records.isEmpty ? null : records.first));
  }

  String _date(DateTime date) => '${date.year}/${date.month}/${date.day}';

  Future<void> _grant(_GiftData data, SubscriptionPackageModel package) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await OfficeSubscriptionGiftService().grant(
        officeId: widget.officeId,
        packageId: package.id,
        expectedSubscriptionId:
            (data.office['subscriptionId'] ?? '').toString(),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(
          content: Text('تم تفعيل الباقة الهدية وإضافة إشعار لصاحب المكتب')));
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر إهداء الباقة: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إهداء باقة اشتراك'),
            content: SizedBox(
              width: 420,
              child: FutureBuilder<_GiftData>(
                future: _data,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('تعذر تحميل المكتب والباقات'),
                      TextButton(
                          onPressed: () => setState(() => _data = _load()),
                          child: const Text('إعادة المحاولة')),
                    ]);
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox(
                        height: 80,
                        child: Center(child: CircularProgressIndicator()));
                  }
                  final data = snapshot.data!;
                  if (data.packages.isEmpty) {
                    return const Text('لا توجد باقات مفعّلة متاحة للإهداء');
                  }
                  final package = data.packages.firstWhere(
                      (item) => item.id == _selectedPackageId,
                      orElse: () => data.packages.first);
                  final gift = buildGiftSubscription(
                      id: 'preview',
                      officeId: widget.officeId,
                      ownerId: (data.office['ownerId'] ?? '').toString(),
                      package: package,
                      now: DateTime.now(),
                      current: data.current);
                  final extending = data.current?.status == 'active' &&
                      data.current?.packageId == package.id &&
                      data.current?.endDate?.isAfter(DateTime.now()) == true;
                  return SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('المكتب: ${data.office['name'] ?? ''}'),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: package.id,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'الباقة الهدية'),
                            items: data.packages
                                .map((item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(item.name,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) =>
                                    setState(() => _selectedPackageId = value),
                          ),
                          const SizedBox(height: 14),
                          Text('مدة الهدية: ${package.durationDays} يومًا'),
                          const Text('التكلفة على المكتب: مجانًا'),
                          Text(
                              'تاريخ الانتهاء بعد المنح: ${_date(gift.endDate!)}'),
                          const SizedBox(height: 10),
                          if (data.current != null)
                            Text(extending
                                ? 'ستُضاف مدة الهدية إلى المدة المتبقية من الباقة نفسها.'
                                : 'ستحل الهدية محل الاشتراك الحالي وتبدأ مدتها الآن.'),
                          const SizedBox(height: 10),
                          const Text(
                              'ستُفعّل مزايا الباقة ويُرسل إشعار لصاحب المكتب.'),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed:
                                _saving ? null : () => _grant(data, package),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.card_giftcard),
                            label: Text(_saving
                                ? 'جارٍ التفعيل...'
                                : 'تفعيل الهدية وإرسال إشعار'),
                          ),
                        ]),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'))
            ],
          ),
        ),
      );
}
