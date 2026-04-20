import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/sync_provider.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/notification_service.dart';
import 'package:merchant/services/order_service.dart';
import 'package:merchant/services/sync_manager.dart';

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
  ///
  /// **Terminologie** : le backend envoie `payment-accepted` pour une nouvelle
  /// commande qui attend validation du partner (machine a etats NestJS, cf.
  /// ORDERS_PARTNER_FLOW.md §2). `pending` est un alias legacy/optimistic que
  /// certains paths frontend utilisent encore — on accepte les deux pour
  /// eviter qu'une nouvelle commande reelle tombe dans "En cours" au lieu de
  /// "Nouvelles".
  static const Set<String> _pendingStatuses = <String>{
    'pending',
    'payment-accepted',
  };

  List<Order> get pendingOrders =>
      orders.where((o) => _pendingStatuses.contains(o.status)).toList();

  /// Statuts consideres comme "actifs / en cours" — aligne 1:1 avec
  /// `OrdersScreen._ongoingStatuses` MOINS les statuts "pending" (gerees par
  /// `pendingOrders` et leur propre tab). Ici on trouve : commandes acceptees
  /// qui sont en cuisine ou en livraison.
  static const Set<String> _activeStatuses = <String>{
    'awaiting-payment',
    'confirmed',
    'preparing',
    'ready',
    'ready-for-delivery',
    'picked_up',
    'on-the-way',
  };

  List<Order> get activeOrders =>
      orders.where((o) => _activeStatuses.contains(o.status)).toList();
}

class OrdersListNotifier extends StateNotifier<OrdersListState> {
  final OrderService _orderService;
  final SyncManager? _syncManager;

  OrdersListNotifier({OrderService? orderService, SyncManager? syncManager})
      : _orderService = orderService ?? OrderService(),
        _syncManager = syncManager,
        super(const OrdersListState());

