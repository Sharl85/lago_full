import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stockage clé/valeur JSON sur l'appareil (SharedPreferences / NSUserDefaults).
class Store {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static dynamic readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? readMap(String key) {
    final v = readJson(key);
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  static List<dynamic> readList(String key) {
    final v = readJson(key);
    return v is List ? v : <dynamic>[];
  }

  static Future<void> writeJson(String key, Object? value) => _prefs.setString(key, jsonEncode(value));

  static String? getString(String key) => _prefs.getString(key);
  static Future<void> setString(String key, String value) => _prefs.setString(key, value);
  static bool getBool(String key) => _prefs.getBool(key) ?? false;
  static Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  static Future<void> remove(String key) => _prefs.remove(key);
}
