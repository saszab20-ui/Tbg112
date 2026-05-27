import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as image_tools;
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
    final image = _prepareImageBytes(
      bytes,
      contentType: file.mimeType ?? _contentTypeFromFileName(file.name),
    );
    return _uploadBytes(
      path: 'avatars/$uid/${_uuid.v4()}.${_imageExtension(image.contentType)}',
      bytes: image.bytes,
      contentType: image.contentType,
    );
  }

  Future<String> uploadChatImage({
    required String chatPath,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final image = _prepareImageBytes(
      bytes,
      contentType: file.mimeType ?? _contentTypeFromFileName(file.name),
    );
    return uploadChatImageBytes(
      chatPath: chatPath,
      fileName: file.name,
      bytes: image.bytes,
      contentType: image.contentType,
    );
  }

  Future<String> uploadChatImageBytes({
    required String chatPath,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final image = _prepareImageBytes(
      bytes,
      contentType: contentType ?? _contentTypeFromFileName(fileName),
    );
    return _uploadBytes(
      path:
          'chat_images/$chatPath/${_uuid.v4()}_${_safeFileName(fileName, image.contentType)}',
      bytes: image.bytes,
      contentType: image.contentType,
    );
  }

  Future<String> uploadChatFile({
    required String chatPath,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    _validateSize(bytes, AppConstants.maxFileUploadBytes, label: 'Plik');
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
    _validateSize(bytes, AppConstants.maxFileUploadBytes, label: 'Wideo');
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
    _validateSize(bytes, AppConstants.maxFileUploadBytes, label: 'Głosówka');
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
    final image = _prepareImageBytes(
      bytes,
      contentType: file.mimeType ?? _contentTypeFromFileName(file.name),
    );
    return _uploadBytes(
      path:
          'chat_backgrounds/$chatId/${_uuid.v4()}.${_imageExtension(image.contentType)}',
      bytes: image.bytes,
      contentType: image.contentType,
    );
  }

  Future<String> uploadEventPoster({
    required String eventId,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final image = _prepareImageBytes(
      bytes,
      contentType: file.mimeType ?? _contentTypeFromFileName(file.name),
    );
    return _uploadBytes(
      path:
          'event_posters/$eventId/${_uuid.v4()}.${_imageExtension(image.contentType)}',
      bytes: image.bytes,
      contentType: image.contentType,
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

  ({Uint8List bytes, String contentType}) _prepareImageBytes(
    Uint8List bytes, {
    required String contentType,
  }) {
    final normalizedContentType = _normalizeImageContentType(contentType);
    if (bytes.length <= AppConstants.maxImageUploadBytes) {
      return (bytes: bytes, contentType: normalizedContentType);
    }

    final decoded = image_tools.decodeImage(bytes);
    if (decoded == null) {
      _validateSize(bytes, AppConstants.maxImageUploadBytes, label: 'Zdjęcie');
    }

    var working = decoded!;
    const targetSizes = [1800, 1500, 1200, 1000, 800];
    const qualities = [82, 74, 66, 58, 50, 42];

    for (final size in targetSizes) {
      final longestSide = working.width > working.height
          ? working.width
          : working.height;
      if (longestSide > size) {
        working = image_tools.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? size : null,
          height: decoded.height > decoded.width ? size : null,
          interpolation: image_tools.Interpolation.average,
        );
      }
      for (final quality in qualities) {
        final compressed = Uint8List.fromList(
          image_tools.encodeJpg(working, quality: quality),
        );
        if (compressed.length <= AppConstants.maxImageUploadBytes) {
          return (bytes: compressed, contentType: 'image/jpeg');
        }
      }
    }

    _validateSize(bytes, AppConstants.maxImageUploadBytes, label: 'Zdjęcie');
    return (bytes: bytes, contentType: normalizedContentType);
  }

  void _validateSize(Uint8List bytes, int maxBytes, {required String label}) {
    if (bytes.length > maxBytes) {
      final maxMb = (maxBytes / (1024 * 1024)).round();
      throw StateError('$label jest za duży, maksymalny rozmiar to $maxMb MB.');
    }
  }

  String _normalizeImageContentType(String contentType) {
    final normalized = contentType.toLowerCase();
    if (normalized == 'image/jpg') return 'image/jpeg';
    if (normalized == 'image/png' ||
        normalized == 'image/jpeg' ||
        normalized == 'image/webp') {
      return normalized;
    }
    return 'image/jpeg';
  }

  String _contentTypeFromFileName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'image/jpeg',
    };
  }

  String _imageExtension(String contentType) {
    return switch (_normalizeImageContentType(contentType)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  String _safeFileName(String fileName, String contentType) {
    final clean = fileName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    if (clean.isEmpty) return 'image.${_imageExtension(contentType)}';
    if (clean.contains('.')) return clean;
    return '$clean.${_imageExtension(contentType)}';
  }
}
