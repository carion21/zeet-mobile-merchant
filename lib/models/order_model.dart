// Modeles representant les commandes cote API partner.
// Correspond aux reponses de `GET /v1/partner/orders`, `GET /v1/partner/orders/:id`, etc.
//
// Le parsing est DEFENSIF : chaque champ qui peut etre un objet ou un int/string
// est traite de maniere flexible (meme pattern que l'app client).

import 'package:flutter/material.dart';

import 'package:merchant/core/utils/color_utils.dart';

/// Statut d'une commande (objet riche renvoye par l'API).
/// `last_order_status` peut etre un objet `{id, label, value, color}`, un int, ou un string.
class OrderStatus {
  final int? id;
  final String? label;
  final String? value;
  final String? color;
  final String? description;

  const OrderStatus({this.id, this.label, this.value, this.color, this.description});

  factory OrderStatus.fromJson(Map<String, dynamic> json) {
    return OrderStatus(
      id: json['id'] as int?,
      label: json['label'] as String?,
      value: json['value'] as String?,
      color: json['color'] as String?,
      description: json['description'] as String?,
    );
  }

  /// Raccourci pour affichage.
  String get displayLabel => label ?? value ?? '';
  String get displayValue => value ?? '';

  /// Couleur parsee depuis [color] (`#RRGGBB` fourni par le core).
  /// `null` si le backend n'a pas envoye de couleur — l'UI doit alors
  /// fallback sur un neutre (`ZeetColors.inkMuted`).
  Color? get colorValue => hexToColor(color);

  @override
  String toString() => value ?? label ?? '';
}

/// Methode de paiement (objet riche renvoye par l'API).
/// Peut etre un objet `{id, label, value}`, un int ou un string.
class OrderPaymentMethod {
  final int? id;
  final String? label;
  final String? value;

  const OrderPaymentMethod({this.id, this.label, this.value});

  factory OrderPaymentMethod.fromJson(Map<String, dynamic> json) {
    return OrderPaymentMethod(
      id: json['id'] as int?,
      label: json['label'] as String?,
      value: json['value'] as String?,
    );
  }

  String get displayLabel => label ?? value ?? '';

  @override
  String toString() => value ?? label ?? '';
}

/// Client associe a la commande.
/// `customer` peut etre un objet ou un int selon l'endpoint.
class OrderCustomer {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? picture;

  const OrderCustomer({
    required this.id,
    this.firstName,
    this.lastName,
    this.phone,
    this.picture,
  });

  String get fullName =>
      [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');

  factory OrderCustomer.fromJson(Map<String, dynamic> json) {
    return OrderCustomer(
      id: json['id'] as int,
      firstName: json['firstname'] as String? ?? json['first_name'] as String?,
      lastName: json['lastname'] as String? ?? json['last_name'] as String?,
      phone: json['phone'] as String?,
      picture: json['picture'] as String?,
    );
  }
}

/// Partenaire (restaurant) associe a la commande.
/// `partner` peut etre un objet ou un int selon l'endpoint.
class OrderPartner {
  final int id;
  final String? name;
  final String? phone;
  final String? address;
  final String? picture;

  const OrderPartner({
    required this.id,
    this.name,
    this.phone,
    this.address,
    this.picture,
  });

  factory OrderPartner.fromJson(Map<String, dynamic> json) {
    return OrderPartner(
      id: json['id'] as int,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      picture: json['picture'] as String?,
    );
  }
}

/// Livreur associe a la commande.
class OrderRider {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? picture;

  const OrderRider({
    required this.id,
    this.firstName,
    this.lastName,
    this.phone,
    this.picture,
  });

  String get fullName =>
      [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');

  factory OrderRider.fromJson(Map<String, dynamic> json) {
    return OrderRider(
      id: json['id'] as int,
      firstName: json['first_name'] as String? ?? json['firstname'] as String?,
      lastName: json['last_name'] as String? ?? json['lastname'] as String?,
      phone: json['phone'] as String?,
      picture: json['picture'] as String?,
    );
  }
}

/// Option selectionnee pour un item de commande.
class OrderItemOption {
  final int id;
  final int optionItemId;
  final String? name;
  final double? price;
  final int quantity;

