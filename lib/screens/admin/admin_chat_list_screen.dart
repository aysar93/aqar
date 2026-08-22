import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:aqar/chat/utils/time_formatter.dart';
import 'admin_chat_screen.dart';
import '../my_properties_screen.dart';

class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  static const _background = Color(0xff0F172A);
  static const _card = Color(0xff1E293B);
  static const _gold = Color(0xffD4AF37);

  String _search = '';
  int _tab = 0;
  late Future<Map<String, Map<String, dynamic>>> _usersFuture;

  Query<Map<String, dynamic>> get _chatsQuery => FirebaseFirestore.instance
      .collection('chats')
      .orderBy('updatedAt', descending: true);

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<Map<String, Map<String, dynamic>>> _loadUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    return {
      for (final doc in snapshot.docs) doc.id: doc.data(),
    };
  }

  String _firstNonEmpty(Iterable<dynamic> values, [String fallback = '']) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String _userName(
    Map<String, dynamic> chat,
    Map<String, dynamic>? user,
  ) {
    return _firstNonEmpty([
      user?['name'],
      user?['displayName'],
      user?['fullName'],
      user?['userName'],
      user?['username'],
      chat['userName'],
    ], 'مستخدم');
  }

  String _userPhone(
    Map<String, dynamic> chat,
    Map<String, dynamic>? user,
  ) {
    return _firstNonEmpty([
      user?['phoneNumber'],
      user?['phone'],
      user?['mobile'],
      chat['userPhone'],
    ]);
  }

  String _userImage(Map<String, dynamic>? user) {
    return _firstNonEmpty([
      user?['photoUrl'],
      user?['photoURL'],
      user?['profileImageUrl'],
      user?['profileImage'],
      user?['imageUrl'],
      user?['avatarUrl'],
      user?['photo'],
    ]);
  }

  String _normalizeText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي');
  }

  String _normalizePhone(String value) {
    var result = value
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
    result = result.replaceAll(RegExp(r'[^0-9+]'), '');
    if (result.startsWith('+964')) result = '0${result.substring(4)}';
    if (result.startsWith('964')) result = '0${result.substring(3)}';
    return result;
  }

  bool _matches(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, Map<String, dynamic>> users,
  ) {
    final data = doc.data();
    final userId = (data['userId'] ?? doc.id).toString();
    final user = users[userId];

    final name = _normalizeText(_userName(data, user));
    final phone = _normalizePhone(_userPhone(data, user));
    final queryText = _normalizeText(_search);
    final queryPhone = _normalizePhone(_search);

    if (_search.trim().isNotEmpty) {
      final nameMatch = name.contains(queryText);
      final phoneMatch = queryPhone.isNotEmpty && phone.contains(queryPhone);
      if (!nameMatch && !phoneMatch) return false;
    }

    final archived = data['isArchived'] == true;
    final pinned = data['isPinned'] == true;
    final unread = (data['unreadAdmin'] as num?)?.toInt() ?? 0;

    if (_tab == 1 && unread == 0) return false;
    if (_tab == 2 && !pinned) return false;
    if (_tab == 3 && !archived) return false;
    if (_tab != 3 && archived) return false;

    return true;
  }

  Map<String, dynamic> _enrichedChat(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, Map<String, dynamic>> users,
  ) {
    final data = Map<String, dynamic>.from(doc.data());
    final userId = (data['userId'] ?? doc.id).toString();
    final user = users[userId];
    data['userId'] = userId;
    data['userName'] = _userName(data, user);
    data['userPhone'] = _userPhone(data, user);
    data['userPhoto'] = _userImage(user);
    return data;
  }

  void _openChat(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, Map<String, dynamic>> users,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminChatScreen(
          userId: doc.id,
          chatData: _enrichedChat(doc, users),
        ),
      ),
    );
  }

  void _openUserProperties(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, Map<String, dynamic>> users,
  ) {
    final data = _enrichedChat(doc, users);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyPropertiesScreen(
          targetUserId: data['userId'].toString(),
          targetUserName: data['userName'].toString(),
          readOnly: true,
        ),
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
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleSpacing: 18,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المحادثات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'إدارة محادثات المستخدمين',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildSearch(),
            _buildFilters(),
            Expanded(
              child: FutureBuilder<Map<String, Map<String, dynamic>>>(
                future: _usersFuture,
                builder: (context, usersSnapshot) {
                  final users =
                      usersSnapshot.data ?? <String, Map<String, dynamic>>{};

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _chatsQuery.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: _gold),
                        );
                      }

                      if (snapshot.hasError) {
                        return _emptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'تعذر تحميل المحادثات',
                          subtitle: 'تحقق من اتصال الإنترنت وقواعد Firestore',
                        );
                      }

                      final docs = snapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      final filtered =
                          docs.where((doc) => _matches(doc, users)).toList();

                      filtered.sort((a, b) {
                        final ad = a.data();
                        final bd = b.data();
                        final ap = ad['isPinned'] == true ? 1 : 0;
                        final bp = bd['isPinned'] == true ? 1 : 0;
                        if (ap != bp) return bp.compareTo(ap);

                        final au = (ad['unreadAdmin'] as num?)?.toInt() ?? 0;
                        final bu = (bd['unreadAdmin'] as num?)?.toInt() ?? 0;
                        if ((au > 0) != (bu > 0)) return bu > 0 ? 1 : -1;

                        final at = (ad['updatedAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final bt = (bd['updatedAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return bt.compareTo(at);
                      });

                      if (filtered.isEmpty) {
                        return _emptyState(
                          icon: _tab == 3
                              ? Icons.archive_outlined
                              : Icons.chat_bubble_outline_rounded,
                          title: _search.isNotEmpty
                              ? 'لا توجد نتائج'
                              : _tab == 3
                                  ? 'لا توجد محادثات مؤرشفة'
                                  : 'لا توجد محادثات حالياً',
                          subtitle: _search.isNotEmpty
                              ? 'جرّب الاسم أو رقم الهاتف بصيغته المحلية أو الدولية.'
                              : 'ستظهر المحادثات الجديدة هنا',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          return _ChatTile(
                            doc: doc,
                            users: users,
                            onOpen: () => _openChat(doc, users),
                            onProfile: () => _openUserProperties(doc, users),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: TextField(
        onChanged: (value) => setState(() => _search = value),
        textDirection: TextDirection.rtl,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'ابحث باسم المستخدم أو رقم الهاتف',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: _gold, size: 21),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  onPressed: () => setState(() => _search = ''),
                  icon: const Icon(Icons.clear_rounded,
                      color: Colors.white38, size: 19),
                  tooltip: 'مسح البحث',
                ),
          filled: true,
          fillColor: _card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .06)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: _gold.withValues(alpha: .45)),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    const labels = ['الكل', 'غير مقروءة', 'مثبتة', 'مؤرشفة'];
    const icons = [
      Icons.chat_rounded,
      Icons.mark_chat_unread_outlined,
      Icons.push_pin_outlined,
      Icons.archive_outlined,
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final selected = _tab == index;
          return ChoiceChip(
            selected: selected,
            label: Text(labels[index]),
            avatar: Icon(
              icons[index],
              size: 16,
              color: selected ? Colors.black : Colors.white60,
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: _gold,
            backgroundColor: _card,
            side: BorderSide(
              color: selected ? _gold : Colors.white.withValues(alpha: .07),
            ),
            onSelected: (_) => setState(() => _tab = index),
          );
        },
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: .08),
                border: Border.all(color: _gold.withValues(alpha: .16)),
              ),
              child: Icon(icon, color: _gold, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, Map<String, dynamic>> users;
  final VoidCallback onOpen;
  final VoidCallback onProfile;

  const _ChatTile({
    required this.doc,
    required this.users,
    required this.onOpen,
    required this.onProfile,
  });

  static const _card = Color(0xff1E293B);
  static const _gold = Color(0xffD4AF37);

  String _firstNonEmpty(Iterable<dynamic> values, [String fallback = '']) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String _name(Map<String, dynamic> chat, Map<String, dynamic>? user) =>
      _firstNonEmpty([
        user?['name'],
        user?['displayName'],
        user?['fullName'],
        user?['userName'],
        user?['username'],
        chat['userName'],
      ], 'مستخدم');

  String _phone(Map<String, dynamic> chat, Map<String, dynamic>? user) =>
      _firstNonEmpty([
        user?['phoneNumber'],
        user?['phone'],
        user?['mobile'],
        chat['userPhone'],
      ]);

  String _image(Map<String, dynamic>? user) => _firstNonEmpty([
        user?['photoUrl'],
        user?['photoURL'],
        user?['profileImageUrl'],
        user?['profileImage'],
        user?['imageUrl'],
        user?['avatarUrl'],
        user?['photo'],
      ]);

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final userId = (data['userId'] ?? doc.id).toString();
    final user = users[userId];
    final name = _name(data, user);
    final phone = _phone(data, user);
    final image = _image(user);
    final last = (data['lastMessage'] ?? '').toString().trim();
    final unread = (data['unreadAdmin'] as num?)?.toInt() ?? 0;
    final pinned = data['isPinned'] == true;
    final blocked = data['isBlocked'] == true;
    final muted = data['isMuted'] == true;
    final archived = data['isArchived'] == true;
    final updatedAt = data['updatedAt'] as Timestamp?;
    final time =
        updatedAt == null ? '' : TimeFormatter.format(updatedAt.toDate());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: unread > 0
                  ? _gold.withValues(alpha: .24)
                  : Colors.white.withValues(alpha: .055),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(29),
                child: _UserAvatar(name: name, imageUrl: image),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (pinned) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.push_pin_rounded,
                                  color: _gold, size: 14),
                            ],
                            if (blocked) ...[
                              const SizedBox(width: 5),
                              const Icon(Icons.block_rounded,
                                  color: Colors.redAccent, size: 14),
                            ],
                          ],
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 9.5),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          last.isEmpty ? 'لا توجد رسائل بعد' : last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread > 0 ? Colors.white70 : Colors.white54,
                            fontSize: 10.5,
                            fontWeight:
                                unread > 0 ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 27,
                            child: OutlinedButton.icon(
                              onPressed: onProfile,
                              icon: const Icon(Icons.person_search_outlined,
                                  size: 14),
                              label: const Text('عرض الصفحة'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _gold,
                                side: BorderSide(
                                    color: _gold.withValues(alpha: .30)),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 9),
                                minimumSize: const Size(0, 27),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              SizedBox(
                width: 42,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (time.isNotEmpty)
                      Text(
                        time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 8.5),
                      ),
                    const SizedBox(height: 5),
                    if (unread > 0)
                      Container(
                        constraints:
                            const BoxConstraints(minWidth: 22, minHeight: 22),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: const BoxDecoration(
                          color: _gold,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 22),
                    const SizedBox(height: 2),
                    PopupMenuButton<String>(
                      tooltip: 'خيارات المحادثة',
                      padding: EdgeInsets.zero,
                      iconSize: 19,
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Colors.white38),
                      color: _card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(color: _gold.withValues(alpha: .16)),
                      ),
                      onSelected: (value) async {
                        await _handleAction(context, value);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'profile',
                          child: _menuRow(Icons.person_search_outlined,
                              'عرض صفحة المستخدم'),
                        ),
                        PopupMenuItem(
                          value: 'pin',
                          child: _menuRow(
                            pinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin_rounded,
                            pinned ? 'إلغاء تثبيت المحادثة' : 'تثبيت المحادثة',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: _menuRow(
                            archived
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                            archived ? 'إلغاء الأرشفة' : 'أرشفة المحادثة',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'mute',
                          child: _menuRow(
                            muted
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_off_outlined,
                            muted ? 'إلغاء الكتم' : 'كتم المحادثة',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: _menuRow(
                            blocked
                                ? Icons.check_circle_outline
                                : Icons.block_outlined,
                            blocked ? 'إلغاء حظر المستخدم' : 'حظر المستخدم',
                            color:
                                blocked ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow(IconData icon, String title, {Color color = Colors.white70}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    if (action == 'profile') {
      onProfile();
      return;
    }

    final ref = FirebaseFirestore.instance.collection('chats').doc(doc.id);
    final current = doc.data();

    switch (action) {
      case 'pin':
        await ref.update({'isPinned': current['isPinned'] != true});
        break;
      case 'archive':
        await ref.update({'isArchived': current['isArchived'] != true});
        break;
      case 'mute':
        await ref.update({'isMuted': current['isMuted'] != true});
        break;
      case 'block':
        final blocked = current['isBlocked'] == true;
        if (!blocked) {
          final confirm = await _confirm(
            context,
            title: 'حظر المستخدم',
            message: 'سيتم منع المستخدم من إرسال رسائل جديدة حتى إلغاء الحظر',
            confirm: 'حظر',
            destructive: true,
          );
          if (!confirm) return;
        }
        await ref.update({'isBlocked': !blocked});
        break;
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirm,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? Colors.redAccent : _gold,
                foregroundColor: destructive ? Colors.white : Colors.black,
              ),
              child: Text(confirm),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }
}

class _UserAvatar extends StatelessWidget {
  final String name;
  final String imageUrl;

  const _UserAvatar({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xff0F172A),
        border: Border.all(
          color: const Color(0xffD4AF37).withValues(alpha: .35),
        ),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final first = name.trim().isEmpty ? '؟' : name.trim().characters.first;
    return Center(
      child: Text(
        first,
        style: const TextStyle(
          color: Color(0xffD4AF37),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
