import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatAttachmentService {

  static Future<Map<String, dynamic>?> uploadFile() async {

    FilePickerResult? result =
        await FilePicker.platform.pickFiles();

    if (result == null) return null;

    final file =
        File(result.files.single.path!);

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';

    await Supabase.instance.client.storage
        .from('chat-files')
        .upload(fileName, file);

    final url =
        Supabase.instance.client.storage
            .from('chat-files')
            .getPublicUrl(fileName);

    return {
      'fileName': result.files.single.name,
      'fileUrl': url,
    };
  }

  static Future<Map<String, dynamic>?> uploadImage() async {

  final picker = ImagePicker();

  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 80,
  );

  if (image == null) {
    return null;
  }

  final file = File(image.path);

  final fileName =
      '${DateTime.now().millisecondsSinceEpoch}.jpg';

  await Supabase.instance.client.storage
      .from('chat-files')
      .upload(fileName, file);

  final url =
      Supabase.instance.client.storage
          .from('chat-files')
          .getPublicUrl(fileName);

  return {
    'fileName': fileName,
    'fileUrl': url,
  };
}

  
}