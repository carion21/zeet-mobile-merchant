// lib/services/sync_manager.dart
//
// Sync manager offline-first — pont entre l'UI et l'API pour les mutations
// sur les commandes. Implemente le pattern :
//
//   UI -> optimistic*   -> drift (update local + enqueue action)
//                       -> triggerSync (best effort immediat)
//
//   SyncManager.run()   -> pour chaque action pending :
//                          - marque syncing
//                          - call API
//                          - success : refresh serveur + markSynced + pop queue
//                          - retryable error : backoff expo, status=pending
//                          - final error : markFailed + notify user
//
// Voir skill `zeet-offline-first` §5/§6/§7.

import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:merchant/data/local/order_cache_serializer.dart';
import 'package:merchant/data/local/partner_database.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/models/payout_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/local_notification_service.dart';
import 'package:merchant/services/order_service.dart';
import 'package:merchant/services/payout_service.dart';
import 'package:uuid/uuid.dart';

/// Résultat d'une action optimistic exposé à l'UI.
class OptimisticResult {
  const OptimisticResult({
    required this.order,
    required this.queuedLocally,
    this.error,
  });

  /// La commande mise a jour localement (version optimistic).
  final Order order;

  /// `true` si la sync serveur n'a pas pu etre faite immediatement
  /// et que l'action est en attente de rejeu.
  final bool queuedLocally;

  /// Message d'erreur si la sync immediate a echoue (null sinon).
  final String? error;
}

class SyncManager {
  SyncManager._({
    required PartnerDatabase database,
    OrderService? orderService,
    PayoutService? payoutService,
  })  : _db = database,
        _orderService = orderService ?? OrderService(),
        _payoutService = payoutService ?? PayoutService();

  static SyncManager? _instance;
  static const Uuid _uuid = Uuid();

  /// Doit etre appele au demarrage de l'app avec la DB singleton.
  static SyncManager initialize({
    required PartnerDatabase database,
    OrderService? orderService,
    PayoutService? payoutService,
  }) {
    _instance ??= SyncManager._(
      database: database,
      orderService: orderService,
      payoutService: payoutService,
    );
    return _instance!;
  }

  static SyncManager get instance {
    final SyncManager? s = _instance;
    if (s == null) {
      throw StateError('SyncManager non initialise — appeler initialize().');
    }
    return s;
  }

  /// Reset le singleton — exclusivement pour les tests, ne pas appeler
  /// en code de production. Cf. test/services/sync_manager_test.dart.
  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  final PartnerDatabase _db;
  final OrderService _orderService;
  final PayoutService _payoutService;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _syncing = false;
  bool _online = true;
  Timer? _backoffTimer;

  /// Set des `action.id` actuellement en vol — empeche la double execution
  /// d'une meme action quand `retryAction()` (manuel) et `run()` (auto via
  /// timer ou connectivity) tombent sur la meme entree pending. Sans ce
  /// garde, le double appel API peut faire echouer la 2e tentative en 4xx
  /// ("deja confirmee") alors que la 1ere a reussi → l'UI montre "erreur"
  /// sur un succes effectif.
  final Set<String> _inFlight = <String>{};

  /// Source d'aleatoire pour le jitter sur le backoff. Sans jitter, plusieurs
  /// actions qui timeout ensemble re-tirent leur retry au meme instant ->
  /// thundering herd quand le backend se remet en ligne.
  static final Random _jitter = Random();

