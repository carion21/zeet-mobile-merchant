import 'dart:convert';
import 'dart:io';
import 'package:merchant/core/constants/api.dart';
import 'package:merchant/core/utils/api_logger.dart';
import 'package:merchant/models/partner_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/token_service.dart';
import 'package:http/http.dart' as http;

/// Service pour la gestion du profil partner.
/// Encapsule les appels aux endpoints `/v1/partner/profile`, `/v1/partner/commission-rate`,
/// `/v1/partner/availability` et `/v1/partner/profile/logo`.
class ProfileService {
  final ApiClient _apiClient;
  final TokenService _tokenService;

  ProfileService({
    ApiClient? apiClient,
    TokenService? tokenService,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _tokenService = tokenService ?? TokenService.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/partner/profile
  // ---------------------------------------------------------------------------
  /// Recupere le profil complet du partner (donnees restaurant).
  ///
  /// Retourne un [PartnerData] avec nom, description, horaires, etc.
  Future<PartnerData> getProfile() async {
    final response = await _apiClient.get(
      ProfileEndpoints.get,
      withAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return PartnerData.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/profile
  // ---------------------------------------------------------------------------
  /// Met a jour le profil du partner.
  ///
  /// Seuls les champs fournis (non null) sont envoyes dans le body.
  /// Champs possibles : description, phone, prep_time_min.
  Future<PartnerData> updateProfile({
    String? description,
    String? phone,
    int? prepTimeMin,
  }) async {
    final body = <String, dynamic>{};
    if (description != null) body['description'] = description;
    if (phone != null) body['phone'] = phone;
    if (prepTimeMin != null) body['prep_time_min'] = prepTimeMin;

    final response = await _apiClient.patch(
      ProfileEndpoints.update,
      body: body,
      withAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return PartnerData.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/commission-rate
  // ---------------------------------------------------------------------------
  /// Recupere le taux de commission applique au partner.
  ///
  /// Retourne le taux sous forme de double (ex: 15.0 pour 15%).
  Future<double> getCommissionRate() async {
    final response = await _apiClient.get(
      ProfileEndpoints.commissionRate,
      withAuth: true,
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return (data['commission_rate'] as num?)?.toDouble() ?? 0;
    }
    // Fallback : la reponse peut etre directement le taux
    if (data is num) return data.toDouble();
    return 0;
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/partner/availability
  // ---------------------------------------------------------------------------
  /// Met a jour les horaires d'ouverture du partner.
  ///
  /// [schedules] : liste de PartnerSchedule avec day, is_open, opening_time, closing_time.
  /// L'API attend un body `{"schedules": [...]}`.
  Future<List<PartnerSchedule>> updateAvailability(
    List<PartnerSchedule> schedules,
  ) async {
    final body = {
      'schedules': schedules.map((s) => {
        'day': s.day,
        'is_open': s.isOpen,
        if (s.openingTime != null) 'opening_time': s.openingTime,
        if (s.closingTime != null) 'closing_time': s.closingTime,
      }).toList(),
    };

    final response = await _apiClient.patch(
      ProfileEndpoints.availability,
      body: body,
      withAuth: true,
    );

    // L'API retourne les schedules mis a jour
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((e) => PartnerSchedule.fromJson(e))
          .toList();
    }
    if (data is Map<String, dynamic> && data['schedules'] is List) {
      return (data['schedules'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => PartnerSchedule.fromJson(e))
          .toList();
    }

    return schedules;
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/profile/logo  (multipart/form-data)
  // ---------------------------------------------------------------------------
  /// Upload le logo du partner.
  ///
  /// [imageFile] : fichier image (JPEG, PNG ou WebP, max 5MB).
  /// Utilise une requete multipart directe car l'ApiClient ne gere que le JSON.
  ///
  /// Retourne l'URL du logo upload, ou null si la reponse ne contient pas d'URL.
  Future<String?> uploadLogo(File imageFile) async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ProfileEndpoints.uploadLogo}');
    final token = await _tokenService.getAccessToken();

    ApiLogger.logRequest(
      method: 'POST',
      url: url.toString(),
      headers: {'Authorization': 'Bearer ${token ?? ''}'},
      body: 'multipart/form-data (file: ${imageFile.path})',
    );

    final stopwatch = Stopwatch()..start();

    final request = http.MultipartRequest('POST', url);

    // Headers d'authentification
    if (token != null && token.isNotEmpty) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    request.headers[HttpHeaders.acceptHeader] = 'application/json';

    // Fichier image
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();

      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      ApiLogger.logResponse(
        method: 'POST',
        url: url.toString(),
        statusCode: response.statusCode,
        body: body,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body['data'] as Map<String, dynamic>?;
        return data?['picture'] as String?;
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: body['message'] is String
            ? body['message'] as String
            : body['message'] is List
                ? (body['message'] as List).join(', ')
                : 'Erreur lors de l\'upload du logo',
      );
    } catch (e, st) {
      stopwatch.stop();
      if (e is ApiException) rethrow;
      ApiLogger.logError(
        method: 'POST',
        url: url.toString(),
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE /v1/partner/profile/logo
  // ---------------------------------------------------------------------------
  /// Supprime le logo du partner.
  Future<void> deleteLogo() async {
    await _apiClient.delete(
      ProfileEndpoints.removeLogo,
      withAuth: true,
    );
  }
}
