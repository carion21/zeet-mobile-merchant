// Modeles representant les categories de produits cote API partner.
// Correspond aux reponses de `GET /v1/partner/product-categories`, etc.
//
// Le parsing est DEFENSIF : chaque champ nullable est gere avec des fallbacks.

/// Categorie simplifiee pour les dropdowns (select).
/// Retournee par `GET /v1/partner/product-categories/select`.
class CategorySelect {
  final int id;
  final String label;
  final String? value;

  const CategorySelect({
    required this.id,
    required this.label,
    this.value,
  });

  factory CategorySelect.fromJson(Map<String, dynamic> json) {
    return CategorySelect(
      id: json['id'] as int,
      label: json['label'] as String? ?? '',
      value: json['value'] as String?,
    );
  }

  @override
  String toString() => label;
}

/// Produit simplifie associe a une categorie (present dans le detail).
class CategoryProduct {
  final int id;
  final String? label;
  final String? slug;
  final double? price;
  final String? picture;
  final bool? status;
  final String? description;

  const CategoryProduct({
    required this.id,
    this.label,
    this.slug,
    this.price,
    this.picture,
    this.status,
    this.description,
  });

  factory CategoryProduct.fromJson(Map<String, dynamic> json) {
    return CategoryProduct(
      id: json['id'] as int,
      label: json['label'] as String? ?? json['name'] as String?,
      slug: json['slug'] as String? ?? json['value'] as String?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      picture: json['picture'] as String? ?? json['image'] as String?,
      status: json['status'] as bool?,
      description: json['description'] as String?,
    );
  }
}

/// Categorie de produits complete telle que retournee par l'API partner.
///
/// Champs principaux :
/// - `id`, `label`, `value` (slug), `status`, `description`, `picture`
/// - `partner` : peut etre un int OU un objet {id, name, picture, slug, status}
/// - `product_count` : nombre de produits (present dans le detail)
/// - `products` : liste de produits (present dans le detail)
class ProductCategory {
  final int id;
  final String label;
  final String? value;
  final bool status;
  final String? description;
  final String? picture;
  final int? partnerId;
  final String? code;
  final int? productCount;
  final List<CategoryProduct> products;
  final String? createdAt;
  final String? updatedAt;

  const ProductCategory({
    required this.id,
    required this.label,
    this.value,
    this.status = true,
    this.description,
    this.picture,
    this.partnerId,
    this.code,
    this.productCount,
    this.products = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// La categorie est-elle active ?
  bool get isActive => status;

  /// Nombre de produits (prefere product_count si dispo, sinon length de products).
  int get totalProducts => productCount ?? products.length;

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    // partner peut etre un int ou un objet
    int? partnerId;
    final partnerRaw = json['partner'];
    if (partnerRaw is int) {
      partnerId = partnerRaw;
    } else if (partnerRaw is Map<String, dynamic>) {
      partnerId = partnerRaw['id'] as int?;
    }
    partnerId ??= json['partner_id'] as int?;

    // products (present dans le detail)
    List<CategoryProduct> products = [];
    if (json['products'] != null && json['products'] is List) {
      products = (json['products'] as List)
          .whereType<Map<String, dynamic>>()
          .map((p) => CategoryProduct.fromJson(p))
          .toList();
    }

    return ProductCategory(
      id: json['id'] as int,
      label: json['label'] as String? ?? json['name'] as String? ?? '',
      value: json['value'] as String? ?? json['slug'] as String?,
      status: json['status'] as bool? ?? true,
      description: json['description'] as String?,
      picture: json['picture'] as String?,
      partnerId: partnerId,
      code: json['code'] as String?,
      productCount: json['product_count'] as int?,
      products: products,
      createdAt:
          json['date_created'] as String? ?? json['created_at'] as String?,
      updatedAt:
          json['date_updated'] as String? ?? json['updated_at'] as String?,
    );
  }

  ProductCategory copyWith({
    int? id,
    String? label,
    String? value,
    bool? status,
    String? description,
    String? picture,
    int? partnerId,
    String? code,
    int? productCount,
    List<CategoryProduct>? products,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      status: status ?? this.status,
      description: description ?? this.description,
      picture: picture ?? this.picture,
      partnerId: partnerId ?? this.partnerId,
      code: code ?? this.code,
      productCount: productCount ?? this.productCount,
      products: products ?? this.products,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