  /// A appeler apres [initialize] pour lancer l'ecoute connectivite +
  /// un premier run opportuniste.
  Future<void> start() async {
    _connSub ??= _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final bool now = results.any((ConnectivityResult r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn);
        final bool wasOffline = !_online;
        _online = now;
        if (now && wasOffline) {
          debugPrint('[SyncManager] connectivite retablie → run()');
          unawaited(run());
        }
      },
    );
    try {
      final List<ConnectivityResult> initial = await _connectivity.checkConnectivity();
      _online = initial.any((ConnectivityResult r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn);
    } catch (_) {
      _online = true;
    }
    unawaited(run());
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
    _connSub = null;
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  // -------------------------------------------------------------
  // Fetch & cache (reads)
  // -------------------------------------------------------------

  /// Fetch serveur + mise en cache. Retourne la page de donnees.
  /// Si hors-ligne ou erreur, l'UI peut fallback sur [watchCachedOrders].
  Future<PaginatedResult<Order>> fetchOrders({
    int page = 1,
    int limit = 25,
    String? status,
    String? search,
  }) async {
    final PaginatedResult<Order> result = await _orderService.getOrders(
      page: page,
      limit: limit,
      status: status,
      search: search,
    );
    // Cache toutes les orders recues (upsert).
    if (result.data.isNotEmpty) {
      await _db.upsertOrders(
        result.data
            .map((Order o) => (
                  id: o.id,
                  status: o.status,
                  payload: OrderCacheSerializer.encode(o),
                ))
            .toList(),
      );
    }
    return result;
  }

  /// Fetch du détail avec cache.
  Future<Order> fetchOrderDetail(int orderId) async {
    final Order o = await _orderService.getOrderDetail(orderId);
    await _db.upsertOrder(
      id: o.id,
      status: o.status,
      payload: OrderCacheSerializer.encode(o),
    );
    return o;
  }

  Stream<List<Order>> watchCachedOrders() {
    return _db.watchAllOrders().map(
      (List<OrdersCacheData> rows) => rows
          .map((OrdersCacheData r) => OrderCacheSerializer.decode(r.payload))
          .whereType<Order>()
          .toList(),
    );
  }

  Stream<int> watchPendingActionsCount() => _db.watchPendingActionsCount();

  // -------------------------------------------------------------
  // Optimistic writes
  // -------------------------------------------------------------

  Future<OptimisticResult> optimisticConfirm(
    int orderId, {
    int estimatedMinutes = 30,
  }) async {
    return _optimistic(
      orderId: orderId,
      newStatus: 'confirmed',
      type: QueuedActionType.confirmOrder,
      payload: <String, dynamic>{'estimated_minutes': estimatedMinutes},
      executor: () =>
          _orderService.confirmOrder(orderId, estimatedMinutes: estimatedMinutes),
    );
  }

  Future<OptimisticResult> optimisticMarkPreparing(
    int orderId, {
    int estimatedMinutes = 20,
  }) async {
    return _optimistic(
      orderId: orderId,
      newStatus: 'preparing',
      type: QueuedActionType.markPreparing,
      payload: <String, dynamic>{'estimated_minutes': estimatedMinutes},
      executor: () => _orderService.markPreparing(orderId,
          estimatedMinutes: estimatedMinutes),
    );
  }

  Future<OptimisticResult> optimisticMarkReady(int orderId) async {
    return _optimistic(
      orderId: orderId,
      newStatus: 'ready',
      type: QueuedActionType.markReady,
      payload: const <String, dynamic>{},
      executor: () => _orderService.markReady(orderId),
    );
  }

  Future<OptimisticResult> optimisticCancel(
    int orderId, {
    required String cancelReason,
  }) async {
    return _optimistic(
      orderId: orderId,
      newStatus: 'cancelled',
      type: QueuedActionType.cancelOrder,
      payload: <String, dynamic>{'cancel_reason': cancelReason},
      executor: () =>
          _orderService.cancelOrder(orderId, cancelReason: cancelReason),
    );
  }

  /// Implémentation commune — écrit le cache local optimistic, enqueue,
  /// tente un appel immédiat si on est online.
  Future<OptimisticResult> _optimistic({
    required int orderId,
    required String newStatus,
    required QueuedActionType type,
    required Map<String, dynamic> payload,
    required Future<Order> Function() executor,
  }) async {
    // 0. Dedup : si une action du meme type/orderId est deja en vol
    //    (pending ou syncing), on retourne immediatement le state local
    //    sans enqueue. Empeche le double-tap "Confirmer" qui faisait
    //    echouer la 2e API call en 4xx ("deja confirmee") -> fausse
    //    erreur affichee a l'user sur un succes effectif.
    final QueuedAction? existing = await _db.findInFlightAction(
      type: type,
      orderId: orderId,
    );
    if (existing != null) {
      debugPrint(
        '[SyncManager] dedup: ${type.name} order=$orderId already inflight '
        '(action=${existing.id} status=${existing.status.name})',
      );
      final OrdersCacheData? row = await _db.getOrderById(orderId);
      final Order opt = row != null
          ? (OrderCacheSerializer.decode(row.payload) ??
              Order(id: orderId, statusValue: newStatus))
          : Order(id: orderId, statusValue: newStatus);
      return OptimisticResult(order: opt, queuedLocally: true);
    }

    // 1. Charge l'entree cache.
    final OrdersCacheData? row = await _db.getOrderById(orderId);
    Order optimistic;
    if (row != null) {
      final String mutated =
          OrderCacheSerializer.applyOptimisticStatus(row.payload, newStatus);
      final Order? decoded = OrderCacheSerializer.decode(mutated);
      optimistic = decoded ??
          Order(id: orderId, statusValue: newStatus);
      await _db.updateOrderStatusOptimistic(
        id: orderId,
        status: newStatus,
        payload: mutated,
      );
    } else {
      // Commande inconnue du cache (first write) — on cree une entree minimale.
      optimistic = Order(id: orderId, statusValue: newStatus);
      await _db.upsertOrder(
        id: orderId,
        status: newStatus,
        payload: OrderCacheSerializer.encode(optimistic),
        syncStatus: CachedOrderSyncStatus.pending,
      );
    }

    // 2. Enqueue l'action.
    final String actionId = _uuid.v4();
    await _db.enqueueAction(
      id: actionId,
      type: type,
      orderId: orderId,
      payload: jsonEncode(payload),
    );

    // 3. Tenter l'appel immediat si online.
    if (!_online) {
      return OptimisticResult(order: optimistic, queuedLocally: true);
    }

    try {
      await _db.markActionSyncing(actionId);
      final Order confirmed = await executor();
      await _db.upsertOrder(
        id: confirmed.id,
        status: confirmed.status,
        payload: OrderCacheSerializer.encode(confirmed),
      );
      await _db.markActionSuccess(actionId);
      return OptimisticResult(order: confirmed, queuedLocally: false);
    } on ApiException catch (e) {
      // 4xx = on n'espere pas que ca marche en rejouant. Markfailed.
      if (e.statusCode >= 400 && e.statusCode < 500 && e.statusCode != 408 && e.statusCode != 429) {
        await _db.markActionFailed(id: actionId, error: e.message);
        await _db.markOrderFailed(orderId);
        return OptimisticResult(
          order: optimistic,
          queuedLocally: false,
          error: e.message,
        );
      }
      // 5xx / timeout → retry.
      await _db.markActionRetry(id: actionId, error: e.message);
      _scheduleRetry();
      return OptimisticResult(
        order: optimistic,
        queuedLocally: true,
        error: e.message,
      );
    } catch (e) {
      await _db.markActionRetry(id: actionId, error: e.toString());
      _scheduleRetry();
      return OptimisticResult(
        order: optimistic,
        queuedLocally: true,
        error: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------
  // Background sync loop
  // -------------------------------------------------------------

  /// Rejoue toutes les actions `pending` dans l'ordre chronologique.
  Future<void> run() async {
    if (_syncing) return;
    if (!_online) return;
    _syncing = true;
    try {
      final List<QueuedAction> pending = await _db.getPendingActions();
      for (final QueuedAction action in pending) {
        if (!_online) break;
        // Skip si retryAction() est en train d'executer cette meme entree.
        if (_inFlight.contains(action.id)) continue;
        await _executeQueuedAction(action);
      }
    } finally {
      _syncing = false;
    }
  }

  /// Retry manuel (ex: tap "Réessayer" sur l'ecran actions en attente).
  Future<void> retryAction(String id) async {
    // Skip si la meme action est deja en cours (timer fire concurrent).
    if (_inFlight.contains(id)) return;
    final QueuedAction? action =
        await (_db.select(_db.queuedActions)..where(($QueuedActionsTable t) => t.id.equals(id)))
            .getSingleOrNull();
    if (action == null) return;
    await _db.markActionRetry(id: id, error: null);
    await _executeQueuedAction(
      action.copyWith(
        status: QueuedActionStatus.pending,
        attempts: action.attempts + 1,
      ),
    );
  }

  Future<void> _executeQueuedAction(QueuedAction action) async {
    // Garde anti-double-execution. `run()` boucle peut s'entrelacer avec
    // `retryAction()` si l'utilisateur tape "Réessayer" pendant qu'un
    // timer de backoff fire. Le set est nettoye en finally.
    if (!_inFlight.add(action.id)) return;
    try {
      await _db.markActionSyncing(action.id);
      final Map<String, dynamic> payload =
          jsonDecode(action.payload) as Map<String, dynamic>;

      Order refreshed;
      switch (action.type) {
        case QueuedActionType.confirmOrder:
          refreshed = await _orderService.confirmOrder(
            action.orderId,
            estimatedMinutes: payload['estimated_minutes'] as int? ?? 30,
          );
          break;
        case QueuedActionType.markPreparing:
          refreshed = await _orderService.markPreparing(
            action.orderId,
            estimatedMinutes: payload['estimated_minutes'] as int? ?? 20,
          );
          break;
        case QueuedActionType.markReady:
          refreshed = await _orderService.markReady(action.orderId);
          break;
        case QueuedActionType.cancelOrder:
          refreshed = await _orderService.cancelOrder(
            action.orderId,
            cancelReason: payload['cancel_reason'] as String? ?? '',
          );
          break;
        case QueuedActionType.signalRupture:
          // Non branche cote UI — aucune ecriture ne doit enqueue ce type
          // tant que product_service.signalRupture n'est pas implemente.
          // On fail l'action proprement sans ecraser le cache avec un
          // Order vide (ce qui corromprait la commande referencee).
          await _notifyActionFailed(action, 'action non prise en charge');
          await _db.markActionFailed(
            id: action.id,
            error: 'signalRupture non implemente (placeholder)',
          );
          return;
        case QueuedActionType.requestPayout:
        case QueuedActionType.validatePayout:
          // Payouts financiers — pas d'`Order` a ecrire en cache (il n'y a
          // pas de commande referencee). On execute l'API et on marque
          // l'action OK/KO. La UI lit `walletProvider` qui se rafraichit
          // au prochain tick (ou via FCM `payout.validated/rejected`).
          await _executePayoutAction(action, payload);
          return;
      }

      await _db.upsertOrder(
        id: refreshed.id,
        status: refreshed.status,
        payload: OrderCacheSerializer.encode(refreshed),
      );
      await _db.markActionSuccess(action.id);
    } on ApiException catch (e) {
      if (e.statusCode >= 400 && e.statusCode < 500 && e.statusCode != 408 && e.statusCode != 429) {
        await _notifyActionFailed(action, e.message);
        await _db.markActionFailed(id: action.id, error: e.message);
        await _db.markOrderFailed(action.orderId);
        return;
      }
      final int attempts = action.attempts + 1;
      if (attempts >= 10) {
        await _notifyActionFailed(action, e.message);
        await _db.markActionFailed(id: action.id, error: e.message);
        return;
      }
      await _db.markActionRetry(id: action.id, error: e.message);
      _scheduleRetry(attempts);
    } catch (e) {
      final int attempts = action.attempts + 1;
      if (attempts >= 10) {
        await _notifyActionFailed(action, e.toString());
        await _db.markActionFailed(id: action.id, error: e.toString());
        return;
      }
      await _db.markActionRetry(id: action.id, error: e.toString());
      _scheduleRetry(attempts);
    } finally {
      _inFlight.remove(action.id);
    }
  }

  /// Notif locale "action non appliquee" quand une QueuedAction passe
  /// definitivement en echec. Sans ce canal, le partner ne sait pas
  /// qu'une action offline n'a pas ete appliquee (cf. audit offline-first).
  Future<void> _notifyActionFailed(QueuedAction action, String reason) async {
    try {
      await LocalNotificationService.showSyncActionFailed(
        orderId: action.orderId,
        actionLabel: _labelForAction(action.type),
        reason: reason,
      );
    } catch (e) {
      debugPrint('[SyncManager] showSyncActionFailed failed: $e');
    }
  }

  String _labelForAction(QueuedActionType type) {
    switch (type) {
      case QueuedActionType.confirmOrder:
        return 'Accepter la commande';
      case QueuedActionType.markPreparing:
        return 'Passer en preparation';
      case QueuedActionType.markReady:
        return 'Marquer prete';
      case QueuedActionType.cancelOrder:
        return 'Annuler la commande';
      case QueuedActionType.signalRupture:
        return 'Signaler une rupture';
      case QueuedActionType.requestPayout:
        return 'Demander un virement';
      case QueuedActionType.validatePayout:
        return 'Valider le virement';
    }
  }

  /// Execute une action payout (request OU validate). Lit l'uuid + amount
  /// depuis le payload JSON. Failure 4xx (sauf 408/429) = markFailed
  /// definitif (le serveur a explicitement rejete — re-try ne marche pas
  /// sur ces codes). Sinon retry exponentiel via SyncManager core loop.
  Future<void> _executePayoutAction(
    QueuedAction action,
    Map<String, dynamic> payload,
  ) async {
    try {
      if (action.type == QueuedActionType.requestPayout) {
        final amount = (payload['amount'] as num?)?.toDouble() ?? 0;
        final note = payload['note'] as String?;
        await _payoutService.create(
          CreatePayoutRequest(amount: amount, note: note),
        );
      } else {
        // validatePayout
        final uuid = payload['uuid'] as String? ?? '';
        final code = payload['code'] as String?;
        if (uuid.isEmpty) {
          await _notifyActionFailed(
              action, 'uuid payout manquant (payload corrompu)');
          await _db.markActionFailed(
            id: action.id,
            error: 'uuid payout manquant',
          );
          return;
        }
        await _payoutService.validate(uuid, code: code);
      }
      await _db.markActionSuccess(action.id);
    } on ApiException catch (e) {
      if (e.statusCode >= 400 &&
          e.statusCode < 500 &&
          e.statusCode != 408 &&
          e.statusCode != 429) {
        await _notifyActionFailed(action, e.message);
        await _db.markActionFailed(id: action.id, error: e.message);
        return;
      }
      final attempts = action.attempts + 1;
      if (attempts >= 10) {
        await _notifyActionFailed(action, e.message);
        await _db.markActionFailed(id: action.id, error: e.message);
        return;
      }
      await _db.markActionRetry(id: action.id, error: e.message);
      _scheduleRetry(attempts);
    } catch (e) {
      final attempts = action.attempts + 1;
      if (attempts >= 10) {
        await _notifyActionFailed(action, e.toString());
        await _db.markActionFailed(id: action.id, error: e.toString());
        return;
      }
      await _db.markActionRetry(id: action.id, error: e.toString());
      _scheduleRetry(attempts);
    }
  }

  // -------------------------------------------------------------
  // Optimistic writes — payouts
  // -------------------------------------------------------------

  /// Enqueue une demande de virement. Tente immediatement si online,
  /// sinon rejoue au retour reseau. Retourne true si l'API a confirme
  /// (succes immediat), false si l'action est en file.
  Future<bool> optimisticRequestPayout({
    required double amount,
    String? note,
  }) async {
    final actionId = _uuid.v4();
    await _db.enqueueAction(
      id: actionId,
      type: QueuedActionType.requestPayout,
      orderId: 0,
      payload: jsonEncode(<String, dynamic>{
        'amount': amount,
        if (note != null) 'note': note,
      }),
    );
    if (!_online) return false;
    try {
      await _db.markActionSyncing(actionId);
      await _payoutService.create(
        CreatePayoutRequest(amount: amount, note: note),
      );
      await _db.markActionSuccess(actionId);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode >= 400 &&
          e.statusCode < 500 &&
          e.statusCode != 408 &&
          e.statusCode != 429) {
        await _db.markActionFailed(id: actionId, error: e.message);
        return false;
      }
      await _db.markActionRetry(id: actionId, error: e.message);
      _scheduleRetry();
      return false;
    } catch (e) {
      await _db.markActionRetry(id: actionId, error: e.toString());
      _scheduleRetry();
      return false;
    }
  }

  /// Enqueue une validation de virement (par uuid).
  Future<bool> optimisticValidatePayout({
    required String uuid,
    String? code,
  }) async {
    final actionId = _uuid.v4();
    await _db.enqueueAction(
      id: actionId,
      type: QueuedActionType.validatePayout,
      orderId: 0,
      payload: jsonEncode(<String, dynamic>{
        'uuid': uuid,
        if (code != null) 'code': code,
      }),
    );
    if (!_online) return false;
    try {
      await _db.markActionSyncing(actionId);
      await _payoutService.validate(uuid, code: code);
      await _db.markActionSuccess(actionId);
      return true;
    } on ApiException catch (e) {
      if (e.statusCode >= 400 &&
          e.statusCode < 500 &&
          e.statusCode != 408 &&
          e.statusCode != 429) {
        await _db.markActionFailed(id: actionId, error: e.message);
        return false;
      }
      await _db.markActionRetry(id: actionId, error: e.message);
      _scheduleRetry();
      return false;
    } catch (e) {
      await _db.markActionRetry(id: actionId, error: e.toString());
      _scheduleRetry();
      return false;
    }
  }

  void _scheduleRetry([int? attempts]) {
    final int a = attempts ?? 1;
    final int seconds = _backoffSeconds(a);
    // Jitter : +/- 0..1000ms d'aleatoire pour eviter le thundering herd
    // si plusieurs actions timeout en meme temps (5xx generalisee, perte
    // reseau partagee). Le delai final est dans [seconds * 1000,
    // seconds * 1000 + 1000) ms.
    final int jitterMs = _jitter.nextInt(1000);
    _backoffTimer?.cancel();
    _backoffTimer = Timer(
      Duration(milliseconds: seconds * 1000 + jitterMs),
      () {
        if (_online) run();
      },
    );
  }

  int _backoffSeconds(int attempts) {
    // 1, 2, 4, 8, 16, 32, 60 cap.
    final int s = (1 << (attempts.clamp(0, 6) - 1));
    if (s >= 60) return 60;
    return s < 1 ? 1 : s;
  }
}
