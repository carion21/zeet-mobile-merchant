// Modeles representant les menus cote API partner.
// Correspond aux reponses de `GET /v1/partner/menus`, `GET /v1/partner/menus/:id`, etc.
//
// Le parsing est DEFENSIF : chaque champ nullable est gere avec des fallbacks.

/// Jours de la semaine ou le menu est actif.
class DaysOfWeek {
  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;

  const DaysOfWeek({
    this.monday = false,
    this.tuesday = false,
    this.wednesday = false,
    this.thursday = false,
    this.friday = false,
    this.saturday = false,
    this.sunday = false,
  });

  /// Tous les jours actifs.
  static const DaysOfWeek allDays = DaysOfWeek(
    monday: true,
    tuesday: true,
    wednesday: true,
    thursday: true,
    friday: true,
    saturday: true,
    sunday: true,
  );

  factory DaysOfWeek.fromJson(Map<String, dynamic> json) {
    return DaysOfWeek(
      monday: json['monday'] == true,
      tuesday: json['tuesday'] == true,
      wednesday: json['wednesday'] == true,
      thursday: json['thursday'] == true,
      friday: json['friday'] == true,
      saturday: json['saturday'] == true,
      sunday: json['sunday'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monday': monday,
      'tuesday': tuesday,
      'wednesday': wednesday,
      'thursday': thursday,
      'friday': friday,
      'saturday': saturday,
      'sunday': sunday,
    };
  }

  DaysOfWeek copyWith({
    bool? monday,
    bool? tuesday,
    bool? wednesday,
    bool? thursday,
    bool? friday,
    bool? saturday,
    bool? sunday,
  }) {
    return DaysOfWeek(
      monday: monday ?? this.monday,
      tuesday: tuesday ?? this.tuesday,
      wednesday: wednesday ?? this.wednesday,
      thursday: thursday ?? this.thursday,
      friday: friday ?? this.friday,
      saturday: saturday ?? this.saturday,
      sunday: sunday ?? this.sunday,
    );
  }

  /// Liste des jours actifs sous forme lisible.
  List<String> get activeDays {
    final days = <String>[];
    if (monday) days.add('Lundi');
    if (tuesday) days.add('Mardi');
    if (wednesday) days.add('Mercredi');
    if (thursday) days.add('Jeudi');
    if (friday) days.add('Vendredi');
    if (saturday) days.add('Samedi');
    if (sunday) days.add('Dimanche');
    return days;
  }

  /// Tous les jours sont actifs.
  bool get isAllDays =>
      monday && tuesday && wednesday && thursday && friday && saturday && sunday;

  /// Resume lisible (ex: "Lun-Ven" ou "Tous les jours").
  String get displayText {
    if (isAllDays) return 'Tous les jours';
    final days = activeDays;
    if (days.isEmpty) return 'Aucun jour';
    if (days.length <= 3) return days.join(', ');
    return '${days.length} jours';
  }
}

/// Produit associe a un item de menu (simplifie).
class MenuItemProduct {
  final int id;
  final String? name;
  final String? description;
  final double? price;
  final bool? isAvailable;
  final String? imageUrl;

  const MenuItemProduct({
    required this.id,
    this.name,
    this.description,
    this.price,
    this.isAvailable,
    this.imageUrl,
  });

  factory MenuItemProduct.fromJson(Map<String, dynamic> json) {
    // Extraire l'image depuis pictures si present
    String? imageUrl;
    if (json['pictures'] != null && json['pictures'] is List) {
      final pics = json['pictures'] as List;
      if (pics.isNotEmpty && pics.first is Map<String, dynamic>) {
        imageUrl = (pics.first as Map<String, dynamic>)['link'] as String?;
      }
    }
    imageUrl ??= json['image'] as String? ?? json['picture'] as String?;

    return MenuItemProduct(
      id: json['id'] as int,
      name: json['name'] as String?,
      description: json['description'] as String?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      isAvailable: json['is_available'] as bool? ?? json['status'] as bool?,
      imageUrl: imageUrl,
    );
  }
}

/// Item d'un menu (liaison menu <-> produit).
class MenuItem {
  final int id;
  final int? menuId;
  final bool status;
  final MenuItemProduct? product;

