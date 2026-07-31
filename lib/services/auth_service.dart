import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tane06_app/models/api_response.dart';
import 'package:tane06_app/services/auth_token_store.dart';

/// Authentication service for user login and registration.
///
/// Endpoints:
///   POST /users/login    — Authenticate an existing user.
///   POST /users/register — Create a new user account.
class AuthService {
  static const String _baseUrl =
      'https://15cq1pkvfa.execute-api.us-east-1.amazonaws.com';

  final http.Client _http;

  AuthService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // -----------------------------------------------------------------------
  // Login
  // -----------------------------------------------------------------------

  /// POST /users/login
  ///
  /// Returns the parsed response body on success.
  /// Throws [ApiException] on failure.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/login'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  // -----------------------------------------------------------------------
  // Register
  // -----------------------------------------------------------------------

  /// POST /users/register
  ///
  /// Returns the parsed response body on success.
  /// Throws [ApiException] on failure.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
        if (name != null && name.isNotEmpty) 'name': name,
      }),
    );

    return _handleResponse(response);
  }

  // -----------------------------------------------------------------------
  // Response handling
  // -----------------------------------------------------------------------

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // The API may use { "success": true/false, "data": {...}, "error": {...} }
    // or it may return a flat body. Handle both gracefully.
    final success = body['success'] as bool? ?? (response.statusCode < 400);

    if (!success || response.statusCode >= 400) {
      String errorMessage = 'Something went wrong';

      if (body['error'] is Map<String, dynamic>) {
        final err = body['error'] as Map<String, dynamic>;
        errorMessage = err['message'] as String? ?? errorMessage;
      } else if (body['message'] is String) {
        errorMessage = body['message'] as String;
      }

      throw ApiException(
        statusCode: response.statusCode,
        error: ApiError(
          code: body['code'] as String? ?? 'AuthError',
          message: errorMessage,
        ),
      );
    }

    _extractAndStoreToken(body);
    return body;
  }

  /// Looks for a token in common response field names and persists it.
  /// Also extracts and stores the user's display name or email.
  void _extractAndStoreToken(Map<String, dynamic> body) {
    // ── Token extraction ─────────────────────────────────────────────────
    final tokenCandidates = <String>['token', 'access_token', 'accessToken', 'jwt'];
    final data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : null;

    for (final key in tokenCandidates) {
      final val = body[key] ?? data?[key];
      if (val is String && val.isNotEmpty) {
        AuthTokenStore.instance.setToken(val);
        break;
      }
    }

    // ── Username / email extraction ───────────────────────────────────────
    // Priority: name > username > email, checked at top level then in data.
    String? resolveUsername(Map<String, dynamic> m) {
      final user = m['user'] is Map<String, dynamic>
          ? m['user'] as Map<String, dynamic>
          : null;
      return (m['name'] ?? m['username'] ?? user?['name'] ?? user?['username'] ??
              m['email'] ?? user?['email'])
          ?.toString();
    }

    final username = resolveUsername(body) ??
        (data != null ? resolveUsername(data) : null);

    if (username != null && username.isNotEmpty) {
      AuthTokenStore.instance.setUsername(username);
    }
  }
}
