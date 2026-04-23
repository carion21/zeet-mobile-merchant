import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/dashboard_model.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/providers/sync_provider.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/dashboard_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum DashboardStatus { initial, loading, loaded, error }

class DashboardState {
  final DashboardStatus status;
  final DashboardSummary? summary;
  final String? errorMessage;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.summary,
    this.errorMessage,
  });

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardSummary? summary,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      errorMessage: errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class DashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardService _dashboardService;

  DashboardNotifier({DashboardService? dashboardService})
      : _dashboardService = dashboardService ?? DashboardService(),
        super(const DashboardState());

  // ---------------------------------------------------------------------------
  // GET /v1/partner/dashboard/summary
  // ---------------------------------------------------------------------------
  /// Charge le resume des KPIs du dashboard.
  Future<void> loadSummary() async {
    state = state.copyWith(status: DashboardStatus.loading);

    try {
      final summary = await _dashboardService.getSummary();
      state = DashboardState(
        status: DashboardStatus.loaded,
        summary: summary,
      );
    } on ApiException catch (e) {
      debugPrint('[DashboardProvider] loadSummary failed: $e');
      state = state.copyWith(
        status: DashboardStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[DashboardProvider] loadSummary error: $e');
      state = state.copyWith(
        status: DashboardStatus.error,
        errorMessage: 'Impossible de charger le tableau de bord',
      );
    }
  }

  /// Rafraichit le dashboard (peut etre appele par pull-to-refresh).
  Future<void> refresh() => loadSummary();
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});

// ---------------------------------------------------------------------------
// Stats du jour — hybride local Drift + backend summary
// ---------------------------------------------------------------------------
//
// Pattern offline-first (CLAUDE.md §Offline-first) : la source de verite
// operationnelle est le cache Drift local. Le backend `dashboard/summary`
// peut etre incomplet / buggy (bug identifie : `orders_today` et
// `revenue_today` renvoyaient 0 pour certains partners actifs).
//
// Strategie : on calcule localement depuis les commandes deja synchronisees
// ET on prend le `max(local, backend)` — couvre les deux cas :
//   - cache riche et backend stale → local gagne
//   - cache vide (fresh install / partner vient de se logger) → backend
//     gagne (s'il est correct)
//
// Critere "commande du jour" : `createdAt` dans la plage [today 00:00,
// maintenant] en heure locale. Ca evite les surprises de fuseau UTC.
//
// Critere "traitee" : tout statut **sauf** pending/rejected/cancelled.
// Couvre confirmed, payment-accepted, preparing, ready, picked_up,
// on-the-way, delivered. Aligne sur le label frontend "Traitees
// aujourd'hui".

/// Statuts exclus du calcul "commandes traitees" — tout le reste compte.
const Set<String> _kNotTreatedStatuses = <String>{
  'pending',
  'rejected',
  'cancelled',
};

bool _isOrderTreatedToday(Order o) {
  final String status = o.status.trim().toLowerCase();
  if (_kNotTreatedStatuses.contains(status)) return false;
  final String? createdAtIso = o.createdAt;
  if (createdAtIso == null || createdAtIso.isEmpty) return false;
  try {
    final DateTime dt = DateTime.parse(createdAtIso).toLocal();
    final DateTime now = DateTime.now();
    return dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
  } catch (_) {
    return false;
  }
}

/// Commandes **traitees** aujourd'hui (calcul local, offline-first).
/// A combiner avec la valeur backend via [ordersTodayProvider].
final ordersTreatedTodayLocalProvider = Provider<int>((ref) {
  final AsyncValue<List<Order>> cached = ref.watch(cachedOrdersProvider);
  final List<Order> orders = cached.valueOrNull ?? const <Order>[];
  return orders.where(_isOrderTreatedToday).length;
});

/// Gains generes aujourd'hui (calcul local). Somme des `netAmount` des
/// commandes traitees du jour — c'est le gain reel du partner apres
/// commission (aligne sur le label "Gains" du profil).
final revenueTodayLocalProvider = Provider<double>((ref) {
  final AsyncValue<List<Order>> cached = ref.watch(cachedOrdersProvider);
  final List<Order> orders = cached.valueOrNull ?? const <Order>[];
  double sum = 0;
  for (final Order o in orders) {
    if (!_isOrderTreatedToday(o)) continue;
    // Priorite netAmount (apres commission) > totalAmount (brut) > 0.
    final double amount = o.netAmount ?? o.totalAmount ?? 0;
    sum += amount;
  }
  return sum;
});

/// Commandes du jour exposees a l'UI — `max(local, backend)`. Le local
/// protege d'un backend qui renvoie 0 alors que le partner a eu de
/// l'activite (bug identifie en production). Le backend protege du cache
/// vide (nouvelle install).
final ordersTodayProvider = Provider<int>((ref) {
  final int local = ref.watch(ordersTreatedTodayLocalProvider);
  final int backend = ref.watch(dashboardProvider).summary?.ordersToday ?? 0;
  return local > backend ? local : backend;
});

/// Revenu du jour expose — `max(local, backend)` meme strategie.
final revenueTodayProvider = Provider<double>((ref) {
  final double local = ref.watch(revenueTodayLocalProvider);
  final double backend =
      ref.watch(dashboardProvider).summary?.revenueToday ?? 0;
  return local > backend ? local : backend;
});

/// Provider pratique pour la note moyenne. Reste backend-only (les
/// reviews clients ne sont pas en cache local).
final ratingProvider = Provider<double>((ref) {
  return ref.watch(dashboardProvider).summary?.rating ?? 0;
});

/// Provider pratique pour les paniers actifs (backend-only, pas de cache
/// local des carts clients).
final activeCartsProvider = Provider<int>((ref) {
  return ref.watch(dashboardProvider).summary?.activeCarts ?? 0;
});
