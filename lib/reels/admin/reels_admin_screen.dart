import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import '../models/reel_model.dart';
import '../screens/reels_screen.dart';
import '../services/reel_service.dart';

class ReelsAdminScreen extends StatelessWidget {
  const ReelsAdminScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('إدارة الريلز'),
              actions: [
                IconButton(
                    tooltip: 'معاينة',
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ReelsScreen())),
                    icon: const Icon(Icons.preview_rounded))
              ],
              bottom: const TabBar(isScrollable: true, tabs: [
                Tab(text: 'الريلز', icon: Icon(Icons.video_collection_rounded)),
                Tab(text: 'الإحصائيات', icon: Icon(Icons.analytics_rounded)),
                Tab(text: 'البلاغات', icon: Icon(Icons.flag_rounded)),
                Tab(text: 'الإعدادات', icon: Icon(Icons.settings_rounded))
              ]),
            ),
            body: const TabBarView(children: [
              _ReelsManagement(),
              _ReelsAnalytics(),
              _ReelsReports(),
              _ReelsSettings()
            ]),
          ),
        ),
      );
}

class _ReelsManagement extends StatefulWidget {
  const _ReelsManagement();
  @override
  State<_ReelsManagement> createState() => _ReelsManagementState();
}

class _ReelsManagementState extends State<_ReelsManagement> {
  String _query = '';
  String _status = 'all';
  String _target = 'all';
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextField(
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'بحث بالعنوان أو التصنيف أو الوسوم')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _filter(
                        'الحالة',
                        _status,
                        const {
                          'all': 'الكل',
                          'draft': 'مسودة',
                          'scheduled': 'مجدول',
                          'published': 'منشور',
                          'hidden': 'مخفي',
                          'archived': 'مؤرشف',
                          'expired': 'منتهي'
                        },
                        (v) => setState(() => _status = v))),
                const SizedBox(width: 8),
                Expanded(
                    child: _filter(
                        'النوع',
                        _target,
                        const {
                          'all': 'الكل',
                          'property': 'عقار',
                          'office': 'مكتب',
                          'general': 'عام'
                        },
                        (v) => setState(() => _target = v))),
              ]),
            ]),
          ),
          Expanded(
              child: StreamBuilder<List<ReelModel>>(
            stream: ReelService.instance.adminReels(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('تعذر تحميل البيانات'));
              }
              final reels = (snapshot.data ?? []).where((r) {
                final search = '${r.title} ${r.category} ${r.tags.join(' ')}'
                    .toLowerCase();
                return (_query.isEmpty || search.contains(_query)) &&
                    (_status == 'all' || r.status.name == _status) &&
                    (_target == 'all' || r.targetType.name == _target);
              }).toList();
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (reels.isEmpty) {
                return const Center(child: Text('لا توجد ريلز مطابقة'));
              }
              return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                  itemCount: reels.length,
                  itemBuilder: (_, i) {
                    final reel = reels[i];
                    return Card(
                        child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: .15),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: AppTheme.primaryColor)),
                      title:
                          Text(reel.title.isEmpty ? 'بدون عنوان' : reel.title),
                      subtitle: Text(
                          '${_statusLabel(reel.status)} • ${reel.category}\n${reel.views} مشاهدة • ${reel.likes} إعجاب • ${reel.saves} حفظ'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ReelEditorScreen(reel: reel)));
                            }
                            if (value == 'duplicate') await _duplicate(reel);
                            if (value == 'archive') {
                              await FirebaseFirestore.instance
                                  .collection('reels')
                                  .doc(reel.id)
                                  .update({
                                'status': 'archived',
                                'updatedAt': FieldValue.serverTimestamp()
                              });
                            }
                            if (value == 'delete' && context.mounted) {
                              await _delete(context, reel.id);
                            }
                          },
                          itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'edit', child: Text('تعديل')),
                                PopupMenuItem(
                                    value: 'duplicate', child: Text('نسخ')),
                                PopupMenuItem(
                                    value: 'archive', child: Text('أرشفة')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('حذف'))
                              ]),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ReelEditorScreen(reel: reel))),
                    ));
                  });
            },
          )),
        ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReelEditorScreen())),
            icon: const Icon(Icons.add),
            label: const Text('إضافة ريل')),
      );

  Widget _filter(String label, String value, Map<String, String> values,
          ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: values.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          });
  String _statusLabel(ReelStatus status) => const {
        'draft': 'مسودة',
        'scheduled': 'مجدول',
        'published': 'منشور',
        'hidden': 'مخفي',
        'archived': 'مؤرشف',
        'expired': 'منتهي'
      }[status.name]!;
  Future<void> _duplicate(ReelModel reel) =>
      FirebaseFirestore.instance.collection('reels').add({
        'title': '${reel.title} - نسخة',
        'description': reel.description,
        'videoUrl': reel.videoUrl,
        'thumbnailUrl': reel.thumbnailUrl,
        'qualityUrls': reel.qualityUrls,
        'status': 'draft',
        'targetType': reel.targetType.name,
        'propertyId': reel.propertyId,
        'officeId': reel.officeId,
        'category': reel.category,
        'tags': reel.tags,
        'externalUrl': reel.externalUrl,
        'ctaLabel': reel.ctaLabel,
        'isPinned': false,
        'isFeatured': reel.isFeatured,
        'isSponsored': false,
        'sortOrder': reel.sortOrder,
        'views': 0,
        'completions': 0,
        'likes': 0,
        'saves': 0,
        'shares': 0,
        'propertyClicks': 0,
        'externalClicks': 0,
        'reports': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });
  Future<void> _delete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('حذف الريل؟'),
                content: const Text(
                    'سيُحذف السجل نهائيًا. استخدم الأرشفة إذا أردت الاحتفاظ به.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('حذف'))
                ]));
    if (ok == true) {
      await FirebaseFirestore.instance.collection('reels').doc(id).delete();
    }
  }
}

