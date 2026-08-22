import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  static const _background = Color(0xFF0F172A);
  static const _card = Color(0xFF1E293B);
  static const _gold = Color(0xFFD4AF37);

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _propertySearchController = TextEditingController();
  final _officeSearchController = TextEditingController();

  String _notificationType = 'general';
  String _deliveryType = 'external';
  bool _sendToAll = true;
  String _search = '';
  String _propertySearch = '';
  String _officeSearch = '';

  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedPropertyId;
  String? _selectedPropertyTitle;
  String? _selectedOfficeId;
  String? _selectedOfficeName;

  bool _sending = false;

  bool get _hasDestination =>
      (_notificationType == 'property' && _selectedPropertyId != null) ||
      (_notificationType == 'office' && _selectedOfficeId != null) ||
      _notificationType == 'general' ||
      _notificationType == 'account';

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      _show('أدخل عنوان ونص التنبيه أولاً');
      return;
    }

    if (!_sendToAll && (_selectedUserId == null || _selectedUserId!.isEmpty)) {
      _show('اختر المستخدم الذي تريد إرسال التنبيه إليه');
      return;
    }

    if (!_hasDestination) {
      _show(
        _notificationType == 'property'
            ? 'اختر العقار المرتبط بالتنبيه'
            : 'اختر المكتب المرتبط بالتنبيه',
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await NotificationService.sendNotification(
        title: title,
        message: message,
        type: _notificationType,
        target: _sendToAll ? 'all' : 'user',
        userId: _selectedUserId ?? '',
        propertyId: _selectedPropertyId ?? '',
        officeId: _selectedOfficeId ?? '',
        deliveryType: _deliveryType,
      );

      if (!mounted) return;

      _titleController.clear();
      _messageController.clear();

      setState(() {
        _selectedPropertyId = null;
        _selectedPropertyTitle = null;
        _selectedOfficeId = null;
        _selectedOfficeName = null;
        _selectedUserId = null;
        _selectedUserName = null;
      });

      _show(
        _deliveryType == 'external'
            ? 'تم إرسال التنبيه داخل التطبيق وخارجه'
            : 'تم إرسال التنبيه داخل التطبيق فقط',
      );
    } catch (e) {
      if (mounted) {
        _show('تعذر إرسال التنبيه');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text('إرسال تنبيه'),
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 34,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _section(
                        title: 'طريقة الإرسال',
                        child: Row(
                          children: [
                            Expanded(
                              child: _modeCard(
                                selected: _deliveryType == 'external',
                                icon: Icons.notifications_active_outlined,
                                title: 'إشعار خارجي',
                                subtitle: 'الهاتف + داخل التطبيق',
                                onTap: () => setState(
                                  () => _deliveryType = 'external',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _modeCard(
                                selected: _deliveryType == 'internal',
                                icon: Icons.notifications_none,
                                title: 'إشعار داخلي',
                                subtitle: 'داخل التطبيق فقط',
                                onTap: () => setState(
                                  () => _deliveryType = 'internal',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        title: 'المستلمون',
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('الجميع'),
                              icon: Icon(Icons.groups_outlined),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('مستخدم'),
                              icon: Icon(Icons.person_outline),
                            ),
                          ],
                          selected: {_sendToAll},
                          onSelectionChanged: (value) {
                            setState(() {
                              _sendToAll = value.first;
                              _selectedUserId = null;
                              _selectedUserName = null;
                            });
                          },
                        ),
                      ),
                      if (!_sendToAll) ...[
                        const SizedBox(height: 12),
                        _buildUserPicker(),
                      ],
                      const SizedBox(height: 12),
                      _section(
                        title: 'محتوى التنبيه',
                        child: Column(
                          children: [
                            TextField(
                              controller: _titleController,
                              textInputAction: TextInputAction.next,
                              decoration: _decoration('عنوان التنبيه'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _messageController,
                              maxLines: 4,
                              decoration: _decoration('نص التنبيه'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        title: 'نوع التنبيه',
                        child: DropdownButtonFormField<String>(
                          initialValue: _notificationType,
                          dropdownColor: _card,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration('نوع التنبيه'),
                          items: const [
                            DropdownMenuItem(
                              value: 'general',
                              child: Text('📢 عام'),
                            ),
                            DropdownMenuItem(
                              value: 'property',
                              child: Text('🏠 عقار'),
                            ),
                            DropdownMenuItem(
                              value: 'office',
                              child: Text('🏢 مكتب'),
                            ),
                            DropdownMenuItem(
                              value: 'account',
                              child: Text('👤 حساب'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _notificationType = value;
                              _selectedPropertyId = null;
                              _selectedPropertyTitle = null;
                              _selectedOfficeId = null;
                              _selectedOfficeName = null;
                            });
                          },
                        ),
                      ),
                      if (_notificationType == 'property') ...[
                        const SizedBox(height: 12),
                        _buildPropertyPicker(),
                      ],
                      if (_notificationType == 'office') ...[
                        const SizedBox(height: 12),
                        _buildOfficePicker(),
                      ],
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _sending ? null : _sendNotification,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _sending ? 'جارٍ الإرسال...' : 'إرسال التنبيه',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: _gold.withValues(alpha: .35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUserPicker() {
    return _section(
      title: 'اختيار المستخدم',
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _search = value.trim().toLowerCase());
            },
            decoration: _decoration(
              'بحث بالاسم أو الهاتف أو البريد',
            ).copyWith(
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return const Text('تعذر تحميل المستخدمين');
              }

              final docs = snapshot.data?.docs ?? [];
              final users = docs
                  .where((doc) {
                    final d = doc.data();
                    if (_search.isEmpty) return true;
                    final name = '${d['name'] ?? ''}'.toLowerCase();
                    final phone = '${d['phone'] ?? ''}'.toLowerCase();
                    final email = '${d['email'] ?? ''}'.toLowerCase();
                    return name.contains(_search) ||
                        phone.contains(_search) ||
                        email.contains(_search);
                  })
                  .take(30)
                  .toList();

              if (users.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد نتائج مطابقة'),
                );
              }

              return SizedBox(
                height: 220,
                child: ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final d = doc.data();
                    final name = '${d['name'] ?? 'مستخدم'}'.trim();
                    final phone = '${d['phone'] ?? ''}'.trim();
                    final image = '${d['photoUrl'] ?? d['imageUrl'] ?? ''}';

                    return ListTile(
                      dense: true,
                      selected: _selectedUserId == doc.id,
                      leading: CircleAvatar(
                        backgroundImage:
                            image.isNotEmpty ? NetworkImage(image) : null,
                        child: image.isEmpty
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedUserId = doc.id;
                          _selectedUserName = name;
                        });
                      },
                    );
                  },
                ),
              );
            },
          ),
          if (_selectedUserName != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'المحدد: $_selectedUserName',
                style: const TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPropertyPicker() {
    return _searchableReferencePicker(
      title: 'اختيار العقار',
      collection: 'properties',
      icon: Icons.home_work_outlined,
      searchController: _propertySearchController,
      searchValue: _propertySearch,
      searchHint: 'رقم الإعلان أو العنوان أو المدينة',
      selectedId: _selectedPropertyId,
      selectedLabel: _selectedPropertyTitle,
      matches: (d, docId, query) {
        final q = query.trim().toLowerCase();
        if (q.isEmpty) return true;
        final values = [
          docId,
          d['propertyNumber'],
          d['adNumber'],
          d['title'],
          d['propertyTitle'],
          d['city'],
          d['location'],
          d['areaName'],
        ].map((v) => '$v'.toLowerCase());
        return values.any((v) => v.contains(q));
      },
      labelBuilder: (d) {
        final number = d['adNumber'] ?? d['propertyNumber'] ?? '';
        final title = d['title'] ?? d['propertyTitle'] ?? 'عقار';
        final city = d['city'] ?? '';
        return number.toString().trim().isEmpty
            ? '$title ${city.toString().trim().isEmpty ? '' : '• $city'}'
            : 'إعلان $number • $title ${city.toString().trim().isEmpty ? '' : '• $city'}';
      },
      onSearch: (v) => setState(() => _propertySearch = v),
      onSelected: (id, label) {
        setState(() {
          _selectedPropertyId = id;
          _selectedPropertyTitle = label;
        });
      },
      onClear: () => setState(() {
        _selectedPropertyId = null;
        _selectedPropertyTitle = null;
      }),
    );
  }

  Widget _buildOfficePicker() {
    return _searchableReferencePicker(
      title: 'اختيار المكتب',
      collection: 'offices',
      icon: Icons.business_outlined,
      searchController: _officeSearchController,
      searchValue: _officeSearch,
      searchHint: 'اسم المكتب أو معرف المكتب',
      selectedId: _selectedOfficeId,
      selectedLabel: _selectedOfficeName,
      matches: (d, docId, query) {
        final q = query.trim().toLowerCase();
        if (q.isEmpty) return true;
        final values = [
          docId,
          d['name'],
          d['officeName'],
          d['officeId'],
        ].map((v) => '$v'.toLowerCase());
        return values.any((v) => v.contains(q));
      },
      labelBuilder: (d) => '${d['name'] ?? d['officeName'] ?? 'مكتب'}',
      onSearch: (v) => setState(() => _officeSearch = v),
      onSelected: (id, label) {
        setState(() {
          _selectedOfficeId = id;
          _selectedOfficeName = label;
        });
      },
      onClear: () => setState(() {
        _selectedOfficeId = null;
        _selectedOfficeName = null;
      }),
    );
  }

  Widget _searchableReferencePicker({
    required String title,
    required String collection,
    required IconData icon,
    required TextEditingController searchController,
    required String searchValue,
    required String searchHint,
    required String? selectedId,
    required String? selectedLabel,
    required bool Function(Map<String, dynamic>, String, String) matches,
    required String Function(Map<String, dynamic>) labelBuilder,
    required ValueChanged<String> onSearch,
    required void Function(String, String) onSelected,
    required VoidCallback onClear,
  }) {
    return _section(
      title: title,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(collection).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return const Text('تعذر تحميل البيانات');
          }
          final docs = snapshot.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final filtered = docs
              .where((doc) => matches(doc.data(), doc.id, searchValue))
              .take(50)
              .toList();

          return Column(
            children: [
              TextField(
                controller: searchController,
                onChanged: onSearch,
                textDirection: TextDirection.rtl,
                decoration: _decoration(searchHint).copyWith(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchValue.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            searchController.clear();
                            onSearch('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (selectedLabel != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _gold.withValues(alpha: .25)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: _gold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: onClear,
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('لا توجد نتائج مطابقة للبحث'),
                )
              else
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final label = labelBuilder(doc.data()).trim();
                      return ListTile(
                        dense: true,
                        selected: selectedId == doc.id,
                        leading: Icon(icon, color: _gold, size: 21),
                        title: Text(label,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: collection == 'offices'
                            ? Text('المعرف: ${doc.id}',
                                maxLines: 1, overflow: TextOverflow.ellipsis)
                            : Text('المعرف: ${doc.id}',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: selectedId == doc.id
                            ? const Icon(Icons.check_circle,
                                color: _gold, size: 20)
                            : null,
                        onTap: () => onSelected(doc.id, label),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: .06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _modeCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? _gold.withValues(alpha: .12)
              : Colors.white.withValues(alpha: .025),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? _gold.withValues(alpha: .65)
                : Colors.white.withValues(alpha: .07),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 23,
              color: selected ? _gold : Colors.white70,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.white.withValues(alpha: .62),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: .025),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: .08),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: .08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _gold),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _propertySearchController.dispose();
    _officeSearchController.dispose();
    super.dispose();
  }
}
