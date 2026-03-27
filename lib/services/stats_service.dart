import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/stats_model.dart';
import 'package:merchant/services/api_client.dart';

/// Service pour les statistiques du partner.
/// Encapsule les appels aux endpoints /v1/partner/stats/* et /v1/partner/product-stats/*.
class StatsService {
  final ApiClient _apiClient;

  StatsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // Helper : construit les query params de date
  // ---------------------------------------------------------------------------

  Map<String, String> _buildDateParams({
    String? dateFrom,
    String? dateTo,
    int? limit,
  }) {
    final params = <String, String>{};
    if (dateFrom != null && dateFrom.isNotEmpty) {
      params['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      params['date_to'] = dateTo;
    }
    if (limit != null) {
      params['limit'] = limit.toString();
    }
    return params;
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/stats/revenue
  // ---------------------------------------------------------------------------
  /// Recupere les stats de revenus sur une periode.
  Future<RevenueStats> getRevenue({
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await _apiClient.get(
      StatsEndpoints.revenue,
      withAuth: true,
      queryParams: _buildDateParams(dateFrom: dateFrom, dateTo: dateTo),
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return RevenueStats.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/stats/orders
  // ---------------------------------------------------------------------------
  /// Recupere les stats de commandes sur une periode.
  Future<OrdersStats> getOrders({
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await _apiClient.get(
      StatsEndpoints.orders,
      withAuth: true,
      queryParams: _buildDateParams(dateFrom: dateFrom, dateTo: dateTo),
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return OrdersStats.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/stats/rating
  // ---------------------------------------------------------------------------
  /// Recupere les stats de notes/avis.
  Future<RatingStats> getRating() async {
    final response = await _apiClient.get(
      StatsEndpoints.rating,
      withAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return RatingStats.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/stats/top-products
  // ---------------------------------------------------------------------------
  /// Recupere le classement des meilleurs produits.
  Future<List<TopProduct>> getTopProducts({
    int? limit,
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await _apiClient.get(
      StatsEndpoints.topProducts,
      withAuth: true,
      queryParams: _buildDateParams(
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: limit,
      ),
    );

    final rawData = response['data'] ?? response['items'] ?? response;
    if (rawData is List) {
      return rawData
          .whereType<Map<String, dynamic>>()
          .map((e) => TopProduct.fromJson(e))
          .toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/stats/top-categories
  // ---------------------------------------------------------------------------
  /// Recupere le classement des meilleures categories.
  Future<List<TopCategory>> getTopCategories({
    int? limit,
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await _apiClient.get(
      StatsEndpoints.topCategories,
      withAuth: true,
      queryParams: _buildDateParams(
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: limit,
      ),
    );

    final rawData = response['data'] ?? response['items'] ?? response;
    if (rawData is List) {
      return rawData
          .whereType<Map<String, dynamic>>()
          .map((e) => TopCategory.fromJson(e))
          .toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/stats/top-customers
  // ---------------------------------------------------------------------------
  /// Recupere le classement des meilleurs clients.
  Future<List<TopCustomer>> getTopCustomers({
    int? limit,
    String? dateFrom,
    String? dateTo,
  }) async {
    final response = await _apiClient.get(
      StatsEndpoints.topCustomers,
      withAuth: true,
      queryParams: _buildDateParams(
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: limit,
      ),
    );

    final rawData = response['data'] ?? response['items'] ?? response;
    if (rawData is List) {
      return rawData
          .whereType<Map<String, dynamic>>()
          .map((e) => TopCustomer.fromJson(e))
          .toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/products/:id/stats
  // ---------------------------------------------------------------------------
  /// Recupere les stats detaillees d'un produit.
  Future<ProductStats> getProductStats(
    int productId, {
    String? period,
    String? sections,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String>{};
    if (period != null && period.isNotEmpty) {
      params['period'] = period;
    }
    if (sections != null && sections.isNotEmpty) {
      params['sections'] = sections;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      params['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      params['date_to'] = dateTo;
    }

    final response = await _apiClient.get(
      ProductEndpoints.stats(productId.toString()),
      withAuth: true,
      queryParams: params.isNotEmpty ? params : null,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductStats.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/product-stats/ranking
  // ---------------------------------------------------------------------------
  /// Recupere le classement global des produits.
  Future<ProductRanking> getProductRanking({
    String? period,
    String? sort,
    String? order,
    int? limit,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String>{};
    if (period != null && period.isNotEmpty) {
      params['period'] = period;
    }
    if (sort != null && sort.isNotEmpty) {
      params['sort'] = sort;
    }
    if (order != null && order.isNotEmpty) {
      params['order'] = order;
    }
    if (limit != null) {
      params['limit'] = limit.toString();
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      params['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      params['date_to'] = dateTo;
    }

    final response = await _apiClient.get(
      ProductStatsEndpoints.ranking,
      withAuth: true,
      queryParams: params.isNotEmpty ? params : null,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return ProductRanking.fromJson(data);
  }
}
