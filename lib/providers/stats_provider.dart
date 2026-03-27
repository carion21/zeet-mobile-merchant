import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/stats_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/stats_service.dart';

// =============================================================================
// Stats State
// =============================================================================

enum StatsStatus { initial, loading, loaded, error }

class StatsState {
  final StatsStatus status;
  final RevenueStats? revenue;
  final OrdersStats? orders;
  final RatingStats? rating;
  final List<TopProduct> topProducts;
  final List<TopCategory> topCategories;
  final List<TopCustomer> topCustomers;
  final String? dateFrom;
  final String? dateTo;
  final String? errorMessage;

  const StatsState({
    this.status = StatsStatus.initial,
    this.revenue,
    this.orders,
    this.rating,
    this.topProducts = const [],
    this.topCategories = const [],
    this.topCustomers = const [],
    this.dateFrom,
    this.dateTo,
    this.errorMessage,
  });

  StatsState copyWith({
    StatsStatus? status,
    RevenueStats? revenue,
    OrdersStats? orders,
    RatingStats? rating,
    List<TopProduct>? topProducts,
    List<TopCategory>? topCategories,
    List<TopCustomer>? topCustomers,
    String? dateFrom,
    String? dateTo,
    String? errorMessage,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return StatsState(
      status: status ?? this.status,
      revenue: revenue ?? this.revenue,
      orders: orders ?? this.orders,
      rating: rating ?? this.rating,
      topProducts: topProducts ?? this.topProducts,
      topCategories: topCategories ?? this.topCategories,
      topCustomers: topCustomers ?? this.topCustomers,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      errorMessage: errorMessage,
    );
  }
}

// =============================================================================
// Stats Notifier
// =============================================================================

class StatsNotifier extends StateNotifier<StatsState> {
  final StatsService _statsService;

  StatsNotifier({StatsService? statsService})
      : _statsService = statsService ?? StatsService(),
        super(const StatsState());

  /// Met a jour les filtres de date et recharge toutes les stats.
  Future<void> setDateRange({String? dateFrom, String? dateTo}) async {
    state = state.copyWith(
      dateFrom: dateFrom,
      dateTo: dateTo,
      clearDateFrom: dateFrom == null,
      clearDateTo: dateTo == null,
    );
    await loadAll();
  }

  /// Charge toutes les stats en parallele.
  Future<void> loadAll() async {
    state = state.copyWith(status: StatsStatus.loading);

    try {
      final results = await Future.wait([
        _statsService.getRevenue(
          dateFrom: state.dateFrom,
          dateTo: state.dateTo,
        ),
        _statsService.getOrders(
          dateFrom: state.dateFrom,
          dateTo: state.dateTo,
        ),
        _statsService.getRating(),
        _statsService.getTopProducts(
          dateFrom: state.dateFrom,
          dateTo: state.dateTo,
        ),
        _statsService.getTopCategories(
          dateFrom: state.dateFrom,
          dateTo: state.dateTo,
        ),
        _statsService.getTopCustomers(
          dateFrom: state.dateFrom,
          dateTo: state.dateTo,
        ),
      ]);

      state = StatsState(
        status: StatsStatus.loaded,
        revenue: results[0] as RevenueStats,
        orders: results[1] as OrdersStats,
        rating: results[2] as RatingStats,
        topProducts: results[3] as List<TopProduct>,
        topCategories: results[4] as List<TopCategory>,
        topCustomers: results[5] as List<TopCustomer>,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
      );
    } on ApiException catch (e) {
      debugPrint('[StatsNotifier] loadAll failed: $e');
      state = state.copyWith(
        status: StatsStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[StatsNotifier] loadAll error: $e');
      state = state.copyWith(
        status: StatsStatus.error,
        errorMessage: 'Impossible de charger les statistiques',
      );
    }
  }

  /// Charge uniquement les revenus.
  Future<void> loadRevenue() async {
    try {
      final revenue = await _statsService.getRevenue(
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
      );
      state = state.copyWith(revenue: revenue);
    } catch (e) {
      debugPrint('[StatsNotifier] loadRevenue error: $e');
    }
  }

  /// Charge uniquement les stats commandes.
  Future<void> loadOrders() async {
    try {
      final orders = await _statsService.getOrders(
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
      );
      state = state.copyWith(orders: orders);
    } catch (e) {
      debugPrint('[StatsNotifier] loadOrders error: $e');
    }
  }

  /// Charge uniquement les stats de notes.
  Future<void> loadRating() async {
    try {
      final rating = await _statsService.getRating();
      state = state.copyWith(rating: rating);
    } catch (e) {
      debugPrint('[StatsNotifier] loadRating error: $e');
    }
  }

  /// Rafraichit toutes les stats.
  Future<void> refresh() => loadAll();
}

// =============================================================================
// Product Stats State
// =============================================================================

enum ProductStatsStatus { initial, loading, loaded, error }

class ProductStatsState {
  final ProductStatsStatus status;
  final ProductStats? productStats;
  final ProductRanking? ranking;
  final String? errorMessage;

