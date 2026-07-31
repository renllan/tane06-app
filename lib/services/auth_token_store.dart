/// In-memory store for the authenticated user's token and identity.
///
/// Holds the token and username as a singleton so both [AuthService] and
/// [TanE06ApiClient] can access them without passing through every constructor.
class AuthTokenStore {
  AuthTokenStore._();
  static final AuthTokenStore instance = AuthTokenStore._();

  String? _token;
  String? _username;

  /// The current auth token, or `null` if the user is not logged in.
  String? get token => _token;

  /// The signed-in user's display name or email.
  String? get username => _username;

  /// Returns true when a token is present.
  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Stores [token] after a successful login or registration.
  void setToken(String token) => _token = token;

  /// Stores the user's display name or email after a successful login.
  void setUsername(String username) => _username = username;

  /// Clears the token and identity on logout.
  void clear() {
    _token = null;
    _username = null;
  }
}
