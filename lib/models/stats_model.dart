export 'package:merchant/models/dashboard_model.dart'
    show TopProduct, TopCategory, TopCustomer;

/// Helper generique pour parser des listes potentiellement null ou mal typees.
List<T> _parseList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw == null || raw is! List) return [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map((e) => fromJson(e))
      .toList();
}

// =============================================================================
// Revenue Stats — GET /v1/partner/stats/revenue
// =============================================================================

/// Statistiques de revenus sur une periode donnee.
class RevenueStats {
  final double totalRevenue;
  final double netRevenue;
  final double commission;
  final double commissionRate;
  final int ordersCount;
  final double averageOrderValue;
  final String? dateFrom;
  final String? dateTo;

  const RevenueStats({
    this.totalRevenue = 0,
    this.netRevenue = 0,
    this.commission = 0,
    this.commissionRate = 0,
    this.ordersCount = 0,
    this.averageOrderValue = 0,
    this.dateFrom,
    this.dateTo,
  });

  factory RevenueStats.fromJson(Map<String, dynamic> json) {
    return RevenueStats(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      netRevenue: (json['net_revenue'] as num?)?.toDouble() ?? 0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0,
      ordersCount: json['orders_count'] as int? ?? 0,
      averageOrderValue:
          (json['average_order_value'] as num?)?.toDouble() ?? 0,
      dateFrom: json['date_from'] as String?,
      dateTo: json['date_to'] as String?,
    );
  }
}

// =============================================================================
// Orders Stats — GET /v1/partner/stats/orders
// =============================================================================

/// Statistiques de commandes sur une periode donnee.
class OrdersStats {
  final int totalOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double completionRate;
  final double cancellationRate;
  final double averagePreparationTime;
  final Map<String, int> byStatus;
  final String? dateFrom;
  final String? dateTo;

  const OrdersStats({
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.completionRate = 0,
    this.cancellationRate = 0,
    this.averagePreparationTime = 0,
    this.byStatus = const {},
    this.dateFrom,
    this.dateTo,
  });

  factory OrdersStats.fromJson(Map<String, dynamic> json) {
    // Parse by_status map defensivement
    final rawByStatus = json['by_status'];
    final Map<String, int> parsedByStatus = {};
    if (rawByStatus is Map) {
      for (final entry in rawByStatus.entries) {
        parsedByStatus[entry.key.toString()] =
            (entry.value as num?)?.toInt() ?? 0;
      }
    }

    return OrdersStats(
      totalOrders: json['total_orders'] as int? ?? 0,
      completedOrders: json['completed_orders'] as int? ?? 0,
      cancelledOrders: json['cancelled_orders'] as int? ?? 0,
      completionRate:
          (json['completion_rate'] as num?)?.toDouble() ?? 0,
      cancellationRate:
          (json['cancellation_rate'] as num?)?.toDouble() ?? 0,
      averagePreparationTime:
          (json['average_preparation_time'] as num?)?.toDouble() ?? 0,
      byStatus: parsedByStatus,
      dateFrom: json['date_from'] as String?,
      dateTo: json['date_to'] as String?,
    );
  }
}

// =============================================================================
// Rating Stats — GET /v1/partner/stats/rating
// =============================================================================

/// Statistiques de notes et avis du partner.
class RatingStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> distribution;

  const RatingStats({
    this.averageRating = 0,
    this.totalReviews = 0,
    this.distribution = const {},
  });

  factory RatingStats.fromJson(Map<String, dynamic> json) {
    // Parse distribution : { "1": 5, "2": 3, ... "5": 20 }
    final rawDist = json['distribution'];
    final Map<int, int> parsedDist = {};
    if (rawDist is Map) {
      for (final entry in rawDist.entries) {
        final key = int.tryParse(entry.key.toString());
        if (key != null) {
          parsedDist[key] = (entry.value as num?)?.toInt() ?? 0;
        }
      }
    }

    return RatingStats(
      averageRating: (json['average_rating'] as num?)?.toDouble() ??
          (json['average'] as num?)?.toDouble() ??
          0,
      totalReviews: json['total_reviews'] as int? ??
          json['total'] as int? ??
          0,
      distribution: parsedDist,
    );
  }
}

