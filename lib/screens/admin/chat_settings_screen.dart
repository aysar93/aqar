import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../chat/models/chat_preferences.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});
  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final _away = TextEditingController();
  final List<TextEditingController> _replies = [];
  bool _loading = true, _saving = false, _voice = true, _hours = false;
  String? _error;
  int _seconds = 120, _deleteHours = 24, _open = 540, _close = 1080;
  Set<int> _days = {1, 2, 3, 4, 6, 7};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .get();
      final p = ChatPreferences.fromMap(doc.data()?['chatPreferences'] is Map
          ? Map<String, dynamic>.from(doc.data()!['chatPreferences'])
          : null);
      if (!mounted) return;
      setState(() {
        _voice = p.voiceEnabled;
        _seconds = p.voiceSeconds;
        _deleteHours = p.deleteHours;
        _hours = p.hoursEnabled;
        _open = p.openingMinute;
        _close = p.closingMinute;
        _days = p.workDays.toSet();
        _away.text = p.awayMessage;
        _replies.addAll(
            p.quickReplies.map((text) => TextEditingController(text: text)));
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل الإعدادات';
        });
      }
    }
  }

  Future<void> _time(bool opening) async {
    final value = opening ? _open : _close;
    final result = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60));
    if (mounted && result != null) {
      setState(() {
        if (opening) {
          _open = result.hour * 60 + result.minute;
        } else {
          _close = result.hour * 60 + result.minute;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_hours &&
        (_days.isEmpty || _open == _close || _away.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'حدد أيام العمل ووقت بداية ونهاية مختلفين ورسالة خارج الدوام')));
      return;
    }
    setState(() => _saving = true);
    final preferences = ChatPreferences(
        voiceEnabled: _voice,
        voiceSeconds: _seconds,
        deleteHours: _deleteHours,
        hoursEnabled: _hours,
        openingMinute: _open,
        closingMinute: _close,
        workDays: _days.toList()..sort(),
        awayMessage: _away.text.trim(),
        quickReplies: _replies
            .map((controller) => controller.text.trim())
            .where((text) => text.isNotEmpty)
            .toList());
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .set({'chatPreferences': preferences.toMap()},
              SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ إعدادات الدردشة')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر الحفظ. تحقق من صلاحيات الإدارة والاتصال')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _away.dispose();
    for (final controller in _replies) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37), surface = Color(0xFF1E293B);
    final days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
            data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                    primary: gold, secondary: gold, surface: surface)),
            child: Scaffold(
              backgroundColor: const Color(0xFF0F172A),
              appBar: AppBar(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  title: const Text('إعدادات المحادثات')),
              bottomNavigationBar: _loading || _error != null
                  ? null
                  : SafeArea(
                      minimum: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                              onPressed: _saving ? null : _save,
                              child: Text(
                                  _saving ? 'جارٍ الحفظ…' : 'حفظ الإعدادات')))),
              body: _loading
                  ? const Center(child: CircularProgressIndicator(color: gold))
                  : _error != null
                      ? Center(
                          child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _error = null;
                                });
                                _load();
                              },
                              child: Text('$_error • إعادة المحاولة')))
                      : ListView(
                          padding: EdgeInsets.fromLTRB(18, 18, 18,
                              24 + MediaQuery.paddingOf(context).bottom),
                          children: [
                              const Text('الرسائل والحذف',
                                  style: TextStyle(
                                      color: gold,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              ListTile(
                                  title:
                                      const Text('مهلة حذف الرسالة لدى الجميع'),
                                  subtitle: const Text(
                                      'تُطبق على المرسل بوقت الخادم. الإدارة تستطيع الحذف للإشراف.'),
                                  trailing: DropdownButton<int>(
                                      value: _deleteHours,
                                      items: ({
                                        1,
                                        6,
                                        12,
                                        24,
                                        48,
                                        72,
                                        168,
                                        _deleteHours
                                      }.toList()
                                            ..sort())
                                          .map((v) => DropdownMenuItem(
                                              value: v, child: Text('$v ساعة')))
                                          .toList(),
                                      onChanged: _saving
                                          ? null
                                          : (v) => setState(
                                              () => _deleteHours = v!))),
                              SwitchListTile(
                                  activeThumbColor: gold,
                                  value: _voice,
                                  title: const Text('الرسائل الصوتية'),
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(() => _voice = v)),
                              ListTile(
                                  title: const Text('أقصى مدة للتسجيل'),
                                  trailing: DropdownButton<int>(
                                      value: _seconds,
                                      items: ({30, 60, 120, 180, 300, _seconds}
                                              .toList()
                                            ..sort())
                                          .map((v) => DropdownMenuItem(
                                              value: v,
                                              child: Text('$v ثانية')))
                                          .toList(),
                                      onChanged: _saving
                                          ? null
                                          : (v) =>
                                              setState(() => _seconds = v!))),
                              const Divider(color: Colors.white10),
                              const Text('التوفر ووقت العمل',
                                  style: TextStyle(
                                      color: gold,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              SwitchListTile(
                                  activeThumbColor: gold,
                                  value: _hours,
                                  title: const Text(
                                      'جدول العمل والرد خارج الدوام'),
                                  subtitle: const Text('بتوقيت بغداد'),
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(() => _hours = v)),
                              if (_hours) ...[
                                Wrap(spacing: 6, children: [
                                  for (var i = 0; i < days.length; i++)
                                    FilterChip(
                                        selected: _days.contains(i + 1),
                                        label: Text(days[i]),
                                        onSelected: _saving
                                            ? null
                                            : (v) => setState(() {
                                                  if (v) {
                                                    _days.add(i + 1);
                                                  } else {
                                                    _days.remove(i + 1);
                                                  }
                                                }))
                                ]),
                                ListTile(
                                    title: const Text('بداية العمل'),
                                    trailing:
                                        Text(ChatPreferences.clock(_open)),
                                    onTap: _saving ? null : () => _time(true)),
                                ListTile(
                                    title: const Text('نهاية العمل'),
                                    trailing:
                                        Text(ChatPreferences.clock(_close)),
                                    onTap: _saving ? null : () => _time(false)),
                                TextField(
                                    controller: _away,
                                    enabled: !_saving,
                                    minLines: 2,
                                    maxLines: 4,
                                    maxLength: 1000,
                                    decoration: const InputDecoration(
                                        labelText: 'الرد التلقائي خارج الدوام',
                                        helperText:
                                            'يُرسل من الخادم مرة واحدة يومياً عند التواصل خارج الدوام')),
                              ],
                              const Divider(color: Colors.white10),
                              const Text('الردود الجاهزة للإدارة',
                                  style: TextStyle(
                                      color: gold,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              for (var i = 0; i < _replies.length; i++)
                                Row(children: [
                                  Expanded(
                                      child: TextField(
                                          controller: _replies[i],
                                          enabled: !_saving,
                                          maxLength: 500,
                                          decoration: InputDecoration(
                                              labelText: 'رد ${i + 1}'))),
                                  IconButton(
                                      tooltip: 'نقل لأعلى',
                                      onPressed: !_saving && i > 0
                                          ? () => setState(() {
                                                final item =
                                                    _replies.removeAt(i);
                                                _replies.insert(i - 1, item);
                                              })
                                          : null,
                                      icon: const Icon(Icons.arrow_upward,
                                          size: 18)),
                                  IconButton(
                                      tooltip: 'حذف الرد',
                                      onPressed: _saving
                                          ? null
                                          : () {
                                              final controller = _replies[i];
                                              setState(
                                                  () => _replies.removeAt(i));
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) =>
                                                      controller.dispose());
                                            },
                                      icon: const Icon(Icons.delete_outline,
                                          color: gold)),
                                ]),
                              TextButton.icon(
                                  onPressed: !_saving && _replies.length < 30
                                      ? () => setState(() =>
                                          _replies.add(TextEditingController()))
                                      : null,
                                  icon: const Icon(Icons.add),
                                  label: const Text('إضافة رد جاهز')),
                              const SizedBox(height: 20),
                            ]),
            )));
  }
}
