/// Modele representant un horaire d'ouverture (schedule) du partner.
class PartnerSchedule {
  final int id;
  final String day;
  final bool isOpen;
  final String? openingTime;
  final String? closingTime;

  const PartnerSchedule({
    required this.id,
    required this.day,
    required this.isOpen,
    this.openingTime,
    this.closingTime,
  });

  factory PartnerSchedule.fromJson(Map<String, dynamic> json) {
    return PartnerSchedule(
      id: json['id'] as int,
      day: json['day'] as String,
      isOpen: json['is_open'] as bool? ?? false,
      openingTime: json['opening_time'] as String?,
      closingTime: json['closing_time'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day': day,
      'is_open': isOpen,
      'opening_time': openingTime,
      'closing_time': closingTime,
    };
  }

  PartnerSchedule copyWith({
    int? id,
    String? day,
    bool? isOpen,
    String? openingTime,
    String? closingTime,
  }) {
    return PartnerSchedule(
      id: id ?? this.id,
      day: day ?? this.day,
      isOpen: isOpen ?? this.isOpen,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
    );
  }
}

/// Modele representant les donnees du partner (restaurant).
class PartnerData {
  final int id;
  final String name;
  final String? slug;
  final String? description;
  final bool status;
  final String? picture;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? address;
  final double? minOrderAmount;
  final int? prepTimeMin;
  final double? commissionRate;
  final int? partnerType;
  final bool? openNow;
  final List<PartnerSchedule> schedules;

  const PartnerData({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.status = true,
    this.picture,
    this.latitude,
    this.longitude,
    this.phone,
    this.address,
    this.minOrderAmount,
    this.prepTimeMin,
    this.commissionRate,
    this.partnerType,
    this.openNow,
    this.schedules = const [],
  });

  factory PartnerData.fromJson(Map<String, dynamic> json) {
    return PartnerData(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      description: json['description'] as String?,
      status: json['status'] as bool? ?? true,
      picture: json['picture'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble(),
      prepTimeMin: json['prep_time_min'] as int?,
      commissionRate: (json['commission_rate'] as num?)?.toDouble(),
      partnerType: json['partner_type'] as int?,
      openNow: json['open_now'] as bool?,
      schedules: (json['schedules'] as List<dynamic>?)
              ?.map((e) => PartnerSchedule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'status': status,
      'picture': picture,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'address': address,
      'min_order_amount': minOrderAmount,
      'prep_time_min': prepTimeMin,
      'commission_rate': commissionRate,
      'partner_type': partnerType,
      'open_now': openNow,
      'schedules': schedules.map((e) => e.toJson()).toList(),
    };
  }

  /// Copie l'objet avec des modifications optionnelles.
  /// [clearPicture] permet de forcer `picture` a null (pour supprimer le logo).
  PartnerData copyWith({
    int? id,
    String? name,
    String? slug,
    String? description,
    bool? status,
    String? picture,
    bool clearPicture = false,
    double? latitude,
    double? longitude,
    String? phone,
    String? address,
    double? minOrderAmount,
    int? prepTimeMin,
    double? commissionRate,
    int? partnerType,
    bool? openNow,
    List<PartnerSchedule>? schedules,
  }) {
    return PartnerData(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      status: status ?? this.status,
      picture: clearPicture ? null : (picture ?? this.picture),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      prepTimeMin: prepTimeMin ?? this.prepTimeMin,
      commissionRate: commissionRate ?? this.commissionRate,
      partnerType: partnerType ?? this.partnerType,
      openNow: openNow ?? this.openNow,
      schedules: schedules ?? this.schedules,
    );
  }
}

/// Modele representant le profil complet du partner (user + partner data).
/// Retourne par GET /v1/auth/me avec un token partner.
class PartnerModel {
  final int id;
  final String? firstname;
  final String? lastname;
  final String phone;
  final String? email;
  final String? photo;
  final String profile;
  final String surface;
  final PartnerData? partner;

  const PartnerModel({
    required this.id,
    this.firstname,
    this.lastname,
    required this.phone,
    this.email,
    this.photo,
    this.profile = 'partner',
    this.surface = 'partner',
    this.partner,
  });

  /// Nom complet du partner (user).
  String get fullName {
    final parts = <String>[];
    if (firstname != null && firstname!.isNotEmpty) parts.add(firstname!);
    if (lastname != null && lastname!.isNotEmpty) parts.add(lastname!);
    return parts.isNotEmpty ? parts.join(' ') : 'Partner';
  }

  /// Nom du restaurant (raccourci).
  String get restaurantName => partner?.name ?? 'Mon Restaurant';

  factory PartnerModel.fromJson(Map<String, dynamic> json) {
    return PartnerModel(
      id: json['id'] as int,
      firstname: json['firstname'] as String?,
      lastname: json['lastname'] as String?,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      photo: json['photo'] as String?,
      profile: json['profile'] as String? ?? 'partner',
      surface: json['surface'] as String? ?? 'partner',
      partner: json['partner'] != null
          ? PartnerData.fromJson(json['partner'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstname': firstname,
      'lastname': lastname,
      'phone': phone,
      'email': email,
      'photo': photo,
      'profile': profile,
      'surface': surface,
      'partner': partner?.toJson(),
    };
  }

  PartnerModel copyWith({
    int? id,
    String? firstname,
    String? lastname,
    String? phone,
    String? email,
    String? photo,
    String? profile,
    String? surface,
    PartnerData? partner,
  }) {
    return PartnerModel(
      id: id ?? this.id,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photo: photo ?? this.photo,
      profile: profile ?? this.profile,
      surface: surface ?? this.surface,
      partner: partner ?? this.partner,
    );
  }
}