  /// Charge la premiere page de commandes + compteurs + statuts.
  /// Lecture passe par SyncManager si dispo (cache drift apres fetch).
  ///
  /// **Résilience** : seul le fetch des commandes bloque le state. Les
  /// compteurs et statuts sont best-effort — si `/counts-by-status` ou
  /// `/statuses` échoue, on logue et on laisse les anciennes valeurs (ou
  /// null) pour que le header de tabs tombe en fallback sur la longueur
  /// locale de la page 1 plutôt que d'afficher "0".
  Future<void> load() async {
    state = state.copyWith(status: OrdersListStatus.loading);

    try {
      final PaginatedResult<Order> ordersResult = _syncManager != null
          ? await _syncManager.fetchOrders(
              page: 1,
              status: state.selectedStatus,
              search: state.search,
            )
          : await _orderService.getOrders(
              page: 1,
              status: state.selectedStatus,
              search: state.search,
            );

      // Compteurs + statuts best-effort en parallèle — swallow les erreurs
      // individuelles pour ne pas faire tomber tout le load.
      final results = await Future.wait(<Future<Object?>>[
        _safeCallCounts(),
        _safeCallStatuses(),
      ]);
      final OrderCountsByStatus? counts = results[0] as OrderCountsByStatus?;
      final List<OrderStatusOption>? statuses =
          results[1] as List<OrderStatusOption>?;

      state = OrdersListState(
        status: OrdersListStatus.loaded,
        orders: ordersResult.data,
        meta: ordersResult.meta,
        counts: counts ?? state.counts,
        statusOptions: statuses ?? state.statusOptions,
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

  Future<OrderCountsByStatus?> _safeCallCounts() async {
    try {
      return await _orderService.getCountsByStatus();
    } catch (e) {
      debugPrint('[OrdersListNotifier] counts-by-status failed: $e');
      return null;
    }
  }

  Future<List<OrderStatusOption>?> _safeCallStatuses() async {
    try {
      return await _orderService.getStatuses();
    } catch (e) {
      debugPrint('[OrdersListNotifier] select/statuses failed: $e');
      return null;
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

  /// Reset les filtres (status + search) et recharge TOUTES les commandes.
  /// À appeler au montage de l'écran "Mes commandes" pour garantir qu'on
  /// voit toutes les commandes, indépendamment d'un état de filtre persistant
  /// hérité d'une navigation précédente.
  Future<void> resetAndLoad() async {
    state = state.copyWith(
      clearStatus: true,
      clearSearch: true,
    );
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

/// Statut du fetch de la liste d'actions disponibles (`/orders/actions`).
/// Independant du statut principal pour permettre un refresh des actions
/// apres une transition sans reset de l'order entier.
enum OrderActionsStatus { initial, loading, loaded, error }

class OrderDetailState {
  final OrderDetailStatus status;
  final Order? order;
  final PickupOtpResponse? pickupOtp;
  final String? errorMessage;
  final String? actionError;

  /// Liste d'actions UI disponibles pour le statut courant — fetched depuis
  /// `GET /v1/partner/orders/actions?status=<value>` (Phase 2 gap #4).
  /// Source de verite pour les boutons de l'action bar.
  final List<OrderActionItem> actions;
  final OrderActionsStatus actionsStatus;

  /// Cache du statut pour lequel on a fetch les actions, pour eviter de
  /// refetch quand le statut n'a pas change (les actions du backend sont
  /// hardcodees par statut, on peut les considerer stables).
  final String? actionsForStatus;

  /// Cooldown sur le bouton "Renvoyer OTP" suite a une 429 backend
  /// (`ERR_OTP_RESEND_RATE_LIMITED`). null = pas de cooldown.
  /// Quand renseigne, l'UI affiche un compte a rebours et desactive le CTA.
  final DateTime? otpResendCooldownUntil;

  const OrderDetailState({
    this.status = OrderDetailStatus.initial,
    this.order,
    this.pickupOtp,
    this.errorMessage,
    this.actionError,
    this.actions = const <OrderActionItem>[],
    this.actionsStatus = OrderActionsStatus.initial,
    this.actionsForStatus,
    this.otpResendCooldownUntil,
  });

  OrderDetailState copyWith({
    OrderDetailStatus? status,
    Order? order,
    PickupOtpResponse? pickupOtp,
    String? errorMessage,
    String? actionError,
    List<OrderActionItem>? actions,
    OrderActionsStatus? actionsStatus,
    String? actionsForStatus,
    DateTime? otpResendCooldownUntil,
    bool clearOtpCooldown = false,
  }) {
    return OrderDetailState(
      status: status ?? this.status,
      order: order ?? this.order,
      pickupOtp: pickupOtp ?? this.pickupOtp,
      errorMessage: errorMessage,
      actionError: actionError,
      actions: actions ?? this.actions,
      actionsStatus: actionsStatus ?? this.actionsStatus,
      actionsForStatus: actionsForStatus ?? this.actionsForStatus,
      otpResendCooldownUntil: clearOtpCooldown
          ? null
          : (otpResendCooldownUntil ?? this.otpResendCooldownUntil),
    );
  }

  /// Combien de secondes restent avant la fin du cooldown OTP. 0 si pas
  /// de cooldown actif.
  int get otpResendCooldownSeconds {
    final until = otpResendCooldownUntil;
    if (until == null) return 0;
    final diff = until.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// `true` si l'utilisateur peut renvoyer l'OTP (pas de cooldown actif).
  bool get canResendOtp => otpResendCooldownSeconds == 0;
}

class OrderDetailNotifier extends StateNotifier<OrderDetailState> {
  final OrderService _orderService;
  final SyncManager? _syncManager;
  final NotificationService _notificationService;

  OrderDetailNotifier({
    OrderService? orderService,
    SyncManager? syncManager,
    NotificationService? notificationService,
  })  : _orderService = orderService ?? OrderService(),
        _syncManager = syncManager,
        _notificationService = notificationService ?? NotificationService(),
        super(const OrderDetailState());

  /// Charge le detail d'une commande.
  ///
  /// [fromNotificationId] : si fourni (> 0), envoie un ACK silent pour
  /// stopper la cascade backend (Phase 2 gap #1). Idempotent : pas de
  /// double appel si l'ecran a deja ete ouvert depuis la notif.
  Future<void> load(int orderId, {int? fromNotificationId}) async {
    state = state.copyWith(status: OrderDetailStatus.loading);

    // ACK "vu" en parallele du load — non bloquant. On lance avant le
    // fetch pour minimiser le temps avant que la cascade backend s'arrete.
    if (fromNotificationId != null && fromNotificationId > 0) {
      // ignore: unawaited_futures
      _notificationService.acknowledgeSilent(fromNotificationId);
    }

    try {
      final Order order = _syncManager != null
          ? await _syncManager.fetchOrderDetail(orderId)
          : await _orderService.getOrderDetail(orderId);

      // Charge les actions disponibles pour ce statut en parallele.
      // Echec swallowe : si l'API actions est down, l'UI peut quand meme
      // afficher l'order avec un fallback hardcode.
      final String statusValue = order.status;
      // ignore: unawaited_futures
      _fetchActionsFor(statusValue);

      state = OrderDetailState(
        status: OrderDetailStatus.loaded,
        order: order,
        // On preserve les actions deja chargees du state precedent en
        // attendant le refetch async (evite un flash "pas d'actions").
        actions: state.actionsForStatus == statusValue
            ? state.actions
            : const <OrderActionItem>[],
        actionsStatus: state.actionsForStatus == statusValue
            ? OrderActionsStatus.loaded
            : OrderActionsStatus.loading,
        actionsForStatus: state.actionsForStatus == statusValue
            ? statusValue
            : null,
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

  /// Fetch les actions disponibles pour [statusValue] depuis le backend.
  /// Met a jour `actions`/`actionsStatus`/`actionsForStatus` une fois
  /// resolu. Errors swallowed (l'UI fallback).
  Future<void> _fetchActionsFor(String statusValue) async {
    try {
      final OrderActionsResponse response =
          await _orderService.getActions(status: statusValue);
      // Si entre-temps l'order a change de statut, on ignore cette reponse.
      final currentStatus = state.order?.status;
      if (currentStatus != null && currentStatus != statusValue) {
        debugPrint(
          '[OrderDetailNotifier] discard stale actions for $statusValue, '
          'now=$currentStatus',
        );
        return;
      }
      state = state.copyWith(
        actions: response.actions,
        actionsStatus: OrderActionsStatus.loaded,
        actionsForStatus: statusValue,
      );
    } catch (e) {
      debugPrint('[OrderDetailNotifier] fetchActions failed: $e');
      state = state.copyWith(
        actions: const <OrderActionItem>[],
        actionsStatus: OrderActionsStatus.error,
        actionsForStatus: statusValue,
      );
    }
  }

  /// Force le refetch des actions disponibles. Utile apres une transition
  /// pour rafraichir les CTAs (`confirmed → preparing` change la liste
  /// d'actions disponibles).
  Future<void> refreshActions() async {
    final currentStatus = state.order?.status;
    if (currentStatus == null) return;
    await _fetchActionsFor(currentStatus);
  }

  /// Confirme la commande (POST /orders/:id/confirm).
  /// Passe par SyncManager (optimistic UI + queue offline) si dispo.
  Future<bool> confirm(int orderId, {int estimatedMinutes = 30}) async {
    state = state.copyWith(status: OrderDetailStatus.acting, actionError: null);

    if (_syncManager != null) {
      final OptimisticResult result = await _syncManager.optimisticConfirm(
        orderId,
        estimatedMinutes: estimatedMinutes,
      );
      _onOrderUpdated(result.order, error: result.error);
      return result.error == null;
    }

    try {
      final order = await _orderService.confirmOrder(
        orderId,
        estimatedMinutes: estimatedMinutes,
      );
      _onOrderUpdated(order);
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

  /// Met a jour l'order dans le state apres une transition reussie ET
  /// declenche un refetch des actions disponibles si le statut a change.
  /// Centralise la logique commune aux methodes confirm/markPreparing/
  /// markReady/cancel.
  void _onOrderUpdated(Order? order, {String? error}) {
    if (order == null) {
      state = state.copyWith(
        status: OrderDetailStatus.loaded,
        actionError: error,
      );
      return;
    }
    final previousStatus = state.order?.status;
    state = state.copyWith(
      status: OrderDetailStatus.loaded,
      order: order,
      actionError: error,
    );
    if (previousStatus != order.status) {
      // ignore: unawaited_futures
      _fetchActionsFor(order.status);
    }
  }

  /// Passe la commande en preparation (POST /orders/:id/preparing).
  Future<bool> markPreparing(int orderId, {int estimatedMinutes = 20}) async {
    state = state.copyWith(status: OrderDetailStatus.acting, actionError: null);

    if (_syncManager != null) {
      final OptimisticResult result = await _syncManager.optimisticMarkPreparing(
        orderId,
        estimatedMinutes: estimatedMinutes,
      );
      _onOrderUpdated(result.order, error: result.error);
      return result.error == null;
    }

    try {
      final order = await _orderService.markPreparing(
        orderId,
        estimatedMinutes: estimatedMinutes,
      );
      _onOrderUpdated(order);
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

    if (_syncManager != null) {
      final OptimisticResult result = await _syncManager.optimisticMarkReady(orderId);
      _onOrderUpdated(result.order, error: result.error);
      return result.error == null;
    }

    try {
      final order = await _orderService.markReady(orderId);
      _onOrderUpdated(order);
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
        actionError: 'Impossible de marquer la commande comme prête',
      );
      return false;
    }
  }

  /// Annule la commande (POST /orders/:id/cancel).
  /// [cancelReason] est **obligatoire** : le backend rejette les refus sans
  /// motif (400). On trim + guard avant tout appel reseau.
  Future<bool> cancel(int orderId, {required String cancelReason}) async {
    final trimmed = cancelReason.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        status: OrderDetailStatus.loaded,
        actionError:
            'La raison du refus est obligatoire pour annuler une commande.',
      );
      return false;
    }

    state = state.copyWith(status: OrderDetailStatus.acting, actionError: null);

    if (_syncManager != null) {
      final OptimisticResult result = await _syncManager.optimisticCancel(
        orderId,
        cancelReason: trimmed,
      );
      _onOrderUpdated(result.order, error: result.error);
      return result.error == null;
    }

    try {
      final order = await _orderService.cancelOrder(
        orderId,
        cancelReason: trimmed,
      );
      _onOrderUpdated(order);
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
      state = state.copyWith(actionError: 'Impossible de récupérer l\'OTP');
      return false;
    }
  }

  /// Renvoie l'OTP de collecte (POST /orders/:id/pickup-otp/resend).
  ///
  /// Gere proprement le 429 `ERR_OTP_RESEND_RATE_LIMITED` en posant un
  /// cooldown UI ([OrderDetailState.otpResendCooldownUntil]) qui desactive
  /// le bouton "Renvoyer" pendant [kOtpResendCooldown]. Le countdown est
  /// affiche par l'ecran OTP plein ecran (Phase 2 gap #2).
  Future<bool> resendPickupOtp(int orderId) async {
    // Garde-fou client : ne pas spam le backend si l'utilisateur clique
    // pendant le cooldown.
    if (!state.canResendOtp) {
      state = state.copyWith(
        actionError:
            'Patientez ${state.otpResendCooldownSeconds}s avant de renvoyer.',
      );
      return false;
    }
    try {
      final otp = await _orderService.resendPickupOtp(orderId);
      state = state.copyWith(pickupOtp: otp, clearOtpCooldown: true);
      return true;
    } on ApiException catch (e) {
      debugPrint('[OrderDetailNotifier] resendPickupOtp failed: $e');
      // 429 → poser un cooldown frontend pour eviter les spam clicks.
      if (e.statusCode == 429) {
        state = state.copyWith(
          otpResendCooldownUntil: DateTime.now().add(kOtpResendCooldown),
          actionError:
              'Trop de demandes. Reessayez dans ${kOtpResendCooldown.inSeconds}s.',
        );
      } else {
        state = state.copyWith(actionError: e.message);
      }
      return false;
    } catch (e) {
      debugPrint('[OrderDetailNotifier] resendPickupOtp error: $e');
      state = state.copyWith(actionError: 'Impossible de renvoyer le code.');
      return false;
    }
  }

  /// Decrement / reset du cooldown — appele par un Timer cote ecran. Permet
  /// de reactiver le bouton automatiquement quand le cooldown expire.
  void tickOtpCooldown() {
    final until = state.otpResendCooldownUntil;
    if (until == null) return;
    if (DateTime.now().isAfter(until)) {
      state = state.copyWith(clearOtpCooldown: true);
    }
  }
}

/// Duree de cooldown applique cote frontend apres un 429
/// `ERR_OTP_RESEND_RATE_LIMITED`. Choisi pour matcher la fenetre backend
/// (typiquement 30-60s). Conservatif cote client pour eviter les rapports
/// "ca ne marche pas" du partner.
const Duration kOtpResendCooldown = Duration(seconds: 60);

// =============================================================================
// Providers
// =============================================================================

/// Provider principal pour la liste des commandes.
final ordersListProvider =
    StateNotifierProvider<OrdersListNotifier, OrdersListState>((ref) {
  return OrdersListNotifier(syncManager: ref.watch(syncManagerProvider));
});

/// Provider pour le detail d'une commande.
/// Utilise .family pour pouvoir charger plusieurs commandes independamment.
final orderDetailProvider =
    StateNotifierProvider<OrderDetailNotifier, OrderDetailState>((ref) {
  return OrderDetailNotifier(syncManager: ref.watch(syncManagerProvider));
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
///
/// Somme les deux valeurs que le backend peut renvoyer (`payment-accepted`
/// canonique + `pending` legacy) pour rester robuste aux deux conventions.
/// Fallback sur la longueur de la liste locale si les counts ne sont pas
/// encore disponibles.
final pendingOrdersCountProvider = Provider<int>((ref) {
  final counts = ref.watch(orderCountsProvider);
  if (counts != null) {
    final int backend =
        counts.get('payment-accepted') + counts.get('pending');
    if (backend > 0) return backend;
  }
  return ref.watch(pendingOrdersProvider).length;
});

/// Statuts disponibles pour le filtre.
final orderStatusOptionsProvider = Provider<List<OrderStatusOption>>((ref) {
  return ref.watch(ordersListProvider).statusOptions;
});
