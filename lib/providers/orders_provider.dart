import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/order_model.dart';

class OrdersNotifier extends StateNotifier<List<Order>> {
  OrdersNotifier() : super([]) {
    _loadMockData();
  }

  void _loadMockData() {
    state = [
      // Commandes en attente
      Order(
        id: 'CMD001',
        customerName: 'Kouadio Aya',
        customerPhone: '+225 0707070701',
        deliveryAddress: 'Cocody, Riviera Palmeraie, Résidence les Jasmins, Apt 12',
        status: OrderStatus.pending,
        totalAmount: 12500,
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        items: [
          OrderItem(name: 'Poulet Braisé', quantity: 2, price: 4000, image: 'assets/images/category/1.png'),
          OrderItem(name: 'Attiéké', quantity: 2, price: 1500, image: 'assets/images/category/2.png'),
          OrderItem(name: 'Alloco', quantity: 1, price: 1500, image: 'assets/images/category/3.png'),
        ],
        paymentMethod: PaymentMethod.zeetPay,
        isPaid: true,
        specialInstructions: 'Sonnez 2 fois',
      ),
      Order(
        id: 'CMD002',
        customerName: 'Yao Jean',
        customerPhone: '+225 0505050502',
        deliveryAddress: 'Marcory, Zone 4, Rue des Jardins',
        status: OrderStatus.pending,
        totalAmount: 8500,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        items: [
          OrderItem(name: 'Pizza Margherita', quantity: 1, price: 6500, image: 'assets/images/category/4.png'),
          OrderItem(name: 'Coca Cola', quantity: 2, price: 1000),
        ],
        paymentMethod: PaymentMethod.cash,
        isPaid: false,
      ),

      // Commandes en cours
      Order(
        id: 'CMD003',
        customerName: 'Diallo Fatou',
        customerPhone: '+225 0909090903',
        deliveryAddress: 'Plateau, Immeuble Alpha 2000, 3ème étage',
        status: OrderStatus.preparing,
        totalAmount: 15000,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        acceptedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        items: [
          OrderItem(name: 'Burger Classique', quantity: 3, price: 4500, image: 'assets/images/category/2.png'),
          OrderItem(name: 'Frites', quantity: 3, price: 500),
        ],
        paymentMethod: PaymentMethod.mobileMoney,
        isPaid: true,
      ),
      Order(
        id: 'CMD004',
        customerName: 'Koffi Marc',
        customerPhone: '+225 0101010104',
        deliveryAddress: 'Cocody, Angré 7ème Tranche',
        status: OrderStatus.ready,
        totalAmount: 20000,
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
        acceptedAt: DateTime.now().subtract(const Duration(minutes: 23)),
        readyAt: DateTime.now().subtract(const Duration(minutes: 5)),
        items: [
          OrderItem(name: 'Poulet Yassa', quantity: 2, price: 7000, image: 'assets/images/category/3.png'),
          OrderItem(name: 'Riz Gras', quantity: 2, price: 3000, image: 'assets/images/category/1.png'),
        ],
        paymentMethod: PaymentMethod.zeetPay,
        isPaid: true,
        riderName: 'Koné Ibrahim',
        riderPhone: '+225 0606060606',
      ),

      // Commandes en livraison
      Order(
        id: 'CMD005',
        customerName: 'Traoré Aïcha',
        customerPhone: '+225 0202020205',
        deliveryAddress: 'Abobo, Gare',
        status: OrderStatus.pickedUp,
        totalAmount: 6500,
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
        acceptedAt: DateTime.now().subtract(const Duration(minutes: 38)),
        readyAt: DateTime.now().subtract(const Duration(minutes: 18)),
        items: [
          OrderItem(name: 'Salade César', quantity: 2, price: 2500, image: 'assets/images/category/4.png'),
          OrderItem(name: 'Jus d\'orange', quantity: 2, price: 750),
        ],
        paymentMethod: PaymentMethod.cash,
        isPaid: false,
        riderName: 'Bamba Seydou',
        riderPhone: '+225 0707070707',
      ),

      // Commandes livrées aujourd'hui
      Order(
        id: 'CMD006',
        customerName: 'Bakayoko Salif',
        customerPhone: '+225 0303030306',
        deliveryAddress: 'Yopougon, Siporex',
        status: OrderStatus.delivered,
        totalAmount: 9500,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        acceptedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 58)),
        readyAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 38)),
        deliveredAt: DateTime.now().subtract(const Duration(hours: 1)),
        items: [
          OrderItem(name: 'Garba', quantity: 3, price: 1500, image: 'assets/images/category/1.png'),
          OrderItem(name: 'Poisson Braisé', quantity: 1, price: 5000, image: 'assets/images/category/2.png'),
        ],
        paymentMethod: PaymentMethod.mobileMoney,
        isPaid: true,
        riderName: 'Koné Ibrahim',
        riderPhone: '+225 0606060606',
      ),
    ];
  }

  // Accepter une commande
  void acceptOrder(String orderId) {
    state = state.map((order) {
      if (order.id == orderId && order.status == OrderStatus.pending) {
        return order.copyWith(
          status: OrderStatus.preparing,
          acceptedAt: DateTime.now(),
        );
      }
      return order;
    }).toList();
  }

  // Marquer une commande comme prête
  void markOrderReady(String orderId) {
    state = state.map((order) {
      if (order.id == orderId && order.status == OrderStatus.preparing) {
        return order.copyWith(
          status: OrderStatus.ready,
          readyAt: DateTime.now(),
        );
      }
      return order;
    }).toList();
  }

  // Refuser une commande
  void rejectOrder(String orderId) {
    state = state.map((order) {
      if (order.id == orderId && order.status == OrderStatus.pending) {
        return order.copyWith(status: OrderStatus.cancelled);
      }
      return order;
    }).toList();
  }

  // Obtenir les commandes par statut
  List<Order> getOrdersByStatus(OrderStatus status) {
    return state.where((order) => order.status == status).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Obtenir les nouvelles commandes
  List<Order> get newOrders => getOrdersByStatus(OrderStatus.pending);

  // Obtenir les commandes actives (accepted, preparing, ready, pickedUp)
  List<Order> get activeOrders {
    return state
        .where((order) => [
              OrderStatus.accepted,
              OrderStatus.preparing,
              OrderStatus.ready,
              OrderStatus.pickedUp,
            ].contains(order.status))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Obtenir les commandes livrées aujourd'hui
  List<Order> get todayDeliveredOrders {
    final today = DateTime.now();
    return state
        .where((order) =>
            order.status == OrderStatus.delivered &&
            order.deliveredAt != null &&
            order.deliveredAt!.day == today.day &&
            order.deliveredAt!.month == today.month &&
            order.deliveredAt!.year == today.year)
        .toList()
      ..sort((a, b) => b.deliveredAt!.compareTo(a.deliveredAt!));
  }

  // Calculer les gains du jour
  double get todayEarnings {
    return todayDeliveredOrders.fold(0, (sum, order) => sum + order.totalAmount);
  }
}

// Provider principal
final ordersProvider = StateNotifierProvider<OrdersNotifier, List<Order>>((ref) {
  return OrdersNotifier();
});

// Provider pour les nouvelles commandes
final newOrdersProvider = Provider<List<Order>>((ref) {
  return ref.watch(ordersProvider).where((order) => order.status == OrderStatus.pending).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

// Provider pour les commandes actives
final activeOrdersProvider = Provider<List<Order>>((ref) {
  return ref
      .watch(ordersProvider)
      .where((order) => [
            OrderStatus.accepted,
            OrderStatus.preparing,
            OrderStatus.ready,
            OrderStatus.pickedUp,
          ].contains(order.status))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

// Provider pour le nombre de nouvelles commandes
final newOrdersCountProvider = Provider<int>((ref) {
  return ref.watch(newOrdersProvider).length;
});

// Provider pour les gains du jour
final todayEarningsProvider = Provider<double>((ref) {
  final orders = ref.watch(ordersProvider);
  final today = DateTime.now();
  return orders
      .where((order) =>
          order.status == OrderStatus.delivered &&
          order.deliveredAt != null &&
          order.deliveredAt!.day == today.day &&
          order.deliveredAt!.month == today.month &&
          order.deliveredAt!.year == today.year)
      .fold(0.0, (sum, order) => sum + order.totalAmount);
});
