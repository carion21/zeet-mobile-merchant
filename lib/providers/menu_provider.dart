import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/menu_model.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/menu_service.dart';

// =============================================================================
// Menus List State + Notifier
// =============================================================================

enum MenusListStatus { initial, loading, loaded, error, loadingMore }

class MenusListState {
  final MenusListStatus status;
  final List<Menu> menus;
  final PaginationMeta? meta;
  final String? search;
  final String? errorMessage;

  const MenusListState({
    this.status = MenusListStatus.initial,
    this.menus = const [],
    this.meta,
    this.search,
    this.errorMessage,
  });

  MenusListState copyWith({
    MenusListStatus? status,
    List<Menu>? menus,
    PaginationMeta? meta,
    String? search,
    String? errorMessage,
    bool clearSearch = false,
  }) {
    return MenusListState(
      status: status ?? this.status,
      menus: menus ?? this.menus,
      meta: meta ?? this.meta,
      search: clearSearch ? null : (search ?? this.search),
      errorMessage: errorMessage,
    );
  }

  /// Menus actifs (publies).
  List<Menu> get activeMenus => menus.where((m) => m.status).toList();

  /// Menus inactifs (non publies).
  List<Menu> get inactiveMenus => menus.where((m) => !m.status).toList();

  /// Menu par defaut.
  Menu? get defaultMenu {
    try {
      return menus.firstWhere((m) => m.isDefault);
    } catch (_) {
      return null;
    }
  }
}

class MenusListNotifier extends StateNotifier<MenusListState> {
  final MenuService _menuService;

  MenusListNotifier({MenuService? menuService})
      : _menuService = menuService ?? MenuService(),
        super(const MenusListState());

