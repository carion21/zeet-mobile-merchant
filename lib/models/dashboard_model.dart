/// Modele representant un produit dans le classement (top products).
class TopProduct {
  final int id;
  final String name;
  final String? picture;
  final int ordersCount;
  final double revenue;

  const TopProduct({
    required this.id,
    required this.name,
    this.picture,
    required this.ordersCount,
    required this.revenue,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      picture: json['picture'] as String?,
      ordersCount: json['orders_count'] as int? ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Modele representant une categorie dans le classement (top categories).
class TopCategory {
  final int id;
  final String name;
  final String? picture;
  final int ordersCount;
  final double revenue;

  const TopCategory({
    required this.id,
    required this.name,
    this.picture,
    required this.ordersCount,
    required this.revenue,
  });

  factory TopCategory.fromJson(Map<String, dynamic> json) {
    return TopCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      picture: json['picture'] as String?,
      ordersCount: json['orders_count'] as int? ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Modele representant un client dans le classement (top customers).
class TopCustomer {
  final int id;
  final String? firstname;
  final String? lastname;
  final String? phone;
  final int ordersCount;
  final double totalSpent;

  const TopCustomer({
    required this.id,
    this.firstname,
    this.lastname,
    this.phone,
    required this.ordersCount,
    required this.totalSpent,
  });

  factory TopCustomer.fromJson(Map<String, dynamic> json) {
    return TopCustomer(
      id: json['id'] as int,
      firstname: json['firstname'] as String?,
      lastname: json['lastname'] as String?,
      phone: json['phone'] as String?,
      ordersCount: json['orders_count'] as int? ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Nom complet du client.
  String get fullName {
    final parts = <String>[];
    if (firstname != null && firstname!.isNotEmpty) parts.add(firstname!);
    if (lastname != null && lastname!.isNotEmpty) parts.add(lastname!);
    return parts.isNotEmpty ? parts.join(' ') : 'Client';
  }
}

/// Modele representant le resume du dashboard partner.
/// Retourne par GET /v1/partner/dashboard/summary.
class DashboardSummary {
  final int ordersToday;
  final double revenueToday;
  final double rating;
  final int activeCarts;
  final List<TopProduct> topProducts;
  final List<TopCategory> topCategories;
  final List<TopCustomer> topCustomers;

  const DashboardSummary({
    this.ordersToday = 0,
    this.revenueToday = 0,
    this.rating = 0,
    this.activeCarts = 0,
    this.topProducts = const [],
    this.topCategories = const [],
    this.topCustomers = const [],
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      ordersToday: json['orders_today'] as int? ?? 0,
      revenueToday: (json['revenue_today'] as num?)?.toDouble() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      activeCarts: json['active_carts'] as int? ?? 0,
      topProducts: _parseList(json['top_products'], TopProduct.fromJson),
      topCategories: _parseList(json['top_categories'], TopCategory.fromJson),
      topCustomers: _parseList(json['top_customers'], TopCustomer.fromJson),
    );
  }

  /// Helper generique pour parser des listes potentiellement null ou mal typees.
  static List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => fromJson(e))
        .toList();
  }
}
