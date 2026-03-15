import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────
//  ApiService
//
//  Single place for all backend HTTP calls.
//  baseUrl must point to your running server,
//  e.g. 'http://192.168.1.10:3000' on LAN or
//       'https://yourserver.com' in production.
//
//  Every method returns null / false / empty list
//  on network error so the app degrades gracefully
//  when offline.
// ─────────────────────────────────────────────

class ApiService {
  // ── Change this to your server's address ──────
  static const String baseUrl = 'http://192.168.100.9:3000'; // Android emulator default

  //'http://127.0.0.1:3000'; // localhost default
  //'http://10.0.2.2:3000'; // Android emulator default
  // For a real device on the same network: 'http://192.168.x.x:3000'
  // For production:                        'https://yourserver.com'

  static const Duration _timeout = Duration(seconds: 10);

  // ── Internal helpers ──────────────────────────

  static Map<String, String> _headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _decode(res);
    } catch (_) {
      return null; // network unavailable
    }
  }

  static Future<Map<String, dynamic>?> _get(
    String path, {
    String? token,
  }) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl$path'), headers: _headers(token: token))
          .timeout(_timeout);
      return _decode(res);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _decode(res);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _delete(String path, {String? token}) async {
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl$path'), headers: _headers(token: token))
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Decodes response; returns null if status >= 400.
  static Map<String, dynamic>? _decode(http.Response res) {
    if (res.statusCode >= 400) return null;
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) return body;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  //  Health check
  // ─────────────────────────────────────────────

  /// Returns true if the server is reachable.
  static Future<bool> isReachable() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  //  Auth
  // ─────────────────────────────────────────────

  /// Register a new account.
  /// Returns { token, user } on success, null on failure.
  static Future<Map<String, dynamic>?> register({
    required String username,
    required String fullName,
    required String password,
  }) => _post('/auth/register', {
        'username': username,
        'fullName': fullName,
        'password': password,
      });

  /// Login.
  /// Returns { token, user } on success, null on failure.
  static Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) => _post('/auth/login', {'username': username, 'password': password});

  /// Reset password (requires current token + current password).
  /// Returns { ok: true } on success, null on failure.
  static Future<Map<String, dynamic>?> resetPassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) => _post(
        '/auth/reset-password',
        {'currentPassword': currentPassword, 'newPassword': newPassword},
        token: token,
      );

  /// Get current user profile.
  static Future<Map<String, dynamic>?> getMe(String token) =>
      _get('/auth/me', token: token);

  // ─────────────────────────────────────────────
  //  Plans
  // ─────────────────────────────────────────────

  /// List plan stubs: [{ planId, updatedAt }, ...]
  /// Returns empty list on failure (offline).
  static Future<List<Map<String, dynamic>>> listPlanStubs(String token) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/plans'), headers: _headers(token: token))
          .timeout(_timeout);
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      if (body is List) {
        return body.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get full plan JSON for a single planId.
  /// Returns null on failure.
  static Future<Map<String, dynamic>?> getPlan(
    String token,
    String planId,
  ) => _get('/plans/$planId', token: token);

  /// Upsert a plan on the server.
  /// [planJson] must be the result of plan.toJsonString().
  /// Returns { planId, updatedAt } on success, null on failure.
  static Future<Map<String, dynamic>?> upsertPlan(
    String token,
    String planId,
    String planJson,
  ) => _put('/plans/$planId', {'planJson': planJson}, token: token);

  /// Delete a plan from the server.
  /// Fire-and-forget safe — returns false silently if offline.
  static Future<bool> deletePlan(String token, String planId) =>
      _delete('/plans/$planId', token: token);

  /// Batch upsert multiple plans (used on first login sync).
  /// [plans] = [{ planId: String, planJson: String }, ...]
  static Future<bool> batchUpsertPlans(
    String token,
    List<Map<String, String>> plans,
  ) async {
    final res = await _post('/plans/batch', {'plans': plans}, token: token);
    return res != null;
  }

  // ─────────────────────────────────────────────
  //  Error message helper
  // ─────────────────────────────────────────────

  /// Extracts an error message from a raw HTTP response body string,
  /// falling back to [fallback] if parsing fails.
  static String errorMessage(String? rawBody, {String fallback = 'Something went wrong'}) {
    if (rawBody == null) return fallback;
    try {
      final j = jsonDecode(rawBody) as Map<String, dynamic>;
      return j['error'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Convenience: performs a POST and also returns the raw response
  /// so callers can read error messages.
  static Future<({int statusCode, Map<String, dynamic>? body})> postRaw(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      Map<String, dynamic>? decoded;
      try { decoded = jsonDecode(res.body); } catch (_) {}
      return (statusCode: res.statusCode, body: decoded);
    } catch (_) {
      return (statusCode: 0, body: null);
    }
  }
}
