import 'dart:io';
@Deprecated('Use uploadMediaImage with an explicit MediaPurpose')
Future<String?> uploadToCloudinary(File file) =>
    throw StateError('An explicit media purpose is required; Cloudinary uploads are disabled in this source');
