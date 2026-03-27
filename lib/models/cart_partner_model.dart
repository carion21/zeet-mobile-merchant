import 'package:merchant/models/order_model.dart';

// =============================================================================
// Partner Cart — GET /v1/partner/carts
// =============================================================================

/// Un item dans le panier d'un client vu cote partner.
class PartnerCartItem {
  final int id;
  final int? productId;
  final String? productName;
  final String? productPicture;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? variantName;
  final List<String> options;

  const PartnerCartItem({
    required this.id,
    this.productId,
    this.productName,
    this.productPicture,
    this.quantity = 1,
    this.unitPrice = 0,
    this.subtotal = 0,
    this.variantName,
    this.options = const [],
  });

  factory PartnerCartItem.fromJson(Map<String, dynamic> json) {
    // Options peut etre une liste de strings ou de maps
    final rawOptions = json['options'];
    final List<String> parsedOptions = [];
    if (rawOptions is List) {
      for (final opt in rawOptions) {
        if (opt is String) {
          parsedOptions.add(opt);
        } else if (opt is Map) {
          parsedOptions.add(opt['name']?.toString() ?? '');
        }
      }
    }

    return PartnerCartItem(
      id: json['id'] as int? ?? 0,
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String? ??
          json['name'] as String?,
      productPicture: json['product_picture'] as String? ??
          json['picture'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ??
          (json['total'] as num?)?.toDouble() ??
          0,
      variantName: json['variant_name'] as String?,
      options: parsedOptions,
    );
  }
}

/// Informations client dans un panier.
class CartCustomer {
  final int id;
  final String? firstname;
  final String? lastname;
  final String? phone;

  const CartCustomer({
    required this.id,
    this.firstname,
    this.lastname,
    this.phone,
  });

  factory CartCustomer.fromJson(Map<String, dynamic> json) {
    return CartCustomer(
      id: json['id'] as int? ?? 0,
      firstname: json['firstname'] as String?,
      lastname: json['lastname'] as String?,
      phone: json['phone'] as String?,
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

/// Panier actif d'un client, vu cote partner.
class PartnerCart {
  final int id;
  final CartCustomer? customer;
  final List<PartnerCartItem> items;
  final double subtotal;
  final String? status;
  final String? lastActivity;
  final String? createdAt;
  final String? updatedAt;

  const PartnerCart({
    required this.id,
    this.customer,
    this.items = const [],
    this.subtotal = 0,
    this.status,
    this.lastActivity,
    this.createdAt,
    this.updatedAt,
  });

  factory PartnerCart.fromJson(Map<String, dynamic> json) {
    return PartnerCart(
      id: json['id'] as int? ?? 0,
      customer: json['customer'] is Map<String, dynamic>
          ? CartCustomer.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      items: _parseCartItems(json['items']),
      subtotal: (json['subtotal'] as num?)?.toDouble() ??
          (json['total'] as num?)?.toDouble() ??
          0,
      status: json['status'] as String?,
      lastActivity: json['last_activity'] as String? ??
          json['updated_at'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  /// Nombre total d'items dans le panier.
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  static List<PartnerCartItem> _parseCartItems(dynamic raw) {
    if (raw == null || raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => PartnerCartItem.fromJson(e))
        .toList();
  }
}

// =============================================================================
// Cart Stats — GET /v1/partner/carts/stats
// =============================================================================

/// Statistiques des paniers actifs pour le partner.
class CartStats {
  final int activeCarts;
  final double totalAmount;
  final double averageCartValue;
  final int totalItems;

  const CartStats({
    this.activeCarts = 0,
    this.totalAmount = 0,
    this.averageCartValue = 0,
    this.totalItems = 0,
  });

  factory CartStats.fromJson(Map<String, dynamic> json) {
    return CartStats(
      activeCarts: json['active_carts'] as int? ??
          json['count'] as int? ??
          json['total'] as int? ??
          0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      averageCartValue:
          (json['average_cart_value'] as num?)?.toDouble() ??
              (json['average_value'] as num?)?.toDouble() ??
              0,
      totalItems: json['total_items'] as int? ?? 0,
    );
  }
}

// =============================================================================
// Paginated Carts result
// =============================================================================

/// Resultat pagine pour les paniers.
/// Reutilise PaginationMeta de order_model.dart.
class PaginatedCarts {
  final List<PartnerCart> data;
  final PaginationMeta meta;

  const PaginatedCarts({required this.data, required this.meta});

  factory PaginatedCarts.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final List<PartnerCart> carts = [];
    if (rawData is List) {
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          carts.add(PartnerCart.fromJson(item));
        }
      }
    }

    final rawMeta = json['meta'] as Map<String, dynamic>? ?? json;
    return PaginatedCarts(
      data: carts,
      meta: PaginationMeta.fromJson(rawMeta),
    );
  }
}
