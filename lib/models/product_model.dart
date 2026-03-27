// Modeles representant les produits et leurs sous-entites cote API partner.
// Correspond aux reponses de `GET /v1/partner/products`, `GET /v1/partner/products/:id`, etc.
//
// Le parsing est DEFENSIF : chaque champ nullable est gere avec des fallbacks.
// Le produit est un modele complexe : il contient des variantes, des groupes
// d'options (chaque groupe a des items), et des images.

/// Image d'un produit.
/// Retournee par `GET /v1/partner/products/:id/pictures` et dans le detail produit.
class ProductPicture {
  final int id;
  final String? link;
  final String? objectName;
  final bool status;
  final int? productId;
  final String? dateCreated;
  final String? dateUpdated;

  const ProductPicture({
    required this.id,
    this.link,
    this.objectName,
    this.status = true,
    this.productId,
    this.dateCreated,
    this.dateUpdated,
  });

  factory ProductPicture.fromJson(Map<String, dynamic> json) {
    // product peut etre un int ou un objet
    int? productId;
    final productRaw = json['product'];
    if (productRaw is int) {
      productId = productRaw;
    } else if (productRaw is Map<String, dynamic>) {
      productId = productRaw['id'] as int?;
    }

    return ProductPicture(
      id: json['id'] as int,
      link: json['link'] as String? ?? json['url'] as String?,
      objectName: json['object_name'] as String?,
      status: json['status'] as bool? ?? true,
      productId: productId ?? json['product_id'] as int?,
      dateCreated:
          json['date_created'] as String? ?? json['created_at'] as String?,
      dateUpdated:
          json['date_updated'] as String? ?? json['updated_at'] as String?,
    );
  }

  ProductPicture copyWith({
    int? id,
    String? link,
    String? objectName,
    bool? status,
    int? productId,
    String? dateCreated,
    String? dateUpdated,
  }) {
    return ProductPicture(
      id: id ?? this.id,
      link: link ?? this.link,
      objectName: objectName ?? this.objectName,
      status: status ?? this.status,
      productId: productId ?? this.productId,
      dateCreated: dateCreated ?? this.dateCreated,
      dateUpdated: dateUpdated ?? this.dateUpdated,
    );
  }
}

/// Item d'un groupe d'options (ex: "Frites", "Salade").
/// Retourne par `GET /v1/partner/products/:id/option-groups/:gid/items`.
class ProductOptionItem {
  final int id;
  final String name;
  final int priceDelta;
  final int orderIndex;
  final String? description;
  final bool status;
  final int? optionGroupId;
  final String? dateCreated;
  final String? dateUpdated;

  const ProductOptionItem({
    required this.id,
    required this.name,
    this.priceDelta = 0,
    this.orderIndex = 0,
    this.description,
    this.status = true,
    this.optionGroupId,
    this.dateCreated,
    this.dateUpdated,
  });

  factory ProductOptionItem.fromJson(Map<String, dynamic> json) {
    // option_group peut etre un int ou un objet
    int? optionGroupId;
    final groupRaw = json['option_group'];
    if (groupRaw is int) {
      optionGroupId = groupRaw;
    } else if (groupRaw is Map<String, dynamic>) {
      optionGroupId = groupRaw['id'] as int?;
    }
    optionGroupId ??= json['option_group_id'] as int?;

    return ProductOptionItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      priceDelta: json['price_delta'] as int? ?? 0,
      orderIndex: json['order_index'] as int? ?? 0,
      description: json['description'] as String?,
      status: json['status'] as bool? ?? true,
      optionGroupId: optionGroupId,
      dateCreated:
          json['date_created'] as String? ?? json['created_at'] as String?,
      dateUpdated:
          json['date_updated'] as String? ?? json['updated_at'] as String?,
    );
  }

  ProductOptionItem copyWith({
    int? id,
    String? name,
    int? priceDelta,
    int? orderIndex,
    String? description,
    bool? status,
    int? optionGroupId,
    String? dateCreated,
    String? dateUpdated,
  }) {
    return ProductOptionItem(
      id: id ?? this.id,
      name: name ?? this.name,
      priceDelta: priceDelta ?? this.priceDelta,
      orderIndex: orderIndex ?? this.orderIndex,
      description: description ?? this.description,
      status: status ?? this.status,
      optionGroupId: optionGroupId ?? this.optionGroupId,
      dateCreated: dateCreated ?? this.dateCreated,
      dateUpdated: dateUpdated ?? this.dateUpdated,
    );
  }
}

/// Groupe d'options d'un produit (ex: "Accompagnement", "Sauce").
/// Contient des [ProductOptionItem] et des contraintes de selection.
class ProductOptionGroup {
  final int id;
  final String name;
  final bool required;
  final bool allowDuplicate;
  final int minSelect;
  final int maxSelect;
  final int orderIndex;
  final bool status;
  final List<ProductOptionItem> items;
  final int? productId;
  final String? dateCreated;
  final String? dateUpdated;

