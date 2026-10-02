import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'models/chat_preferences.dart';
import 'screens/property_picker_sheet.dart';
import 'services/chat_audio_service.dart';
import 'services/chat_history_preferences.dart';
import 'services/chat_image_service.dart';
import 'services/chat_service.dart';
import 'widgets/chat_message_tile.dart';
import 'widgets/date_separator.dart';
import 'widgets/property_chat_card.dart';
import 'widgets/voice_recorder_sheet.dart';
import 'widgets/hold_voice_button.dart';
import 'utils/chat_search.dart';
import '../screens/admin/chat_settings_screen.dart';

class ConversationScreen extends StatefulWidget {
  final String? chatId;
  final bool admin;
  final String? title;
  final VoidCallback? onBack;
  final Map<String, dynamic>? initialProperty;
  const ConversationScreen(
      {super.key,
      this.chatId,
      this.admin = false,
      this.title,
      this.onBack,
      this.initialProperty});
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with WidgetsBindingObserver {
  static const _background = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _gold = Color(0xFFD4AF37);
  final _service = ChatService();
  final _history = ChatHistoryPreferences();
  final _text = TextEditingController();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final Map<String, GlobalKey> _keys = {};
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _settingsSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _accountChanged = false;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _chatSubscription;
  ChatPreferences _preferences = const ChatPreferences();
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _chat = {};
  List<QueryDocumentSnapshot> _documents = [];
  Set<String> _hidden = {};
  String? _chatId;
  String? _error;
  String? _replyId;
  Map<String, dynamic>? _pendingProperty;
  VoiceRecording? _pendingAudio;
  Map<String, dynamic>? _uploadedAudio;
  bool _loading = true;
  bool _sending = false;
  bool _savingHistory = false;
  bool _searching = false;
  bool _loadingMessages = true;
  bool _loadingMore = false;
  bool _foreground = true;
  int _limit = 50;
  Timer? _draftTimer;
  Timer? _typingTimer;
  Timer? _clockTimer;
  DateTime? _lastTyping;
  String? _jumpTarget;
  String? _highlightId;
  Timer? _highlightTimer;
  Future<void> _draftQueue = Future.value();
  final Set<String> _receipts = {};

  bool get _enabled =>
      !_loading &&
      _error == null &&
      _chatId != null &&
      _chat.isNotEmpty &&
      _chat['isClosed'] != true &&
      _chat['isBlocked'] != true &&
      _settings['allowChat'] != false;
  String get _senderType => widget.admin ? 'admin' : 'user';
  List<QueryDocumentSnapshot> get _visible =>
      _documents.where((doc) => !_hidden.contains(doc.id)).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pendingProperty = widget.initialProperty;
    _initialize();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user?.uid == _uid) return;
      _saveDraft();
      _draftTimer?.cancel();
      _typingTimer?.cancel();
      _messagesSubscription?.cancel();
      _chatSubscription?.cancel();
      _settingsSubscription?.cancel();
      _text.removeListener(_textChanged);
      _text.clear();
      setState(() {
        _accountChanged = true;
        _documents = [];
        _chat = {};
        _hidden = {};
        _loading = false;
        _loadingMessages = false;
        _pendingProperty = null;
        _replyId = null;
        _pendingAudio = null;
        _searching = false;
        _chatId = null;
        _error = 'تغيّر الحساب. أعد فتح المحادثة للحساب الحالي';
      });
    });
    _text.addListener(_textChanged);
    _clockTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initialize() async {
    if (_accountChanged) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (_uid == null) {
      setState(() {
        _loading = false;
        _error = 'سجّل الدخول للتواصل مع الإدارة';
      });
      return;
    }
    try {
      final id = widget.chatId ??
          await _service
              .getOrCreateChat(FirebaseAuth.instance.currentUser!)
              .timeout(const Duration(seconds: 15));
      final hidden = await _history.load(_uid!, id);
      final draft = await _history.loadDraft(_uid!, id);
      if (!mounted) return;
      _text.removeListener(_textChanged);
      _text.text = draft['text'] ?? '';
      _replyId = (draft['replyId'] ?? '').isEmpty ? null : draft['replyId'];
      _text.addListener(_textChanged);
      _chatId = id;
      _hidden = hidden;
      await _settingsSubscription?.cancel();
      if (!mounted) return;
      _settingsSubscription = FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .snapshots()
          .listen((snapshot) {
        if (!mounted || _accountChanged) return;
        setState(() {
          _settings = snapshot.data() ?? {};
          _preferences = ChatPreferences.fromMap(
              _settings['chatPreferences'] is Map
                  ? Map<String, dynamic>.from(_settings['chatPreferences'])
                  : null);
        });
      }, onError: (Object error) {
        debugPrint('Chat preferences: $error');
      });
      await _chatSubscription?.cancel();
      if (!mounted) return;
      _chatSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(id)
          .snapshots()
          .listen((snapshot) {
        if (!mounted || _accountChanged) return;
        setState(() {
          _chat = snapshot.data() ?? {};
          _error = snapshot.exists ? null : 'المحادثة غير متاحة';
        });
      }, onError: (Object error) {
        if (mounted) setState(() => _error = 'تعذر تحميل المحادثة');
      });
      _listenMessages();
      setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر فتح المحادثة. تحقق من الاتصال ثم أعد المحاولة';
        });
      }
    }
  }

  void _listenMessages() {
    _messagesSubscription?.cancel();
    _messagesSubscription =
        _service.messages(_chatId!, limit: _limit).listen((snapshot) {
      if (!mounted || _accountChanged) return;
      final newLastId = snapshot.docs.isEmpty ? null : snapshot.docs.last.id;
      final oldLastId = _documents.isEmpty ? null : _documents.last.id;
      final atBottom =
          !_scroll.hasClients || _scroll.position.extentAfter < 120;
      final initial = _loadingMessages;
      final older = _loadingMore && !_searching && _jumpTarget == null;
      final oldExtent =
          _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
      final oldOffset = _scroll.hasClients ? _scroll.offset : 0.0;
      setState(() {
        _documents = snapshot.docs;
        _loadingMessages = false;
        _loadingMore = false;
      });
      if (initial || (newLastId != oldLastId && atBottom && !_searching)) {
        _scrollToBottom();
      }
      unawaited(_markRead(snapshot.docs));
      if (older) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.jumpTo(
                (oldOffset + _scroll.position.maxScrollExtent - oldExtent)
                    .clamp(0.0, _scroll.position.maxScrollExtent));
          }
        });
      }
      if (_jumpTarget != null) {
        final target = _jumpTarget!;
        _jumpTarget = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_jump(target));
        });
      }
    }, onError: (Object error) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل الرسائل. أعد المحاولة';
          _loadingMessages = false;
          _loadingMore = false;
        });
      }
    });
  }

  Future<void> _markRead(List<QueryDocumentSnapshot> docs) async {
    if (!_foreground) return;
    final unread = docs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return (widget.admin
              ? d['senderType'] == 'user'
              : ['admin', 'system'].contains(d['senderType'])) &&
          d['deletedAt'] == null &&
          d['status'] != 'read' &&
          !_receipts.contains(doc.id);
    }).toList();
    // Clear conversation badges even when only deleted messages remain unread.
    _receipts.addAll(unread.map((doc) => doc.id));
    try {
      for (var i = 0; i < unread.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in unread.skip(i).take(400)) {
          batch.update(doc.reference, {
            'status': 'read',
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
            'deliveredAt': FieldValue.serverTimestamp()
          });
        }
        await batch.commit();
      }
      if (widget.admin) {
        await _service.markAdminRead(_chatId!);
      } else {
        await _service.markUserRead(_chatId!);
      }
    } catch (error) {
      _receipts.removeAll(unread.map((doc) => doc.id));
      debugPrint('Chat receipts: $error');
    }
  }

  void _textChanged() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), _saveDraft);
    if (!_enabled) return;
    final now = DateTime.now();
    if (_text.text.trim().isNotEmpty &&
        (_lastTyping == null || now.difference(_lastTyping!).inSeconds >= 4)) {
      _lastTyping = now;
      unawaited(_typing(true));
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 5), () => _typing(false));
  }

  Future<void> _typing(bool value) async {
    if (_chatId == null) return;
    if (!value) _lastTyping = null;
    try {
      await _service.setTyping(_chatId!, widget.admin, value);
    } catch (_) {}
  }

  void _saveDraft() {
    if (_uid == null || _chatId == null) return;
    final id = _chatId!;
    final text = _text.text;
    final reply = _replyId ?? '';
    _draftQueue = _draftQueue
        .then((_) => _history.saveDraft(_uid!, id, text, reply))
        .catchError((Object error) {
      debugPrint('Chat draft: $error');
    });
  }

  Future<bool> _send(
      {String type = 'text',
      String imageUrl = '',
      String imagePath = '',
      Map<String, dynamic>? property,
      Map<String, dynamic>? audio,
      double? latitude,
      double? longitude}) async {
    if (!_enabled || _sending) return false;
    final text = _text.text.trim();
    if (type == 'text' && text.isEmpty) return false;
    final replyId = _replyId;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(
          chatId: _chatId!,
          senderType: _senderType,
          message: type == 'text' ? text : '',
          type: type,
          imageUrl: imageUrl,
          imagePath: imagePath,
          property: property,
          audioUrl: audio?['audioUrl'] ?? '',
          audioPath: audio?['audioPath'] ?? '',
          audioSeconds: audio?['audioSeconds'] ?? 0,
          latitude: latitude,
          longitude: longitude,
          replyToId: replyId ?? '');
      if (!mounted) return true;
      if (type == 'text' && _text.text.trim() == text) _text.clear();
      setState(() {
        _replyId = null;
        if (type == 'property') _pendingProperty = null;
      });
      _saveDraft();
      unawaited(_typing(false));
      _scrollToBottom();
      return true;
    } catch (error) {
      _notice('تعذر إرسال الرسالة. تحقق من الاتصال والصلاحيات');
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });
  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _attachment(String kind) async {
    if (!_enabled || _sending) return;
    try {
      if (kind == 'property') {
        final property = await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            isScrollControlled: true,
            backgroundColor: _surface,
            builder: (_) => const PropertyPickerSheet());
        if (mounted && property != null) {
          setState(() => _pendingProperty = property);
        }
      } else if (kind == 'image') {
        final image = await ImagePicker().pickImage(
            source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
        if (image == null || !mounted) return;
        setState(() => _sending = true);
        final imageData =
            await ChatImageService.uploadAttachment(_chatId!, File(image.path));
        if (!mounted || _accountChanged) {
          if ((imageData['path'] ?? '').isNotEmpty) {
            await FirebaseStorage.instance.ref(imageData['path']).delete();
          }
          return;
        }
        setState(() => _sending = false);
        final sent = await _send(
            type: 'image',
            imageUrl: imageData['url']!,
            imagePath: imageData['path']!);
        if (!sent) {
          if ((imageData['path'] ?? '').isNotEmpty) {
            await FirebaseStorage.instance.ref(imageData['path']).delete();
          }
        }
      } else if (kind == 'location') {
        if (!await Geolocator.isLocationServiceEnabled()) {
          _notice('فعّل خدمة الموقع لمشاركته');
          return;
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if ([LocationPermission.denied, LocationPermission.deniedForever]
            .contains(permission)) {
          _notice('السماح بالوصول إلى الموقع مطلوب');
          return;
        }
        if (!mounted || _accountChanged) return;
        setState(() => _sending = true);
        final position = await Geolocator.getCurrentPosition()
            .timeout(const Duration(seconds: 20));
        if (!mounted || _accountChanged) return;
        setState(() => _sending = false);
        await _send(
            type: 'location',
            latitude: position.latitude,
            longitude: position.longitude);
      }
    } catch (error) {
      debugPrint('Chat attachment: $error');
      _notice('تعذر إرسال المرفق. تحقق من الاتصال والصلاحيات');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _sendAudio() async {
    final recording = _pendingAudio;
    if (recording == null ||
        _sending ||
        !_enabled ||
        !_preferences.voiceEnabled) {
      return;
    }
    try {
      if (_uploadedAudio == null) {
        setState(() => _sending = true);
        _uploadedAudio = await ChatAudioService.upload(_chatId!, recording);
        if (!mounted || _accountChanged) {
          try {
            if ((_uploadedAudio!['audioPath'] ?? '').toString().isNotEmpty) {
              await FirebaseStorage.instance
                  .ref(_uploadedAudio!['audioPath'])
                  .delete();
            }
          } finally {
            if (await File(recording.path).exists()) {
              await File(recording.path).delete();
            }
          }
          return;
        }
        setState(() => _sending = false);
      }
      if (await _send(type: 'audio', audio: _uploadedAudio)) {
        _uploadedAudio = null;
        if (mounted) {
          setState(() => _pendingAudio = null);
        }
        final file = File(recording.path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (error) {
      debugPrint('Chat audio upload: $error');
      _notice('تعذر إرسال التسجيل. يمكنك إعادة المحاولة أو إلغاء التسجيل');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _cancelAudio() async {
    if (_sending) return;
    final recording = _pendingAudio;
    final remote = _uploadedAudio;
    setState(() {
      _pendingAudio = null;
      _uploadedAudio = null;
    });
    try {
      if (recording != null && await File(recording.path).exists()) {
        await File(recording.path).delete();
      }
      if (remote != null && (remote['audioPath'] ?? '').toString().isNotEmpty) {
        await FirebaseStorage.instance.ref(remote['audioPath']).delete();
      }
    } catch (_) {
      debugPrint('Pending audio cleanup deferred');
    }
  }

  Future<void> _actions(QueryDocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    final date = (d['createdAt'] as Timestamp?)?.toDate();
    final mine =
        d['authorUid'] == _uid || (!widget.admin && d['senderId'] == _uid);
    final deleted = d['deletedAt'] != null;
    final withinWindow = date != null &&
        DateTime.now().difference(date).inSeconds >= 0 &&
        DateTime.now().difference(date) <
            Duration(hours: _preferences.deleteHours);
    final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: _surface,
        builder: (sheetContext) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!deleted && _enabled)
                _action(sheetContext, 'رد', Icons.reply_rounded, 'reply'),
              if (!deleted && (d['message'] ?? '').toString().isNotEmpty)
                _action(
                    sheetContext, 'نسخ الرسالة', Icons.copy_outlined, 'copy'),
              _action(sheetContext, 'حذف لدي', Icons.delete_outline, 'local'),
              if (!deleted && (widget.admin || (mine && withinWindow)))
                _action(sheetContext, 'حذف لدى الجميع',
                    Icons.delete_sweep_outlined, 'everyone'),
            ])));
    if (!mounted) return;
    if (action == 'reply') {
      setState(() => _replyId = doc.id);
      _saveDraft();
      _focus.requestFocus();
    }
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: d['message']));
      _notice('تم نسخ الرسالة');
    }
    if (action == 'local') await _hide([doc.id]);
    if (action == 'everyone' &&
        await _confirm('حذف الرسالة لدى الجميع؟',
            'سيُستبدل محتوى الرسالة بعبارة «تم حذف هذه الرسالة» لدى الطرفين.')) {
      try {
        await _service.deleteForEveryone(_chatId!, doc.id);
        _notice('تم حذف الرسالة لدى الجميع');
      } catch (_) {
        _notice('تعذر الحذف. قد تكون المهلة انتهت أو الاتصال غير متاح');
      }
    }
  }

  Widget _action(
          BuildContext context, String title, IconData icon, String value) =>
      ListTile(
          textColor: Colors.white,
          leading: Icon(icon, color: _gold),
          title: Text(title),
          onTap: () => Navigator.pop(context, value));

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                  backgroundColor: _surface,
                  title:
                      Text(title, style: const TextStyle(color: Colors.white)),
                  content:
                      Text(body, style: const TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('إلغاء')),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('حذف')),
                  ])) ==
      true;

  Future<void> _hide(List<String> ids) async {
    if (_savingHistory || _uid == null || _chatId == null) return;
    _savingHistory = true;
    try {
      final hidden = {..._hidden, ...ids};
      await _history.save(_uid!, _chatId!, hidden);
      if (mounted) setState(() => _hidden = hidden);
      _notice('تم الحذف لديك على هذا الجهاز');
    } catch (_) {
      _notice('تعذر حفظ الحذف');
    } finally {
      _savingHistory = false;
    }
  }

  Future<void> _menu() async {
    final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: _surface,
        builder: (sheetContext) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              _action(sheetContext, 'البحث في المحادثة', Icons.search_rounded,
                  'search'),
              _action(sheetContext, 'حذف جميع الرسائل لدي',
                  Icons.delete_sweep_outlined, 'clear'),
              if (widget.admin) ...[
                _action(
                    sheetContext,
                    _chat['isClosed'] == true
                        ? 'فتح المحادثة'
                        : 'إغلاق المحادثة',
                    Icons.lock_outline,
                    'status'),
                _action(sheetContext, 'إعدادات الدردشة والردود الجاهزة',
                    Icons.tune_rounded, 'settings'),
              ],
            ])));
    if (!mounted) return;
    if (action == 'search') {
      setState(() {
        _searching = true;
        _loadingMore = true;
      });
      try {
        final count = await FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatId!)
            .collection('messages')
            .count()
            .get();
        if (!mounted) return;
        _limit = (count.count ?? _limit) + 50;
        _listenMessages();
      } catch (_) {
        if (mounted) setState(() => _loadingMore = false);
        _notice('تعذر تحميل كامل سجل البحث. تظهر النتائج المحمّلة فقط');
      }
    }
    if (action == 'settings') {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ChatSettingsScreen()));
    }
    if (action == 'status') {
      try {
        await _service.setClosed(_chatId!, _chat['isClosed'] != true);
      } catch (_) {
        _notice('تعذر تغيير حالة المحادثة');
      }
    }
    if (action == 'clear' &&
        await _confirm('حذف جميع الرسائل لدي؟',
            'سيتم إخفاء الرسائل الحالية من هذا الجهاز فقط. تبقى نسخة الطرف الآخر محفوظة، وتظهر الرسائل الجديدة بشكل طبيعي.')) {
      if (!mounted) return;
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatId!)
            .collection('messages')
            .get();
        if (mounted) await _hide(snapshot.docs.map((doc) => doc.id).toList());
      } catch (_) {
        _notice('تعذر تحميل الرسائل لحذفها');
      }
    }
  }

  Future<void> _quickReplies() async {
    final reply = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: _surface,
        builder: (sheetContext) => SafeArea(
                child: ListView(shrinkWrap: true, children: [
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('الردود الجاهزة',
                      style: TextStyle(color: Colors.white, fontSize: 18))),
              for (final reply in _preferences.quickReplies)
                ListTile(
                    textColor: Colors.white,
                    title: Text(reply),
                    onTap: () => Navigator.pop(sheetContext, reply)),
              if (_preferences.quickReplies.isEmpty)
                const ListTile(title: Text('أضف ردوداً من إعدادات الدردشة')),
            ])));
    if (mounted && reply != null) {
      _text.text = reply;
      _text.selection = TextSelection.collapsed(offset: reply.length);
      _focus.requestFocus();
    }
  }

  Map<String, dynamic>? _message(String? id) {
    for (final doc in _documents) {
      if (doc.id == id) return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> _jump(String id) async {
    if (_searching) {
      setState(() {
        _searching = false;
        _search.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_jump(id));
        }
      });
      return;
    }
    if (_hidden.contains(id)) {
      _notice('الرسالة الأصلية محذوفة لديك');
      return;
    }
    if (_message(id) == null) {
      try {
        final reference = FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatId!)
            .collection('messages');
        final original = await reference.doc(id).get();
        if (!mounted || _accountChanged) return;
        if (!original.exists) {
          _notice('الرسالة الأصلية غير متاحة');
          return;
        }
        final later = await reference
            .orderBy('createdAt')
            .startAtDocument(original)
            .count()
            .get();
        if (!mounted || _accountChanged) return;
        _limit = (later.count ?? _limit) + 20;
        _jumpTarget = id;
        _listenMessages();
        return;
      } catch (_) {
        _notice('تعذر تحميل الرسالة الأصلية');
        return;
      }
    }
    final target = _keys[id]?.currentContext;
    setState(() => _highlightId = id);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _highlightId = null);
      }
    });
    if (target != null) {
      await Scrollable.ensureVisible(target,
          alignment: .5, duration: const Duration(milliseconds: 250));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_markRead(_documents));
    if (state != AppLifecycleState.resumed) {
      _saveDraft();
      _typingTimer?.cancel();
      unawaited(_typing(false));
    }
  }

  @override
  void dispose() {
    if (!_sending && _pendingAudio != null) {
      final recording = _pendingAudio!;
      final remote = _uploadedAudio;
      unawaited(() async {
        try {
          if (await File(recording.path).exists()) {
            await File(recording.path).delete();
          }
          if (remote != null &&
              (remote['audioPath'] ?? '').toString().isNotEmpty) {
            await FirebaseStorage.instance.ref(remote['audioPath']).delete();
          }
        } catch (_) {}
      }());
    }
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _typingTimer?.cancel();
    _clockTimer?.cancel();
    _highlightTimer?.cancel();
    _saveDraft();
    unawaited(_typing(false));
    _settingsSubscription?.cancel();
    _authSubscription?.cancel();
    _messagesSubscription?.cancel();
    _chatSubscription?.cancel();
    _text.dispose();
    _search.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typingAt =
        _chat[widget.admin ? 'userTypingAt' : 'adminTypingAt'] as Timestamp?;
    final age =
        typingAt == null ? null : DateTime.now().difference(typingAt.toDate());
    final typing = age != null && age.inSeconds >= 0 && age.inSeconds < 8;
    final open = _preferences.isOpen(DateTime.now());
    final title = widget.title ??
        (_settings['officeName'] ?? 'عقارات الأنبار').toString();
    final filtered = _visible.where((doc) {
      if (!_searching || _search.text.trim().isEmpty) return true;
      final d = doc.data() as Map<String, dynamic>;
      if (d['deletedAt'] != null) return false;
      return normalizeChatSearch(
              '${ChatMessageTile.summary(d)} ${d['property']?['location'] ?? ''} ${d['property']?['price'] ?? ''} ${d['property']?['number'] ?? ''}')
          .contains(normalizeChatSearch(_search.text));
    }).toList();
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: _gold, secondary: _gold, surface: _surface),
              inputDecorationTheme: const InputDecorationTheme(
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none),
            ),
            child: Scaffold(
              backgroundColor: _background,
              appBar: AppBar(
                backgroundColor: _background,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                    tooltip: 'رجوع',
                    icon: const Icon(Icons.arrow_back_rounded, color: _gold),
                    onPressed:
                        widget.onBack ?? () => Navigator.maybePop(context)),
                title: Row(children: [
                  if (!widget.admin) ...[
                    ClipOval(
                        child: SizedBox(
                            width: 36,
                            height: 36,
                            child: (_settings['logoUrl'] ?? '')
                                    .toString()
                                    .isNotEmpty
                                ? Image.network(_settings['logoUrl'].toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Image.asset('assets/images/logo.png'))
                                : Image.asset('assets/images/logo.png',
                                    fit: BoxFit.cover))),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        if (typing ||
                            _chat['isClosed'] == true ||
                            widget.admin ||
                            _preferences.hoursEnabled)
                          Text(
                              typing
                                  ? 'يكتب الآن…'
                                  : _chat['isClosed'] == true
                                      ? 'المحادثة مغلقة'
                                      : widget.admin
                                          ? 'محادثة المستخدم'
                                          : !_preferences.hoursEnabled
                                              ? ''
                                              : open
                                                  ? 'ضمن وقت العمل'
                                                  : 'خارج وقت العمل',
                              style:
                                  const TextStyle(color: _gold, fontSize: 11)),
                      ])),
                ]),
                actions: [
                  IconButton(
                      tooltip: 'إعدادات المحادثة',
                      onPressed:
                          _chatId == null || _accountChanged ? null : _menu,
                      icon: const Icon(Icons.more_vert_rounded, color: _gold))
                ],
              ),
              body: SafeArea(
                  child: Column(children: [
                if (_searching)
                  Container(
                      color: _surface,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _search,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                    hintText: 'ابحث في الرسائل ورقم العقار',
                                    prefixIcon:
                                        Icon(Icons.search, color: _gold)),
                                onChanged: (_) => setState(() {}))),
                        IconButton(
                            tooltip: 'إغلاق البحث',
                            onPressed: () => setState(() {
                                  _searching = false;
                                  _search.clear();
                                }),
                            icon:
                                const Icon(Icons.close, color: Colors.white54)),
                      ])),
                if (!widget.admin && _preferences.hoursEnabled && !open)
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                          'وقت العمل: ${ChatPreferences.clock(_preferences.openingMinute)} – ${ChatPreferences.clock(_preferences.closingMinute)} • بتوقيت بغداد',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11))),
                Expanded(
                    child: _loading || _loadingMessages && _error == null
                        ? const Center(
                            child: CircularProgressIndicator(color: _gold))
                        : _error != null
                            ? Center(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                    Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(_error!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: Colors.white60))),
                                    if (_uid != null && !_accountChanged)
                                      TextButton.icon(
                                          onPressed: _initialize,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('إعادة المحاولة')),
                                  ]))
                            : SingleChildScrollView(
                                controller: _scroll,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                child: Column(children: [
                                  if (_documents.length >= _limit)
                                    TextButton(
                                        onPressed: _loadingMore
                                            ? null
                                            : () {
                                                setState(() {
                                                  _limit += 50;
                                                  _loadingMore = true;
                                                });
                                                _listenMessages();
                                              },
                                        child: Text(_loadingMore
                                            ? 'جارٍ التحميل…'
                                            : 'تحميل الرسائل الأقدم')),
                                  if (filtered.isEmpty)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 56),
                                        child: Column(children: [
                                          const Icon(Icons.forum_outlined,
                                              color: _gold, size: 40),
                                          const SizedBox(height: 14),
                                          Text(
                                              _searching
                                                  ? 'لا توجد نتائج مطابقة'
                                                  : 'مرحباً بك في عقارات الأنبار',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16)),
                                          const SizedBox(height: 8),
                                          const Text(
                                              'تواصل مع الإدارة للاستفسار عن العقارات',
                                              style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12)),
                                        ])),
                                  for (var i = 0; i < filtered.length; i++) ...[
                                    if (i == 0 ||
                                        !_sameDay(filtered[i - 1], filtered[i]))
                                      DateSeparator(
                                          date: ((filtered[i].data() as Map<
                                                          String,
                                                          dynamic>)['createdAt']
                                                      as Timestamp?)
                                                  ?.toDate() ??
                                              DateTime.now()),
                                    ChatMessageTile(
                                        key: _keys.putIfAbsent(
                                            filtered[i].id, () => GlobalKey()),
                                        data: filtered[i].data()
                                            as Map<String, dynamic>,
                                        isMe: (filtered[i].data() as Map<String,
                                                dynamic>)['senderType'] ==
                                            _senderType,
                                        reply: _message((filtered[i].data()
                                                as Map<String, dynamic>)[
                                            'replyToId']),
                                        chatId: _chatId!,
                                        highlighted:
                                            _highlightId == filtered[i].id,
                                        onActions: () => _searching
                                            ? _jump(filtered[i].id)
                                            : _actions(filtered[i]),
                                        onReplyTap: () =>
                                            _jump((filtered[i].data() as Map<String, dynamic>)['replyToId'])),
                                  ],
                                ]))),
                if (!_enabled && !_loading && _error == null)
                  const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('الإرسال غير متاح حالياً',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12))),
                if (_replyId != null)
                  Container(
                      color: _surface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.reply, color: _gold, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                _message(_replyId) == null
                                    ? 'رد على رسالة سابقة'
                                    : ChatMessageTile.summary(
                                        _message(_replyId)!),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12))),
                        IconButton(
                            tooltip: 'إلغاء الرد',
                            onPressed: () {
                              setState(() => _replyId = null);
                              _saveDraft();
                            },
                            icon: const Icon(Icons.close,
                                color: Colors.white54, size: 18)),
                      ])),
                if (_pendingProperty != null)
                  Container(
                      color: _surface,
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(
                            child: SizedBox(
                                height: 150,
                                child: SingleChildScrollView(
                                    child: PropertyChatCard(
                                        property: _pendingProperty!)))),
                        Column(children: [
                          TextButton(
                              onPressed: _enabled && !_sending
                                  ? () => _send(
                                      type: 'property',
                                      property: _pendingProperty)
                                  : null,
                              child: const Text('إرسال البطاقة')),
                          TextButton(
                              onPressed: () =>
                                  setState(() => _pendingProperty = null),
                              child: const Text('إلغاء'))
                        ]),
                      ])),
                if (_pendingAudio != null)
                  Container(
                      color: _surface,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(children: [
                        const Text('تسجيل جاهز للإرسال',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 12)),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                  onPressed:
                                      _enabled && !_sending ? _sendAudio : null,
                                  child: const Text('إرسال التسجيل')),
                              TextButton(
                                  onPressed: _sending ? null : _cancelAudio,
                                  child: const Text('إلغاء')),
                            ]),
                      ])),
                Container(
                    decoration: const BoxDecoration(
                        color: _surface,
                        border: Border(top: BorderSide(color: Colors.white10))),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                        textDirection: TextDirection.ltr,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          PopupMenuButton<String>(
                              enabled: _enabled && !_sending,
                              tooltip: 'إرفاق',
                              icon: const Icon(Icons.add_rounded, color: _gold),
                              color: _surface,
                              onSelected: _attachment,
                              itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: 'property',
                                        child: Text('بطاقة عقار')),
                                    const PopupMenuItem(
                                        value: 'image', child: Text('صورة')),
                                    const PopupMenuItem(
                                        value: 'location',
                                        child: Text('الموقع'))
                                  ]),
                          Expanded(
                              child: TextField(
                                  controller: _text,
                                  focusNode: _focus,
                                  enabled: _enabled && !_sending,
                                  minLines: 1,
                                  maxLines: 5,
                                  maxLength: 5000,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: const InputDecoration(
                                      hintText: 'اكتب رسالتك…',
                                      counterText: '',
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 12)))),
                          if (widget.admin)
                            IconButton(
                                tooltip: 'ردود جاهزة',
                                onPressed: _enabled && !_sending
                                    ? _quickReplies
                                    : null,
                                icon: const Icon(Icons.notes_rounded,
                                    color: _gold)),
                          if (_preferences.voiceEnabled)
                            HoldVoiceButton(
                              enabled: _enabled &&
                                  !_sending &&
                                  _pendingAudio == null,
                              maxSeconds: _preferences.voiceSeconds,
                              onError: _notice,
                              onComplete: (recording) async {
                                if (!mounted || _accountChanged) {
                                  final file = File(recording.path);
                                  if (await file.exists()) await file.delete();
                                  return;
                                }
                                setState(() => _pendingAudio = recording);
                                await _sendAudio();
                              },
                            ),
                          IconButton(
                              tooltip: 'إرسال',
                              onPressed:
                                  _enabled && !_sending ? () => _send() : null,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: _gold))
                                  : Icon(Icons.send_rounded,
                                      color:
                                          _enabled ? _gold : Colors.white24)),
                        ])),
              ])),
            )));
  }

  bool _sameDay(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    final first =
        ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
            ?.toDate();
    final second =
        ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
            ?.toDate();
    return first != null &&
        second != null &&
        first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
