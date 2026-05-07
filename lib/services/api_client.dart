import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:merchant/core/constants/api.dart';
import 'package:merchant/core/errors/api_exceptions.dart';
import 'package:merchant/core/utils/api_logger.dart';
import 'package:merchant/services/idempotency_cache.dart';
import 'package:merchant/services/token_service.dart';
import 'package:http/http.dart' as http;

// Re-export `ApiException` (et sous-classes typees) pour compat avec les
// call-sites historiques qui faisaient `import '...api_client.dart'`.
export 'package:merchant/core/errors/api_exceptions.dart';

/// Client HTTP centralise avec gestion automatique :
/// - Headers d'authentification (Bearer token)
/// - Refresh automatique du token sur 401
/// - Logging des requetes/reponses
/// - Parsing standardise des reponses
/// - **Idempotency-Key** sur les mutations critiques (Skill plan 7-D §1)
/// - **Retry exponentiel** sur 5xx + timeout (3 essais, 1s/2s/4s + jitter)
/// - **Erreurs typees** (Auth/Forbidden/NotFound/Validation/Conflict/Server/Network)
class ApiClient {
  static ApiClient? _instance;
  final TokenService _tokenService;
  final http.Client _httpClient;

  /// Timeout par defaut pour les requetes HTTP.
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Politique de retry exponentiel pour 5xx + timeout (`NetworkException`).
  /// Cible : 3 tentatives au total (1 initiale + 2 retries) avec backoff
  /// 1s puis 2s + jitter aleatoire +/- 250ms.
  static const int _maxRetries = 2;
  static const List<Duration> _retryBackoff = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  /// Drapeau pour eviter les boucles infinies de refresh.
  bool _isRefreshing = false;

  /// Callback appele quand la session est definitivement expiree
  /// (refresh echoue). L'appelant doit rediriger vers le login.
  static VoidCallback? onSessionExpired;

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

  Future<Map<String, String>> _buildHeaders({
    bool withAuth = true,
    String? idempotencyKey,
  }) async {
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

    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
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
    return _execute(
      method: 'GET',
      endpoint: endpoint,
      withAuth: withAuth,
      queryParams: queryParams,
    );
  }

