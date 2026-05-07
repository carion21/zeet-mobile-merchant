// lib/data/local/partner_database.dart
//
// Base locale Drift (SQLite) pour l'app Partner ZEET.
//
// Deux tables :
// - `orders_cache` : snapshot local des commandes en cours (source
//   de verite reactive pour l'UI pendant les coupures reseau).
// - `queued_actions` : queue persistante des actions ecrites pendant
//   l'offline, rejouees au retour du reseau par SyncManager.
//
// Le schema reste volontairement simple (JSON blobs + metadata typee)
// pour que toute evolution de l'API cote serveur ne necessite pas
// de migration Drift lourde.
//
// Voir skill `zeet-offline-first` §4 pour l'architecture locale-first.

import 'dart:io';

import 'package:drift/drift.dart';
// ignore: depend_on_referenced_packages
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'partner_database.g.dart';

// -----------------------------------------------------------------
// Enums — chaque int cote SQLite correspond a une valeur metier.
// -----------------------------------------------------------------

enum CachedOrderSyncStatus {
  /// Synchronise avec le serveur (aucune mutation locale en attente).
  synced,

  /// Action optimistic appliquee localement, sync en cours / en file.
  pending,

  /// Sync definitivement rejetee — rollback UI + alerte utilisateur.
  failed,
}

enum QueuedActionType {
  confirmOrder,
  markPreparing,
  markReady,
  cancelOrder,
  signalRupture,
  // Payouts (financiers) — partagent la queue offline pour beneficier du
  // retry exponentiel + dead letter. La cle metier (uuid payout) est
  // stockee dans le `payload` JSON, `orderId` est inutilise (force a 0).
  requestPayout,
  validatePayout,
}

enum QueuedActionStatus {
  pending,
  syncing,
  success,
  failed,
}

// -----------------------------------------------------------------
// Tables
// -----------------------------------------------------------------

/// Cache reactif des commandes partner. La source de verite UI lit
/// cette table via des Streams Drift, ce qui garantit que l'affichage
/// suit instantanement les updates optimistic.
///
/// `payload` : JSON complet serialise (Order.toJson).
/// `status`  : statut metier (pending / confirmed / preparing / …).
class OrdersCache extends Table {
  IntColumn get id => integer()();
  TextColumn get status => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get syncStatus =>
      intEnum<CachedOrderSyncStatus>().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Queue persistante des actions emises en offline-first.
/// Rejouees au retour du reseau par SyncManager.
class QueuedActions extends Table {
  TextColumn get id => text()();
  IntColumn get type => intEnum<QueuedActionType>()();
  IntColumn get orderId => integer()();
  TextColumn get payload => text().withDefault(const Constant('{}'))();
  DateTimeColumn get enqueuedAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get status =>
      intEnum<QueuedActionStatus>().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

// -----------------------------------------------------------------
// Database
// -----------------------------------------------------------------

@DriftDatabase(tables: <Type>[OrdersCache, QueuedActions])
class PartnerDatabase extends _$PartnerDatabase {
  PartnerDatabase() : super(_openConnection());

  PartnerDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  // ---- Orders cache ----

