import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'widgets/search_bar_widget.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  static const _bg = Color(0xff0F172A);
  static const _card = Color(0xff1E293B);
  static const _gold = Color(0xffD4AF37);

  final TextEditingController searchController = TextEditingController();

  String _search = '';
  String _filter = 'all';
  bool _busy = false;

  String _stringValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  String _userName(Map<String, dynamic> data) {
    return _stringValue(data, const [
      'name',
      'displayName',
      'fullName',
      'userName',
      'username',
    ]);
  }

  String _userPhone(Map<String, dynamic> data) {
    return _stringValue(data, const [
      'phone',
      'phoneNumber',
      'mobile',
    ]);
  }

  String _userEmail(Map<String, dynamic> data) {
    return _stringValue(data, const ['email']);
  }

  String _userImage(Map<String, dynamic> data) {
    return _stringValue(data, const [
      'photoUrl',
      'photoURL',
      'profileImageUrl',
      'profileImage',
      'imageUrl',
      'avatarUrl',
      'photo',
    ]);
  }

  String _normalizeArabicDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(arabic[i], '$i');
      result = result.replaceAll(persian[i], '$i');
    }
    return result;
  }

  String _normalizePhone(String value) {
    var phone = _normalizeArabicDigits(value).replaceAll(
      RegExp(r'[\s\-\(\)]'),
      '',
    );

    if (phone.startsWith('+964')) {
      phone = phone.substring(4);
    } else if (phone.startsWith('00964')) {
      phone = phone.substring(5);
    } else if (phone.startsWith('964')) {
      phone = phone.substring(3);
    }

    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    return phone;
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return true;

    final name = _userName(data).toLowerCase();
    final email = _userEmail(data).toLowerCase();
    final phone = _normalizePhone(_userPhone(data));
    final normalizedQuery = _normalizeArabicDigits(query).toLowerCase();
    final queryPhone = _normalizePhone(normalizedQuery);

    return name.contains(normalizedQuery) ||
        email.contains(normalizedQuery) ||
        _userPhone(data).toLowerCase().contains(normalizedQuery) ||
        (queryPhone.isNotEmpty && phone.contains(queryPhone));
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final isAdmin = data['isAdmin'] == true;

    switch (_filter) {
      case 'admins':
        return isAdmin;
      case 'users':
        return !isAdmin;
      default:
        return true;
    }
  }

  Future<void> _setAdmin(
    DocumentSnapshot user,
    bool value,
  ) async {
    if (_busy) return;

    final data = user.data() as Map<String, dynamic>? ?? {};
    final name = _userName(data);
    final action = value ? 'تعيين هذا المستخدم كمدير؟' : 'إزالة صلاحية المدير؟';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              value ? 'تعيين كمدير' : 'إزالة صلاحية المدير',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              '$action\n\n${name.isEmpty ? 'هذا المستخدم' : name}',
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: value ? _gold : Colors.redAccent,
                  foregroundColor: value ? Colors.black : Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(value ? 'تعيين' : 'إزالة'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    try {
      await user.reference.set(
        {
          'isAdmin': value,
          'adminUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: value ? const Color(0xff166534) : _card,
          content: Text(
            value
                ? 'تم تعيين ${name.isEmpty ? 'المستخدم' : name} كمدير بنجاح'
                : 'تمت إزالة صلاحية المدير من ${name.isEmpty ? 'المستخدم' : name}',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade900,
          content: Text(
            e.code == 'permission-denied'
                ? 'لا تملك صلاحية تنفيذ هذا الإجراء. تأكد من أن حساب الأدمن الحالي يحمل isAdmin = true في Firestore.'
                : 'تعذر تحديث صلاحية المستخدم: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade900,
          content: Text('حدث خطأ أثناء تحديث صلاحية المدير: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteUser(DocumentSnapshot user) async {
    if (_busy) return;

    final data = user.data() as Map<String, dynamic>? ?? {};
    final name = _userName(data);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'حذف المستخدم',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              'هل أنت متأكد من حذف ${name.isEmpty ? 'هذا المستخدم' : name}؟\n\n'
              'سيتم حذف سجل المستخدم من Firestore',
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    try {
      await user.reference.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('تم حذف المستخدم بنجاح'),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade900,
          content: Text('تعذر حذف المستخدم: ${e.message ?? e.code}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _buildAvatar(Map<String, dynamic> data) {
    final imageUrl = _userImage(data);
    final name = _userName(data);
    final firstLetter = name.isNotEmpty ? name.characters.first : 'م';

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _gold.withValues(alpha: .14),
        border: Border.all(
          color: _gold.withValues(alpha: .28),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackAvatar(firstLetter),
            )
          : _fallbackAvatar(firstLetter),
    );
  }

  Widget _fallbackAvatar(String letter) {
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: _gold,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _filter = value);
      },
      selectedColor: _gold,
      backgroundColor: _card,
      side: BorderSide(
        color: selected ? _gold : Colors.white.withValues(alpha: .08),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontWeight: FontWeight.w800,
        fontSize: 11,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'إدارة المستخدمين',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          actions: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'تعذر تحميل المستخدمين\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final allDocs = snapshot.data?.docs ?? const [];
            final docs = allDocs.where((doc) {
              final data = doc.data();
              return _matchesSearch(data) && _matchesFilter(data);
            }).toList();

            final adminCount = allDocs.where((doc) {
              return doc.data()['isAdmin'] == true;
            }).length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SearchBarWidget(
                    controller: searchController,
                    hintText: 'ابحث بالاسم أو الهاتف أو البريد ',
                    onChanged: (value) {
                      setState(() => _search = value.trim());
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'إجمالي المستخدمين',
                          value: '${allDocs.length}',
                          icon: Icons.people_alt_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          title: 'المديرون',
                          value: '$adminCount',
                          icon: Icons.admin_panel_settings_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('all', 'الكل'),
                      const SizedBox(width: 8),
                      _buildFilterChip('users', 'المستخدمون'),
                      const SizedBox(width: 8),
                      _buildFilterChip('admins', 'المديرون'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: docs.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد نتائج مطابقة',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final user = docs[index];
                            final data = user.data();

                            final name = _userName(data);
                            final phone = _userPhone(data);
                            final email = _userEmail(data);
                            final isAdmin = data['isAdmin'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isAdmin
                                      ? _gold.withValues(alpha: .24)
                                      : Colors.white.withValues(alpha: .06),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(11),
                                child: Row(
                                  children: [
                                    _buildAvatar(data),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name.isEmpty
                                                      ? 'مستخدم بدون اسم'
                                                      : name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 7),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isAdmin
                                                      ? _gold.withValues(
                                                          alpha: .14,
                                                        )
                                                      : Colors.white.withValues(
                                                          alpha: .06,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  isAdmin ? 'مدير' : 'مستخدم',
                                                  style: TextStyle(
                                                    color: isAdmin
                                                        ? _gold
                                                        : Colors.white54,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (phone.isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Text(
                                              phone,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                          if (email.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    PopupMenuButton<String>(
                                      tooltip: 'إدارة المستخدم',
                                      color: _card,
                                      enabled: !_busy,
                                      icon: const Icon(
                                        Icons.more_vert_rounded,
                                        color: Colors.white60,
                                      ),
                                      onSelected: (value) {
                                        if (value == 'admin') {
                                          _setAdmin(user, true);
                                        } else if (value == 'user') {
                                          _setAdmin(user, false);
                                        } else if (value == 'delete') {
                                          _deleteUser(user);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'admin',
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons
                                                    .admin_panel_settings_outlined,
                                                color: _gold,
                                                size: 19,
                                              ),
                                              const SizedBox(width: 9),
                                              Text(
                                                isAdmin
                                                    ? 'المدير مفعل'
                                                    : 'تعيين كمدير',
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isAdmin)
                                          const PopupMenuItem(
                                            value: 'user',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.person_remove_outlined,
                                                  color: Colors.orangeAccent,
                                                  size: 19,
                                                ),
                                                SizedBox(width: 9),
                                                Text(
                                                  'إزالة صلاحية المدير',
                                                ),
                                              ],
                                            ),
                                          ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 19,
                                              ),
                                              SizedBox(width: 9),
                                              Text('حذف المستخدم'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xff1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffD4AF37).withValues(alpha: .10),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 2),
          Icon(
            icon,
            color: const Color(0xffD4AF37),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