  const ProductOptionGroup({
    required this.id,
    required this.name,
    this.required = false,
    this.allowDuplicate = false,
    this.minSelect = 0,
    this.maxSelect = 0,
    this.orderIndex = 0,
    this.status = true,
    this.items = const [],
    this.productId,
    this.dateCreated,
    this.dateUpdated,
  });

  factory ProductOptionGroup.fromJson(Map<String, dynamic> json) {
    // product peut etre un int ou un objet
    int? productId;
    final productRaw = json['product'];
    if (productRaw is int) {
      productId = productRaw;
    } else if (productRaw is Map<String, dynamic>) {
      productId = productRaw['id'] as int?;
    }
    productId ??= json['product_id'] as int?;

    // items
    List<ProductOptionItem> items = [];
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((i) => ProductOptionItem.fromJson(i))
          .toList();
    }

    return ProductOptionGroup(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      required: json['required'] as bool? ?? false,
      allowDuplicate: json['allow_duplicate'] as bool? ?? false,
      minSelect: json['min_select'] as int? ?? 0,
      maxSelect: json['max_select'] as int? ?? 0,
      orderIndex: json['order_index'] as int? ?? 0,
      status: json['status'] as bool? ?? true,
      items: items,
      productId: productId,
      dateCreated:
          json['date_created'] as String? ?? json['created_at'] as String?,
      dateUpdated:
          json['date_updated'] as String? ?? json['updated_at'] as String?,
    );
  }

  ProductOptionGroup copyWith({
    int? id,
    String? name,
    bool? required,
    bool? allowDuplicate,
    int? minSelect,
    int? maxSelect,
    int? orderIndex,
    bool? status,
    List<ProductOptionItem>? items,
    int? productId,
    String? dateCreated,
    String? dateUpdated,
  }) {
    return ProductOptionGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      required: required ?? this.required,
      allowDuplicate: allowDuplicate ?? this.allowDuplicate,
      minSelect: minSelect ?? this.minSelect,
      maxSelect: maxSelect ?? this.maxSelect,
      orderIndex: orderIndex ?? this.orderIndex,
      status: status ?? this.status,
      items: items ?? this.items,
      productId: productId ?? this.productId,
      dateCreated: dateCreated ?? this.dateCreated,
      dateUpdated: dateUpdated ?? this.dateUpdated,
    );
  }
}

/// Variante d'un produit (ex: "Double steak", "Grand format").
/// Le `priceDelta` represente la difference de prix par rapport au prix de base.
class ProductVariant {
  final int id;
  final String name;
  final int priceDelta;
  final int orderIndex;
  final String? description;
  final bool status;
  final int? productId;
  final String? dateCreated;
  final String? dateUpdated;

  const ProductVariant({
    required this.id,
    required this.name,
    this.priceDelta = 0,
    this.orderIndex = 0,
    this.description,
    this.status = true,
    this.productId,
    this.dateCreated,
    this.dateUpdated,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    // product peut etre un int ou un objet
    int? productId;
    final productRaw = json['product'];
    if (productRaw is int) {
      productId = productRaw;
    } else if (productRaw is Map<String, dynamic>) {
      productId = productRaw['id'] as int?;
    }
    productId ??= json['product_id'] as int?;

    return ProductVariant(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      priceDelta: json['price_delta'] as int? ?? 0,
      orderIndex: json['order_index'] as int? ?? 0,
      description: json['description'] as String?,
      status: json['status'] as bool? ?? true,
      productId: productId,
      dateCreated:
          json['date_created'] as String? ?? json['created_at'] as String?,
      dateUpdated:
          json['date_updated'] as String? ?? json['updated_at'] as String?,
    );
  }

  ProductVariant copyWith({
    int? id,
    String? name,
    int? priceDelta,
    int? orderIndex,
    String? description,
    bool? status,
    int? productId,
    String? dateCreated,
    String? dateUpdated,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      name: name ?? this.name,
      priceDelta: priceDelta ?? this.priceDelta,
      orderIndex: orderIndex ?? this.orderIndex,
      description: description ?? this.description,
      status: status ?? this.status,
      productId: productId ?? this.productId,
      dateCreated: dateCreated ?? this.dateCreated,
      dateUpdated: dateUpdated ?? this.dateUpdated,
    );
  }
}

/// Produit complet tel que retourne par l'API partner.
///
/// En mode liste (GET /products), seuls les champs de base sont presents.
/// En mode detail (GET /products/:id), les variants, optionGroups et pictures
/// sont egalement inclus.
///
/// Champs principaux :
/// - `id`, `name`, `price`, `description`, `available`
/// - `productCategory` : peut etre un int OU un objet {id, label, ...}
/// - `partner` : peut etre un int OU un objet {id, name, ...}
/// - `variants`, `optionGroups`, `pictures` : listes imbriquees (detail)
class Product {
  final int id;
  final String name;
  final int price;
  final String? description;
  final String? slug;
  final bool available;
  final bool status;
  final int? categoryId;
  final String? categoryLabel;
  final int? partnerId;
  final String? picture;
  final List<ProductVariant> variants;
  final List<ProductOptionGroup> optionGroups;
  final List<ProductPicture> pictures;
  final String? defaultImage;
  final int? orderCount;
  final String? dateCreated;
  final String? dateUpdated;