  const OrderItemOption({
    required this.id,
    required this.optionItemId,
    this.name,
    this.price,
    required this.quantity,
  });

  factory OrderItemOption.fromJson(Map<String, dynamic> json) {
    return OrderItemOption(
      id: _asIntOrZero(json['id']),
      // Backend peut renvoyer option_item_id en int ou en string (cas vu
      // sur certains anciens endpoints). Le `as int?` brut throw une
      // FormatException sur string -> crash parsing.
      optionItemId: _asIntOrZero(json['option_item_id']) != 0
          ? _asIntOrZero(json['option_item_id'])
          : _asIntOrZero(json['id']),
      name: json['name'] as String?,
      price: json['price'] is num ? (json['price'] as num).toDouble() : null,
      quantity: _asIntOrZero(json['quantity']) > 0
          ? _asIntOrZero(json['quantity'])
          : 1,
    );
  }
}

int _asIntOrZero(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Item d'une commande.
class OrderItem {
  final int id;
  final int productId;
  final String? productName;
  final double? unitPrice;
  final String? productImage;
  final int? variantId;
  final String? variantName;
  final int quantity;
  final double? totalPrice;
  final String? note;
  final List<OrderItemOption> options;

  const OrderItem({
    required this.id,
    required this.productId,
    this.productName,
    this.unitPrice,
    this.productImage,
    this.variantId,
    this.variantName,
    required this.quantity,
    this.totalPrice,
    this.note,
    this.options = const [],
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // product peut etre un int, un objet {id, name, ...}, ou absent
    Map<String, dynamic>? product;
    int productId = 0;
    final productRaw = json['product'];
    if (productRaw is Map<String, dynamic>) {
      product = productRaw;
      productId = product['id'] as int? ?? 0;
    } else if (productRaw is int) {
      productId = productRaw;
    }
    productId = json['product_id'] as int? ?? productId;

    // variant peut etre un int ou un objet
    int? variantId;
    String? variantName;
    final variantRaw = json['variant'];
    if (variantRaw is Map<String, dynamic>) {
      variantId = variantRaw['id'] as int?;
      variantName = variantRaw['name'] as String?;
    } else if (variantRaw is int) {
      variantId = variantRaw;
    }
    variantName ??= json['variant_name'] as String?;

    // Image du produit
    String? imageUrl;
    if (product != null && product['pictures'] != null) {
      final pics = product['pictures'] as List;
      if (pics.isNotEmpty && pics.first is Map<String, dynamic>) {
        imageUrl = (pics.first as Map<String, dynamic>)['link'] as String?;
      }
    }

    // Nom du produit : product.name > product_name_snapshot > product_name
    final productName = product?['name'] as String? ??
        json['product_name_snapshot'] as String? ??
        json['product_name'] as String?;

    // Prix : unit_price > product.price
    final unitPrice = json['unit_price'] != null
        ? (json['unit_price'] as num).toDouble()
        : product?['price'] != null
            ? (product!['price'] as num).toDouble()
            : null;

    // Options
    List<OrderItemOption> options = [];
    final optionsRaw = json['options'] ?? json['product_options_snapshot'];
    if (optionsRaw is List && optionsRaw.isNotEmpty) {
      options = optionsRaw
          .whereType<Map<String, dynamic>>()
          .map((o) => OrderItemOption.fromJson(o))
          .toList();
    }

    return OrderItem(
      id: json['id'] as int? ?? 0,
      productId: productId,
      productName: productName,
      unitPrice: unitPrice,
      productImage: imageUrl ?? json['product_image'] as String?,
      variantId: variantId,
      variantName: variantName,
      quantity: json['quantity'] as int? ?? 1,
      totalPrice: json['total_price'] != null
          ? (json['total_price'] as num).toDouble()
          : null,
      note: json['note'] as String?,
      options: options,
    );
  }
}

/// Entree d'historique d'une commande : un changement de statut horodate,
/// eventuellement accompagne d'une observation libre cote backend.
///
/// Payload backend (cf. `GET /v1/partner/orders/:id` → `data.logs[]`) :
/// ```json
/// {
///   "id": 4948,
///   "date_created": "2026-04-21T03:42:43.630Z",
///   "observation": "Confirmed with estimated 30 minutes",
///   "order_status": { "id": 4, "label": "Confirmee", "value": "confirmed", "color": "#2563EB" }
/// }
/// ```
///
/// La couleur d'affichage provient du backend (`order_status.color`) —
/// ne jamais mapper un statut vers une couleur cote Flutter (cf.
/// memoire `status_colors_from_core`).
class OrderLog {
  final int? id;
  final OrderStatus? orderStatus;
  final String? observation;
  final String? createdAt;

  const OrderLog({
    this.id,
    this.orderStatus,
    this.observation,
    this.createdAt,
  });

  factory OrderLog.fromJson(Map<String, dynamic> json) {
    OrderStatus? status;
    final raw = json['order_status'];
    if (raw is Map<String, dynamic>) {
      status = OrderStatus.fromJson(raw);
    }
    return OrderLog(
      id: json['id'] as int?,
      orderStatus: status,
      observation: json['observation'] as String?,
      createdAt:
          json['date_created'] as String? ?? json['created_at'] as String?,
    );
  }
}

/// Position de livraison (pickup + dropoff).
class OrderPosition {
  final String? pickupLat;
  final String? pickupLng;
  final String? pickupAddress;
  final String? dropoffLat;
  final String? dropoffLng;
  final String? dropoffAddress;
  final double? distanceKm;

  const OrderPosition({
    this.pickupLat,
    this.pickupLng,
    this.pickupAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.dropoffAddress,
    this.distanceKm,
  });

  factory OrderPosition.fromJson(Map<String, dynamic> json) {
    return OrderPosition(
      pickupLat: json['pickup_lat']?.toString(),
      pickupLng: json['pickup_lng']?.toString(),
      pickupAddress: json['pickup_address'] as String?,
      dropoffLat: json['dropoff_lat']?.toString(),
      dropoffLng: json['dropoff_lng']?.toString(),
      dropoffAddress: json['dropoff_address'] as String?,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
    );
  }
}

/// Timings operationnels calcules par le backend (cf. `GET /v1/partner/orders/:id`
/// → `data.timings`). Agrege les horodatages des transitions cles et les
/// durees breakdown entre chaque phase en secondes.
///
/// Source de verite pour les KPI de service cote partner :
/// - `acceptanceSeconds` : `pending → confirmed` (temps de reponse du partner)
/// - `preparationSeconds` : `confirmed → ready-for-delivery` (temps en cuisine)
/// - `pickupWaitSeconds` : `ready → picked_up` (attente rider a la cuisine)
/// - `transitSeconds` : `picked_up → delivered` (trajet rider)
/// - `totalSeconds` : `pending → delivered` (cycle complet)
///
/// Les timestamps bruts (`*_at`) permettent a l'UI de dater chaque phase
/// sans avoir a deduire depuis les logs.
class OrderTimings {
  final String? pendingAt;
  final String? confirmedAt;
  final String? readyAt;
  final String? pickedUpAt;
  final String? deliveredAt;
  final int? acceptanceSeconds;
  final int? preparationSeconds;
  final int? pickupWaitSeconds;
  final int? transitSeconds;
  final int? totalSeconds;

  const OrderTimings({
    this.pendingAt,
    this.confirmedAt,
    this.readyAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.acceptanceSeconds,
    this.preparationSeconds,
    this.pickupWaitSeconds,
    this.transitSeconds,
    this.totalSeconds,
  });

  factory OrderTimings.fromJson(Map<String, dynamic> json) {
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }

    return OrderTimings(
      pendingAt: json['pending_at'] as String?,
      confirmedAt: json['confirmed_at'] as String?,
      readyAt: json['ready_at'] as String?,
      pickedUpAt: json['picked_up_at'] as String?,
      deliveredAt: json['delivered_at'] as String?,
      acceptanceSeconds: toInt(json['acceptance_seconds']),
      preparationSeconds: toInt(json['preparation_seconds']),
      pickupWaitSeconds: toInt(json['pickup_wait_seconds']),
      transitSeconds: toInt(json['transit_seconds']),
      totalSeconds: toInt(json['total_seconds']),
    );
  }

  /// Vrai si au moins une phase est renseignee (evite d'afficher une card
  /// vide quand le backend n'a pas encore calcule les durees, p.ex. pour
  /// une commande en cours qui n'a pas atteint la premiere transition).
  bool get hasAnyBreakdown =>
      acceptanceSeconds != null ||
      preparationSeconds != null ||
      pickupWaitSeconds != null ||
      transitSeconds != null;
}

/// Une commande complete telle que retournee par l'API partner.
class Order {
  final int id;
  final String? code;
  final String? uuid;
  final OrderStatus? orderStatus;
  final String? statusValue;
  final int? customerId;
  final OrderCustomer? customer;
  final int? partnerId;
  final OrderPartner? partner;
  final OrderRider? rider;
  final List<OrderItem> items;
  final double? subtotal;
  final double? deliveryFee;
  final double? netAmount;
  final double? commission;
  final double? discount;
  final double? totalAmount;
  final OrderPaymentMethod? paymentMethod;
  final String? deliveryAddress;
  final OrderPosition? position;
  final int? etaMinutes;
  final int? estimatedMinutes;
  final String? noteCustomer;
  final String? notePartner;
  final String? cancelReason;
  final String? cancelledAt;
  final String? pickupOtp;
  final List<OrderLog> logs;
  final OrderTimings? timings;
  final String? createdAt;
  final String? updatedAt;

  const Order({
    required this.id,
    this.code,
    this.uuid,
    this.orderStatus,
    this.statusValue,
    this.customerId,
    this.customer,
    this.partnerId,
    this.partner,
    this.rider,
    this.items = const [],
    this.subtotal,
    this.deliveryFee,
    this.netAmount,
    this.commission,
    this.discount,
    this.totalAmount,
    this.paymentMethod,
    this.deliveryAddress,
    this.position,
    this.etaMinutes,
    this.estimatedMinutes,
    this.noteCustomer,
    this.notePartner,
    this.cancelReason,
    this.cancelledAt,
    this.pickupOtp,
    this.logs = const [],
    this.timings,
    this.createdAt,
    this.updatedAt,
  });

  /// Raccourcis pratiques.
  String get status => statusValue ?? orderStatus?.value ?? '';
  String get statusLabel => orderStatus?.label ?? status;
  String get statusColor => orderStatus?.color ?? '#808080';

  /// Nom du client. Priorite : `customer.fullName` (embed backend) > simple
  /// "Client" lisible. On n'expose PLUS l'id technique "Client #5" dans
  /// l'UI — l'id n'aide pas le partner et pollue l'ecran (issue M-22).
  /// Si le backend n'embed pas le `customer` dans /orders/:id, il faut
  /// l'ajouter cote backend plutot qu'afficher un id brut cote UI.
  String get customerName {
    final String full = customer?.fullName.trim() ?? '';
    if (full.isNotEmpty) return full;
    return 'Client';
  }

  String get customerPhone => customer?.phone ?? '';

  factory Order.fromJson(Map<String, dynamic> json) {
    // status peut etre un objet {id, label, value, color}, un int, ou un string
    OrderStatus? orderStatus;
    String? statusValue;
    final statusRaw = json['last_order_status'] ?? json['status'];
    if (statusRaw is Map<String, dynamic>) {
      orderStatus = OrderStatus.fromJson(statusRaw);
      statusValue = orderStatus.value;
    } else if (statusRaw is String) {
      statusValue = statusRaw;
    } else if (statusRaw is int) {
      // `last_order_status` renvoye comme simple id (cas des endpoints
      // POST /confirm|preparing|ready|cancel). On garde l'id pour le lien
      // backend mais on laisse `statusValue` null : synthetiser un slug
      // type "status-5" le fait remonter tel quel dans la chip via le
      // fallback UI (`_fallbackStatusLabel`). L'enrichissement (label,
      // color, value) viendra d'un refetch silencieux cote provider.
      orderStatus = OrderStatus(id: statusRaw);
    }

    // customer peut etre un objet ou un int
    OrderCustomer? customer;
    int? customerId;
    final customerRaw = json['customer'];
    if (customerRaw is Map<String, dynamic>) {
      customer = OrderCustomer.fromJson(customerRaw);
      customerId = customer.id;
    } else if (customerRaw is int) {
      customerId = customerRaw;
    }
    customerId ??= json['customer_id'] as int?;

    // partner peut etre un objet ou un int
    OrderPartner? partner;
    int? partnerId;
    final partnerRaw = json['partner'];
    if (partnerRaw is Map<String, dynamic>) {
      partner = OrderPartner.fromJson(partnerRaw);
      partnerId = partner.id;
    } else if (partnerRaw is int) {
      partnerId = partnerRaw;
    }
    partnerId ??= json['partner_id'] as int?;

    // rider peut etre un objet ou absent
    OrderRider? rider;
    final riderRaw = json['rider'];
    if (riderRaw is Map<String, dynamic>) {
      rider = OrderRider.fromJson(riderRaw);
    }

    // payment_method peut etre un objet, un int ou un string
    OrderPaymentMethod? paymentMethod;
    final pmRaw = json['payment_method'];
    if (pmRaw is Map<String, dynamic>) {
      paymentMethod = OrderPaymentMethod.fromJson(pmRaw);
    } else if (pmRaw is int) {
      paymentMethod = OrderPaymentMethod(id: pmRaw);
    } else if (pmRaw is String) {
      paymentMethod = OrderPaymentMethod(value: pmRaw);
    }

    // items (peut etre injecte depuis le detail)
    List<OrderItem> items = [];
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((i) => OrderItem.fromJson(i))
          .toList();
    }

    // logs (peut etre injecte depuis le detail)
    List<OrderLog> logs = [];
    if (json['logs'] != null && json['logs'] is List) {
      logs = (json['logs'] as List)
          .whereType<Map<String, dynamic>>()
          .map((l) => OrderLog.fromJson(l))
          .toList();
    }

    // timings (uniquement sur GET /v1/partner/orders/:id, pas sur la liste)
    OrderTimings? timings;
    if (json['timings'] is Map<String, dynamic>) {
      timings = OrderTimings.fromJson(json['timings'] as Map<String, dynamic>);
    }

    // position (peut etre injectee depuis le detail)
    OrderPosition? position;
    if (json['position'] != null && json['position'] is Map<String, dynamic>) {
      position = OrderPosition.fromJson(json['position'] as Map<String, dynamic>);
    } else if (json['pickup_address'] != null || json['dropoff_address'] != null) {
      position = OrderPosition(
        pickupLat: json['pickup_lat']?.toString(),
        pickupLng: json['pickup_lng']?.toString(),
        pickupAddress: json['pickup_address'] as String?,
        dropoffLat: json['dropoff_lat']?.toString(),
        dropoffLng: json['dropoff_lng']?.toString(),
        dropoffAddress: json['dropoff_address'] as String?,
        distanceKm: json['distance_km'] != null
            ? (json['distance_km'] as num).toDouble()
            : null,
      );
    }

    return Order(
      id: json['id'] as int,
      code: json['code'] as String? ?? json['reference'] as String?,
      uuid: json['uuid'] as String?,
      orderStatus: orderStatus,
      statusValue: statusValue,
      customerId: customerId,
      customer: customer,
      partnerId: partnerId,
      partner: partner,
      rider: rider,
      items: items,
      subtotal: json['subtotal'] != null
          ? (json['subtotal'] as num).toDouble()
          : null,
      deliveryFee: json['delivery_fee'] != null
          ? (json['delivery_fee'] as num).toDouble()
          : null,
      netAmount: json['net_amount'] != null
          ? (json['net_amount'] as num).toDouble()
          : null,
      commission: json['commission'] != null
          ? (json['commission'] as num).toDouble()
          : null,
      discount: json['discount_amount'] != null
          ? (json['discount_amount'] as num).toDouble()
          : json['discount'] != null
              ? (json['discount'] as num).toDouble()
              : null,
      totalAmount: json['total_amount'] != null
          ? (json['total_amount'] as num).toDouble()
          : json['total'] != null
              ? (json['total'] as num).toDouble()
              : null,
      paymentMethod: paymentMethod,
      deliveryAddress: json['delivery_address'] as String?,
      position: position,
      etaMinutes: json['eta_minutes'] as int?,
      estimatedMinutes: json['estimated_minutes'] as int?,
      noteCustomer: json['note_customer'] as String? ?? json['note'] as String?,
      notePartner: json['note_partner'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      cancelledAt: json['cancelled_at'] as String?,
      pickupOtp: json['pickup_otp'] as String?,
      logs: logs,
      timings: timings,
      createdAt: json['date_created'] as String? ?? json['created_at'] as String?,
      updatedAt: json['date_updated'] as String? ?? json['updated_at'] as String?,
    );
  }
}

/// Compteurs de commandes par statut.
/// Reponse de GET /v1/partner/orders/counts-by-status.
class OrderCountsByStatus {
  final Map<String, int> counts;

  const OrderCountsByStatus({required this.counts});

  int get(String statusValue) => counts[statusValue] ?? 0;
  int get total => counts.values.fold(0, (sum, c) => sum + c);

  factory OrderCountsByStatus.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    json.forEach((key, value) {
      if (value is int) {
        counts[key] = value;
      } else if (value is num) {
        counts[key] = value.toInt();
      }
    });
    return OrderCountsByStatus(counts: counts);
  }
}

/// Element de dropdown statut.
/// Reponse de GET /v1/partner/orders/select/statuses.
class OrderStatusOption {
  final int? id;
  final String? label;
  final String? value;
  final String? color;

