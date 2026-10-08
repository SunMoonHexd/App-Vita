import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  LocalStorageService({SharedPreferences? preferences}) : _preferences = preferences;

  static const _key = 'vita_store_v1';

  SharedPreferences? _preferences;

  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  Map<String, dynamic> load() {
    final raw = _preferences?.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  Future<void> save(Map<String, dynamic> data) async {
    await _preferences?.setString(_key, jsonEncode(data));
  }

  Future<void> clear() async {
    await _preferences?.remove(_key);
  }
}