  const Product({
    required this.id,
    required this.name,
    this.price = 0,
    this.description,
    this.slug,
    this.available = true,
    this.status = true,
    this.categoryId,
    this.categoryLabel,
    this.partnerId,
    this.picture,
    this.variants = const [],
    this.optionGroups = const [],
    this.pictures = const [],
    this.defaultImage,
    this.orderCount,
    this.dateCreated,
    this.dateUpdated,
  });

  /// URL de l'image principale : premiere picture ou le champ picture ou defaultImage.
  String? get mainImage {
    if (pictures.isNotEmpty) return pictures.first.link;
    if (picture != null) return picture;
    return defaultImage;
  }

  /// Nombre de variantes.
  int get variantCount => variants.length;

  /// Nombre de groupes d'options.
  int get optionGroupCount => optionGroups.length;

  factory Product.fromJson(Map<String, dynamic> json) {
    // product_category peut etre un int ou un objet
    int? categoryId;
    String? categoryLabel;
    final catRaw = json['product_category'];
    if (catRaw is int) {
      categoryId = catRaw;
    } else if (catRaw is Map<String, dynamic>) {
      categoryId = catRaw['id'] as int?;
      categoryLabel =
          catRaw['label'] as String? ?? catRaw['name'] as String?;
    }
    categoryId ??= json['product_category_id'] as int? ?? json['category_id'] as int?;

    // partner peut etre un int ou un objet
    int? partnerId;
    final partnerRaw = json['partner'];
    if (partnerRaw is int) {
      partnerId = partnerRaw;
    } else if (partnerRaw is Map<String, dynamic>) {
      partnerId = partnerRaw['id'] as int?;
    }
    partnerId ??= json['partner_id'] as int?;

    // variants
    List<ProductVariant> variants = [];
    if (json['variants'] != null && json['variants'] is List) {
      variants = (json['variants'] as List)
          .whereType<Map<String, dynamic>>()
          .map((v) => ProductVariant.fromJson(v))
          .toList();
    }

    // option_groups / optionGroups
    List<ProductOptionGroup> optionGroups = [];
    final ogRaw = json['option_groups'] ?? json['optionGroups'];
    if (ogRaw != null && ogRaw is List) {
      optionGroups = ogRaw
          .whereType<Map<String, dynamic>>()
          .map((g) => ProductOptionGroup.fromJson(g))
          .toList();
    }

    // pictures
    List<ProductPicture> pictures = [];
    if (json['pictures'] != null && json['pictures'] is List) {
      pictures = (json['pictures'] as List)
          .whereType<Map<String, dynamic>>()
          .map((p) => ProductPicture.fromJson(p))
          .toList();
    }

    // available : peut etre un bool ou provenir de `status`
    final availableRaw = json['available'];
    final bool available;
    if (availableRaw is bool) {
      available = availableRaw;
    } else {
      available = json['status'] as bool? ?? true;
    }

    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? json['label'] as String? ?? '',
      price: json['price'] as int? ?? 0,
      description: json['description'] as String?,
      slug: json['slug'] as String? ?? json['value'] as String?,
      available: available,
      status: json['status'] as bool? ?? true,
      categoryId: categoryId,
      categoryLabel: categoryLabel,
      partnerId: partnerId,
      picture: json['picture'] as String? ?? json['image'] as String?,
      variants: variants,
      optionGroups: optionGroups,
      pictures: pictures,
      defaultImage: json['default_image'] as String?,
      orderCount: json['order_count'] as int?,
      dateCreated:
          json['date_created'] as String? ?? json['created_at'] as String?,
      dateUpdated:
          json['date_updated'] as String? ?? json['updated_at'] as String?,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    int? price,
    String? description,
    String? slug,
    bool? available,
    bool? status,
    int? categoryId,
    String? categoryLabel,
    int? partnerId,
    String? picture,
    List<ProductVariant>? variants,
    List<ProductOptionGroup>? optionGroups,
    List<ProductPicture>? pictures,
    String? defaultImage,
    int? orderCount,
    String? dateCreated,
    String? dateUpdated,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      slug: slug ?? this.slug,
      available: available ?? this.available,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      partnerId: partnerId ?? this.partnerId,
      picture: picture ?? this.picture,
      variants: variants ?? this.variants,
      optionGroups: optionGroups ?? this.optionGroups,
      pictures: pictures ?? this.pictures,
      defaultImage: defaultImage ?? this.defaultImage,
      orderCount: orderCount ?? this.orderCount,
      dateCreated: dateCreated ?? this.dateCreated,
      dateUpdated: dateUpdated ?? this.dateUpdated,
    );
  }
}