class ReelEditorScreen extends StatefulWidget {
  final ReelModel? reel;
  const ReelEditorScreen({super.key, this.reel});
  @override
  State<ReelEditorScreen> createState() => _ReelEditorScreenState();
}

class _ReelEditorScreenState extends State<ReelEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title,
      _description,
      _video,
      _thumbnail,
      _external,
      _cta,
      _category,
      _tags,
      _sort;
  String _status = 'draft', _target = 'general';
  String? _propertyId, _officeId;
  bool _pinned = false,
      _featured = false,
      _sponsored = false,
      _uploading = false;
  DateTime? _publishAt, _expiresAt;
  @override
  void initState() {
    super.initState();
    final r = widget.reel;
    _title = TextEditingController(text: r?.title);
    _description = TextEditingController(text: r?.description);
    _video = TextEditingController(text: r?.videoUrl);
    _thumbnail = TextEditingController(text: r?.thumbnailUrl);
    _external = TextEditingController(text: r?.externalUrl);
    _cta = TextEditingController(text: r?.ctaLabel ?? 'مشاهدة الفيديو كاملاً');
    _category = TextEditingController(text: r?.category ?? 'عقارات');
    _tags = TextEditingController(text: r?.tags.join(', '));
    _sort = TextEditingController(text: '${r?.sortOrder ?? 0}');
    _status = r?.status.name ?? 'draft';
    _target = r?.targetType.name ?? 'general';
    _propertyId = r?.propertyId;
    _officeId = r?.officeId;
    _pinned = r?.isPinned ?? false;
    _featured = r?.isFeatured ?? false;
    _sponsored = r?.isSponsored ?? false;
    _publishAt = r?.publishAt;
    _expiresAt = r?.expiresAt;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _video,
      _thumbnail,
      _external,
      _cta,
      _category,
      _tags,
      _sort
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ReelService.instance.uploadVideo(
          bytes: await file.readAsBytes(),
          fileName: file.name,
          contentType: file.mimeType ?? 'video/mp4');
      _video.text = url;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر رفع الفيديو. تحقق من إعداد R2 في الخادم.')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<Map<String, dynamic>> _snapshot(String collection, String? id) async {
    if (id == null || id.isEmpty) return {};
    final doc =
        await FirebaseFirestore.instance.collection(collection).doc(id).get();
    final d = doc.data() ?? {};
    return collection == 'properties'
        ? {
            'title': d['title'],
            'location':
                d['location'] ?? '${d['city'] ?? ''} - ${d['areaName'] ?? ''}',
            'area': d['area'],
            'price': d['price'],
            'imageUrl': d['imageUrl']
          }
        : {'name': d['name'], 'logoUrl': d['logoUrl'], 'city': d['city']};
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_target == 'property' && _propertyId == null ||
        _target == 'office' && _officeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر العنصر المرتبط بالريل')));
      return;
    }
    final propertySnapshot = await _snapshot('properties', _propertyId);
    final officeSnapshot = await _snapshot('offices', _officeId);
    final automaticCover = _target == 'property'
        ? (propertySnapshot['imageUrl'] ?? '').toString()
        : (officeSnapshot['logoUrl'] ?? '').toString();
    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'videoUrl': _video.text.trim(),
      'thumbnailUrl': _thumbnail.text.trim().isNotEmpty
          ? _thumbnail.text.trim()
          : automaticCover,
      'qualityUrls': {'auto': _video.text.trim()},
      'status': _status,
      'targetType': _target,
      'propertyId': _target == 'property' ? _propertyId : null,
      'officeId': _target == 'office' ? _officeId : null,
      'category': _category.text.trim(),
      'tags': _tags.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'externalUrl': _external.text.trim(),
      'ctaLabel': _cta.text.trim(),
      'isPinned': _pinned,
      'isFeatured': _featured,
      'isSponsored': _sponsored,
      'publishAt': _publishAt == null ? null : Timestamp.fromDate(_publishAt!),
      'expiresAt': _expiresAt == null ? null : Timestamp.fromDate(_expiresAt!),
      'sortOrder': int.tryParse(_sort.text) ?? 0,
      'propertySnapshot': propertySnapshot,
      'officeSnapshot': officeSnapshot,
      'updatedAt': FieldValue.serverTimestamp()
    };
    final collection = FirebaseFirestore.instance.collection('reels');
    if (widget.reel == null) {
      data.addAll({
        'views': 0,
        'completions': 0,
        'likes': 0,
        'saves': 0,
        'shares': 0,
        'propertyClicks': 0,
        'externalClicks': 0,
        'reports': 0,
        'createdAt': FieldValue.serverTimestamp()
      });
      await collection.add(data);
    } else {
      await collection.doc(widget.reel!.id).update(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(
              title: Text(widget.reel == null ? 'إضافة ريل' : 'تعديل الريل')),
          body: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _field(_title, 'العنوان', required: true),
                _field(_description, 'الوصف', lines: 3),
                Row(children: [
                  Expanded(
                      child:
                          _field(_video, 'رابط الفيديو في R2', required: true)),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: _uploading ? null : _pickVideo,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_rounded))
                ]),
                _field(_thumbnail, 'صورة غلاف الريل (اختياري)',
                    helper:
                        'تظهر قبل تشغيل الفيديو وأثناء التحميل. اتركها فارغة لاستخدام صورة العقار أو شعار المكتب تلقائيًا.'),
                DropdownButtonFormField(
                    initialValue: _target,
                    decoration: const InputDecoration(labelText: 'نوع الربط'),
                    items: const [
                      DropdownMenuItem(
                          value: 'general', child: Text('ريل عام')),
                      DropdownMenuItem(
                          value: 'property', child: Text('مرتبط بعقار')),
                      DropdownMenuItem(
                          value: 'office', child: Text('مرتبط بمكتب'))
                    ],
                    onChanged: (v) => setState(() => _target = v!)),
                const SizedBox(height: 12),
                if (_target == 'property')
                  _documentSelector('properties', _propertyId, 'اختر العقار',
                      (v) => setState(() => _propertyId = v)),
                if (_target == 'office')
                  _documentSelector('offices', _officeId, 'اختر المكتب',
                      (v) => setState(() => _officeId = v)),
                _field(_category, 'التصنيف'),
                _field(_tags, 'كلمات البحث (اختياري)',
                    helper:
                        'تساعدك في البحث والتصنيف داخل الإدارة، مثل: الرمادي، للبيع، بيت. افصل بينها بفاصلة.'),
                _field(_external, 'الرابط الخارجي'),
                _field(_cta, 'نص زر الرابط'),
                _field(_sort, 'الترتيب', keyboard: TextInputType.number),
                DropdownButtonFormField(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const {
                      'draft': 'مسودة',
                      'scheduled': 'مجدول',
                      'published': 'منشور',
                      'hidden': 'مخفي',
                      'archived': 'مؤرشف',
                      'expired': 'منتهي'
                    }
                        .entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v!)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _date('موعد النشر', _publishAt,
                          (v) => setState(() => _publishAt = v))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _date('تاريخ الانتهاء', _expiresAt,
                          (v) => setState(() => _expiresAt = v)))
                ]),
                SwitchListTile(
                    value: _pinned,
                    onChanged: (v) => setState(() => _pinned = v),
                    title: const Text('مثبت')),
                SwitchListTile(
                    value: _featured,
                    onChanged: (v) => setState(() => _featured = v),
                    title: const Text('مميز')),
                SwitchListTile(
                    value: _sponsored,
                    onChanged: (v) => setState(() => _sponsored = v),
                    title: const Text('ممول')),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('حفظ الريل')),
              ]))));
  Widget _field(TextEditingController c, String label,
          {bool required = false,
          int lines = 1,
          TextInputType? keyboard,
          String? helper}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              controller: c,
              maxLines: lines,
              keyboardType: keyboard,
              decoration: InputDecoration(labelText: label, helperText: helper),
              validator: required
                  ? (v) =>
                      v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null
                  : null));
  Widget _documentSelector(String collection, String? value, String label,
          ValueChanged<String?> changed) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(collection)
                  .limit(200)
                  .snapshots(),
              builder: (_, s) {
                final docs = s.data?.docs ?? [];
                final selectedDocs = docs.where((d) => d.id == value).toList();
                final selected =
                    selectedDocs.isEmpty ? null : selectedDocs.first;
                final data = selected?.data();
                final title =
                    (data?['title'] ?? data?['name'] ?? label).toString();
                final detail = collection == 'properties' && data != null
                    ? 'رقم الإعلان: ${data['adNumber'] ?? '-'}  •  ${data['location'] ?? data['city'] ?? ''}'
                    : data == null
                        ? 'اضغط للبحث والاختيار'
                        : '${data['city'] ?? ''}';
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await _showDocumentPicker(
                        collection, label, docs, value);
                    if (picked != null) changed(picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: label,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: const Icon(Icons.arrow_drop_down_rounded)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                );
              }));

  Future<String?> _showDocumentPicker(
      String collection,
      String label,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      String? selectedId) async {
    var query = '';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final normalized = query.trim().toLowerCase();
          final filtered = docs.where((doc) {
            final d = doc.data();
            final searchable = [
              d['title'],
              d['name'],
              d['adNumber'],
              d['propertyNumber'],
              d['location'],
              d['city'],
              d['areaName'],
              d['district'],
              doc.id
            ].whereType<Object>().join(' ').toLowerCase();
            return normalized.isEmpty || searchable.contains(normalized);
          }).toList();
          return FractionallySizedBox(
            heightFactor: .88,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    autofocus: true,
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: InputDecoration(
                      labelText: 'ابحث في $label',
                      hintText: collection == 'properties'
                          ? 'العنوان، رقم الإعلان، المنطقة أو المدينة'
                          : 'اسم المكتب أو المدينة',
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('لا توجد نتائج مطابقة'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final doc = filtered[index];
                            final d = doc.data();
                            final title =
                                (d['title'] ?? d['name'] ?? doc.id).toString();
                            final subtitle = collection == 'properties'
                                ? 'رقم الإعلان: ${d['adNumber'] ?? '-'}  •  ${d['location'] ?? d['city'] ?? ''}'
                                : '${d['city'] ?? ''}';
                            return ListTile(
                              selected: doc.id == selectedId,
                              leading: Icon(collection == 'properties'
                                  ? Icons.home_work_rounded
                                  : Icons.business_rounded),
                              title: Text(title),
                              subtitle: Text(subtitle),
                              trailing: doc.id == selectedId
                                  ? const Icon(Icons.check_circle,
                                      color: AppTheme.primaryColor)
                                  : null,
                              onTap: () => Navigator.pop(sheetContext, doc.id),
                            );
                          }),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _date(String label, DateTime? date, ValueChanged<DateTime?> changed) =>
      OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 1825)));
            if (d != null && mounted) {
              final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(date ?? DateTime.now()));
              changed(DateTime(
                  d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0));
            }
          },
          icon: const Icon(Icons.event),
          label: Text(date == null
              ? label
              : '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'));
}

