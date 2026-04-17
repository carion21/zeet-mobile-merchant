import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/order_model.dart' show PaginationMeta, PaginatedResult;
import 'package:merchant/models/wallet_model.dart';
import 'package:merchant/services/api_client.dart';

/// Service pour les operations sur le portefeuille partner.
/// Encapsule les appels aux endpoints `/v1/partner/wallet/*`.
class WalletService {
  final ApiClient _apiClient;

  WalletService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/partner/wallet
  // ---------------------------------------------------------------------------
  /// Recupere le solde du portefeuille.
  Future<Wallet> getBalance() async {
    final response = await _apiClient.get(WalletEndpoints.balance);

    final data = response['data'] ?? response;
    if (data is Map<String, dynamic>) {
      return Wallet.fromJson(data);
    }
    return Wallet.empty;
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/wallet/entries
  // ---------------------------------------------------------------------------
  /// Recupere la liste paginee des transactions du portefeuille.
  ///
  /// [page] : numero de page (defaut 1).
  /// [limit] : nombre de resultats par page (defaut 25).
  /// [direction] : filtre optionnel par direction ("debit" ou "credit").
  Future<PaginatedResult<WalletEntry>> getEntries({
    int page = 1,
    int limit = 25,
    String? direction,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (direction != null && direction.isNotEmpty) {
      queryParams['direction'] = direction;
    }

    final response = await _apiClient.get(
      WalletEndpoints.entries,
      queryParams: queryParams,
    );

    // Pattern "spread": l'API peut retourner { message, data, meta } ou
    // { message, ...result } selon la route. On accepte les deux.
    final rawList = response['data'] as List? ?? const [];
    final entries = rawList
        .whereType<Map<String, dynamic>>()
        .map(WalletEntry.fromJson)
        .toList();

    final rawMeta = response['meta'];
    final meta = rawMeta is Map<String, dynamic>
        ? PaginationMeta.fromJson(rawMeta)
        : PaginationMeta(
            total: entries.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );

    return PaginatedResult<WalletEntry>(data: entries, meta: meta);
  }
}
