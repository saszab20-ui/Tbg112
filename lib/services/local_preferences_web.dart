// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

abstract interface class LocalPreferences {
  String? getString(String key);
  bool? getBool(String key);
  int? getInt(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> setInt(String key, int value);
  Future<void> remove(String key);
}

Future<LocalPreferences> loadLocalPreferences() async {
  return const WebLocalPreferences();
}

class WebLocalPreferences implements LocalPreferences {
  const WebLocalPreferences();

  @override
  String? getString(String key) => html.window.localStorage[key];

  @override
  bool? getBool(String key) {
    final value = html.window.localStorage[key];
    if (value == null) return null;
    return value == 'true';
  }

  @override
  int? getInt(String key) {
    final value = html.window.localStorage[key];
    return value == null ? null : int.tryParse(value);
  }

  @override
  Future<void> setString(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    html.window.localStorage[key] = value.toString();
  }

  @override
  Future<void> setInt(String key, int value) async {
    html.window.localStorage[key] = value.toString();
  }

  @override
  Future<void> remove(String key) async {
    html.window.localStorage.remove(key);
  }
}