class _ReelsAnalytics extends StatelessWidget {
  const _ReelsAnalytics();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('reels').snapshots(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          int total(String key) => docs.fold(
              0,
              (current, doc) =>
                  current + ((doc.data()[key] as num?)?.toInt() ?? 0));
          final metrics = <String, int>{
            'الريلز': docs.length,
            'المشاهدات': total('views'),
            'الإكمال': total('completions'),
            'الإعجابات': total('likes'),
            'الحفظ': total('saves'),
            'المشاركات': total('shares'),
            'ضغطات العقارات': total('propertyClicks'),
            'ضغطات الروابط': total('externalClicks'),
          };
          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            childAspectRatio: 1.5,
            children: metrics.entries
                .map((entry) => Card(
                        child: Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                          Text('${entry.value}',
                              style: const TextStyle(
                                  fontSize: 28,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold)),
                          Text(entry.key)
                        ]))))
                .toList(),
          );
        },
      );
}

class _ReelsReports extends StatelessWidget {
  const _ReelsReports();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reel_reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد بلاغات'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data();
              final reelId = (data['reelId'] ?? '').toString();
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: reelId.isEmpty
                    ? null
                    : FirebaseFirestore.instance
                        .collection('reels')
                        .doc(reelId)
                        .get(),
                builder: (context, reelSnapshot) {
                  final reelData = reelSnapshot.data?.data();
                  final reelTitle = (data['reelTitle'] ??
                          reelData?['title'] ??
                          'ريل غير متوفر')
                      .toString();
                  final details = (data['details'] ?? '').toString();
                  final status = (data['status'] ?? 'open').toString();
                  final statusLabel = const {
                        'open': 'جديد',
                        'reviewed': 'تمت المراجعة',
                        'dismissed': 'مرفوض',
                        'actioned': 'تم اتخاذ إجراء'
                      }[status] ??
                      status;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.flag_rounded, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(reelTitle,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                            Chip(label: Text(statusLabel)),
                          ]),
                          const SizedBox(height: 8),
                          Text('سبب البلاغ: ${data['reason'] ?? 'غير محدد'}'),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('التوضيح: $details'),
                          ],
                          const SizedBox(height: 5),
                          SelectableText('معرّف الريل: $reelId',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: reelSnapshot.data?.exists == true
                                    ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReelsScreen(
                                                initialReelId: reelId),
                                          ),
                                        )
                                    : null,
                                icon: const Icon(Icons.play_circle_rounded),
                                label: const Text('عرض الريل ومراجعته'),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'تغيير حالة البلاغ',
                              onSelected: (value) => doc.reference.update({
                                'status': value,
                                'resolvedAt': FieldValue.serverTimestamp()
                              }),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'reviewed',
                                    child: Text('تمت المراجعة')),
                                PopupMenuItem(
                                    value: 'dismissed',
                                    child: Text('رفض البلاغ')),
                                PopupMenuItem(
                                    value: 'actioned',
                                    child: Text('تم اتخاذ إجراء')),
                              ],
                            ),
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      );
}

