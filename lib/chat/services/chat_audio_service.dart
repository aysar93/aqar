import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../widgets/voice_recorder_sheet.dart';

class ChatAudioService {
  static Future<Map<String, dynamic>> upload(
      String chatId, VoiceRecording recording) async {
    final file = File(recording.path);
    if (await file.length() > 5 * 1024 * 1024) {
      throw StateError('Audio too large');
    }
    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST',
          Uri.parse('https://api.cloudinary.com/v1_1/hwxcrlcj/video/upload'));
      request.fields['upload_preset'] = 'pmlhhqdd';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response =
          await client.send(request).timeout(const Duration(seconds: 90));
      final body = await response.stream
          .bytesToString()
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['secure_url'] is! String) {
        throw StateError(
            'Audio upload rejected (${response.statusCode}): ${data['error']?['message']}');
      }
      return {
        'audioUrl': data['secure_url'],
        'audioPath': '',
        'audioSeconds': recording.seconds
      };
    } finally {
      client.close();
    }
  }
}
