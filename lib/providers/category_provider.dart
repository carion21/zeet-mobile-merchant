import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/category_model.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/category_service.dart';

// =============================================================================
// Categories Select (dropdown)
// =============================================================================

/// Provider pour la liste simplifiee des categories (dropdown).
/// Retourne un Future via FutureProvider.
final categoriesSelectProvider =
    FutureProvider<List<CategorySelect>>((ref) async {
  final service = CategoryService();
  return service.selectCategories();
});

// =============================================================================
// Categories List State + Notifier
// =============================================================================

enum CategoriesListStatus { initial, loading, loaded, error, loadingMore }

class CategoriesListState {
  final CategoriesListStatus status;
  final List<ProductCategory> categories;
  final PaginationMeta? meta;
  final String? search;
  final String? errorMessage;

  const CategoriesListState({
    this.status = CategoriesListStatus.initial,
    this.categories = const [],
    this.meta,
    this.search,
    this.errorMessage,
  });

  CategoriesListState copyWith({
    CategoriesListStatus? status,
    List<ProductCategory>? categories,
    PaginationMeta? meta,
    String? search,
    String? errorMessage,
    bool clearSearch = false,
  }) {
    return CategoriesListState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      meta: meta ?? this.meta,
      search: clearSearch ? null : (search ?? this.search),
      errorMessage: errorMessage,
    );
  }

  /// Categories actives.
  List<ProductCategory> get activeCategories =>
      categories.where((c) => c.isActive).toList();

  /// Categories inactives.
  List<ProductCategory> get inactiveCategories =>
      categories.where((c) => !c.isActive).toList();
}

class CategoriesListNotifier extends StateNotifier<CategoriesListState> {
  final CategoryService _categoryService;

  CategoriesListNotifier({CategoryService? categoryService})
      : _categoryService = categoryService ?? CategoryService(),
        super(const CategoriesListState());

