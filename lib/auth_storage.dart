import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
//  AuthStorage
//
//  Persists the JWT token and basic user info
//  (username, fullName) in SharedPreferences.
//
//  Keys:
//    'auth_token'    → JWT string
//    'auth_user'     → JSON { id, username, fullName }
// ─────────────────────────────────────────────

class AuthStorage {
  static const _tokenKey = 'auth_token';
  static const _userKey  = 'auth_user';

  // ── Save after login / register ──────────────
  static Future<void> save({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  // ── Read token ────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // ── Read user info ────────────────────────────
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Convenience getters ───────────────────────
  static Future<String?> getUsername() async {
    final u = await getUser();
    return u?['username'] as String?;
  }

  static Future<String?> getFullName() async {
    final u = await getUser();
    return u?['fullName'] as String?;
  }

  // ── Check if logged in ────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Clear on logout ───────────────────────────
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
