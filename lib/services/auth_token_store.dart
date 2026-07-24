/// In-memory store for the authenticated user's token.
///
/// Holds the token as a singleton so both [AuthService] and
/// [TanE06ApiClient] can access it without passing it through
/// every constructor.
class AuthTokenStore {
  AuthTokenStore._();
  static final AuthTokenStore instance = AuthTokenStore._();

  String? _token;

  /// The current auth token, or `null` if the user is not logged in.
  String? get token => _token;

  /// Returns true when a token is present.
  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Stores [token] after a successful login or registration.
  void setToken(String token) => _token = token;

  /// Clears the token on logout.
  void clear() => _token = null;
}
