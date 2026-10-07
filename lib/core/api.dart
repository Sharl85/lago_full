import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'storage.dart';

/// Résultat d'un appel API.
/// [offline] = serveur injoignable (on bascule en mode local) ;
/// sinon [ok] indique si le serveur a accepté la requête.
class ApiResult {
  final bool ok;
  final int status;
  final Map<String, dynamic>? data;
  final bool offline;
  const ApiResult({required this.ok, required this.status, this.data, this.offline = false});

  String message(String fallback) => (data != null && data!['message'] is String) ? data!['message'] as String : fallback;

  static const offlineResult = ApiResult(ok: false, status: 0, offline: true);
}

/// Client de l'API REST LaGo (serveur Node.js fourni dans /server).
class Api {
  static const _envUrl = String.fromEnvironment('LAGO_API_URL', defaultValue: '');
  static const _prefKey = 'lago_api_url';
  static const timeout = Duration(seconds: 10);

  static String? token;
  static void Function()? onUnauthorized;

  /// URL du serveur : réglage de l'app, sinon valeur fournie au build (--dart-define=LAGO_API_URL=…)
  static String get baseUrl {
    final custom = Store.getString(_prefKey);
    final url = (custom != null && custom.isNotEmpty) ? custom : _envUrl;
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  static bool get enabled => baseUrl.isNotEmpty;

  static Future<void> setBaseUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) {
      await Store.remove(_prefKey);
    } else {
      await Store.setString(_prefKey, clean);
    }
  }

  static Future<ApiResult> _request(String method, String path, [Map<String, dynamic>? body]) async {
    if (!enabled) return ApiResult.offlineResult;
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await req.send().timeout(timeout);
      final res = await http.Response.fromStream(streamed);
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      if (res.statusCode == 401 && token != null && onUnauthorized != null) onUnauthorized!();
      return ApiResult(ok: res.statusCode >= 200 && res.statusCode < 300, status: res.statusCode, data: data);
    } catch (_) {
      return ApiResult.offlineResult;
    }
  }

  static Future<ApiResult> health() => _request('GET', '/api/health');

  // --- Auth ---
  static Future<ApiResult> login(String email, String password) =>
      _request('POST', '/api/auth/login', {'email': email, 'password': password});
  static Future<ApiResult> register(String name, String email, String password, int? age,
          {Map<String, dynamic>? settings, String accountType = 'member'}) =>
      _request('POST', '/api/auth/register', {
        'name': name,
        'email': email,
        'password': password,
        'age': age,
        'accountType': accountType,
        if (settings != null) 'settings': settings,
      });
  static Future<ApiResult> me() => _request('GET', '/api/auth/me');
  static Future<ApiResult> changePassword(String current, String next) =>
      _request('POST', '/api/auth/password', {'currentPassword': current, 'newPassword': next});
  static Future<ApiResult> deleteAccount() => _request('DELETE', '/api/auth/account');

  // --- Cycle ---
  static Future<ApiResult> getSettings() => _request('GET', '/api/cycle/settings');
  static Future<ApiResult> getLogs() => _request('GET', '/api/cycle/logs');
  static Future<ApiResult> importData(Map<String, dynamic> payload) => _request('POST', '/api/cycle/import', payload);
  static Future<ApiResult> clearData() => _request('DELETE', '/api/cycle/data');

  // --- Suivi parental ---
  static Future<ApiResult> familyInvite() => _request('POST', '/api/family/invite');
  static Future<ApiResult> familyLink(String code) => _request('POST', '/api/family/link', {'code': code});
  static Future<ApiResult> familyChildren() => _request('GET', '/api/family/children');
  static Future<ApiResult> familyFollowers() => _request('GET', '/api/family/followers');
  static Future<ApiResult> familyUnlink(String userId) =>
      _request('DELETE', '/api/family/link?userId=${Uri.encodeQueryComponent(userId)}');

  // --- Photo de profil chiffrée (le serveur ne reçoit qu'un bloc illisible) ---
  static Future<ApiResult> avatarGet() => _request('GET', '/api/profile/avatar');
  static Future<ApiResult> avatarPut(String blob) => _request('POST', '/api/profile/avatar', {'data': blob});
  static Future<ApiResult> avatarDelete() => _request('DELETE', '/api/profile/avatar');

  // --- Super Admin ---
  static Future<ApiResult> adminStats() => _request('GET', '/api/admin/stats');
  static Future<ApiResult> adminUsers() => _request('GET', '/api/admin/users');
  static Future<ApiResult> adminCreateUser(String name, String email, String password, int? age) =>
      _request('POST', '/api/admin/user', {'name': name, 'email': email, 'password': password, 'age': age});
  static Future<ApiResult> adminSetRole(String userId, String role) =>
      _request('POST', '/api/admin/user/role', {'userId': userId, 'role': role});
  static Future<ApiResult> adminSetStatus(String userId, String status) =>
      _request('POST', '/api/admin/user/status', {'userId': userId, 'status': status});
  static Future<ApiResult> adminDeleteUser(String userId) =>
      _request('DELETE', '/api/admin/user?userId=${Uri.encodeQueryComponent(userId)}');
}
