import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/order_model.dart' show PaginationMeta, PaginatedResult;
import 'package:merchant/models/transaction_model.dart';
import 'package:merchant/services/api_client.dart';

/// Service pour les operations sur les transactions financieres du partner.
/// Encapsule les appels a l'endpoint `/v1/partner/transactions`.
class TransactionService {
  final ApiClient _apiClient;

  TransactionService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/partner/transactions
  // ---------------------------------------------------------------------------
  /// Recupere la liste paginee des transactions financieres du partner.
  ///
  /// [page] : numero de page (defaut 1).
  /// [limit] : nombre de resultats par page (defaut 25).
  /// [search] : recherche par code ou reference externe.
  /// [type] : filtre par type ("recharge", "purchase", "refund").
  /// [status] : filtre par statut ("pending", "completed", "failed").
  /// [dateFrom] : date de debut au format ISO.
  /// [dateTo] : date de fin au format ISO.
  Future<PaginatedResult<Transaction>> list({
    int page = 1,
    int limit = 25,
    String? search,
    String? type,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParams['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParams['date_to'] = dateTo;
    }

    final response = await _apiClient.get(
      TransactionEndpoints.list,
      queryParams: queryParams,
    );

    final rawList = response['data'] as List? ?? const [];
    final transactions = rawList
        .whereType<Map<String, dynamic>>()
        .map(Transaction.fromJson)
        .toList();

    final rawMeta = response['meta'];
    final meta = rawMeta is Map<String, dynamic>
        ? PaginationMeta.fromJson(rawMeta)
        : PaginationMeta(
            total: transactions.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );

    return PaginatedResult<Transaction>(data: transactions, meta: meta);
  }
}