  /// Charge la premiere page de menus.
  Future<void> load() async {
    state = state.copyWith(status: MenusListStatus.loading);

    try {
      final result = await _menuService.listMenus(
        page: 1,
        search: state.search,
      );

      state = MenusListState(
        status: MenusListStatus.loaded,
        menus: result.data,
        meta: result.meta,
        search: state.search,
      );
    } on ApiException catch (e) {
      debugPrint('[MenusListNotifier] load failed: $e');
      state = state.copyWith(
        status: MenusListStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[MenusListNotifier] load error: $e');
      state = state.copyWith(
        status: MenusListStatus.error,
        errorMessage: 'Impossible de charger les menus',
      );
    }
  }

  /// Charge la page suivante (pagination infinie).
  Future<void> loadMore() async {
    if (state.meta == null || !state.meta!.hasNextPage) return;
    if (state.status == MenusListStatus.loadingMore) return;

    state = state.copyWith(status: MenusListStatus.loadingMore);

    try {
      final result = await _menuService.listMenus(
        page: state.meta!.page + 1,
        search: state.search,
      );

      state = state.copyWith(
        status: MenusListStatus.loaded,
        menus: [...state.menus, ...result.data],
        meta: result.meta,
      );
    } on ApiException catch (e) {
      debugPrint('[MenusListNotifier] loadMore failed: $e');
      state = state.copyWith(
        status: MenusListStatus.loaded,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[MenusListNotifier] loadMore error: $e');
      state = state.copyWith(status: MenusListStatus.loaded);
    }
  }

  /// Recherche par texte.
  Future<void> searchMenus(String? query) async {
    state = state.copyWith(
      search: query,
      clearSearch: query == null || query.isEmpty,
    );
    await load();
  }

  /// Rafraichit la liste (pull-to-refresh).
  Future<void> refresh() async {
    await load();
  }

  /// Met a jour un menu dans la liste locale (apres update/publish).
  void updateMenuInList(Menu updatedMenu) {
    state = state.copyWith(
      menus: [
        for (final m in state.menus)
          if (m.id == updatedMenu.id) updatedMenu else m
      ],
    );
  }

  /// Retire un menu de la liste locale (apres suppression).
  void removeMenuFromList(int menuId) {
    state = state.copyWith(
      menus: state.menus.where((m) => m.id != menuId).toList(),
    );
  }
}

// =============================================================================
// Menu Detail State + Notifier
// =============================================================================

enum MenuDetailStatus { initial, loading, loaded, error, acting }

class MenuDetailState {
  final MenuDetailStatus status;
  final Menu? menu;
  final String? errorMessage;
  final String? actionError;

  const MenuDetailState({
    this.status = MenuDetailStatus.initial,
    this.menu,
    this.errorMessage,
    this.actionError,
  });

  MenuDetailState copyWith({
    MenuDetailStatus? status,
    Menu? menu,
    String? errorMessage,
    String? actionError,
  }) {
    return MenuDetailState(
      status: status ?? this.status,
      menu: menu ?? this.menu,
      errorMessage: errorMessage,
      actionError: actionError,
    );
  }
}

class MenuDetailNotifier extends StateNotifier<MenuDetailState> {
  final MenuService _menuService;

  MenuDetailNotifier({MenuService? menuService})
      : _menuService = menuService ?? MenuService(),
        super(const MenuDetailState());

  /// Charge le detail d'un menu.
  Future<void> load(int menuId) async {
    state = state.copyWith(status: MenuDetailStatus.loading);

    try {
      final menu = await _menuService.getMenu(menuId);
      state = MenuDetailState(
        status: MenuDetailStatus.loaded,
        menu: menu,
      );
    } on ApiException catch (e) {
      debugPrint('[MenuDetailNotifier] load failed: $e');
      state = state.copyWith(
        status: MenuDetailStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[MenuDetailNotifier] load error: $e');
      state = state.copyWith(
        status: MenuDetailStatus.error,
        errorMessage: 'Impossible de charger le menu',
      );
    }
  }

  /// Met a jour un menu (PATCH /menus/:id).
  Future<bool> update(
    int menuId, {
    String? name,
    String? description,
    bool? isDefault,
    String? timeStart,
    String? timeEnd,
    DaysOfWeek? daysOfWeek,
    List<int>? productIds,
  }) async {
    state = state.copyWith(status: MenuDetailStatus.acting, actionError: null);

    try {
      final menu = await _menuService.updateMenu(
        menuId,
        name: name,
        description: description,
        isDefault: isDefault,
        timeStart: timeStart,
        timeEnd: timeEnd,
        daysOfWeek: daysOfWeek,
        productIds: productIds,
      );
      state = MenuDetailState(
        status: MenuDetailStatus.loaded,
        menu: menu,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[MenuDetailNotifier] update failed: $e');
      state = state.copyWith(
        status: MenuDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[MenuDetailNotifier] update error: $e');
      state = state.copyWith(
        status: MenuDetailStatus.loaded,
        actionError: 'Impossible de modifier le menu',
      );
      return false;
    }
  }

  /// Publie/active un menu (PATCH /menus/:id/publish).
  Future<bool> publish(int menuId) async {
    state = state.copyWith(status: MenuDetailStatus.acting, actionError: null);

    try {
      final menu = await _menuService.publishMenu(menuId);
      state = MenuDetailState(
        status: MenuDetailStatus.loaded,
        menu: menu,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[MenuDetailNotifier] publish failed: $e');
      state = state.copyWith(
        status: MenuDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[MenuDetailNotifier] publish error: $e');
      state = state.copyWith(
        status: MenuDetailStatus.loaded,
        actionError: 'Impossible de publier le menu',
      );
      return false;
    }
  }

  /// Supprime un menu (DELETE /menus/:id).
  Future<bool> delete(int menuId) async {
    state = state.copyWith(status: MenuDetailStatus.acting, actionError: null);

    try {
      await _menuService.deleteMenu(menuId);
      state = const MenuDetailState(
        status: MenuDetailStatus.loaded,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[MenuDetailNotifier] delete failed: $e');
      state = state.copyWith(
        status: MenuDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[MenuDetailNotifier] delete error: $e');
      state = state.copyWith(
        status: MenuDetailStatus.loaded,
        actionError: 'Impossible de supprimer le menu',
      );
      return false;
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provider principal pour la liste des menus.
final menusListProvider =
    StateNotifierProvider<MenusListNotifier, MenusListState>((ref) {
  return MenusListNotifier();
});

/// Provider pour le detail d'un menu.
final menuDetailProvider =
    StateNotifierProvider<MenuDetailNotifier, MenuDetailState>((ref) {
  return MenuDetailNotifier();
});

// ---------------------------------------------------------------------------
// Providers pratiques (computed)
// ---------------------------------------------------------------------------

/// Menus actifs (publies).
final activeMenusProvider = Provider<List<Menu>>((ref) {
  return ref.watch(menusListProvider).activeMenus;
});

/// Menus inactifs (non publies).
final inactiveMenusProvider = Provider<List<Menu>>((ref) {
  return ref.watch(menusListProvider).inactiveMenus;
});

/// Nombre total de menus.
final menusCountProvider = Provider<int>((ref) {
  return ref.watch(menusListProvider).menus.length;
});

/// Menu par defaut.
final defaultMenuProvider = Provider<Menu?>((ref) {
  return ref.watch(menusListProvider).defaultMenu;
});
