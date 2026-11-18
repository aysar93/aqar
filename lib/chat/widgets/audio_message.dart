import '../../services/media_store.dart';
import '../../services/media_location.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioMessage extends StatefulWidget {
  final String url;
  final int seconds;
  const AudioMessage({super.key, required this.url, required this.seconds});
  @override
  State<AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<AudioMessage> {
  final _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<dynamic>? _authSubscription;
  String? _playbackUid;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _watchPrivateAuth();
    _subscriptions.add(_player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    }));
    _subscriptions.add(_player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    }));
    _subscriptions.add(_player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    }));
  }

  void _watchPrivateAuth() {
    _authSubscription?.cancel();
    _playbackUid = null;
    if (!MediaLocation.needsAuth(widget.url, MediaLocation.defaultBucket))
      return;
    _authSubscription =
        MediaStore.instance.auth.authStateChanges().listen((user) {
      if (_playbackUid != null && user?.uid != _playbackUid) {
        _playbackUid = null;
        _player.stop();
        if (mounted) setState(() => _position = Duration.zero);
      }
    });
  }

  @override
  void didUpdateWidget(AudioMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _player.stop();
      _position = Duration.zero;
      _watchPrivateAuth();
    }
  }

  Future<Source> _privateSource() async {
    final url = widget.url;
    final store = MediaStore.instance;
    final uid = store.auth.currentUser?.uid;
    final mime = await store.privateContentType(url);
    final bytes = await store.readPrivate(url);
    if (uid == null ||
        store.auth.currentUser?.uid != uid ||
        !mounted ||
        widget.url != url) {
      throw StateError('Account changed');
    }
    _playbackUid = uid;
    return BytesSource(bytes,
        mimeType: mime?.startsWith('audio/') == true ? mime : null);
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.play(
            MediaLocation.needsAuth(widget.url, MediaLocation.defaultBucket)
                ? await _privateSource()
                : widget.url.startsWith('http')
                    ? UrlSource(widget.url)
                    : DeviceFileSource(widget.url),
            position: _position);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر تشغيل التسجيل')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 240,
      child: Row(children: [
        IconButton(
            tooltip: _playing ? 'إيقاف مؤقت' : 'تشغيل التسجيل',
            onPressed: _busy ? null : _toggle,
            icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: const Color(0xFFD4AF37))),
        Expanded(
            child: LinearProgressIndicator(
                value: widget.seconds <= 0
                    ? 0
                    : (_position.inSeconds / widget.seconds).clamp(0, 1),
                color: const Color(0xFFD4AF37),
                backgroundColor: Colors.white12)),
        const SizedBox(width: 8),
        Text(
            '${widget.seconds ~/ 60}:${(widget.seconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]));
}
