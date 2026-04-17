import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/order_model.dart' show PaginationMeta;
import 'package:merchant/models/transaction_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/transaction_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum TransactionsStatus { initial, loading, loaded, error }

class TransactionsListState {
  final TransactionsStatus status;
  final List<Transaction> transactions;
  final PaginationMeta? meta;
  final bool isLoadingMore;
  final String? errorMessage;
  final String? typeFilter;
  final String? statusFilter;
  final String? search;
  final String? dateFrom;
  final String? dateTo;

  const TransactionsListState({
    this.status = TransactionsStatus.initial,
    this.transactions = const [],
    this.meta,
    this.isLoadingMore = false,
    this.errorMessage,
    this.typeFilter,
    this.statusFilter,
    this.search,
    this.dateFrom,
    this.dateTo,
  });

  TransactionsListState copyWith({
    TransactionsStatus? status,
    List<Transaction>? transactions,
    PaginationMeta? meta,
    bool? isLoadingMore,
    String? errorMessage,
    String? typeFilter,
    String? statusFilter,
    String? search,
    String? dateFrom,
    String? dateTo,
    bool clearError = false,
    bool clearTypeFilter = false,
    bool clearStatusFilter = false,
    bool clearSearch = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return TransactionsListState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      meta: meta ?? this.meta,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      search: clearSearch ? null : (search ?? this.search),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }

  bool get hasNextPage => meta?.hasNextPage ?? false;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class TransactionsListNotifier extends StateNotifier<TransactionsListState> {
  final TransactionService _service;

  TransactionsListNotifier({TransactionService? service})
      : _service = service ?? TransactionService(),
        super(const TransactionsListState());

  /// Charge la premiere page (reset du state).
  Future<void> load() async {
    state = state.copyWith(
      status: TransactionsStatus.loading,
      clearError: true,
    );
    try {
      final result = await _service.list(
        page: 1,
        limit: 25,
        search: state.search,
        type: state.typeFilter,
        status: state.statusFilter,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
      );
      state = state.copyWith(
        status: TransactionsStatus.loaded,
        transactions: result.data,
        meta: result.meta,
      );
    } on ApiException catch (e) {
      debugPrint('[TransactionsProvider] load failed: $e');
      state = state.copyWith(
        status: TransactionsStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[TransactionsProvider] load error: $e');
      state = state.copyWith(
        status: TransactionsStatus.error,
        errorMessage: 'Impossible de charger les transactions',
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
        search: state.search,
        type: state.typeFilter,
        status: state.statusFilter,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
      );
      state = state.copyWith(
        transactions: <Transaction>[
          ...state.transactions,
          ...result.data,
        ],
        meta: result.meta,
        isLoadingMore: false,
      );
    } catch (e) {
      debugPrint('[TransactionsProvider] loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Applique un filtre par type et recharge.
  Future<void> setTypeFilter(String? type) async {
    if (type == state.typeFilter) return;
    state = state.copyWith(
      typeFilter: type,
      clearTypeFilter: type == null,
      transactions: const [],
    );
    await load();
  }

  /// Applique un filtre par statut et recharge.
  Future<void> setStatusFilter(String? status) async {
    if (status == state.statusFilter) return;
    state = state.copyWith(
      statusFilter: status,
      clearStatusFilter: status == null,
      transactions: const [],
    );
    await load();
  }

  /// Applique une recherche et recharge.
  Future<void> setSearch(String? search) async {
    if (search == state.search) return;
    state = state.copyWith(
      search: search,
      clearSearch: search == null || search.isEmpty,
      transactions: const [],
    );
    await load();
  }

  /// Applique un intervalle de dates et recharge.
  Future<void> setDateRange({String? from, String? to}) async {
    state = state.copyWith(
      dateFrom: from,
      dateTo: to,
      clearDateFrom: from == null,
      clearDateTo: to == null,
      transactions: const [],
    );
    await load();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService();
});

final transactionsListProvider =
    StateNotifierProvider<TransactionsListNotifier, TransactionsListState>(
        (ref) {
  return TransactionsListNotifier(
    service: ref.watch(transactionServiceProvider),
  );
});
