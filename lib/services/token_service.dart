import 'package:shared_preferences/shared_preferences.dart';

/// Service de stockage securise des tokens JWT.
/// Utilise SharedPreferences pour persister les tokens entre les sessions.
class TokenService {
  static const String _accessTokenKey = 'zeet_merchant_access_token';
  static const String _refreshTokenKey = 'zeet_merchant_refresh_token';

  static TokenService? _instance;
  SharedPreferences? _prefs;

  TokenService._();

  /// Singleton pour garantir une seule instance.
  static TokenService get instance {
    _instance ??= TokenService._();
    return _instance!;
  }

  /// Initialise le service (doit etre appele au demarrage de l'app).
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Assure que les prefs sont initialisees.
  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // ---------------------------------------------------------------------------
  // Access Token
  // ---------------------------------------------------------------------------

  Future<String?> getAccessToken() async {
    final prefs = await _preferences;
    return prefs.getString(_accessTokenKey);
  }

  Future<void> setAccessToken(String token) async {
    final prefs = await _preferences;
    await prefs.setString(_accessTokenKey, token);
  }

  // ---------------------------------------------------------------------------
  // Refresh Token
  // ---------------------------------------------------------------------------

  Future<String?> getRefreshToken() async {
    final prefs = await _preferences;
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> setRefreshToken(String token) async {
    final prefs = await _preferences;
    await prefs.setString(_refreshTokenKey, token);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Sauvegarde les deux tokens d'un coup (apres login/refresh).
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      setAccessToken(accessToken),
      setRefreshToken(refreshToken),
    ]);
  }

  /// Supprime tous les tokens (deconnexion).
  Future<void> clearTokens() async {
    final prefs = await _preferences;
    await Future.wait([
      prefs.remove(_accessTokenKey),
      prefs.remove(_refreshTokenKey),
    ]);
  }

  /// Verifie si un access token est stocke.
  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
