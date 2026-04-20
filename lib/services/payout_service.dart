import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/order_model.dart' show PaginationMeta, PaginatedResult;
import 'package:merchant/models/payout_model.dart';
import 'package:merchant/services/api_client.dart';

/// Service pour les operations sur les demandes de virement (payouts) du partner.
/// Encapsule les appels aux endpoints `/v1/partner/payouts/*`.
class PayoutService {
  final ApiClient _apiClient;

  PayoutService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // POST /v1/partner/payouts
  // ---------------------------------------------------------------------------
  /// Cree une nouvelle demande de virement.
  Future<Payout> create(CreatePayoutRequest request) async {
    final response = await _apiClient.post(
      PayoutEndpoints.create,
      body: request.toJson(),
    );

    final data = response['data'] ?? response;
    if (data is Map<String, dynamic>) {
      return Payout.fromJson(data);
    }
    throw const ApiException(
      statusCode: 500,
      message: 'Réponse de création de payout invalide',
    );
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/payouts
  // ---------------------------------------------------------------------------
  /// Recupere la liste paginee des demandes de virement du partner.
  ///
  /// [page] : numero de page (defaut 1).
  /// [limit] : nombre de resultats par page (defaut 25).
  /// [status] : filtre optionnel par statut.
  Future<PaginatedResult<Payout>> list({
    int page = 1,
    int limit = 25,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.get(
      PayoutEndpoints.list,
      queryParams: queryParams,
    );

    final rawList = response['data'] as List? ?? const [];
    final payouts = rawList
        .whereType<Map<String, dynamic>>()
        .map(Payout.fromJson)
        .toList();

    final rawMeta = response['meta'];
    final meta = rawMeta is Map<String, dynamic>
        ? PaginationMeta.fromJson(rawMeta)
        : PaginationMeta(
            total: payouts.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );

    return PaginatedResult<Payout>(data: payouts, meta: meta);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/payouts/:uuid
  // ---------------------------------------------------------------------------
  /// Recupere le detail d'une demande de virement par son UUID.
  Future<Payout> getByUuid(String uuid) async {
    final response = await _apiClient.get(PayoutEndpoints.detail(uuid));

    final data = response['data'] ?? response;
    if (data is Map<String, dynamic>) {
      return Payout.fromJson(data);
    }
    throw ApiException(
      statusCode: 500,
      message: 'Reponse de detail de payout invalide pour $uuid',
    );
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/payouts/:uuid/validate
  // ---------------------------------------------------------------------------
  /// Valide une demande de virement.
  ///
  /// [code] : code de confirmation optionnel (non requis par l'API actuelle,
  /// mais expose pour compatibilite future si un OTP venait a etre ajoute).
  Future<Payout> validate(String uuid, {String? code}) async {
    final body = <String, dynamic>{};
    if (code != null && code.isNotEmpty) {
      body['code'] = code;
    }

    final response = await _apiClient.post(
      PayoutEndpoints.validate(uuid),
      body: body.isEmpty ? null : body,
    );

    final data = response['data'] ?? response;
    if (data is Map<String, dynamic>) {
      return Payout.fromJson(data);
    }
    throw ApiException(
      statusCode: 500,
      message: 'Reponse de validation de payout invalide pour $uuid',
    );
  }
}
