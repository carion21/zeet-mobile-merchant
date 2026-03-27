import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/partner_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/token_service.dart';

/// Service d'authentification pour la surface partner.
/// Encapsule les appels aux endpoints `/v1/auth/*`.
///
/// IMPORTANT : le partner utilise login/password (pas OTP).
/// Le body du login inclut toujours `"surface": "partner"`.
class AuthService {
  final ApiClient _apiClient;
  final TokenService _tokenService;

  AuthService({
    ApiClient? apiClient,
    TokenService? tokenService,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _tokenService = tokenService ?? TokenService.instance;

  // ---------------------------------------------------------------------------
  // POST /v1/auth/login
  // ---------------------------------------------------------------------------
  /// Authentifie le partner avec son telephone et mot de passe.
  ///
  /// [phone]    : numero au format local (ex: "0746041504").
  /// [password] : mot de passe du partner.
  ///
  /// CRITIQUE : `surface` est toujours "partner".
  ///
  /// En cas de succes, sauvegarde automatiquement les tokens (access + refresh)
  /// et retourne la reponse contenant les tokens.
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final response = await _apiClient.post(
      AuthEndpoints.login,
      body: {
        'phone': phone,
        'password': password,
        'surface': 'partner',
      },
      withAuth: false,
    );

    // Extraire et persister les tokens
    final data = response['data'] as Map<String, dynamic>? ?? response;
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken != null && refreshToken != null) {
      await _tokenService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }

    return response;
  }

  // ---------------------------------------------------------------------------
  // POST /v1/auth/refresh
  // ---------------------------------------------------------------------------
  /// Rafraichit le token d'acces en utilisant le refresh token stocke.
  ///
  /// Sauvegarde automatiquement les nouveaux tokens.
  /// Retourne `true` si le refresh a reussi, `false` sinon.
  Future<bool> refreshToken() async {
    final refreshToken = await _tokenService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _apiClient.post(
        AuthEndpoints.refresh,
        body: {'refresh_token': refreshToken},
        withAuth: false,
      );

      final data = response['data'] as Map<String, dynamic>? ?? response;
      final newAccessToken = data['access_token'] as String?;
      final newRefreshToken = data['refresh_token'] as String?;

      if (newAccessToken != null) {
        await _tokenService.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken ?? refreshToken,
        );
        return true;
      }

      return false;
    } on ApiException {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // GET /v1/auth/me
  // ---------------------------------------------------------------------------
  /// Recupere le profil du partner connecte (enrichi avec les donnees partner).
  ///
  /// Necessite un access token valide (envoye automatiquement via ApiClient).
  /// Retourne un [PartnerModel] incluant partner data + schedules.
  Future<PartnerModel> getMe() async {
    final response = await _apiClient.get(
      AuthEndpoints.me,
      withAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return PartnerModel.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/auth/logout
  // ---------------------------------------------------------------------------
  /// Deconnecte le partner en invalidant son refresh token cote serveur,
  /// puis supprime les tokens locaux.
  Future<void> logout() async {
    final refreshToken = await _tokenService.getRefreshToken();

    // Tenter de notifier le serveur (best-effort)
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _apiClient.post(
          AuthEndpoints.logout,
          body: {'refresh_token': refreshToken},
          withAuth: true,
        );
      } catch (_) {
        // On ne bloque pas la deconnexion locale si le serveur echoue
      }
    }

    // Toujours nettoyer les tokens locaux
    await _tokenService.clearTokens();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Verifie si le partner a une session active (tokens stockes).
  Future<bool> isAuthenticated() async {
    return _tokenService.hasTokens();
  }
}