  /// Charge la premiere page de categories.
  Future<void> load() async {
    state = state.copyWith(status: CategoriesListStatus.loading);

    try {
      final result = await _categoryService.listCategories(
        page: 1,
        search: state.search,
      );

      state = CategoriesListState(
        status: CategoriesListStatus.loaded,
        categories: result.data,
        meta: result.meta,
        search: state.search,
      );
    } on ApiException catch (e) {
      debugPrint('[CategoriesListNotifier] load failed: $e');
      state = state.copyWith(
        status: CategoriesListStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[CategoriesListNotifier] load error: $e');
      state = state.copyWith(
        status: CategoriesListStatus.error,
        errorMessage: 'Impossible de charger les categories',
      );
    }
  }

  /// Charge la page suivante (pagination infinie).
  Future<void> loadMore() async {
    if (state.meta == null || !state.meta!.hasNextPage) return;
    if (state.status == CategoriesListStatus.loadingMore) return;

    state = state.copyWith(status: CategoriesListStatus.loadingMore);

    try {
      final result = await _categoryService.listCategories(
        page: state.meta!.page + 1,
        search: state.search,
      );

      state = state.copyWith(
        status: CategoriesListStatus.loaded,
        categories: [...state.categories, ...result.data],
        meta: result.meta,
      );
    } on ApiException catch (e) {
      debugPrint('[CategoriesListNotifier] loadMore failed: $e');
      state = state.copyWith(
        status: CategoriesListStatus.loaded,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[CategoriesListNotifier] loadMore error: $e');
      state = state.copyWith(status: CategoriesListStatus.loaded);
    }
  }

  /// Recherche par texte.
  Future<void> searchCategories(String? query) async {
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

  /// Met a jour une categorie dans la liste locale (apres update).
  void updateCategoryInList(ProductCategory updatedCategory) {
    state = state.copyWith(
      categories: [
        for (final c in state.categories)
          if (c.id == updatedCategory.id) updatedCategory else c
      ],
    );
  }

  /// Retire une categorie de la liste locale (apres suppression).
  void removeCategoryFromList(int categoryId) {
    state = state.copyWith(
      categories:
          state.categories.where((c) => c.id != categoryId).toList(),
    );
  }

  /// Retire plusieurs categories de la liste locale (apres bulk delete).
  void removeCategoriesFromList(List<int> categoryIds) {
    state = state.copyWith(
      categories: state.categories
          .where((c) => !categoryIds.contains(c.id))
          .toList(),
    );
  }

  /// Ajoute une categorie en debut de liste (apres creation).
  void addCategoryToList(ProductCategory category) {
    state = state.copyWith(
      categories: [category, ...state.categories],
    );
  }
}

// =============================================================================
// Category Detail State + Notifier
// =============================================================================

enum CategoryDetailStatus { initial, loading, loaded, error, acting }

class CategoryDetailState {
  final CategoryDetailStatus status;
  final ProductCategory? category;
  final String? errorMessage;
  final String? actionError;

  const CategoryDetailState({
    this.status = CategoryDetailStatus.initial,
    this.category,
    this.errorMessage,
    this.actionError,
  });

  CategoryDetailState copyWith({
    CategoryDetailStatus? status,
    ProductCategory? category,
    String? errorMessage,
    String? actionError,
  }) {
    return CategoryDetailState(
      status: status ?? this.status,
      category: category ?? this.category,
      errorMessage: errorMessage,
      actionError: actionError,
    );
  }
}

class CategoryDetailNotifier extends StateNotifier<CategoryDetailState> {
  final CategoryService _categoryService;

  CategoryDetailNotifier({CategoryService? categoryService})
      : _categoryService = categoryService ?? CategoryService(),
        super(const CategoryDetailState());

  /// Charge le detail d'une categorie.
  Future<void> load(int categoryId) async {
    state = state.copyWith(status: CategoryDetailStatus.loading);

    try {
      final category = await _categoryService.getCategory(categoryId);
      state = CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        category: category,
      );
    } on ApiException catch (e) {
      debugPrint('[CategoryDetailNotifier] load failed: $e');
      state = state.copyWith(
        status: CategoryDetailStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[CategoryDetailNotifier] load error: $e');
      state = state.copyWith(
        status: CategoryDetailStatus.error,
        errorMessage: 'Impossible de charger la categorie',
      );
    }
  }

  /// Met a jour une categorie (PATCH /product-categories/:id).
  Future<bool> update(
    int categoryId, {
    String? label,
    String? description,
    bool? status,
  }) async {
    state =
        state.copyWith(status: CategoryDetailStatus.acting, actionError: null);

    try {
      final category = await _categoryService.updateCategory(
        categoryId,
        label: label,
        description: description,
        status: status,
      );
      state = CategoryDetailState(
        status: CategoryDetailStatus.loaded,
        category: category,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[CategoryDetailNotifier] update failed: $e');
      state = state.copyWith(
        status: CategoryDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[CategoryDetailNotifier] update error: $e');
      state = state.copyWith(
        status: CategoryDetailStatus.loaded,
        actionError: 'Impossible de modifier la categorie',
      );
      return false;
    }
  }

  /// Supprime une categorie (DELETE /product-categories/:id).
  Future<bool> delete(int categoryId) async {
    state =
        state.copyWith(status: CategoryDetailStatus.acting, actionError: null);

    try {
      await _categoryService.deleteCategory(categoryId);
      state = const CategoryDetailState(
        status: CategoryDetailStatus.loaded,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[CategoryDetailNotifier] delete failed: $e');
      state = state.copyWith(
        status: CategoryDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[CategoryDetailNotifier] delete error: $e');
      state = state.copyWith(
        status: CategoryDetailStatus.loaded,
        actionError: 'Impossible de supprimer la categorie',
      );
      return false;
    }
  }

  /// Upload l'image d'une categorie (POST /product-categories/:id/picture).
  Future<bool> uploadPicture(int categoryId, File imageFile) async {
    state =
        state.copyWith(status: CategoryDetailStatus.acting, actionError: null);

    try {
      final pictureUrl =
          await _categoryService.uploadPicture(categoryId, imageFile);

      // Met a jour la categorie locale avec la nouvelle image
      if (state.category != null) {
        state = CategoryDetailState(
          status: CategoryDetailStatus.loaded,
          category: state.category!.copyWith(picture: pictureUrl),
        );
      } else {
        state = state.copyWith(status: CategoryDetailStatus.loaded);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[CategoryDetailNotifier] uploadPicture failed: $e');
      state = state.copyWith(
        status: CategoryDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[CategoryDetailNotifier] uploadPicture error: $e');
      state = state.copyWith(
        status: CategoryDetailStatus.loaded,
        actionError: 'Impossible d\'uploader l\'image',
      );
      return false;
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provider principal pour la liste des categories.
final categoriesListProvider =
    StateNotifierProvider<CategoriesListNotifier, CategoriesListState>((ref) {
  return CategoriesListNotifier();
});

/// Provider pour le detail d'une categorie.
final categoryDetailProvider =
    StateNotifierProvider<CategoryDetailNotifier, CategoryDetailState>((ref) {
  return CategoryDetailNotifier();
});

// ---------------------------------------------------------------------------
// Providers pratiques (computed)
// ---------------------------------------------------------------------------

/// Categories actives.
final activeCategoriesProvider = Provider<List<ProductCategory>>((ref) {
  return ref.watch(categoriesListProvider).activeCategories;
});

/// Categories inactives.
final inactiveCategoriesProvider = Provider<List<ProductCategory>>((ref) {
  return ref.watch(categoriesListProvider).inactiveCategories;
});

/// Nombre total de categories.
final categoriesCountProvider = Provider<int>((ref) {
  return ref.watch(categoriesListProvider).categories.length;
});