  const ProductStatsState({
    this.status = ProductStatsStatus.initial,
    this.productStats,
    this.ranking,
    this.errorMessage,
  });

  ProductStatsState copyWith({
    ProductStatsStatus? status,
    ProductStats? productStats,
    ProductRanking? ranking,
    String? errorMessage,
  }) {
    return ProductStatsState(
      status: status ?? this.status,
      productStats: productStats ?? this.productStats,
      ranking: ranking ?? this.ranking,
      errorMessage: errorMessage,
    );
  }
}

// =============================================================================
// Product Stats Notifier
// =============================================================================

class ProductStatsNotifier extends StateNotifier<ProductStatsState> {
  final StatsService _statsService;

  ProductStatsNotifier({StatsService? statsService})
      : _statsService = statsService ?? StatsService(),
        super(const ProductStatsState());

  /// Charge les stats d'un produit specifique.
  Future<void> loadProductStats(
    int productId, {
    String? period,
    String sections = 'sales,quality',
    String? dateFrom,
    String? dateTo,
  }) async {
    state = state.copyWith(status: ProductStatsStatus.loading);

    try {
      final stats = await _statsService.getProductStats(
        productId,
        period: period,
        sections: sections,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      state = ProductStatsState(
        status: ProductStatsStatus.loaded,
        productStats: stats,
        ranking: state.ranking,
      );
    } on ApiException catch (e) {
      debugPrint('[ProductStatsNotifier] loadProductStats failed: $e');
      state = state.copyWith(
        status: ProductStatsStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[ProductStatsNotifier] loadProductStats error: $e');
      state = state.copyWith(
        status: ProductStatsStatus.error,
        errorMessage: 'Impossible de charger les stats du produit',
      );
    }
  }

  /// Charge le classement global des produits.
  Future<void> loadRanking({
    String? period,
    String sort = 'revenue',
    String order = 'desc',
    int limit = 10,
    String? dateFrom,
    String? dateTo,
  }) async {
    state = state.copyWith(status: ProductStatsStatus.loading);

    try {
      final ranking = await _statsService.getProductRanking(
        period: period,
        sort: sort,
        order: order,
        limit: limit,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      state = ProductStatsState(
        status: ProductStatsStatus.loaded,
        productStats: state.productStats,
        ranking: ranking,
      );
    } on ApiException catch (e) {
      debugPrint('[ProductStatsNotifier] loadRanking failed: $e');
      state = state.copyWith(
        status: ProductStatsStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[ProductStatsNotifier] loadRanking error: $e');
      state = state.copyWith(
        status: ProductStatsStatus.error,
        errorMessage: 'Impossible de charger le classement',
      );
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provider principal pour les stats globales du partner.
final statsProvider =
    StateNotifierProvider<StatsNotifier, StatsState>((ref) {
  return StatsNotifier();
});

/// Provider pour les stats produit (detail + ranking).
final productStatsProvider =
    StateNotifierProvider<ProductStatsNotifier, ProductStatsState>((ref) {
  return ProductStatsNotifier();
});

// ---------------------------------------------------------------------------
// Providers pratiques (computed)
// ---------------------------------------------------------------------------

/// Stats de revenus.
final revenueStatsProvider = Provider<RevenueStats?>((ref) {
  return ref.watch(statsProvider).revenue;
});

/// Stats de commandes.
final ordersStatsProvider = Provider<OrdersStats?>((ref) {
  return ref.watch(statsProvider).orders;
});

/// Stats de notes.
final ratingStatsProvider = Provider<RatingStats?>((ref) {
  return ref.watch(statsProvider).rating;
});

/// Top produits (stats detaillees).
final topProductsStatsProvider = Provider<List<TopProduct>>((ref) {
  return ref.watch(statsProvider).topProducts;
});

/// Top categories (stats detaillees).
final topCategoriesStatsProvider = Provider<List<TopCategory>>((ref) {
  return ref.watch(statsProvider).topCategories;
});

/// Top clients (stats detaillees).
final topCustomersStatsProvider = Provider<List<TopCustomer>>((ref) {
  return ref.watch(statsProvider).topCustomers;
});

/// Classement produits.
final productRankingProvider = Provider<ProductRanking?>((ref) {
  return ref.watch(productStatsProvider).ranking;
});