// =============================================================================
// Product Stats — GET /v1/partner/products/:id/stats
// =============================================================================

/// Section ventes d'un produit.
class ProductSalesStat {
  final int totalOrders;
  final int totalQuantity;
  final double totalRevenue;
  final double averageOrderValue;

  const ProductSalesStat({
    this.totalOrders = 0,
    this.totalQuantity = 0,
    this.totalRevenue = 0,
    this.averageOrderValue = 0,
  });

  factory ProductSalesStat.fromJson(Map<String, dynamic> json) {
    return ProductSalesStat(
      totalOrders: json['total_orders'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      averageOrderValue:
          (json['average_order_value'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Section qualite d'un produit.
class ProductQualityStat {
  final double averageRating;
  final int totalReviews;
  final double returnRate;

  const ProductQualityStat({
    this.averageRating = 0,
    this.totalReviews = 0,
    this.returnRate = 0,
  });

  factory ProductQualityStat.fromJson(Map<String, dynamic> json) {
    return ProductQualityStat(
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      returnRate: (json['return_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Stats detaillees d'un produit (sales + quality).
class ProductStats {
  final int productId;
  final String? productName;
  final ProductSalesStat? sales;
  final ProductQualityStat? quality;
  final String? period;

  const ProductStats({
    required this.productId,
    this.productName,
    this.sales,
    this.quality,
    this.period,
  });

  factory ProductStats.fromJson(Map<String, dynamic> json) {
    return ProductStats(
      productId: json['product_id'] as int? ?? json['id'] as int? ?? 0,
      productName: json['product_name'] as String? ?? json['name'] as String?,
      sales: json['sales'] is Map<String, dynamic>
          ? ProductSalesStat.fromJson(json['sales'] as Map<String, dynamic>)
          : null,
      quality: json['quality'] is Map<String, dynamic>
          ? ProductQualityStat.fromJson(
              json['quality'] as Map<String, dynamic>)
          : null,
      period: json['period'] as String?,
    );
  }
}

// =============================================================================
// Product Ranking — GET /v1/partner/product-stats/ranking
// =============================================================================

/// Un produit dans le classement (plus detaille que TopProduct du dashboard).
class ProductRankingItem {
  final int id;
  final String name;
  final String? picture;
  final int rank;
  final int ordersCount;
  final int totalQuantity;
  final double revenue;
  final double averageRating;

  const ProductRankingItem({
    required this.id,
    required this.name,
    this.picture,
    this.rank = 0,
    this.ordersCount = 0,
    this.totalQuantity = 0,
    this.revenue = 0,
    this.averageRating = 0,
  });

  factory ProductRankingItem.fromJson(Map<String, dynamic> json) {
    return ProductRankingItem(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      picture: json['picture'] as String?,
      rank: json['rank'] as int? ?? 0,
      ordersCount: json['orders_count'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Reponse du classement produits.
class ProductRanking {
  final List<ProductRankingItem> items;
  final String? period;
  final String? sort;
  final String? order;

  const ProductRanking({
    this.items = const [],
    this.period,
    this.sort,
    this.order,
  });

  factory ProductRanking.fromJson(Map<String, dynamic> json) {
    return ProductRanking(
      items: _parseList(
        json['items'] ?? json['data'] ?? json['products'],
        ProductRankingItem.fromJson,
      ),
      period: json['period'] as String?,
      sort: json['sort'] as String?,
      order: json['order'] as String?,
    );
  }
}

// TopProduct, TopCategory, TopCustomer sont definis dans dashboard_model.dart
// et re-exportes via l'export en haut de ce fichier.