  const OrderStatusOption({this.id, this.label, this.value, this.color});

  factory OrderStatusOption.fromJson(Map<String, dynamic> json) {
    return OrderStatusOption(
      id: json['id'] as int?,
      label: json['label'] as String?,
      value: json['value'] as String?,
      color: json['color'] as String?,
    );
  }
}

/// Action disponible sur une commande.
class OrderActionItem {
  final String key;
  final String? label;
  final String? description;
  final String? type;
  final String? method;
  final String? endpoint;
  final String? targetStatus;
  final List<String> requiredFields;

  const OrderActionItem({
    required this.key,
    this.label,
    this.description,
    this.type,
    this.method,
    this.endpoint,
    this.targetStatus,
    this.requiredFields = const [],
  });

  factory OrderActionItem.fromJson(Map<String, dynamic> json) {
    return OrderActionItem(
      key: json['key'] as String? ?? '',
      label: json['label'] as String?,
      description: json['description'] as String?,
      type: json['type'] as String?,
      method: json['method'] as String?,
      endpoint: json['endpoint'] as String?,
      targetStatus: json['target_status'] as String?,
      requiredFields: json['required_fields'] != null
          ? (json['required_fields'] as List).map((e) => e.toString()).toList()
          : [],
    );
  }
}

/// Reponse de GET /v1/partner/orders/transitions.
class OrderTransitionsResponse {
  final String? surface;
  final OrderStatus? status;
  final List<OrderStatus> transitions;