  const MenuItem({
    required this.id,
    this.menuId,
    this.status = true,
    this.product,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // product peut etre un objet ou un int
    MenuItemProduct? product;
    final productRaw = json['product'];
    if (productRaw is Map<String, dynamic>) {
      product = MenuItemProduct.fromJson(productRaw);
    }

    return MenuItem(
      id: json['id'] as int? ?? 0,
      menuId: json['menu'] as int? ?? json['menu_id'] as int?,
      status: json['status'] as bool? ?? true,
      product: product,
    );
  }
}

/// Un menu complet tel que retourne par l'API partner.
class Menu {
  final int id;
  final String? code;
  final String name;
  final String? description;
  final bool status;
  final bool isDefault;
  final int? partnerId;
  final int? parentMenuId;
  final int? sortOrder;
  final String? timeStart;
  final String? timeEnd;
  final String? startsAt;
  final String? endsAt;
  final String? image;
  final DaysOfWeek daysOfWeek;
  final List<MenuItem> items;
  final String? createdAt;
  final String? updatedAt;

  const Menu({
    required this.id,
    this.code,
    required this.name,
    this.description,
    this.status = true,
    this.isDefault = false,
    this.partnerId,
    this.parentMenuId,
    this.sortOrder,
    this.timeStart,
    this.timeEnd,
    this.startsAt,
    this.endsAt,
    this.image,
    this.daysOfWeek = const DaysOfWeek(),
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Nombre de produits dans le menu.
  int get productCount => items.length;

  /// Le menu est-il publie (actif) ?
  bool get isPublished => status;

  /// Resume des horaires (ex: "08:00 - 22:00" ou "Toute la journee").
  String get scheduleText {
    if (timeStart != null && timeEnd != null) {
      return '$timeStart - $timeEnd';
    }
    return 'Toute la journee';
  }

  factory Menu.fromJson(Map<String, dynamic> json) {
    // days_of_week peut etre un objet ou null
    DaysOfWeek daysOfWeek = const DaysOfWeek();
    final dowRaw = json['days_of_week'];
    if (dowRaw is Map<String, dynamic>) {
      daysOfWeek = DaysOfWeek.fromJson(dowRaw);
    }

    // items (present dans le detail)
    List<MenuItem> items = [];
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((i) => MenuItem.fromJson(i))
          .toList();
    }

    // partner peut etre un int ou un objet
    int? partnerId;
    final partnerRaw = json['partner'];
    if (partnerRaw is int) {
      partnerId = partnerRaw;
    } else if (partnerRaw is Map<String, dynamic>) {
      partnerId = partnerRaw['id'] as int?;
    }
    partnerId ??= json['partner_id'] as int?;

    // parent_menu peut etre un int ou un objet ou null
    int? parentMenuId;
    final parentRaw = json['parent_menu'];
    if (parentRaw is int) {
      parentMenuId = parentRaw;
    } else if (parentRaw is Map<String, dynamic>) {
      parentMenuId = parentRaw['id'] as int?;
    }
    parentMenuId ??= json['parent_menu_id'] as int?;

    return Menu(
      id: json['id'] as int,
      code: json['code'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as bool? ?? true,
      isDefault: json['is_default'] as bool? ?? false,
      partnerId: partnerId,
      parentMenuId: parentMenuId,
      sortOrder: json['sort_order'] as int?,
      timeStart: json['time_start'] as String?,
      timeEnd: json['time_end'] as String?,
      startsAt: json['starts_at'] as String?,
      endsAt: json['ends_at'] as String?,
      image: json['image'] as String?,
      daysOfWeek: daysOfWeek,
      items: items,
      createdAt: json['date_created'] as String? ?? json['created_at'] as String?,
      updatedAt: json['date_updated'] as String? ?? json['updated_at'] as String?,
    );
  }

  Menu copyWith({
    int? id,
    String? code,
    String? name,
    String? description,
    bool? status,
    bool? isDefault,
    int? partnerId,
    int? parentMenuId,
    int? sortOrder,
    String? timeStart,
    String? timeEnd,
    String? startsAt,
    String? endsAt,
    String? image,
    DaysOfWeek? daysOfWeek,
    List<MenuItem>? items,
    String? createdAt,
    String? updatedAt,
  }) {
    return Menu(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      isDefault: isDefault ?? this.isDefault,
      partnerId: partnerId ?? this.partnerId,
      parentMenuId: parentMenuId ?? this.parentMenuId,
      sortOrder: sortOrder ?? this.sortOrder,
      timeStart: timeStart ?? this.timeStart,
      timeEnd: timeEnd ?? this.timeEnd,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      image: image ?? this.image,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
