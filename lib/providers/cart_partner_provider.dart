import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/cart_partner_model.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/cart_partner_service.dart';

// =============================================================================
// Carts List State + Notifier
// =============================================================================

enum CartsListStatus { initial, loading, loaded, error, loadingMore }

class CartsListState {
  final CartsListStatus status;
  final List<PartnerCart> carts;
  final PaginationMeta? meta;
  final String? errorMessage;

  const CartsListState({
    this.status = CartsListStatus.initial,
    this.carts = const [],
    this.meta,
    this.errorMessage,
  });

  CartsListState copyWith({
    CartsListStatus? status,
    List<PartnerCart>? carts,
    PaginationMeta? meta,
    String? errorMessage,
  }) {
    return CartsListState(
      status: status ?? this.status,
      carts: carts ?? this.carts,
      meta: meta ?? this.meta,
      errorMessage: errorMessage,
    );
  }
}

class CartsListNotifier extends StateNotifier<CartsListState> {
  final CartPartnerService _cartService;

  CartsListNotifier({CartPartnerService? cartService})
      : _cartService = cartService ?? CartPartnerService(),
        super(const CartsListState());

  /// Charge la premiere page de paniers actifs.
  Future<void> load() async {
    state = state.copyWith(status: CartsListStatus.loading);

    try {
      final result = await _cartService.listCarts(page: 1);
      state = CartsListState(
        status: CartsListStatus.loaded,
        carts: result.data,
        meta: result.meta,
      );
    } on ApiException catch (e) {
      debugPrint('[CartsListNotifier] load failed: $e');
      state = state.copyWith(
        status: CartsListStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[CartsListNotifier] load error: $e');
      state = state.copyWith(
        status: CartsListStatus.error,
        errorMessage: 'Impossible de charger les paniers',
      );
    }
  }

  /// Charge la page suivante (pagination infinie).
  Future<void> loadMore() async {
    if (state.meta == null || !state.meta!.hasNextPage) return;
    if (state.status == CartsListStatus.loadingMore) return;

    state = state.copyWith(status: CartsListStatus.loadingMore);

    try {
      final result = await _cartService.listCarts(
        page: state.meta!.page + 1,
      );

      state = state.copyWith(
        status: CartsListStatus.loaded,
        carts: [...state.carts, ...result.data],
        meta: result.meta,
      );
    } on ApiException catch (e) {
      debugPrint('[CartsListNotifier] loadMore failed: $e');
      state = state.copyWith(
        status: CartsListStatus.loaded,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[CartsListNotifier] loadMore error: $e');
      state = state.copyWith(status: CartsListStatus.loaded);
    }
  }

  /// Rafraichit la liste (pull-to-refresh).
  Future<void> refresh() => load();
}

// =============================================================================
// Cart Stats State + Notifier
// =============================================================================

enum CartStatsStatus { initial, loading, loaded, error }

class CartStatsState {
  final CartStatsStatus status;
  final CartStats? stats;
  final String? errorMessage;

  const CartStatsState({
    this.status = CartStatsStatus.initial,
    this.stats,
    this.errorMessage,
  });

  CartStatsState copyWith({
    CartStatsStatus? status,
    CartStats? stats,
    String? errorMessage,
  }) {
    return CartStatsState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      errorMessage: errorMessage,
    );
  }
}

class CartStatsNotifier extends StateNotifier<CartStatsState> {
  final CartPartnerService _cartService;

  CartStatsNotifier({CartPartnerService? cartService})
      : _cartService = cartService ?? CartPartnerService(),
        super(const CartStatsState());

  /// Charge les stats des paniers.
  Future<void> load() async {
    state = state.copyWith(status: CartStatsStatus.loading);

    try {
      final stats = await _cartService.getCartStats();
      state = CartStatsState(
        status: CartStatsStatus.loaded,
        stats: stats,
      );
    } on ApiException catch (e) {
      debugPrint('[CartStatsNotifier] load failed: $e');
      state = state.copyWith(
        status: CartStatsStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[CartStatsNotifier] load error: $e');
      state = state.copyWith(
        status: CartStatsStatus.error,
        errorMessage: 'Impossible de charger les stats paniers',
      );
    }
  }

  /// Rafraichit les stats paniers.
  Future<void> refresh() => load();
}

// =============================================================================
// Providers
// =============================================================================

/// Provider principal pour la liste des paniers actifs.
final cartsListProvider =
    StateNotifierProvider<CartsListNotifier, CartsListState>((ref) {
  return CartsListNotifier();
});

/// Provider pour les stats des paniers.
final cartStatsProvider =
    StateNotifierProvider<CartStatsNotifier, CartStatsState>((ref) {
  return CartStatsNotifier();
});

// ---------------------------------------------------------------------------
// Providers pratiques (computed)
// ---------------------------------------------------------------------------

/// Nombre de paniers actifs.
final activeCartsCountProvider = Provider<int>((ref) {
  return ref.watch(cartStatsProvider).stats?.activeCarts ?? 0;
});

/// Montant total des paniers actifs.
final cartsTotalAmountProvider = Provider<double>((ref) {
  return ref.watch(cartStatsProvider).stats?.totalAmount ?? 0;
});

/// Valeur moyenne des paniers.
final cartsAverageValueProvider = Provider<double>((ref) {
  return ref.watch(cartStatsProvider).stats?.averageCartValue ?? 0;
});