  const OrderTransitionsResponse({
    this.surface,
    this.status,
    this.transitions = const [],
  });

  factory OrderTransitionsResponse.fromJson(Map<String, dynamic> json) {
    OrderStatus? status;
    final statusRaw = json['status'];
    if (statusRaw is Map<String, dynamic>) {
      status = OrderStatus.fromJson(statusRaw);
    }

    return OrderTransitionsResponse(
      surface: json['surface'] as String?,
      status: status,
      transitions: json['transitions'] != null
          ? (json['transitions'] as List)
              .whereType<Map<String, dynamic>>()
              .map((t) => OrderStatus.fromJson(t))
              .toList()
          : [],
    );
  }
}

/// Reponse de GET /v1/partner/orders/actions.
class OrderActionsResponse {
  final String? surface;
  final OrderStatus? status;
  final List<OrderActionItem> actions;

  const OrderActionsResponse({
    this.surface,
    this.status,
    this.actions = const [],
  });

  factory OrderActionsResponse.fromJson(Map<String, dynamic> json) {
    OrderStatus? status;
    final statusRaw = json['status'];
    if (statusRaw is Map<String, dynamic>) {
      status = OrderStatus.fromJson(statusRaw);
    }

    return OrderActionsResponse(
      surface: json['surface'] as String?,
      status: status,
      actions: json['actions'] != null
          ? (json['actions'] as List)
              .whereType<Map<String, dynamic>>()
              .map((a) => OrderActionItem.fromJson(a))
              .toList()
          : [],
    );
  }
}

/// Reponse de GET /v1/partner/orders/:id/pickup-otp.
///
/// Contrat backend (cf. ORDERS_PARTNER_FLOW.md section 3.11) :
/// ```json
/// {
///   "code": "1234",
///   "status": "pending",
///   "expires_at": "2026-04-19T15:15:00Z",
///   "attempt_count": 0,
///   "max_attempts": 5
/// }
/// ```
class PickupOtpResponse {
  /// Code OTP a 4 chiffres (peut etre dans `otp`, `code` ou `pickup_otp`
  /// selon les versions backend).
  final String? otp;

