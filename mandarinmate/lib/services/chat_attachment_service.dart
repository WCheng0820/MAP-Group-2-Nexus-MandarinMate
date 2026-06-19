import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatAttachmentService {

  static Future<Map<String, dynamic>?> pickAndUploadFile() async {

    FilePickerResult? result =
        await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
      ],
    );

    if (result == null) {
      return null;
    }

    final file =
        File(result.files.single.path!);

    final fileName =
        result.files.single.name;

    final storageRef =
        FirebaseStorage.instance
            .ref()
            .child('chat_files')
            .child(
              DateTime.now()
                  .millisecondsSinceEpoch
                  .toString(),
            )
            .child(fileName);

    await storageRef.putFile(file);

    final downloadUrl =
        await storageRef.getDownloadURL();

    return {
      'fileName': fileName,
      'fileUrl': downloadUrl,
    };
  }
}