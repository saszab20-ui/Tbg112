import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  Future<String> uploadAvatar({
    required String uid,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    _validateSize(bytes, AppConstants.maxImageUploadBytes);
    return _uploadBytes(
      path: 'avatars/$uid/${_uuid.v4()}.jpg',
      bytes: bytes,
      contentType: file.mimeType ?? 'image/jpeg',
    );
  }

  Future<String> uploadChatImage({
    required String chatPath,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    _validateSize(bytes, AppConstants.maxImageUploadBytes);
    return _uploadBytes(
      path: 'chat_images/$chatPath/${_uuid.v4()}.jpg',
      bytes: bytes,
      contentType: file.mimeType ?? 'image/jpeg',
    );
  }

  Future<String> uploadChatFile({
    required String chatPath,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    _validateSize(bytes, AppConstants.maxFileUploadBytes);
    return _uploadBytes(
      path: 'chat_files/$chatPath/${_uuid.v4()}_$fileName',
      bytes: bytes,
      contentType: contentType ?? 'application/octet-stream',
    );
  }

  Future<String> uploadChatVideo({
    required String chatPath,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    _validateSize(bytes, AppConstants.maxFileUploadBytes);
    return _uploadBytes(
      path: 'chat_videos/$chatPath/${_uuid.v4()}.mp4',
      bytes: bytes,
      contentType: file.mimeType ?? 'video/mp4',
    );
  }

  Future<String> uploadChatVoice({
    required String chatPath,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    _validateSize(bytes, AppConstants.maxFileUploadBytes);
    return _uploadBytes(
      path: 'chat_voice/$chatPath/${_uuid.v4()}_$fileName',
      bytes: bytes,
      contentType: contentType ?? 'audio/mpeg',
    );
  }

  Future<String> uploadChatBackground({
    required String chatId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    _validateSize(bytes, AppConstants.maxImageUploadBytes);
    return _uploadBytes(
      path: 'chat_backgrounds/$chatId/${_uuid.v4()}.jpg',
      bytes: bytes,
      contentType: file.mimeType ?? 'image/jpeg',
    );
  }

  Future<String> _uploadBytes({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final reference = _storage.ref(path);
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }

  void _validateSize(Uint8List bytes, int maxBytes) {
    if (bytes.length > maxBytes) {
      throw StateError('Plik przekracza dozwolony rozmiar.');
    }
  }
}
