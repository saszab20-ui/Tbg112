import 'package:shared_preferences/shared_preferences.dart';

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
  return SharedPreferencesLocalPreferences(
    await SharedPreferences.getInstance(),
  );
}

class SharedPreferencesLocalPreferences implements LocalPreferences {
  const SharedPreferencesLocalPreferences(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