  /// Statut de l'OTP : `pending` (genere, en attente saisie rider),
  /// `consumed` (rider a saisi avec succes), `expired`, `failed`.
  final String? status;

  /// Date d'expiration ISO 8601 brute.
  final String? expiresAt;

  /// Nombre de tentatives ratees du rider (>= max_attempts → OTP bloque).
  final int? attemptCount;

  /// Nombre max de tentatives autorisees (defaut backend : 5).
  final int? maxAttempts;

  const PickupOtpResponse({
    this.otp,
    this.status,
    this.expiresAt,
    this.attemptCount,
    this.maxAttempts,
  });

  factory PickupOtpResponse.fromJson(Map<String, dynamic> json) {
    return PickupOtpResponse(
      otp: json['otp'] as String? ??
          json['pickup_otp'] as String? ??
          json['code'] as String?,
      status: json['status'] as String?,
      expiresAt: json['expires_at'] as String?,
      attemptCount: _asIntOtp(json['attempt_count']),
      maxAttempts: _asIntOtp(json['max_attempts']),
    );
  }

  /// DateTime parse de [expiresAt], ou `null` si non parsable.
  DateTime? get expiresAtDateTime {
    if (expiresAt == null || expiresAt!.isEmpty) return null;
    return DateTime.tryParse(expiresAt!)?.toLocal();
  }

  /// `true` si l'OTP est expire ou consume (plus utilisable).
  bool get isUsable {
    final s = status;
    if (s == 'consumed' || s == 'expired' || s == 'failed') return false;
    final dt = expiresAtDateTime;
    if (dt != null && dt.isBefore(DateTime.now())) return false;
    return otp != null && otp!.isNotEmpty;
  }

  static int? _asIntOtp(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Metadata de pagination.
class PaginationMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const PaginationMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  bool get hasNextPage => page < totalPages;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 25,
      totalPages: json['totalPages'] as int? ?? json['total_pages'] as int? ?? 1,
    );
  }
}

/// Resultat pagine generique.
class PaginatedResult<T> {
  final List<T> data;
  final PaginationMeta meta;

  const PaginatedResult({required this.data, required this.meta});
}
