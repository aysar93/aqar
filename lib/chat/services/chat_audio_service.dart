import 'dart:io';
import '../../services/media_store.dart';
import '../widgets/voice_recorder_sheet.dart';

class ChatAudioService {
  static Future<Map<String, dynamic>> upload(
          String chatId, VoiceRecording recording) =>
      MediaStore.instance
          .uploadAudio(File(recording.path), chatId, recording.seconds);
}
