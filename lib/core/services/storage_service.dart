import 'dart:io';
import 'dart:typed_data';

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

  /// Largest avatar `storage.rules` accepts.
  static const maxAvatarBytes = 1024 * 1024;

  /// Uploads the citizen's profile photo and returns its Storage *path*
  /// (not a download URL — a download URL is a bearer link anyone could
  /// open; the path is only readable through the owner-only rules).
  /// `putData` rather than `putFile` so it also works on the web build.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    final path = 'avatars/$userId/avatar.jpg';
    await _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return path;
  }

  Future<Uint8List?> loadAvatar(String path) {
    return _storage.ref(path).getData(maxAvatarBytes);
  }
}
