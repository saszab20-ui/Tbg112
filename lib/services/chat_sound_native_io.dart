import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String?> materializeCustomSoundDataUrl(
  String dataUrl,
  String name,
) async {
  final comma = dataUrl.indexOf(',');
  if (!dataUrl.startsWith('data:') || comma < 0) return null;
  final payload = dataUrl.substring(comma + 1);
  final bytes = base64Decode(payload);
  final directory = await getApplicationDocumentsDirectory();
  final soundsDirectory = Directory(
    '${directory.path}${Platform.pathSeparator}sounds',
  );
  if (!await soundsDirectory.exists()) {
    await soundsDirectory.create(recursive: true);
  }
  final cleanName = _cleanFileName(name);
  final file = File(
    '${soundsDirectory.path}${Platform.pathSeparator}$cleanName',
  );
  if (!await file.exists() || await file.length() != bytes.length) {
    await file.writeAsBytes(bytes, flush: true);
  }
  return file.path;
}

String _cleanFileName(String name) {
  final fallback = name.trim().isEmpty ? 'custom_sound.mp3' : name.trim();
  return fallback.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
