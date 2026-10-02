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
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
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

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.play(
            widget.url.startsWith('http')
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
