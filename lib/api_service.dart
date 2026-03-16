import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
//  ApiService
//  All backend HTTP calls in one place.
//  Returns null / false / [] on any failure so
//  the app degrades gracefully when offline.
// ─────────────────────────────────────────────

class ApiService {
  static const _defaultUrl  = 'http://192.168.1.10:3000';
  static const _urlPrefKey  = 'dev_base_url';
  static const _timeout     = Duration(seconds: 10);

  static String _baseUrl = _defaultUrl;
  static String get baseUrl => _baseUrl;

  /// Call once from main() before runApp() to restore the saved URL.
  static Future<void> loadSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_urlPrefKey);
    if (saved != null && saved.isNotEmpty) _baseUrl = saved;
  }

  /// Called by the dev button to change + persist the URL.
  static Future<void> setBaseUrl(String url) async {
    url = url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    url = url.replaceAll(RegExp(r'/+$'), '');
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlPrefKey, url);
  }

  // ── Headers ───────────────────────────────────────────────────────────────
  static Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // ── Low-level helpers ─────────────────────────────────────────────────────
  static Future<http.Response?> _get(String path, {String? token}) async {
    try {
      return await http
          .get(Uri.parse('$_baseUrl$path'), headers: _headers(token: token))
          .timeout(_timeout);
    } catch (_) { return null; }
  }

  static Future<http.Response?> _post(String path, Map<String, dynamic> body, {String? token}) async {
    try {
      return await http
          .post(Uri.parse('$_baseUrl$path'),
          headers: _headers(token: token), body: jsonEncode(body))
          .timeout(_timeout);
    } catch (_) { return null; }
  }

  static Future<http.Response?> _put(String path, Map<String, dynamic> body, {String? token}) async {
    try {
      return await http
          .put(Uri.parse('$_baseUrl$path'),
          headers: _headers(token: token), body: jsonEncode(body))
          .timeout(_timeout);
    } catch (_) { return null; }
  }

  static Future<http.Response?> _delete(String path, {String? token}) async {
    try {
      return await http
          .delete(Uri.parse('$_baseUrl$path'), headers: _headers(token: token))
          .timeout(_timeout);
    } catch (_) { return null; }
  }

  static Map<String, dynamic>? _json(http.Response? res) {
    if (res == null) return null;
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) return {...body, '_status': res.statusCode};
      return null;
    } catch (_) { return null; }
  }

  // ── Health ────────────────────────────────────────────────────────────────
  static Future<bool> isReachable() async {
    final res = await _get('/health');
    return res?.statusCode == 200;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  /// POST /auth/register → { token, user } or { error }
  static Future<Map<String, dynamic>?> register({
    required String username,
    required String fullName,
    required String password,
  }) async {
    final res = await _post('/auth/register', {
      'username': username,
      'fullName': fullName,
      'password': password,
    });
    return _json(res);
  }

  /// POST /auth/login → { token, user } or { error }
  static Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    final res = await _post('/auth/login', {
      'username': username,
      'password': password,
    });
    return _json(res);
  }

  /// POST /auth/reset-password → { ok: true } or { error }
  static Future<Map<String, dynamic>?> resetPassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _post(
      '/auth/reset-password',
      {'currentPassword': currentPassword, 'newPassword': newPassword},
      token: token,
    );
    return _json(res);
  }

  // ── Plans ─────────────────────────────────────────────────────────────────
  /// GET /plans → [{ planId, updatedAt }, ...]
  static Future<List<Map<String, dynamic>>> listPlanStubs(String token) async {
    final res = await _get('/plans', token: token);
    if (res == null || res.statusCode >= 400) return [];
    try {
      final body = jsonDecode(res.body);
      if (body is List) return body.cast<Map<String, dynamic>>();
    } catch (_) {}
    return [];
  }

  /// GET /plans/:planId → { planId, planJson, updatedAt }
  static Future<Map<String, dynamic>?> getPlan(String token, String planId) async {
    final res = await _get('/plans/$planId', token: token);
    if (res == null || res.statusCode >= 400) return null;
    return _json(res);
  }

  /// PUT /plans/:planId → { planId, updatedAt }
  static Future<bool> upsertPlan(String token, String planId, String planJson) async {
    final res = await _put('/plans/$planId', {'planJson': planJson}, token: token);
    return res != null && res.statusCode < 400;
  }

  /// DELETE /plans/:planId → { ok: true }
  static Future<bool> deletePlan(String token, String planId) async {
    final res = await _delete('/plans/$planId', token: token);
    return res != null && res.statusCode < 400;
  }
}