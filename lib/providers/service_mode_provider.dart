import 'package:flutter_riverpod/legacy.dart';

final serviceModeExpiresAtProvider = StateProvider<DateTime?>((ref) => null);

bool isServiceModeActive(DateTime? expiresAt) {
  return expiresAt != null && expiresAt.isAfter(DateTime.now());
}