  Stream<List<OrdersCacheData>> watchAllOrders() {
    return (select(ordersCache)..orderBy(<OrderClauseGenerator<$OrdersCacheTable>>[
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<OrdersCacheData?> getOrderById(int id) {
    return (select(ordersCache)..where(($OrdersCacheTable t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertOrder({
    required int id,
    required String status,
    required String payload,
    CachedOrderSyncStatus syncStatus = CachedOrderSyncStatus.synced,
  }) {
    return into(ordersCache).insertOnConflictUpdate(
      OrdersCacheCompanion.insert(
        id: Value<int>(id),
        status: status,
        payload: payload,
        updatedAt: DateTime.now().toUtc(),
        syncStatus: Value<CachedOrderSyncStatus>(syncStatus),
      ),
    );
  }

  Future<void> upsertOrders(
    List<({int id, String status, String payload})> entries,
  ) async {
    await batch((Batch batch) {
      for (final ({int id, String status, String payload}) e in entries) {
        batch.insert(
          ordersCache,
          OrdersCacheCompanion.insert(
            id: Value<int>(e.id),
            status: e.status,
            payload: e.payload,
            updatedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> updateOrderStatusOptimistic({
    required int id,
    required String status,
    required String payload,
  }) {
    return (update(ordersCache)..where(($OrdersCacheTable t) => t.id.equals(id)))
        .write(
      OrdersCacheCompanion(
        status: Value<String>(status),
        payload: Value<String>(payload),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
        syncStatus: const Value<CachedOrderSyncStatus>(CachedOrderSyncStatus.pending),
      ),
    );
  }

  Future<void> markOrderSynced(int id) {
    return (update(ordersCache)..where(($OrdersCacheTable t) => t.id.equals(id)))
        .write(
      const OrdersCacheCompanion(
        syncStatus: Value<CachedOrderSyncStatus>(CachedOrderSyncStatus.synced),
      ),
    );
  }

  Future<void> markOrderFailed(int id) {
    return (update(ordersCache)..where(($OrdersCacheTable t) => t.id.equals(id)))
        .write(
      const OrdersCacheCompanion(
        syncStatus: Value<CachedOrderSyncStatus>(CachedOrderSyncStatus.failed),
      ),
    );
  }

  Future<void> deleteOrder(int id) {
    return (delete(ordersCache)..where(($OrdersCacheTable t) => t.id.equals(id))).go();
  }

  // ---- Queued actions ----

  Stream<List<QueuedAction>> watchPendingActions() {
    return (select(queuedActions)
          ..where(($QueuedActionsTable t) =>
              t.status.equalsValue(QueuedActionStatus.pending) |
              t.status.equalsValue(QueuedActionStatus.syncing))
          ..orderBy(<OrderClauseGenerator<$QueuedActionsTable>>[
            (t) => OrderingTerm(expression: t.enqueuedAt, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Stream<int> watchPendingActionsCount() {
    final Expression<int> countExp = queuedActions.id.count();
    final JoinedSelectStatement<HasResultSet, dynamic> query =
        (selectOnly(queuedActions)
          ..addColumns(<Expression<Object>>[countExp])
          ..where(queuedActions.status.equalsValue(QueuedActionStatus.pending) |
              queuedActions.status.equalsValue(QueuedActionStatus.syncing)));
    return query.map((TypedResult row) => row.read(countExp) ?? 0).watchSingle();
  }

  Future<List<QueuedAction>> getPendingActions() {
    return (select(queuedActions)
          ..where(($QueuedActionsTable t) =>
              t.status.equalsValue(QueuedActionStatus.pending))
          ..orderBy(<OrderClauseGenerator<$QueuedActionsTable>>[
            (t) => OrderingTerm(expression: t.enqueuedAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<List<QueuedAction>> getAllActions() => select(queuedActions).get();

  /// Cherche une action pending OU syncing du meme type/orderId. Utilise
  /// par SyncManager pour dedupliquer un double-tap (ex: confirmer la
  /// meme commande deux fois en < 500ms — la 2e action serait redondante
  /// et ferait echouer la 2e API call en 4xx ("deja confirmee") ce qui
  /// remontait une fausse erreur dans l'UI).
  Future<QueuedAction?> findInFlightAction({
    required QueuedActionType type,
    required int orderId,
  }) {
    return (select(queuedActions)
          ..where(($QueuedActionsTable t) =>
              t.type.equalsValue(type) &
              t.orderId.equals(orderId) &
              (t.status.equalsValue(QueuedActionStatus.pending) |
                  t.status.equalsValue(QueuedActionStatus.syncing)))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> enqueueAction({
    required String id,
    required QueuedActionType type,
    required int orderId,
    String payload = '{}',
  }) {
    return into(queuedActions).insertOnConflictUpdate(
      QueuedActionsCompanion.insert(
        id: id,
        type: type,
        orderId: orderId,
        payload: Value<String>(payload),
        enqueuedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> markActionSyncing(String id) {
    return (update(queuedActions)..where(($QueuedActionsTable t) => t.id.equals(id)))
        .write(
      QueuedActionsCompanion(
        status: const Value<QueuedActionStatus>(QueuedActionStatus.syncing),
        lastAttemptAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> markActionSuccess(String id) {
    return (delete(queuedActions)..where(($QueuedActionsTable t) => t.id.equals(id)))
        .go();
  }

  Future<void> markActionRetry({
    required String id,
    required String? error,
  }) async {
    final QueuedAction? existing = await (select(queuedActions)
          ..where(($QueuedActionsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;
    await (update(queuedActions)..where(($QueuedActionsTable t) => t.id.equals(id)))
        .write(
      QueuedActionsCompanion(
        status: const Value<QueuedActionStatus>(QueuedActionStatus.pending),
        lastAttemptAt: Value<DateTime>(DateTime.now().toUtc()),
        attempts: Value<int>(existing.attempts + 1),
        lastError: Value<String?>(error),
      ),
    );
  }

  Future<void> markActionFailed({
    required String id,
    required String? error,
  }) async {
    await (update(queuedActions)..where(($QueuedActionsTable t) => t.id.equals(id)))
        .write(
      QueuedActionsCompanion(
        status: const Value<QueuedActionStatus>(QueuedActionStatus.failed),
        lastError: Value<String?>(error),
      ),
    );
  }

  Future<void> removeAction(String id) {
    return (delete(queuedActions)..where(($QueuedActionsTable t) => t.id.equals(id)))
        .go();
  }

  Future<void> clearFailedActions() {
    return (delete(queuedActions)
          ..where(($QueuedActionsTable t) =>
              t.status.equalsValue(QueuedActionStatus.failed)))
        .go();
  }

  Future<void> clearAll() async {
    await batch((Batch batch) {
      batch.deleteAll(ordersCache);
      batch.deleteAll(queuedActions);
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String path = p.join(dir.path, 'zeet_partner.sqlite');
    return NativeDatabase.createInBackground(File(path));
  });
}
