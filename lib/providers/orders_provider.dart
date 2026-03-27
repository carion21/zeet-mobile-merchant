import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/order_service.dart';

// =============================================================================
// Orders List State + Notifier
// =============================================================================

enum OrdersListStatus { initial, loading, loaded, error, loadingMore }

class OrdersListState {
  final OrdersListStatus status;
  final List<Order> orders;
  final PaginationMeta? meta;
  final OrderCountsByStatus? counts;
  final List<OrderStatusOption> statusOptions;
  final String? selectedStatus;
  final String? search;
  final String? errorMessage;

  const OrdersListState({
    this.status = OrdersListStatus.initial,
    this.orders = const [],
    this.meta,
    this.counts,
    this.statusOptions = const [],
    this.selectedStatus,
    this.search,
    this.errorMessage,
  });

  OrdersListState copyWith({
    OrdersListStatus? status,
    List<Order>? orders,
    PaginationMeta? meta,
    OrderCountsByStatus? counts,
    List<OrderStatusOption>? statusOptions,
    String? selectedStatus,
    String? search,
    String? errorMessage,
    bool clearStatus = false,
    bool clearSearch = false,
  }) {
    return OrdersListState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      meta: meta ?? this.meta,
      counts: counts ?? this.counts,
      statusOptions: statusOptions ?? this.statusOptions,
      selectedStatus: clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      search: clearSearch ? null : (search ?? this.search),
      errorMessage: errorMessage,
    );
  }

  /// Raccourcis pratiques pour filtrer cote client.
  List<Order> get pendingOrders =>
      orders.where((o) => o.status == 'pending').toList();

  List<Order> get activeOrders => orders
      .where((o) => ['confirmed', 'preparing', 'ready', 'picked_up']
          .contains(o.status))
      .toList();
}

class OrdersListNotifier extends StateNotifier<OrdersListState> {
  final OrderService _orderService;

  OrdersListNotifier({OrderService? orderService})
      : _orderService = orderService ?? OrderService(),
        super(const OrdersListState());

