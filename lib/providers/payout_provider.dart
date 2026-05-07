import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/order_model.dart' show PaginationMeta;
import 'package:merchant/models/payout_model.dart';
import 'package:merchant/providers/wallet_provider.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/payout_service.dart';
import 'package:merchant/services/sync_manager.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum PayoutsStatus { initial, loading, loaded, error }

class PayoutsListState {
  final PayoutsStatus status;
  final List<Payout> payouts;
  final PaginationMeta? meta;
  final bool isLoadingMore;
  final bool isCreating;
  final bool isValidating;
  final String? errorMessage;
  final String? statusFilter;

  const PayoutsListState({
    this.status = PayoutsStatus.initial,
    this.payouts = const [],
    this.meta,
    this.isLoadingMore = false,
    this.isCreating = false,
    this.isValidating = false,
    this.errorMessage,
    this.statusFilter,
  });

  PayoutsListState copyWith({
    PayoutsStatus? status,
    List<Payout>? payouts,
    PaginationMeta? meta,
    bool? isLoadingMore,
    bool? isCreating,
    bool? isValidating,
    String? errorMessage,
    String? statusFilter,
    bool clearError = false,
    bool clearStatusFilter = false,
  }) {
    return PayoutsListState(
      status: status ?? this.status,
      payouts: payouts ?? this.payouts,
      meta: meta ?? this.meta,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isCreating: isCreating ?? this.isCreating,
      isValidating: isValidating ?? this.isValidating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
    );
  }

  bool get hasNextPage => meta?.hasNextPage ?? false;
}

// ---------------------------------------------------------------------------
// Notifier — Liste paginee + actions (create, validate)
// ---------------------------------------------------------------------------

class PayoutsListNotifier extends StateNotifier<PayoutsListState> {
  final PayoutService _service;
  final Ref _ref;

  PayoutsListNotifier({
    required Ref ref,
    PayoutService? service,
  })  : _ref = ref,
        _service = service ?? PayoutService(),
        super(const PayoutsListState());

