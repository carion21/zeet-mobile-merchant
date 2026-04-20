// lib/providers/sync_provider.dart
//
// Providers Riverpod autour de la sync offline-first (Drift + SyncManager).
//
// - [partnerDatabaseProvider] : singleton DB, lifecycle automatique.
// - [syncManagerProvider]      : singleton SyncManager branche sur la DB.
// - [queuedActionsCountProvider] : stream du nombre d'actions en attente,
//   utilise par la bannière offline + l'ecran actions en attente.
// - [cachedOrdersProvider]     : stream des commandes en cache drift.
//
// Voir skill `zeet-offline-first` §4.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/data/local/partner_database.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/services/sync_manager.dart';

/// Singleton DB. Disposé quand le ProviderScope est démonté.
final partnerDatabaseProvider = Provider<PartnerDatabase>((Ref ref) {
  final PartnerDatabase db = PartnerDatabase();
  ref.onDispose(() async {
    try {
      await db.close();
    } catch (e) {
      debugPrint('[partnerDatabaseProvider] close failed: $e');
    }
  });
  return db;
});

/// Singleton SyncManager. Lance l'ecoute connectivite au premier build.
final syncManagerProvider = Provider<SyncManager>((Ref ref) {
  final PartnerDatabase db = ref.watch(partnerDatabaseProvider);
  final SyncManager sm = SyncManager.initialize(database: db);
  // Demarre la loop de sync (écoute connectivity + run initial).
  sm.start();
  ref.onDispose(() async {
    await sm.dispose();
  });
  return sm;
});

/// Nombre d'actions en attente (pending OR syncing).
/// 0 = file vide → bannière sans compteur.
final queuedActionsCountProvider = StreamProvider<int>((Ref ref) {
  final SyncManager sm = ref.watch(syncManagerProvider);
  return sm.watchPendingActionsCount();
});

/// Liste reactive des commandes en cache drift.
final cachedOrdersProvider = StreamProvider<List<Order>>((Ref ref) {
  final SyncManager sm = ref.watch(syncManagerProvider);
  return sm.watchCachedOrders();
});

/// Actions en attente (visualisables dans l'ecran "Actions en attente").
final pendingActionsProvider = StreamProvider<List<QueuedAction>>((Ref ref) {
  final PartnerDatabase db = ref.watch(partnerDatabaseProvider);
  return db.watchPendingActions();
});
