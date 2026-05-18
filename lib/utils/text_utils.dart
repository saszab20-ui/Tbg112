class TextUtils {
  const TextUtils._();

  static String normalizeId(String input) {
    final lower = input.trim().toLowerCase();
    final ascii = lower
        .replaceAll('ą', 'a')
        .replaceAll('ć', 'c')
        .replaceAll('ę', 'e')
        .replaceAll('ł', 'l')
        .replaceAll('ń', 'n')
        .replaceAll('ó', 'o')
        .replaceAll('ś', 's')
        .replaceAll('ż', 'z')
        .replaceAll('ź', 'z');
    final normalized = ascii.replaceAll(RegExp('[^a-z0-9]+'), '-');
    return normalized.replaceAll(RegExp(r'(^-+|-+$)'), '');
  }

  static String unitChatId(String unitNameOrId) {
    final normalized = normalizeId(
      unitNameOrId.replaceFirst(RegExp('^unit[_-]'), ''),
    );
    return normalized.isEmpty ? '' : 'unit_$normalized';
  }

  static String normalizeLogin(String input) {
    final normalized = input.trim().toLowerCase();
    return normalized.replaceAll(RegExp('[^a-z0-9._-]+'), '');
  }

  static String normalizeInviteCode(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static String initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'T112';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
