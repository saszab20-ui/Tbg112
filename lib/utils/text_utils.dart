class TextUtils {
  const TextUtils._();

  static String repairPolishText(String input) {
    if (input.isEmpty) return input;
    var value = input;
    const replacements = <String, String>{
      'Do??czy?e?': 'Do\u0142\u0105czy\u0142e\u015b',
      'Wiadomo??': 'Wiadomo\u015b\u0107',
      'wiadomo??': 'wiadomo\u015b\u0107',
      'Wiadomo?ci': 'Wiadomo\u015bci',
      'wiadomo?ci': 'wiadomo\u015bci',
      'Je?li': 'Je\u015bli',
      'mo?esz': 'mo\u017cesz',
      'mo?na': 'mo\u017cna',
      'pobra?': 'pobra\u0107',
      'napisa?': 'napisa\u0107',
      'pierwsz?': 'pierwsz\u0105',
      'Zosta?e?': 'Zosta\u0142e\u015b',
      'czyta?': 'czyta\u0107',
      'pisa?': 'pisa\u0107',
      'Od?wie?': 'Od\u015bwie\u017c',
      'Tre??': 'Tre\u015b\u0107',
      'Zg?oszenie': 'Zg\u0142oszenie',
      'podgl?d': 'podgl\u0105d',
      'wy??czone': 'wy\u0142\u0105czone',
      'u?ytkownik': 'u\u017cytkownik',
      'U?ytkownik': 'U\u017cytkownik',
      'u?ytkownicy': 'u\u017cytkownicy',
      'U?ytkownicy': 'U\u017cytkownicy',
      'Usu?': 'Usu\u0144',
      'Kana?': 'Kana\u0142',
      'si?': 'si\u0119',
      'has?o': 'has\u0142o',
      'dost?pu': 'dost\u0119pu',
      's?u?by': 's\u0142u\u017cby',
      'Imi?': 'Imi\u0119',
      'Cz?onek': 'Cz\u0142onek',
      'cz?onek': 'cz\u0142onek',
      'g?os': 'g\u0142os',
      'dost?p': 'dost\u0119p',
      '\u00c4\u2026': '\u0105',
      '\u00c4\u2021': '\u0107',
      '\u00c4\u2122': '\u0119',
      '\u0139\u201a': '\u0142',
      '\u0139\u201e': '\u0144',
      '\u0102\u0142': '\u00f3',
      '\u0139\u203a': '\u015b',
      '\u0139\u015f': '\u017a',
      '\u0139\u013d': '\u017c',
      '\u00c5\u0082': '\u0142',
      '\u00c5\u009b': '\u015b',
      '\u00c5\u00bc': '\u017c',
      '\u00c5\u00ba': '\u017a',
      '\u00c5\u0084': '\u0144',
      '\u00c3\u00b3': '\u00f3',
      '\u00c4\u0085': '\u0105',
      '\u00c4\u0087': '\u0107',
      '\u00c4\u0099': '\u0119',
      '\u00c4\u201e': '\u0104',
      '\u00c4\u2020': '\u0106',
      '\u0102\u201c': '\u00d3',
      '\u0139\u0160': '\u015a',
      '\u0139\u0105': '\u0179',
      '\u0139\u00bb': '\u017b',
      '\u00c5\u0081': '\u0141',
      '\u00c5\u009a': '\u015a',
      '\u00c5\u00b9': '\u0179',
      '\u00c5\u00bb': '\u017b',
      '\u00c3\u0093': '\u00d3',
    };
    for (final entry in replacements.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return value;
  }

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
    final clean = unitNameOrId.replaceFirst(RegExp('^unit[_-]'), '').trim();
    if (isServiceChannelId(clean)) return 'unit_$clean';
    final normalized = normalizeId(clean);
    return normalized.isEmpty ? '' : 'unit_$normalized';
  }

  static bool isServiceChannelId(String input) {
    return input == 'service_psp' ||
        input == 'service_policja' ||
        input == 'service_medycy' ||
        input == 'service_media';
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
