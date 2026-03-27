import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/dashboard_model.dart';
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

/// Provider pratique pour les commandes du jour.
final ordersTodayProvider = Provider<int>((ref) {
  return ref.watch(dashboardProvider).summary?.ordersToday ?? 0;
});

/// Provider pratique pour le revenu du jour.
final revenueTodayProvider = Provider<double>((ref) {
  return ref.watch(dashboardProvider).summary?.revenueToday ?? 0;
});

/// Provider pratique pour la note moyenne.
final ratingProvider = Provider<double>((ref) {
  return ref.watch(dashboardProvider).summary?.rating ?? 0;
});

/// Provider pratique pour les paniers actifs.
final activeCartsProvider = Provider<int>((ref) {
  return ref.watch(dashboardProvider).summary?.activeCarts ?? 0;
});
