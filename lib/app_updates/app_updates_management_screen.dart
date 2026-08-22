import 'package:flutter/material.dart';

import 'app_update_dialog.dart';
import 'app_update_icons.dart';
import 'app_update_model.dart';
import 'app_update_service.dart';

class AppUpdatesManagementScreen extends StatefulWidget {
  const AppUpdatesManagementScreen({super.key});

  @override
  State<AppUpdatesManagementScreen> createState() =>
      _AppUpdatesManagementScreenState();
}

class _AppUpdatesManagementScreenState
    extends State<AppUpdatesManagementScreen> {
  static const _bg = Color(0xff0F172A);
  static const _card = Color(0xff1E293B);
  static const _gold = Color(0xffD4AF37);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          centerTitle: true,
          title: const Text('إدارة تحديثات التطبيق',
              style: TextStyle(fontWeight: FontWeight.w900)),
          leading: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          actions: [
            IconButton(
              tooltip: 'إنشاء إصدار',
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add_circle_outline_rounded, color: _gold),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _gold,
          foregroundColor: Colors.black,
          onPressed: () => _openEditor(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('تحديث جديد',
              style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: StreamBuilder<List<AppUpdateModel>>(
          stream: AppUpdateService.instance.watchUpdates(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _errorState(snapshot.error.toString());
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _gold));
            }

            final updates = snapshot.data ?? const <AppUpdateModel>[];
            final active = updates.where((e) => e.isActive).toList();
            final published = active.isNotEmpty ? active.first : null;
            final mandatory = updates.where((e) => e.isMandatory).length;

            return RefreshIndicator(
              color: _gold,
              backgroundColor: _card,
              onRefresh: () async {
                // StreamBuilder سيعيد القراءة تلقائياً؛ التأخير الصغير يعطي إحساساً واضحاً بالسحب للتحديث.
                await Future<void>.delayed(const Duration(milliseconds: 350));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                children: [
                  _hero(published, updates.length, mandatory),
                  const SizedBox(height: 18),
                  _sectionHeader(
                    title: 'الإصدارات المحفوظة',
                    subtitle:
                        'يمكنك تعديلها أو معاينتها أو إيقاف ظهورها للمستخدمين',
                  ),
                  const SizedBox(height: 10),
                  if (updates.isEmpty)
                    _empty(context)
                  else
                    ...updates.map((u) => _updateCard(context, u)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(AppUpdateModel? active, int count, int mandatory) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xff1B2B44), Color(0xff111827)],
        ),
        border: Border.all(color: _gold.withValues(alpha: .25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: _gold, size: 28),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مركز تحديث التطبيق',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('أنشئ الإصدار، راجعه، ثم انشره عندما يصبح جاهزاً',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'الإصدار المنشور',
                  active?.version ?? 'لا يوجد',
                  Icons.verified_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stat('الإصدارات', '$count', Icons.layers_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stat('إجباري', '$mandatory', Icons.lock_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: .04)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _gold, size: 20),
          const SizedBox(height: 10),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _sectionHeader({required String title, required String subtitle}) {
    return Row(
      children: [
        Container(width: 4, height: 26, color: _gold),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 10.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _updateCard(BuildContext context, AppUpdateModel update) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: update.isActive
              ? _gold.withValues(alpha: .34)
              : Colors.white.withValues(alpha: .06),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child:
                    const Icon(Icons.system_update_alt_rounded, color: _gold),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(update.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5)),
                    const SizedBox(height: 5),
                    Text(
                        'الإصدار ${update.version}  •  Build ${update.buildNumber}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              _status(update),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(update.isMandatory ? 'إجباري' : 'اختياري',
                  update.isMandatory ? Colors.redAccent : Colors.greenAccent),
              const SizedBox(width: 7),
              _chip('${update.features.length} مميزات', _gold),
              const Spacer(),
              IconButton(
                tooltip: 'معاينة',
                onPressed: () => _preview(context, update),
                icon:
                    const Icon(Icons.visibility_rounded, color: Colors.white70),
              ),
              IconButton(
                tooltip: 'تعديل',
                onPressed: () => _openEditor(context, update: update),
                icon: const Icon(Icons.edit_rounded, color: Colors.white70),
              ),
              PopupMenuButton<String>(
                color: _card,
                onSelected: (value) => _menu(context, value, update),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'active',
                    child: Text(
                      update.isActive ? 'إيقاف الظهور' : 'نشر هذا الإصدار',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف الإصدار',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
                icon:
                    const Icon(Icons.more_vert_rounded, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _status(AppUpdateModel update) {
    final color = update.isActive ? Colors.greenAccent : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(update.isActive ? 'منشور' : 'محفوظ',
          style: TextStyle(
              color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _empty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration:
          BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Icon(Icons.system_update_rounded,
              color: Colors.white24, size: 55),
          const SizedBox(height: 12),
          const Text('لا توجد إصدارات محفوظة',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          const Text('أنشئ إصداراً جديداً ثم راجعه من المعاينة قبل نشره',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.5)),
          const SizedBox(height: 17),
          ElevatedButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إنشاء إصدار جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: _card, borderRadius: BorderRadius.circular(22)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 48),
              const SizedBox(height: 10),
              const Text('تعذر تحميل الإصدارات',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
              const SizedBox(height: 7),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context,
      {AppUpdateModel? update}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateEditorDialog(update: update),
    );
  }

  void _preview(BuildContext context, AppUpdateModel update) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppUpdateDialog(update: update, preview: true),
    );
  }

  Future<void> _menu(
      BuildContext context, String value, AppUpdateModel update) async {
    if (value == 'active') {
      try {
        await AppUpdateService.instance.setActive(update.id, !update.isActive);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(update.isActive
                ? 'تم إيقاف ظهور الإصدار'
                : 'تم نشر الإصدار للمستخدمين'),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تعذر تغيير حالة الإصدار: $e')));
        }
      }
      return;
    }

    if (value == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _card,
          title:
              const Text('حذف الإصدار', style: TextStyle(color: Colors.white)),
          content: const Text('سيتم حذف سجل الإصدار نهائياً. هل تريد المتابعة؟',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('حذف', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await AppUpdateService.instance.deleteUpdate(update.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('تم حذف الإصدار')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('تعذر حذف الإصدار: $e')));
        }
      }
    }
  }
}

class _UpdateEditorDialog extends StatefulWidget {
  final AppUpdateModel? update;

  const _UpdateEditorDialog({this.update});

  @override
  State<_UpdateEditorDialog> createState() => _UpdateEditorDialogState();
}

class _UpdateEditorDialogState extends State<_UpdateEditorDialog> {
  static const _gold = Color(0xffD4AF37);
  static const _bg = Color(0xff0B1220);
  static const _card = Color(0xff1E293B);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _version;
  late final TextEditingController _build;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _storeUrl;
  late bool _mandatory;
  late bool _active;
  late List<_FeatureDraft> _features;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.update;
    _version = TextEditingController(text: u?.version ?? '');
    _build = TextEditingController(text: u?.buildNumber.toString() ?? '');
    _title = TextEditingController(text: u?.title ?? 'تحديث جديد متاح!');
    _description = TextEditingController(
      text: u?.description ?? 'احصل على أحدث التحسينات والمميزات لتجربة أفضل',
    );
    _storeUrl = TextEditingController(text: u?.storeUrl ?? '');
    _mandatory = u?.isMandatory ?? false;
    _active = u?.isActive ?? false;
    _features = u?.features.map(_FeatureDraft.fromModel).toList() ??
        [
          _FeatureDraft(
              iconKey: 'speed',
              title: 'تحسين الأداء',
              description: 'سرعة واستجابة أفضل'),
          _FeatureDraft(
              iconKey: 'bug',
              title: 'إصلاح الأخطاء',
              description: 'تحسين الاستقرار ومعالجة المشاكل'),
          _FeatureDraft(
              iconKey: 'star',
              title: 'مميزات جديدة',
              description: 'تجربة أفضل ومزايا جديدة'),
        ];
  }

  @override
  void dispose() {
    _version.dispose();
    _build.dispose();
    _title.dispose();
    _description.dispose();
    _storeUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _features.removeWhere(
        (f) => f.title.trim().isEmpty && f.description.trim().isEmpty);
    if (_features.isEmpty) {
      _toast('أضف ميزة واحدة على الأقل');
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final model = AppUpdateModel(
        id: widget.update?.id ?? '',
        version: _version.text.trim(),
        buildNumber: int.parse(_build.text.trim()),
        title: _title.text.trim(),
        description: _description.text.trim(),
        storeUrl: _storeUrl.text.trim(),
        isMandatory: _mandatory,
        isActive: _active,
        features: _features.map((e) => e.toModel()).toList(),
        publishedAt: widget.update?.publishedAt ?? (_active ? now : null),
        updatedAt: now,
        createdAt: widget.update?.createdAt ?? now,
      );

      if (widget.update == null) {
        await AppUpdateService.instance.createUpdate(model);
      } else {
        await AppUpdateService.instance.updateUpdate(model);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _previewDraft() {
    if (!_formKey.currentState!.validate()) return;
    final draft = AppUpdateModel(
      id: widget.update?.id ?? 'preview',
      version: _version.text.trim(),
      buildNumber: int.tryParse(_build.text.trim()) ?? 1,
      title: _title.text.trim(),
      description: _description.text.trim(),
      storeUrl: _storeUrl.text.trim().isEmpty
          ? 'https://play.google.com/store'
          : _storeUrl.text.trim(),
      isMandatory: _mandatory,
      isActive: _active,
      features: _features
          .where((f) =>
              f.title.trim().isNotEmpty || f.description.trim().isNotEmpty)
          .map((e) => e.toModel())
          .toList(),
      publishedAt: null,
      updatedAt: null,
      createdAt: null,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppUpdateDialog(update: draft, preview: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final width = MediaQuery.sizeOf(context).width;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: _bg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 700,
            maxHeight: (height - 28).clamp(600.0, 900.0).toDouble(),
            minWidth: width > 720 ? 620 : 0,
          ),
          child: Column(
            children: [
              _header(),
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    children: [
                      _sectionTitle(
                          'بيانات الإصدار', Icons.info_outline_rounded),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: _version,
                              label: 'رقم الإصدار',
                              hint: 'مثال: 2.3.0',
                              icon: Icons.sell_outlined,
                              validator: (v) =>
                                  v!.trim().isEmpty ? 'أدخل رقم الإصدار' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field(
                              controller: _build,
                              label: 'Build Number',
                              hint: 'مثال: 23',
                              icon: Icons.tag_rounded,
                              keyboard: TextInputType.number,
                              validator: (v) {
                                final value = int.tryParse(v!.trim());
                                return value == null || value <= 0
                                    ? 'رقم Build غير صحيح'
                                    : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _title,
                        label: 'عنوان التحديث',
                        hint: 'مثال: تحديث جديد متاح!',
                        icon: Icons.title_rounded,
                        validator: (v) =>
                            v!.trim().isEmpty ? 'أدخل العنوان' : null,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _description,
                        label: 'وصف التحديث',
                        hint: 'وصف مختصر يظهر للمستخدم',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                        validator: (v) =>
                            v!.trim().isEmpty ? 'أدخل الوصف' : null,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _storeUrl,
                        label: 'رابط Google Play',
                        hint:
                            'https://play.google.com/store/apps/details?id=...',
                        icon: Icons.storefront_outlined,
                        keyboard: TextInputType.url,
                        validator: (v) {
                          final value = Uri.tryParse(v!.trim());
                          return value != null && value.hasScheme
                              ? null
                              : 'أدخل رابط متجر صحيح';
                        },
                      ),
                      const SizedBox(height: 14),
                      _settingsCard(),
                      const SizedBox(height: 18),
                      _sectionTitle(
                          'محتوى التحديث', Icons.auto_awesome_rounded),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('المميزات التي ستظهر في نافذة التحديث',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() => _features.add(
                                _FeatureDraft(
                                    iconKey: 'star',
                                    title: '',
                                    description: ''))),
                            icon: const Icon(Icons.add_rounded,
                                color: _gold, size: 19),
                            label: const Text('إضافة ميزة',
                                style: TextStyle(
                                    color: _gold, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...List.generate(_features.length, _featureEditor),
                    ],
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 10, 12),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
                color: _gold.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.system_update_rounded, color: _gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.update == null ? 'إنشاء إصدار جديد' : 'تعديل الإصدار',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _gold, size: 19),
        const SizedBox(width: 7),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      textInputAction:
          maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: _card,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
        floatingLabelStyle: const TextStyle(
            color: _gold, fontSize: 12, fontWeight: FontWeight.bold),
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _gold, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _settingsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _gold,
            title: const Text('تحديث إجباري',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('لا يظهر زر الإلغاء للمستخدم',
                style: TextStyle(color: Colors.white54, fontSize: 10.5)),
            value: _mandatory,
            onChanged: (v) => setState(() => _mandatory = v),
          ),
          const Divider(color: Colors.white10, height: 1),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _gold,
            title: const Text('نشر الإصدار الآن',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text(
                'عند النشر سيتم إيقاف الإصدار المنشور سابقاً تلقائياً',
                style: TextStyle(color: Colors.white54, fontSize: 10.5)),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ],
      ),
    );
  }

  Widget _featureEditor(int index) {
    final feature = _features[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () async {
                  final key = await _pickIcon(context, feature.iconKey);
                  if (key != null && mounted)
                    setState(() => feature.iconKey = key);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _gold.withValues(alpha: .15)),
                  ),
                  child: Icon(AppUpdateIcons.fromKey(feature.iconKey),
                      color: _gold, size: 26),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _featureTextField(
                  initial: feature.title,
                  label: 'عنوان الميزة',
                  hint: 'مثال: تحسين الأداء',
                  onChanged: (v) => feature.title = v,
                ),
              ),
              IconButton(
                tooltip: 'حذف الميزة',
                onPressed: () => setState(() => _features.removeAt(index)),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _featureTextField(
            initial: feature.description,
            label: 'وصف مختصر',
            hint: 'مثال: سرعة واستجابة أفضل',
            maxLines: 2,
            onChanged: (v) => feature.description = v,
          ),
        ],
      ),
    );
  }

  Widget _featureTextField({
    required String initial,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return TextFormField(
      initialValue: initial,
      onChanged: onChanged,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xff162236),
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
        floatingLabelStyle: const TextStyle(color: _gold, fontSize: 11),
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .09)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .09)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _gold),
        ),
      ),
    );
  }

  Future<String?> _pickIcon(BuildContext context, String selected) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xff111827),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اختر أيقونة الميزة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 9,
                  physics: const NeverScrollableScrollPhysics(),
                  children: AppUpdateIcons.values.entries.map((entry) {
                    final selectedItem = entry.key == selected;
                    return InkWell(
                      onTap: () => Navigator.pop(sheetContext, entry.key),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selectedItem
                              ? _gold.withValues(alpha: .16)
                              : Colors.white.withValues(alpha: .04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: selectedItem ? _gold : Colors.transparent),
                        ),
                        child: Icon(entry.value,
                            color: selectedItem ? _gold : Colors.white70,
                            size: 25),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _previewDraft,
              icon: const Icon(Icons.visibility_rounded, size: 12),
              label: const Text('معاينة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: _gold.withValues(alpha: .55)),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                  _saving
                      ? 'جاري الحفظ...'
                      : (_active ? 'حفظ ونشر' : 'حفظ الإصدار'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureDraft {
  String iconKey;
  String title;
  String description;

  _FeatureDraft(
      {required this.iconKey, required this.title, required this.description});

  factory _FeatureDraft.fromModel(AppUpdateFeature feature) => _FeatureDraft(
        iconKey: feature.iconKey,
        title: feature.title,
        description: feature.description,
      );

  AppUpdateFeature toModel() => AppUpdateFeature(
        iconKey: iconKey,
        title: title.trim(),
        description: description.trim(),
      );
}