class _ReelsSettings extends StatefulWidget {
  const _ReelsSettings();
  @override
  State<_ReelsSettings> createState() => _ReelsSettingsState();
}

class _ReelsSettingsState extends State<_ReelsSettings> {
  final _duration = TextEditingController(text: '15');
  final _preload = TextEditingController(text: '2');
  bool _autoplay = true;
  bool _defaultMuted = false;
  bool _reports = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('reels')
        .get();
    final data = doc.data() ?? const <String, dynamic>{};
    _duration.text = '${data['maxDurationSeconds'] ?? 15}';
    _preload.text = '${data['preloadCount'] ?? 2}';
    if (mounted) {
      setState(() {
        _autoplay = data['autoplay'] != false;
        _defaultMuted = data['defaultMuted'] == true;
        _reports = data['reportsEnabled'] != false;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(
          controller: _duration,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'المدة القصوى بالثواني')),
      const SizedBox(height: 12),
      TextField(
          controller: _preload,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'عدد الفيديوهات المحملة مسبقًا')),
      SwitchListTile(
          value: _autoplay,
          onChanged: (value) => setState(() => _autoplay = value),
          title: const Text('التشغيل التلقائي')),
      SwitchListTile(
          value: _defaultMuted,
          onChanged: (value) => setState(() => _defaultMuted = value),
          title: const Text('كتم الصوت افتراضيًا')),
      SwitchListTile(
          value: _reports,
          onChanged: (value) => setState(() => _reports = value),
          title: const Text('تفعيل البلاغات')),
      ElevatedButton(onPressed: _save, child: const Text('حفظ الإعدادات')),
    ]);
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance.collection('settings').doc('reels').set({
      'maxDurationSeconds': int.tryParse(_duration.text) ?? 15,
      'preloadCount': int.tryParse(_preload.text) ?? 2,
      'autoplay': _autoplay,
      'defaultMuted': _defaultMuted,
      'reportsEnabled': _reports,
      'qualities': ['auto', '360p', '720p', '1080p'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
