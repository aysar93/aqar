import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecording {
  final String path;
  final int seconds;
  const VoiceRecording(this.path, this.seconds);
}

class VoiceRecorderSheet extends StatefulWidget {
  final int maxSeconds;
  const VoiceRecorderSheet({super.key, required this.maxSeconds});
  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  Timer? _timer;
  String? _path;
  int _seconds = 0;
  bool _recording = false;
  bool _busy = true;
  bool _keepFile = false;
  bool _playing = false;
  String? _error;
  StreamSubscription<PlayerState>? _playerSubscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playerSubscription = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
    _start();
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        throw StateError('اسمح باستخدام الميكروفون لتسجيل رسالة صوتية');
      }
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/chat_${DateTime.now().microsecondsSinceEpoch}.m4a';
      if (!mounted) return;
      _path = path;
      await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
          path: path);
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      setState(() {
        _recording = true;
        _busy = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
        if (_seconds >= widget.maxSeconds) unawaited(_stop());
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _busy = false;
        });
      }
    }
  }

  Future<void> _stop() async {
    if (!_recording || _busy) return;
    _timer?.cancel();
    setState(() => _busy = true);
    try {
      _path = await _recorder.stop();
      if (mounted) setState(() => _recording = false);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر حفظ التسجيل');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording) unawaited(_stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _playerSubscription?.cancel();
    _player.dispose();
    _recorder.dispose();
    if (!_keepFile && _path != null) {
      final file = File(_path!);
      unawaited(file.exists().then((exists) async {
        if (exists) await file.delete();
      }).catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.mic_none_rounded,
                color: Color(0xFFD4AF37), size: 42),
            const SizedBox(height: 12),
            Text(_recording ? 'جارٍ التسجيل' : 'معاينة الرسالة الصوتية',
                style: const TextStyle(color: Colors.white, fontSize: 18)),
            Text(
                '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')} / ${widget.maxSeconds ~/ 60}:${(widget.maxSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white60)),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            if (_busy)
              const CircularProgressIndicator(color: Color(0xFFD4AF37))
            else if (_recording)
              OutlinedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('إنهاء التسجيل'))
            else if (_path != null && _seconds > 0 && _error == null)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton.icon(
                    onPressed: () async {
                      try {
                        if (_playing) {
                          await _player.pause();
                        } else {
                          await _player.play(DeviceFileSource(_path!));
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(() => _error = 'تعذر تشغيل المعاينة');
                        }
                      }
                    },
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    label: const Text('استماع')),
                FilledButton.icon(
                    onPressed: () {
                      _keepFile = true;
                      Navigator.pop(context, VoiceRecording(_path!, _seconds));
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('إرسال')),
              ]),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
          ])));
}
