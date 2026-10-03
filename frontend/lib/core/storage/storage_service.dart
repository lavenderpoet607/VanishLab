import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'auth_jwt_token';
  static const String _keyBaseUrl = 'custom_base_url';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  StorageService({
    required this._secureStorage,
    required this._prefs,
  });

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: _keyToken);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _keyToken);
  }

  Future<void> saveCustomBaseUrl(String url) async {
    await _prefs.setString(_keyBaseUrl, url);
  }

  String? getCustomBaseUrl() {
    return _prefs.getString(_keyBaseUrl);
  }

  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';

  Future<void> clearCustomBaseUrl() async {
    await _prefs.remove(_keyBaseUrl);
  }

  bool hasSeenOnboarding() {
    return _prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    await _prefs.setBool(_keyHasSeenOnboarding, value);
  }
}
