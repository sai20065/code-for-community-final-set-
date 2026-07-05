import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadSubmissionMedia({
    required String userId,
    required File file,
    required String extension,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref('submissions/$userId/$fileName');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }
}
