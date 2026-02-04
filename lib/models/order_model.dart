class Order {
  final String id;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final OrderStatus status;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? deliveredAt;
  final List<OrderItem> items;
  final String? riderName;
  final String? riderPhone;
  final String? specialInstructions;
  final PaymentMethod paymentMethod;
  final bool isPaid;

  Order({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    this.acceptedAt,
    this.readyAt,
    this.deliveredAt,
    required this.items,
    this.riderName,
    this.riderPhone,
    this.specialInstructions,
    required this.paymentMethod,
    required this.isPaid,
  });

  Order copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    OrderStatus? status,
    double? totalAmount,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? readyAt,
    DateTime? deliveredAt,
    List<OrderItem>? items,
    String? riderName,
    String? riderPhone,
    String? specialInstructions,
    PaymentMethod? paymentMethod,
    bool? isPaid,
  }) {
    return Order(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      readyAt: readyAt ?? this.readyAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      items: items ?? this.items,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'status': status.toString(),
      'totalAmount': totalAmount,
      'createdAt': createdAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'readyAt': readyAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'riderName': riderName,
      'riderPhone': riderPhone,
      'specialInstructions': specialInstructions,
      'paymentMethod': paymentMethod.toString(),
      'isPaid': isPaid,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      deliveryAddress: json['deliveryAddress'] as String,
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      acceptedAt: json['acceptedAt'] != null ? DateTime.parse(json['acceptedAt'] as String) : null,
      readyAt: json['readyAt'] != null ? DateTime.parse(json['readyAt'] as String) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.parse(json['deliveredAt'] as String) : null,
      items: (json['items'] as List).map((item) => OrderItem.fromJson(item)).toList(),
      riderName: json['riderName'] as String?,
      riderPhone: json['riderPhone'] as String?,
      specialInstructions: json['specialInstructions'] as String?,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString() == json['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      isPaid: json['isPaid'] as bool,
    );
  }
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;
  final String? image;
  final String? note;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.image,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'image': image,
      'note': note,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      image: json['image'] as String?,
      note: json['note'] as String?,
    );
  }
}

enum OrderStatus {
  pending,      // Nouvelle commande
  accepted,     // Acceptée par le restaurant
  preparing,    // En préparation
  ready,        // Prête à être livrée
  pickedUp,     // Récupérée par le livreur
  delivered,    // Livrée
  cancelled,    // Annulée
}

enum PaymentMethod {
  cash,         // Espèces
  zeetPay,      // ZeetPay
  mobileMoney,  // Mobile Money
  card,         // Carte bancaire
}

extension OrderStatusExtension on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.accepted:
        return 'Acceptée';
      case OrderStatus.preparing:
        return 'En préparation';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.pickedUp:
        return 'En livraison';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }

  String get icon {
    switch (this) {
      case OrderStatus.pending:
        return 'clock';
      case OrderStatus.accepted:
        return 'check';
      case OrderStatus.preparing:
        return 'restaurant';
      case OrderStatus.ready:
        return 'done_all';
      case OrderStatus.pickedUp:
        return 'delivery';
      case OrderStatus.delivered:
        return 'check_circle';
      case OrderStatus.cancelled:
        return 'close';
    }
  }
}

extension PaymentMethodExtension on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.zeetPay:
        return 'ZeetPay';
      case PaymentMethod.mobileMoney:
        return 'Mobile Money';
      case PaymentMethod.card:
        return 'Carte bancaire';
    }
  }

  String get icon {
    switch (this) {
      case PaymentMethod.cash:
        return 'payment';
      case PaymentMethod.zeetPay:
        return 'wallet';
      case PaymentMethod.mobileMoney:
        return 'phone';
      case PaymentMethod.card:
        return 'payment';
    }
  }
}
