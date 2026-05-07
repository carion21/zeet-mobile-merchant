import 'package:merchant/core/constants/api.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/services/api_client.dart';

/// Service pour les operations sur les commandes partner.
/// Encapsule les appels aux 12 endpoints `/v1/partner/orders/*`.
class OrderService {
  final ApiClient _apiClient;

  OrderService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/partner/orders
  // ---------------------------------------------------------------------------
  /// Recupere la liste paginee des commandes du partner.
  ///
  /// [page] : numero de page (defaut 1).
  /// [limit] : nombre de resultats par page (defaut 25).
  /// [status] : filtre optionnel par statut (ex: "pending").
  /// [search] : recherche optionnelle (code, nom client).
  Future<PaginatedResult<Order>> getOrders({
    int page = 1,
    int limit = 25,
    String? status,
    String? search,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _apiClient.get(
      OrderEndpoints.list,
      queryParams: queryParams,
    );

    final dataList = response['data'] as List? ?? [];
    final orders = dataList
        .whereType<Map<String, dynamic>>()
        .map((json) => Order.fromJson(json))
        .toList();

    final meta = response['meta'] != null
        ? PaginationMeta.fromJson(response['meta'] as Map<String, dynamic>)
        : PaginationMeta(
            total: orders.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );

    return PaginatedResult(data: orders, meta: meta);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/orders/counts-by-status
  // ---------------------------------------------------------------------------
  /// Recupere les compteurs de commandes par statut.
  Future<OrderCountsByStatus> getCountsByStatus() async {
    final response = await _apiClient.get(
      OrderEndpoints.countsByStatus,
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return OrderCountsByStatus.fromJson(data);
    }
    return const OrderCountsByStatus(counts: {});
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/orders/select/statuses
  // ---------------------------------------------------------------------------
  /// Recupere la liste des statuts pour le dropdown de filtre.
  Future<List<OrderStatusOption>> getStatuses() async {
    final response = await _apiClient.get(
      OrderEndpoints.statuses,
    );

    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((json) => OrderStatusOption.fromJson(json))
          .toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/orders/transitions?status=pending
  // ---------------------------------------------------------------------------
  /// Recupere les transitions disponibles pour un statut donne.
  Future<OrderTransitionsResponse> getTransitions({String? status}) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.get(
      OrderEndpoints.transitions,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return OrderTransitionsResponse.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/orders/actions?status=pending
  // ---------------------------------------------------------------------------
  /// Recupere les actions disponibles pour un statut donne.
  Future<OrderActionsResponse> getActions({String? status}) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.get(
      OrderEndpoints.actions,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    final data = response['data'] as Map<String, dynamic>? ?? response;
    return OrderActionsResponse.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/orders/:id
  // ---------------------------------------------------------------------------
  /// Recupere le detail d'une commande.
  /// L'API renvoie `{order:{...}, items:[...], position:{...}, logs:[...]}` dans data.
  /// On fusionne les donnees avant le parsing (meme pattern que l'app client).
  Future<Order> getOrderDetail(int orderId) async {
    final response = await _apiClient.get(
      OrderEndpoints.get(orderId.toString()),
    );

    final data = response['data'] as Map<String, dynamic>;

    // L'API separe order et items — on les fusionne pour le parsing
    if (data.containsKey('order')) {
      final orderJson =
          Map<String, dynamic>.from(data['order'] as Map<String, dynamic>);

      // Injecter les items dans l'objet order
      if (data['items'] != null) {
        orderJson['items'] = data['items'];
      }

      // Injecter la position
      if (data['position'] != null) {
        orderJson['position'] = data['position'];
      }

      // Injecter les logs
      if (data['logs'] != null) {
        orderJson['logs'] = data['logs'];
      }

      // Injecter les discounts si presents
      if (data['discounts'] != null) {
        orderJson['discounts'] = data['discounts'];
      }

      return Order.fromJson(orderJson);
    }

    return Order.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/orders/:id/confirm
  // ---------------------------------------------------------------------------
  /// Confirme une commande en attente.
  ///
  /// [estimatedMinutes] : temps estime de preparation (ex: 30 minutes).
  ///
  /// L'appel utilise un `Idempotency-Key` stable (UUID v4 persiste 24h) pour
  /// garantir que retry reseau ou double-tap ne provoque pas de doublon
  /// serveur. Cle logique : `order:{id}:confirm`.
  Future<Order> confirmOrder(int orderId, {int estimatedMinutes = 30}) async {
    final response = await _apiClient.post(
      OrderEndpoints.confirm(orderId.toString()),
      body: {'estimated_minutes': estimatedMinutes},
      idempotencyLogicalKey: 'order:$orderId:confirm',
    );

    return Order.fromJson(response['data'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/orders/:id/preparing
  // ---------------------------------------------------------------------------
  /// Passe la commande en preparation (declenche le dispatch rider).
  ///
  /// [estimatedMinutes] : temps estime restant (ex: 20 minutes).
  ///
  /// `Idempotency-Key` cle logique : `order:{id}:preparing`.
  Future<Order> markPreparing(int orderId, {int estimatedMinutes = 20}) async {
    final response = await _apiClient.post(
      OrderEndpoints.preparing(orderId.toString()),
      body: {'estimated_minutes': estimatedMinutes},
      idempotencyLogicalKey: 'order:$orderId:preparing',
    );

    return Order.fromJson(response['data'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/orders/:id/ready
  // ---------------------------------------------------------------------------
  /// Marque la commande comme prete pour collecte par le rider.
  ///
  /// `Idempotency-Key` cle logique : `order:{id}:ready`.
  Future<Order> markReady(int orderId) async {
    final response = await _apiClient.post(
      OrderEndpoints.ready(orderId.toString()),
      idempotencyLogicalKey: 'order:$orderId:ready',
    );

    return Order.fromJson(response['data'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/orders/:id/cancel
  // ---------------------------------------------------------------------------
  /// Annule une commande.
  ///
  /// [cancelReason] : raison de l'annulation — **obligatoire** (backend 2026-04-15).
  /// Le backend repond 400 si ce champ est vide, null ou absent.
  Future<Order> cancelOrder(int orderId, {required String cancelReason}) async {
    final trimmed = cancelReason.trim();
    if (trimmed.isEmpty) {
      // Garde-fou cote client : on evite un aller-retour reseau inutile.
      throw const ApiException(
        statusCode: 400,
        message:
            'La raison du refus est obligatoire pour annuler une commande.',
      );
    }

    final response = await _apiClient.post(
      OrderEndpoints.cancel(orderId.toString()),
      body: {'cancel_reason': trimmed},
      idempotencyLogicalKey: 'order:$orderId:cancel',
    );

    return Order.fromJson(response['data'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------------------------------
  // GET /v1/partner/orders/:id/pickup-otp
  // ---------------------------------------------------------------------------
  /// Recupere le code OTP de collecte pour une commande.
  Future<PickupOtpResponse> getPickupOtp(int orderId) async {
    final response = await _apiClient.get(
      OrderEndpoints.pickupOtp(orderId.toString()),
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return PickupOtpResponse.fromJson(data);
    }
    return PickupOtpResponse.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/partner/orders/:id/pickup-otp/resend
  // ---------------------------------------------------------------------------
  /// Renvoie le code OTP de collecte.
  Future<PickupOtpResponse> resendPickupOtp(int orderId) async {
    final response = await _apiClient.post(
      OrderEndpoints.resendPickupOtp(orderId.toString()),
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return PickupOtpResponse.fromJson(data);
    }
    return PickupOtpResponse.fromJson(response);
  }
}
