import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<String?> uploadToCloudinary(
  File imageFile,
) async {

  final url = Uri.parse(
    'https://api.cloudinary.com/v1_1/hwxcrlcj/image/upload',
  );

  final request =
      http.MultipartRequest(
    'POST',
    url,
  );

  request.fields['upload_preset'] =
      'pmlhhqdd';

  request.files.add(
    await http.MultipartFile
        .fromPath(
      'file',
      imageFile.path,
    ),
  );

  final response =
      await request.send();

  if (response.statusCode == 200) {

    final data =
        jsonDecode(
      await response.stream
          .bytesToString(),
    );

    return data['secure_url'];
  }

  return null;
}