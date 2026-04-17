import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/order_model.dart' show PaginationMeta;
import 'package:merchant/models/wallet_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/wallet_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum WalletStatus { initial, loading, loaded, error }

/// Filtre applique a la liste des entries.
enum WalletDirectionFilter { all, credit, debit }

extension WalletDirectionFilterX on WalletDirectionFilter {
  String? get apiValue {
    switch (this) {
      case WalletDirectionFilter.all:
        return null;
      case WalletDirectionFilter.credit:
        return 'credit';
      case WalletDirectionFilter.debit:
        return 'debit';
    }
  }

  String get label {
    switch (this) {
      case WalletDirectionFilter.all:
        return 'Tous';
      case WalletDirectionFilter.credit:
        return 'Credits';
      case WalletDirectionFilter.debit:
        return 'Debits';
    }
  }
}

class WalletState {
  final WalletStatus balanceStatus;
  final WalletStatus entriesStatus;
  final Wallet? wallet;
  final List<WalletEntry> entries;
  final PaginationMeta? meta;
  final WalletDirectionFilter filter;
  final bool isLoadingMore;
  final String? errorMessage;

  const WalletState({
    this.balanceStatus = WalletStatus.initial,
    this.entriesStatus = WalletStatus.initial,
    this.wallet,
    this.entries = const [],
    this.meta,
    this.filter = WalletDirectionFilter.all,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  WalletState copyWith({
    WalletStatus? balanceStatus,
    WalletStatus? entriesStatus,
    Wallet? wallet,
    List<WalletEntry>? entries,
    PaginationMeta? meta,
    WalletDirectionFilter? filter,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WalletState(
      balanceStatus: balanceStatus ?? this.balanceStatus,
      entriesStatus: entriesStatus ?? this.entriesStatus,
      wallet: wallet ?? this.wallet,
      entries: entries ?? this.entries,
      meta: meta ?? this.meta,
      filter: filter ?? this.filter,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get hasNextPage => meta?.hasNextPage ?? false;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class WalletNotifier extends StateNotifier<WalletState> {
  final WalletService _service;

  WalletNotifier({WalletService? service})
      : _service = service ?? WalletService(),
        super(const WalletState());

  /// Charge le solde ET la premiere page d'entries en parallele.
  Future<void> load() async {
    await Future.wait<void>([
      loadBalance(),
      loadEntries(reset: true),
    ]);
  }

  /// Rafraichit tout (pull-to-refresh).
  Future<void> refresh() => load();

  // ---------------------------------------------------------------------------
  // Balance — GET /v1/partner/wallet
  // ---------------------------------------------------------------------------
  Future<void> loadBalance() async {
    state = state.copyWith(balanceStatus: WalletStatus.loading, clearError: true);
    try {
      final wallet = await _service.getBalance();
      state = state.copyWith(
        balanceStatus: WalletStatus.loaded,
        wallet: wallet,
      );
    } on ApiException catch (e) {
      debugPrint('[WalletProvider] loadBalance failed: $e');
      state = state.copyWith(
        balanceStatus: WalletStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[WalletProvider] loadBalance error: $e');
      state = state.copyWith(
        balanceStatus: WalletStatus.error,
        errorMessage: 'Impossible de charger le solde',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Entries — GET /v1/partner/wallet/entries
  // ---------------------------------------------------------------------------
  Future<void> loadEntries({bool reset = false}) async {
    state = state.copyWith(
      entriesStatus: WalletStatus.loading,
      clearError: true,
    );
    try {
      final result = await _service.getEntries(
        page: 1,
        limit: 25,
        direction: state.filter.apiValue,
      );
      state = state.copyWith(
        entriesStatus: WalletStatus.loaded,
        entries: result.data,
        meta: result.meta,
      );
    } on ApiException catch (e) {
      debugPrint('[WalletProvider] loadEntries failed: $e');
      state = state.copyWith(
        entriesStatus: WalletStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[WalletProvider] loadEntries error: $e');
      state = state.copyWith(
        entriesStatus: WalletStatus.error,
        errorMessage: 'Impossible de charger l\'historique',
      );
    }
  }

  /// Charge la page suivante (pagination infinie).
  Future<void> loadMore() async {
    final meta = state.meta;
    if (meta == null || !meta.hasNextPage || state.isLoadingMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _service.getEntries(
        page: meta.page + 1,
        limit: meta.limit,
        direction: state.filter.apiValue,
      );
      state = state.copyWith(
        entries: <WalletEntry>[...state.entries, ...result.data],
        meta: result.meta,
        isLoadingMore: false,
      );
    } catch (e) {
      debugPrint('[WalletProvider] loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Change le filtre et recharge la premiere page.
  Future<void> setFilter(WalletDirectionFilter filter) async {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter, entries: const []);
    await loadEntries(reset: true);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});

/// Solde courant (0 si non encore charge).
final walletBalanceProvider = Provider<double>((ref) {
  return ref.watch(walletProvider).wallet?.balance ?? 0;
});

/// Currency affichee (fallback XOF pour la zone CFA).
final walletCurrencyProvider = Provider<String>((ref) {
  return ref.watch(walletProvider).wallet?.currency ?? 'XOF';
});