  /// Charge la premiere page de commandes + compteurs + statuts.
  Future<void> load() async {
    state = state.copyWith(status: OrdersListStatus.loading);

    try {
      // Charger en parallele : commandes, compteurs, statuts
      final results = await Future.wait([
        _orderService.getOrders(
          page: 1,
          status: state.selectedStatus,
          search: state.search,
        ),
        _orderService.getCountsByStatus(),
        _orderService.getStatuses(),
      ]);

      final ordersResult = results[0] as PaginatedResult<Order>;
      final counts = results[1] as OrderCountsByStatus;
      final statuses = results[2] as List<OrderStatusOption>;

      state = OrdersListState(
        status: OrdersListStatus.loaded,
        orders: ordersResult.data,
        meta: ordersResult.meta,
        counts: counts,
        statusOptions: statuses,
        selectedStatus: state.selectedStatus,
        search: state.search,
      );
    } on ApiException catch (e) {
      debugPrint('[OrdersListNotifier] load failed: $e');
      state = state.copyWith(
        status: OrdersListStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[OrdersListNotifier] load error: $e');
      state = state.copyWith(
        status: OrdersListStatus.error,
        errorMessage: 'Impossible de charger les commandes',
      );
    }
  }

  /// Charge la page suivante (pagination infinie).
  Future<void> loadMore() async {
    if (state.meta == null || !state.meta!.hasNextPage) return;
    if (state.status == OrdersListStatus.loadingMore) return;

    state = state.copyWith(status: OrdersListStatus.loadingMore);

    try {
      final result = await _orderService.getOrders(
        page: state.meta!.page + 1,
        status: state.selectedStatus,
        search: state.search,
      );

      state = state.copyWith(
        status: OrdersListStatus.loaded,
        orders: [...state.orders, ...result.data],
        meta: result.meta,
      );
    } on ApiException catch (e) {
      debugPrint('[OrdersListNotifier] loadMore failed: $e');
      state = state.copyWith(
        status: OrdersListStatus.loaded,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[OrdersListNotifier] loadMore error: $e');
      state = state.copyWith(status: OrdersListStatus.loaded);
    }
  }

  /// Filtre par statut.
  Future<void> filterByStatus(String? status) async {
    if (status == state.selectedStatus) return;
    state = state.copyWith(
      selectedStatus: status,
      clearStatus: status == null,
    );
    await load();
  }

  /// Recherche par texte.
  Future<void> searchOrders(String? query) async {
    state = state.copyWith(
      search: query,
      clearSearch: query == null || query.isEmpty,
    );
    await load();
  }

  /// Rafraichit la liste et les compteurs (pull-to-refresh).
  Future<void> refresh() async {
    await load();
  }

  /// Recharge uniquement les compteurs (apres une action sur une commande).
  Future<void> refreshCounts() async {
    try {
      final counts = await _orderService.getCountsByStatus();
      state = state.copyWith(counts: counts);
    } catch (_) {
      // Silencieux : les compteurs se mettront a jour au prochain refresh
    }
  }
}

// =============================================================================
// Order Detail State + Notifier
// =============================================================================

enum OrderDetailStatus { initial, loading, loaded, error, acting }

class OrderDetailState {
  final OrderDetailStatus status;
  final Order? order;
  final PickupOtpResponse? pickupOtp;
  final String? errorMessage;
  final String? actionError;

  const OrderDetailState({
    this.status = OrderDetailStatus.initial,
    this.order,
    this.pickupOtp,
    this.errorMessage,
    this.actionError,
  });

  OrderDetailState copyWith({
    OrderDetailStatus? status,
    Order? order,
    PickupOtpResponse? pickupOtp,
    String? errorMessage,
    String? actionError,
  }) {
    return OrderDetailState(
      status: status ?? this.status,
      order: order ?? this.order,
      pickupOtp: pickupOtp ?? this.pickupOtp,
      errorMessage: errorMessage,
      actionError: actionError,
    );
  }
}

class OrderDetailNotifier extends StateNotifier<OrderDetailState> {
  final OrderService _orderService;

  OrderDetailNotifier({OrderService? orderService})
      : _orderService = orderService ?? OrderService(),
        super(const OrderDetailState());

  /// Charge le detail d'une commande.
  Future<void> load(int orderId) async {
    state = state.copyWith(status: OrderDetailStatus.loading);

    try {
      final order = await _orderService.getOrderDetail(orderId);
      state = OrderDetailState(
        status: OrderDetailStatus.loaded,
        order: order,
      );
    } on ApiException catch (e) {
      debugPrint('[OrderDetailNotifier] load failed: $e');
      state = state.copyWith(
        status: OrderDetailStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[OrderDetailNotifier] load error: $e');
      state = state.copyWith(
        status: OrderDetailStatus.error,
        errorMessage: 'Impossible de charger la commande',
      );
    }
  }

  /// Confirme la commande (POST /orders/:id/confirm).
  Future<bool> confirm(int orderId, {int estimatedMinutes = 30}) async {
    state = state.copyWith(status: OrderDetailStatus.acting, actionError: null);

    try {
      final order = await _orderService.confirmOrder(
        orderId,
        estimatedMinutes: estimatedMinutes,
      );
      state = OrderDetailState(
        status: OrderDetailStatus.loaded,
        order: order,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[OrderDetailNotifier] confirm failed: $e');
      state = state.copyWith(
        status: OrderDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[OrderDetailNotifier] confirm error: $e');
      state = state.copyWith(
        status: OrderDetailStatus.loaded,
        actionError: 'Impossible de confirmer la commande',
      );
      return false;
    }
  }

  /// Passe la commande en preparation (POST /orders/:id/preparing).
  Future<bool> markPreparing(int orderId, {int estimatedMinutes = 20}) async {
    state = state.copyWith(status: OrderDetailStatus.acting, actionError: null);

    try {
      final order = await _orderService.markPreparing(
        orderId,
        estimatedMinutes: estimatedMinutes,
      );
      state = OrderDetailState(
        status: OrderDetailStatus.loaded,
        order: order,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[OrderDetailNotifier] markPreparing failed: $e');
      state = state.copyWith(
        status: OrderDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[OrderDetailNotifier] markPreparing error: $e');
      state = state.copyWith(
        status: OrderDetailStatus.loaded,
        actionError: 'Impossible de passer en preparation',
      );
      return false;
    }
  }

  /// Marque la commande comme prete (POST /orders/:id/ready).
  Future<bool> markReady(int orderId) async {
    state = state.copyWith(status: OrderDetailStatus.acting, actionError: null);

    try {
      final order = await _orderService.markReady(orderId);
      state = OrderDetailState(
        status: OrderDetailStatus.loaded,
        order: order,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[OrderDetailNotifier] markReady failed: $e');
      state = state.copyWith(
        status: OrderDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[OrderDetailNotifier] markReady error: $e');
      state = state.copyWith(
        status: OrderDetailStatus.loaded,
        actionError: 'Impossible de marquer la commande comme prete',
      );
      return false;
    }
  }

  /// Annule la commande (POST /orders/:id/cancel).
  Future<bool> cancel(int orderId, {required String cancelReason}) async {
    state = state.copyWith(status: OrderDetailStatus.acting, actionError: null);

    try {
      final order = await _orderService.cancelOrder(
        orderId,
        cancelReason: cancelReason,
      );
      state = OrderDetailState(
        status: OrderDetailStatus.loaded,
        order: order,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[OrderDetailNotifier] cancel failed: $e');
      state = state.copyWith(
        status: OrderDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[OrderDetailNotifier] cancel error: $e');
      state = state.copyWith(
        status: OrderDetailStatus.loaded,
        actionError: 'Impossible d\'annuler la commande',
      );
      return false;
    }
  }

  /// Recupere l'OTP de collecte (GET /orders/:id/pickup-otp).
  Future<bool> getPickupOtp(int orderId) async {
    try {
      final otp = await _orderService.getPickupOtp(orderId);
      state = state.copyWith(pickupOtp: otp);
      return true;
    } on ApiException catch (e) {
      debugPrint('[OrderDetailNotifier] getPickupOtp failed: $e');
      state = state.copyWith(actionError: e.message);
      return false;
    } catch (e) {
      debugPrint('[OrderDetailNotifier] getPickupOtp error: $e');
      state = state.copyWith(actionError: 'Impossible de recuperer l\'OTP');
      return false;
    }
  }

  /// Renvoie l'OTP de collecte (POST /orders/:id/pickup-otp/resend).
  Future<bool> resendPickupOtp(int orderId) async {
    try {
      final otp = await _orderService.resendPickupOtp(orderId);
      state = state.copyWith(pickupOtp: otp);
      return true;
    } on ApiException catch (e) {
      debugPrint('[OrderDetailNotifier] resendPickupOtp failed: $e');
      state = state.copyWith(actionError: e.message);
      return false;
    } catch (e) {
      debugPrint('[OrderDetailNotifier] resendPickupOtp error: $e');
      state = state.copyWith(actionError: 'Impossible de renvoyer l\'OTP');
      return false;
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provider principal pour la liste des commandes.
final ordersListProvider =
    StateNotifierProvider<OrdersListNotifier, OrdersListState>((ref) {
  return OrdersListNotifier();
});

/// Provider pour le detail d'une commande.
/// Utilise .family pour pouvoir charger plusieurs commandes independamment.
final orderDetailProvider =
    StateNotifierProvider<OrderDetailNotifier, OrderDetailState>((ref) {
  return OrderDetailNotifier();
});

// ---------------------------------------------------------------------------
// Providers pratiques (computed)
// ---------------------------------------------------------------------------

/// Nouvelles commandes (statut pending) depuis la liste chargee.
final pendingOrdersProvider = Provider<List<Order>>((ref) {
  return ref.watch(ordersListProvider).pendingOrders;
});

/// Commandes actives (confirmed, preparing, ready, picked_up).
final activeOrdersProvider = Provider<List<Order>>((ref) {
  return ref.watch(ordersListProvider).activeOrders;
});

/// Compteurs par statut.
final orderCountsProvider = Provider<OrderCountsByStatus?>((ref) {
  return ref.watch(ordersListProvider).counts;
});

/// Nombre de commandes en attente.
final pendingOrdersCountProvider = Provider<int>((ref) {
  final counts = ref.watch(orderCountsProvider);
  return counts?.get('pending') ?? ref.watch(pendingOrdersProvider).length;
});

/// Statuts disponibles pour le filtre.
final orderStatusOptionsProvider = Provider<List<OrderStatusOption>>((ref) {
  return ref.watch(ordersListProvider).statusOptions;
});
