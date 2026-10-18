import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'voice_recorder_sheet.dart';

class HoldVoiceButton extends StatefulWidget {
  final bool enabled;
  final int maxSeconds;
  final Future<void> Function(VoiceRecording) onComplete;
  final void Function(String) onError;
  const HoldVoiceButton(
      {super.key,
      required this.enabled,
      required this.maxSeconds,
      required this.onComplete,
      required this.onError});
  @override
  State<HoldVoiceButton> createState() => _HoldVoiceButtonState();
}

class _HoldVoiceButtonState extends State<HoldVoiceButton>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  Timer? _timer;
  DateTime? _started;
  bool _busy = false, _recording = false, _released = false, _cancelled = false;
  int _seconds = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _start() async {
    if (!widget.enabled || _busy || _recording) return;
    _released = false;
    _cancelled = false;
    setState(() => _busy = true);
    try {
      if (!await _recorder.hasPermission()) {
        widget.onError('اسمح باستخدام الميكروفون لتسجيل بصمة');
        return;
      }
      if (!mounted || _released || _cancelled) return;
      final directory = await getTemporaryDirectory();
      if (!mounted || _released || _cancelled) return;
      await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
          path:
              '${directory.path}/chat_${DateTime.now().microsecondsSinceEpoch}.m4a');
      if (!mounted || _cancelled) {
        await _recorder.cancel();
        return;
      }
      _started = DateTime.now();
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(
            () => _seconds = DateTime.now().difference(_started!).inSeconds);
        if (_seconds >= widget.maxSeconds) unawaited(_finish());
      });
    } catch (_) {
      if (mounted) widget.onError('تعذر بدء التسجيل. تحقق من إذن الميكروفون');
    } finally {
      if (mounted) setState(() => _busy = false);
      if (_released && _recording) unawaited(_finish(cancel: _cancelled));
    }
  }

  Future<void> _finish({bool cancel = false}) async {
    _released = true;
    _cancelled = _cancelled || cancel;
    if (!_recording || _busy) return;
    _timer?.cancel();
    setState(() {
      _busy = true;
      _recording = false;
    });
    try {
      final milliseconds = DateTime.now().difference(_started!).inMilliseconds;
      final path = await _recorder.stop();
      if (path == null) return;
      if (_cancelled || !mounted || milliseconds < 300) {
        final file = File(path);
        if (await file.exists()) await file.delete();
        return;
      }
      final seconds =
          ((milliseconds + 999) ~/ 1000).clamp(1, widget.maxSeconds);
      await widget.onComplete(VoiceRecording(path, seconds));
    } catch (_) {
      if (mounted) widget.onError('تعذر حفظ التسجيل');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_finish(cancel: true));
  }

  @override
  void didUpdateWidget(covariant HoldVoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && (_recording || _busy)) {
      unawaited(_finish(cancel: true));
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
        _recorder.cancel().catchError((_) {}).whenComplete(_recorder.dispose));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
      message: 'اضغط مطولاً للتسجيل وارفع إصبعك للإرسال',
      child: GestureDetector(
        onLongPressStart: widget.enabled ? (_) => _start() : null,
        onLongPressEnd: (_) => _finish(),
        onLongPressCancel: () => _finish(cancel: true),
        child: SizedBox(
            width: 48,
            height: _recording ? 68 : 48,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_recording)
                Text(
                    '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        color: Color(0xFFD4AF37), fontSize: 12)),
              if (_busy)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFD4AF37)))
              else
                Icon(_recording ? Icons.mic : Icons.mic_none_rounded,
                    color: widget.enabled
                        ? const Color(0xFFD4AF37)
                        : Colors.white24),
            ])),
      ));
}
