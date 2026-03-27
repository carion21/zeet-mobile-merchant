import 'dart:convert';
import 'dart:io';
import 'package:merchant/core/constants/api.dart';
import 'package:merchant/core/utils/api_logger.dart';
import 'package:merchant/services/token_service.dart';
import 'package:http/http.dart' as http;

/// Exception personnalisee pour les erreurs API.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';

  /// Verifie si l'erreur est une 401 Unauthorized.
  bool get isUnauthorized => statusCode == 401;

  /// Verifie si l'erreur est une 422 Validation.
  bool get isValidation => statusCode == 422;
}

/// Client HTTP centralise avec gestion automatique :
/// - Headers d'authentification (Bearer token)
/// - Refresh automatique du token sur 401
/// - Logging des requetes/reponses
/// - Parsing standardise des reponses
class ApiClient {
  static ApiClient? _instance;
  final TokenService _tokenService;
  final http.Client _httpClient;

  /// Timeout par defaut pour les requetes HTTP.
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Drapeau pour eviter les boucles infinies de refresh.
  bool _isRefreshing = false;

  ApiClient._({
    TokenService? tokenService,
    http.Client? httpClient,
  })  : _tokenService = tokenService ?? TokenService.instance,
        _httpClient = httpClient ?? http.Client();

  /// Singleton.
  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _buildHeaders({bool withAuth = true}) async {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };

    if (withAuth) {
      final token = await _tokenService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
    }

    return headers;
  }

  // ---------------------------------------------------------------------------
  // Methodes HTTP publiques
  // ---------------------------------------------------------------------------

  /// GET request.
  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool withAuth = true,
    Map<String, String>? queryParams,
  }) async {
    final url = _buildUrl(endpoint, queryParams);
    final headers = await _buildHeaders(withAuth: withAuth);

    ApiLogger.logRequest(method: 'GET', url: url.toString(), headers: headers);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient.get(url, headers: headers).timeout(_defaultTimeout);
      stopwatch.stop();
      return _handleResponse('GET', url.toString(), response, stopwatch.elapsed);
    } catch (e, st) {
      stopwatch.stop();
      ApiLogger.logError(method: 'GET', url: url.toString(), error: e, stackTrace: st);
      rethrow;
    }
  }

  /// POST request.
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    final url = _buildUrl(endpoint);
    final headers = await _buildHeaders(withAuth: withAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;

    ApiLogger.logRequest(method: 'POST', url: url.toString(), headers: headers, body: encodedBody);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient.post(url, headers: headers, body: encodedBody).timeout(_defaultTimeout);
      stopwatch.stop();
      return _handleResponse('POST', url.toString(), response, stopwatch.elapsed);
    } catch (e, st) {
      stopwatch.stop();
      ApiLogger.logError(method: 'POST', url: url.toString(), error: e, stackTrace: st);
      rethrow;
    }
  }

  /// PUT request.
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    final url = _buildUrl(endpoint);
    final headers = await _buildHeaders(withAuth: withAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;

    ApiLogger.logRequest(method: 'PUT', url: url.toString(), headers: headers, body: encodedBody);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient.put(url, headers: headers, body: encodedBody).timeout(_defaultTimeout);
      stopwatch.stop();
      return _handleResponse('PUT', url.toString(), response, stopwatch.elapsed);
    } catch (e, st) {
      stopwatch.stop();
      ApiLogger.logError(method: 'PUT', url: url.toString(), error: e, stackTrace: st);
      rethrow;
    }
  }

  /// PATCH request.
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    final url = _buildUrl(endpoint);
    final headers = await _buildHeaders(withAuth: withAuth);
    final encodedBody = body != null ? jsonEncode(body) : null;

    ApiLogger.logRequest(method: 'PATCH', url: url.toString(), headers: headers, body: encodedBody);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient.patch(url, headers: headers, body: encodedBody).timeout(_defaultTimeout);
      stopwatch.stop();
      return _handleResponse('PATCH', url.toString(), response, stopwatch.elapsed);
    } catch (e, st) {
      stopwatch.stop();
      ApiLogger.logError(method: 'PATCH', url: url.toString(), error: e, stackTrace: st);
      rethrow;
    }
  }

  /// DELETE request.
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool withAuth = true,
  }) async {
    final url = _buildUrl(endpoint);
    final headers = await _buildHeaders(withAuth: withAuth);

    ApiLogger.logRequest(method: 'DELETE', url: url.toString(), headers: headers);
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient.delete(url, headers: headers).timeout(_defaultTimeout);
      stopwatch.stop();
      return _handleResponse('DELETE', url.toString(), response, stopwatch.elapsed);
    } catch (e, st) {
      stopwatch.stop();
      ApiLogger.logError(method: 'DELETE', url: url.toString(), error: e, stackTrace: st);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Gestion des reponses
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _handleResponse(
    String method,
    String url,
    http.Response response,
    Duration duration,
  ) async {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic> : <String, dynamic>{};

    ApiLogger.logResponse(
      method: method,
      url: url,
      statusCode: response.statusCode,
      body: body,
      duration: duration,
    );

    // Succes (2xx)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // 401 Unauthorized -- tenter un refresh automatique
    if (response.statusCode == 401 && !_isRefreshing) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        // Re-executer la requete originale avec le nouveau token
        return _retryRequest(method, url);
      }
    }

    // Erreur — message peut etre String ou List (validation NestJS)
    throw ApiException(
      statusCode: response.statusCode,
      message: body['message'] is String
          ? body['message'] as String
          : body['message'] is List
              ? (body['message'] as List).join(', ')
              : 'Une erreur est survenue',
      errors: body['errors'] as Map<String, dynamic>?,
    );
  }

  /// Tente de rafraichir le token d'acces.
  Future<bool> _tryRefreshToken() async {
    _isRefreshing = true;
    try {
      final refreshToken = await _tokenService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final url = _buildUrl(AuthEndpoints.refresh);
      final headers = {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
      };
      final body = jsonEncode({'refresh_token': refreshToken});

      final response = await _httpClient.post(url, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final responseData = data['data'] as Map<String, dynamic>? ?? data;

        final newAccessToken = responseData['access_token'] as String?;
        final newRefreshToken = responseData['refresh_token'] as String?;

        if (newAccessToken != null) {
          await _tokenService.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken ?? refreshToken,
          );
          return true;
        }
      }

      // Le refresh a echoue : nettoyer les tokens
      await _tokenService.clearTokens();
      return false;
    } catch (_) {
      await _tokenService.clearTokens();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Re-execute une requete apres un refresh de token reussi.
  Future<Map<String, dynamic>> _retryRequest(String method, String url) async {
    final headers = await _buildHeaders(withAuth: true);
    final uri = Uri.parse(url);

    http.Response response;
    switch (method) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers);
        break;
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: headers);
        break;
      default:
        // Pour POST/PUT on ne peut pas re-executer sans le body original.
        // Dans la majorite des cas, le 401 survient sur des GET.
        throw const ApiException(
          statusCode: 401,
          message: 'Session expiree, veuillez vous reconnecter',
        );
    }

    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: body['message'] is String
          ? body['message'] as String
          : body['message'] is List
              ? (body['message'] as List).join(', ')
              : 'Une erreur est survenue',
      errors: body['errors'] as Map<String, dynamic>?,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Uri _buildUrl(String endpoint, [Map<String, String>? queryParams]) {
    final fullUrl = '${ApiConfig.baseUrl}$endpoint';
    final uri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }
}
