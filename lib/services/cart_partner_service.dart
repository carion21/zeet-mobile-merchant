import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/cart_partner_model.dart';
import 'package:merchant/services/api_client.dart';

/// Service pour les paniers actifs cote partner.
/// Encapsule les appels aux endpoints /v1/partner/carts.
class CartPartnerService {
  final ApiClient _apiClient;

  CartPartnerService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/partner/carts
  // ---------------------------------------------------------------------------
  /// Liste les paniers actifs des clients pour ce partner (pagine).
  Future<PaginatedCarts> listCarts({
    int page = 1,
    int limit = 25,
  }) async {
    final response = await _apiClient.get(
      CartEndpoints.list,
      withAuth: true,
      queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    return PaginatedCarts.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/carts/stats
  // ---------------------------------------------------------------------------
  /// Recupere les stats des paniers (nombre actifs, montant total, etc.).
  Future<CartStats> getCartStats() async {
    final response = await _apiClient.get(
      CartEndpoints.stats,
      withAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return CartStats.fromJson(data);
  }
}
