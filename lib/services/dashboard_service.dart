import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/dashboard_model.dart';
import 'package:merchant/services/api_client.dart';

/// Service pour le dashboard partner.
/// Encapsule l'appel a GET /v1/partner/dashboard/summary.
class DashboardService {
  final ApiClient _apiClient;

  DashboardService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/partner/dashboard/summary
  // ---------------------------------------------------------------------------
  /// Recupere le resume des KPIs du partner :
  /// orders_today, revenue_today, rating, active_carts,
  /// top_products, top_categories, top_customers.
  Future<DashboardSummary> getSummary() async {
    final response = await _apiClient.get(
      DashboardEndpoints.summary,
      withAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return DashboardSummary.fromJson(data);
  }
}