  /// Charge la premiere page (reset du state).
  Future<void> load() async {
    state = state.copyWith(
      status: PayoutsStatus.loading,
      clearError: true,
    );
    try {
      final result = await _service.list(
        page: 1,
        limit: 25,
        status: state.statusFilter,
      );
      state = state.copyWith(
        status: PayoutsStatus.loaded,
        payouts: result.data,
        meta: result.meta,
      );
    } on ApiException catch (e) {
      debugPrint('[PayoutsProvider] load failed: $e');
      state = state.copyWith(
        status: PayoutsStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[PayoutsProvider] load error: $e');
      state = state.copyWith(
        status: PayoutsStatus.error,
        errorMessage: 'Impossible de charger les demandes de virement',
      );
    }
  }

  /// Pull-to-refresh.
  Future<void> refresh() => load();

  /// Charge la page suivante (pagination infinie).
  Future<void> loadMore() async {
    final meta = state.meta;
    if (meta == null || !meta.hasNextPage || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _service.list(
        page: meta.page + 1,
        limit: meta.limit,
        status: state.statusFilter,
      );
      state = state.copyWith(
        payouts: <Payout>[...state.payouts, ...result.data],
        meta: result.meta,
        isLoadingMore: false,
      );
    } catch (e) {
      debugPrint('[PayoutsProvider] loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Filtre par statut et recharge.
  Future<void> setStatusFilter(String? status) async {
    if (status == state.statusFilter) return;
    state = state.copyWith(
      statusFilter: status,
      clearStatusFilter: status == null,
      payouts: const [],
    );
    await load();
  }

  /// Cree une nouvelle demande de virement.
  ///
  /// Route via `SyncManager.optimisticRequestPayout` qui :
  ///  - Idempotency-Key automatique (cf. payout_service.dart)
  ///  - Tente immediatement si online
  ///  - Enqueue dans Drift offline queue si le reseau est coupe
  ///  - Retry exponentiel + dead letter 10 essais sur 5xx/timeout
  ///
  /// En cas de succes immediat : recharge la liste serveur pour avoir
  /// le payout fraichement cree (avec uuid + status backend) — la
  /// methode optimisticRequestPayout ne renvoie pas le Payout, elle
  /// renvoie un bool "sync immediate OK".
  Future<Payout?> create(CreatePayoutRequest request) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final synced = await SyncManager.instance.optimisticRequestPayout(
        amount: request.amount,
        note: request.note,
      );
      if (synced) {
        // Sync immediate OK — recharger la page 1 pour avoir le nouveau
        // payout en tete de liste (le serveur retourne uuid + status reels).
        await load();
        try {
          await _ref.read(walletProvider.notifier).loadBalance();
        } catch (e) {
          debugPrint('[PayoutsProvider] wallet refresh failed: $e');
        }
        state = state.copyWith(isCreating: false);
        return state.payouts.isNotEmpty ? state.payouts.first : null;
      }
      // Action en queue offline ou echec metier — UI doit afficher
      // "Enregistre, sera envoye au retour reseau" (cf. PartnerConnectivityBanner).
      state = state.copyWith(
        isCreating: false,
        errorMessage:
            'Demande enregistree localement. On l\'envoie des que le reseau revient.',
      );
      return null;
    } on ApiException catch (e) {
      debugPrint('[PayoutsProvider] create failed: $e');
      state = state.copyWith(
        isCreating: false,
        errorMessage: e.message,
      );
      return null;
    } catch (e) {
      debugPrint('[PayoutsProvider] create error: $e');
      state = state.copyWith(
        isCreating: false,
        errorMessage: 'Impossible de creer la demande de virement',
      );
      return null;
    }
  }

  /// Valide une demande de virement (uuid).
  ///
  /// Route via `SyncManager.optimisticValidatePayout` (meme benefices
  /// retry/offline que `create`). Si succes immediat, recharge le payout
  /// par UUID pour mettre a jour son status local.
  Future<Payout?> validate(String uuid, {String? code}) async {
    state = state.copyWith(isValidating: true, clearError: true);
    try {
      final synced = await SyncManager.instance.optimisticValidatePayout(
        uuid: uuid,
        code: code,
      );
      if (synced) {
        // Recharge le payout par uuid pour avoir status mis a jour.
        try {
          final updated = await _service.getByUuid(uuid);
          state = state.copyWith(
            isValidating: false,
            payouts: state.payouts
                .map((p) => p.uuid == uuid ? updated : p)
                .toList(),
          );
          return updated;
        } catch (_) {
          state = state.copyWith(isValidating: false);
          return null;
        }
      }
      state = state.copyWith(
        isValidating: false,
        errorMessage:
            'Validation enregistree localement. On l\'envoie des que le reseau revient.',
      );
      return null;
    } on ApiException catch (e) {
      debugPrint('[PayoutsProvider] validate failed: $e');
      state = state.copyWith(
        isValidating: false,
        errorMessage: e.message,
      );
      return null;
    } catch (e) {
      debugPrint('[PayoutsProvider] validate error: $e');
      state = state.copyWith(
        isValidating: false,
        errorMessage: 'Impossible de valider la demande de virement',
      );
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final payoutServiceProvider = Provider<PayoutService>((ref) {
  return PayoutService();
});

final payoutsListProvider =
    StateNotifierProvider<PayoutsListNotifier, PayoutsListState>((ref) {
  return PayoutsListNotifier(
    ref: ref,
    service: ref.watch(payoutServiceProvider),
  );
});

/// Detail d'un payout par UUID.
/// FutureProvider.family pour charger a la demande depuis un ecran detail.
final payoutDetailProvider =
    FutureProvider.family<Payout, String>((ref, uuid) async {
  final service = ref.watch(payoutServiceProvider);
  return service.getByUuid(uuid);
});