  /// POST request.
  ///
  /// Si `idempotencyLogicalKey` est fourni, un en-tete `Idempotency-Key`
  /// stable est ajoute a la requete (UUID v4 persiste 24h). Garantit
  /// qu'un retry reseau ne provoque pas de doublon serveur. A utiliser
  /// pour toutes les mutations critiques (orders, payouts, wallet
  /// transfers...).
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    String? idempotencyLogicalKey,
  }) async {
    return _execute(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      withAuth: withAuth,
      idempotencyLogicalKey: idempotencyLogicalKey,
    );
  }

  /// PUT request.
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    String? idempotencyLogicalKey,
  }) async {
    return _execute(
      method: 'PUT',
      endpoint: endpoint,
      body: body,
      withAuth: withAuth,
      idempotencyLogicalKey: idempotencyLogicalKey,
    );
  }

  /// PATCH request.
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    String? idempotencyLogicalKey,
  }) async {
    return _execute(
      method: 'PATCH',
      endpoint: endpoint,
      body: body,
      withAuth: withAuth,
      idempotencyLogicalKey: idempotencyLogicalKey,
    );
  }

  /// DELETE request.
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool withAuth = true,
    String? idempotencyLogicalKey,
  }) async {
    return _execute(
      method: 'DELETE',
      endpoint: endpoint,
      withAuth: withAuth,
      idempotencyLogicalKey: idempotencyLogicalKey,
    );
  }

  // ---------------------------------------------------------------------------
  // Pipeline interne (timeout + retry exponentiel + refresh 401 + typage)
  // ---------------------------------------------------------------------------

  /// Execute la requete avec retry exponentiel pour 5xx + erreurs reseau.
  /// Les 4xx (sauf 408 Request Timeout) ne sont jamais retryees.
  Future<Map<String, dynamic>> _execute({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    bool withAuth = true,
    Map<String, String>? queryParams,
    String? idempotencyLogicalKey,
  }) async {
    final url = _buildUrl(endpoint, queryParams);
    final encodedBody = body != null ? jsonEncode(body) : null;

    // Genere ou recupere la cle d'idempotency pour cette mutation logique.
    String? idempotencyKey;
    if (idempotencyLogicalKey != null && idempotencyLogicalKey.isNotEmpty) {
      idempotencyKey = await IdempotencyCache.instance
          .keyFor(idempotencyLogicalKey);
    }

    int attempt = 0;
    while (true) {
      final headers = await _buildHeaders(
        withAuth: withAuth,
        idempotencyKey: idempotencyKey,
      );

      ApiLogger.logRequest(
        method: method,
        url: url.toString(),
        headers: headers,
        body: encodedBody,
      );
      final stopwatch = Stopwatch()..start();

      try {
        final response = await _send(method, url, headers, encodedBody);
        stopwatch.stop();
        final result = await _handleResponse(
          method: method,
          url: url.toString(),
          response: response,
          duration: stopwatch.elapsed,
          requestBody: encodedBody,
          idempotencyLogicalKey: idempotencyLogicalKey,
        );
        return result;
      } on ServerException catch (e) {
        // 5xx — retry exponentiel jusqu'a `_maxRetries`.
        if (attempt < _maxRetries) {
          await _sleepBackoff(attempt);
          attempt++;
          continue;
        }
        if (kDebugMode) {
          debugPrint(
            '[ApiClient] $method $url echec apres ${attempt + 1} tentatives '
            '(5xx persistant): ${e.message}',
          );
        }
        rethrow;
      } on NetworkException catch (e) {
        // Erreur reseau / timeout → retry exponentiel.
        if (attempt < _maxRetries) {
          await _sleepBackoff(attempt);
          attempt++;
          continue;
        }
        if (kDebugMode) {
          debugPrint(
            '[ApiClient] $method $url echec apres ${attempt + 1} tentatives '
            '(reseau persistant): ${e.message}',
          );
        }
        rethrow;
      } catch (e, st) {
        stopwatch.stop();
        ApiLogger.logError(
          method: method,
          url: url.toString(),
          error: e,
          stackTrace: st,
          requestBody: encodedBody,
        );
        rethrow;
      }
    }
  }

  /// Envoi HTTP brut. Convertit `SocketException` / `TimeoutException` /
  /// `HttpException` en `NetworkException` typee pour la couche superieure.
  Future<http.Response> _send(
    String method,
    Uri url,
    Map<String, String> headers,
    String? body,
  ) async {
    try {
      final http.Response response;
      switch (method) {
        case 'GET':
          response = await _httpClient
              .get(url, headers: headers)
              .timeout(_defaultTimeout);
          break;
        case 'DELETE':
          response = await _httpClient
              .delete(url, headers: headers, body: body)
              .timeout(_defaultTimeout);
          break;
        case 'POST':
          response = await _httpClient
              .post(url, headers: headers, body: body)
              .timeout(_defaultTimeout);
          break;
        case 'PUT':
          response = await _httpClient
              .put(url, headers: headers, body: body)
              .timeout(_defaultTimeout);
          break;
        case 'PATCH':
          response = await _httpClient
              .patch(url, headers: headers, body: body)
              .timeout(_defaultTimeout);
          break;
        default:
          throw ApiException(
            statusCode: 400,
            message: 'Methode HTTP non supportee : $method',
          );
      }
      return response;
    } on TimeoutException catch (e) {
      throw NetworkException(
        message: 'Le serveur ne repond pas (timeout). On va reessayer.',
        cause: e,
      );
    } on SocketException catch (e) {
      throw NetworkException(
        message: 'Pas de connexion reseau. L\'action sera envoyee plus tard.',
        cause: e,
      );
    } on HttpException catch (e) {
      throw NetworkException(message: 'Erreur reseau.', cause: e);
    }
  }

  /// Backoff exponentiel avec jitter aleatoire +/- 250ms pour eviter les
  /// thundering herds sur 5xx.
  Future<void> _sleepBackoff(int attempt) async {
    final base = _retryBackoff[attempt.clamp(0, _retryBackoff.length - 1)];
    final jitterMs = math.Random().nextInt(500) - 250; // [-250, 250)
    final wait = Duration(
      milliseconds: math.max(50, base.inMilliseconds + jitterMs),
    );
    await Future<void>.delayed(wait);
  }

  // ---------------------------------------------------------------------------
  // Gestion des reponses
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _handleResponse({
    required String method,
    required String url,
    required http.Response response,
    required Duration duration,
    String? requestBody,
    String? idempotencyLogicalKey,
  }) async {
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    ApiLogger.logResponse(
      method: method,
      url: url,
      statusCode: response.statusCode,
      body: body,
      duration: duration,
    );

    // Succes (2xx)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Mutation reussie : purger la cle d'idempotency pour eviter qu'un
      // retry futur (apres TTL) ne reutilise la meme cle a tort.
      if (idempotencyLogicalKey != null) {
        await IdempotencyCache.instance.purge(idempotencyLogicalKey);
      }
      return body;
    }

    // 401 Unauthorized -- tenter un refresh automatique
    if (response.statusCode == 401 && !_isRefreshing) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        return _retryRequest(method, url, requestBody, idempotencyLogicalKey);
      }
    }

    // Erreur — message peut etre String ou List (validation NestJS)
    final message = body['message'] is String
        ? body['message'] as String
        : body['message'] is List
            ? (body['message'] as List).join(', ')
            : 'Une erreur est survenue';

    // Log consolide avec input + reponse pour faciliter le debug
    ApiLogger.logError(
      method: method,
      url: url,
      error: 'HTTP ${response.statusCode}: $message',
      statusCode: response.statusCode,
      requestBody: requestBody,
      responseBody: body,
    );

    final errorCode = body['code'] as String?;
    final errorMap = body['errors'] as Map<String, dynamic>?;

    // Cas 4xx definitif (sauf 408 Request Timeout traitee comme reseau) :
    // purger la cle d'idempotency car la mutation est rejetee metier et
    // ne doit pas etre rejouee avec la meme cle.
    final is4xxFinal =
        response.statusCode >= 400 && response.statusCode < 500 &&
            response.statusCode != 408;
    if (is4xxFinal && idempotencyLogicalKey != null) {
      await IdempotencyCache.instance.purge(idempotencyLogicalKey);
    }

    // 408 Request Timeout : assimile a une erreur reseau pour beneficier
    // du retry exponentiel.
    if (response.statusCode == 408) {
      throw NetworkException(message: message);
    }

    throw ApiException.fromStatus(
      statusCode: response.statusCode,
      message: message,
      code: errorCode,
      errors: errorMap,
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

      final response =
          await _httpClient.post(url, headers: headers, body: body);

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

      // Le refresh a echoue : nettoyer les tokens et notifier.
      await _tokenService.clearTokens();
      onSessionExpired?.call();
      return false;
    } catch (_) {
      await _tokenService.clearTokens();
      onSessionExpired?.call();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Re-execute une requete apres un refresh de token reussi.
  Future<Map<String, dynamic>> _retryRequest(
    String method,
    String url,
    String? requestBody,
    String? idempotencyLogicalKey,
  ) async {
    String? idempotencyKey;
    if (idempotencyLogicalKey != null) {
      idempotencyKey =
          await IdempotencyCache.instance.keyFor(idempotencyLogicalKey);
    }
    final headers =
        await _buildHeaders(withAuth: true, idempotencyKey: idempotencyKey);
    final uri = Uri.parse(url);

    final response = await _send(method, uri, headers, requestBody);

    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (idempotencyLogicalKey != null) {
        await IdempotencyCache.instance.purge(idempotencyLogicalKey);
      }
      return body;
    }

    if (response.statusCode == 408) {
      throw NetworkException(
        message: body['message'] is String
            ? body['message'] as String
            : 'Le serveur ne repond pas.',
      );
    }

    throw ApiException.fromStatus(
      statusCode: response.statusCode,
      message: body['message'] is String
          ? body['message'] as String
          : body['message'] is List
              ? (body['message'] as List).join(', ')
              : 'Une erreur est survenue',
      code: body['code'] as String?,
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
