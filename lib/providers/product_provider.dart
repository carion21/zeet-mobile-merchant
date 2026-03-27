import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/models/order_model.dart';
import 'package:merchant/models/product_model.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/product_service.dart';

// =============================================================================
// Products List State + Notifier
// =============================================================================

enum ProductsListStatus { initial, loading, loaded, error, loadingMore }

class ProductsListState {
  final ProductsListStatus status;
  final List<Product> products;
  final PaginationMeta? meta;
  final String? search;
  final int? categoryFilter;
  final String? errorMessage;

  const ProductsListState({
    this.status = ProductsListStatus.initial,
    this.products = const [],
    this.meta,
    this.search,
    this.categoryFilter,
    this.errorMessage,
  });

  ProductsListState copyWith({
    ProductsListStatus? status,
    List<Product>? products,
    PaginationMeta? meta,
    String? search,
    int? categoryFilter,
    String? errorMessage,
    bool clearSearch = false,
    bool clearCategoryFilter = false,
  }) {
    return ProductsListState(
      status: status ?? this.status,
      products: products ?? this.products,
      meta: meta ?? this.meta,
      search: clearSearch ? null : (search ?? this.search),
      categoryFilter:
          clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      errorMessage: errorMessage,
    );
  }

  /// Produits disponibles.
  List<Product> get availableProducts =>
      products.where((p) => p.available).toList();

  /// Produits indisponibles.
  List<Product> get unavailableProducts =>
      products.where((p) => !p.available).toList();
}

class ProductsListNotifier extends StateNotifier<ProductsListState> {
  final ProductService _productService;

  ProductsListNotifier({ProductService? productService})
      : _productService = productService ?? ProductService(),
        super(const ProductsListState());

  /// Charge la premiere page de produits.
  Future<void> load() async {
    state = state.copyWith(status: ProductsListStatus.loading);

    try {
      final result = await _productService.listProducts(
        page: 1,
        search: state.search,
        category: state.categoryFilter,
      );

      state = ProductsListState(
        status: ProductsListStatus.loaded,
        products: result.data,
        meta: result.meta,
        search: state.search,
        categoryFilter: state.categoryFilter,
      );
    } on ApiException catch (e) {
      debugPrint('[ProductsListNotifier] load failed: $e');
      state = state.copyWith(
        status: ProductsListStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[ProductsListNotifier] load error: $e');
      state = state.copyWith(
        status: ProductsListStatus.error,
        errorMessage: 'Impossible de charger les produits',
      );
    }
  }

  /// Charge la page suivante (pagination infinie).
  Future<void> loadMore() async {
    if (state.meta == null || !state.meta!.hasNextPage) return;
    if (state.status == ProductsListStatus.loadingMore) return;

    state = state.copyWith(status: ProductsListStatus.loadingMore);

    try {
      final result = await _productService.listProducts(
        page: state.meta!.page + 1,
        search: state.search,
        category: state.categoryFilter,
      );

      state = state.copyWith(
        status: ProductsListStatus.loaded,
        products: [...state.products, ...result.data],
        meta: result.meta,
      );
    } on ApiException catch (e) {
      debugPrint('[ProductsListNotifier] loadMore failed: $e');
      state = state.copyWith(
        status: ProductsListStatus.loaded,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[ProductsListNotifier] loadMore error: $e');
      state = state.copyWith(status: ProductsListStatus.loaded);
    }
  }

  /// Recherche par texte.
  Future<void> searchProducts(String? query) async {
    state = state.copyWith(
      search: query,
      clearSearch: query == null || query.isEmpty,
    );
    await load();
  }

  /// Filtre par categorie.
  Future<void> filterByCategory(int? categoryId) async {
    state = state.copyWith(
      categoryFilter: categoryId,
      clearCategoryFilter: categoryId == null,
    );
    await load();
  }

  /// Rafraichit la liste (pull-to-refresh).
  Future<void> refresh() async {
    await load();
  }

  /// Action en masse (activate, deactivate, delete).
  /// Met a jour la liste locale apres succes.
  Future<bool> bulkAction(List<int> ids, String action) async {
    try {
      await _productService.bulkAction(ids: ids, action: action);

      // Mise a jour locale
      if (action == 'delete') {
        state = state.copyWith(
          products:
              state.products.where((p) => !ids.contains(p.id)).toList(),
        );
      } else if (action == 'activate') {
        state = state.copyWith(
          products: [
            for (final p in state.products)
              if (ids.contains(p.id)) p.copyWith(available: true) else p
          ],
        );
      } else if (action == 'deactivate') {
        state = state.copyWith(
          products: [
            for (final p in state.products)
              if (ids.contains(p.id)) p.copyWith(available: false) else p
          ],
        );
      }

      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductsListNotifier] bulkAction failed: $e');
      return false;
    } catch (e) {
      debugPrint('[ProductsListNotifier] bulkAction error: $e');
      return false;
    }
  }

  /// Met a jour un produit dans la liste locale (apres update depuis le detail).
  void updateProductInList(Product updatedProduct) {
    state = state.copyWith(
      products: [
        for (final p in state.products)
          if (p.id == updatedProduct.id) updatedProduct else p
      ],
    );
  }

  /// Retire un produit de la liste locale (apres suppression).
  void removeProductFromList(int productId) {
    state = state.copyWith(
      products: state.products.where((p) => p.id != productId).toList(),
    );
  }

  /// Ajoute un produit en debut de liste (apres creation).
  void addProductToList(Product product) {
    state = state.copyWith(
      products: [product, ...state.products],
    );
  }
}

// =============================================================================
// Product Detail State + Notifier
// =============================================================================

enum ProductDetailStatus { initial, loading, loaded, error, acting }

class ProductDetailState {
  final ProductDetailStatus status;
  final Product? product;
  final String? errorMessage;
  final String? actionError;

  const ProductDetailState({
    this.status = ProductDetailStatus.initial,
    this.product,
    this.errorMessage,
    this.actionError,
  });

  ProductDetailState copyWith({
    ProductDetailStatus? status,
    Product? product,
    String? errorMessage,
    String? actionError,
  }) {
    return ProductDetailState(
      status: status ?? this.status,
      product: product ?? this.product,
      errorMessage: errorMessage,
      actionError: actionError,
    );
  }
}

class ProductDetailNotifier extends StateNotifier<ProductDetailState> {
  final ProductService _productService;

  ProductDetailNotifier({ProductService? productService})
      : _productService = productService ?? ProductService(),
        super(const ProductDetailState());

  // ---------------------------------------------------------------------------
  // Product CRUD
  // ---------------------------------------------------------------------------

  /// Charge le detail d'un produit.
  Future<void> load(int productId) async {
    state = state.copyWith(status: ProductDetailStatus.loading);

    try {
      final product = await _productService.getProduct(productId);
      state = ProductDetailState(
        status: ProductDetailStatus.loaded,
        product: product,
      );
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] load failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[ProductDetailNotifier] load error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.error,
        errorMessage: 'Impossible de charger le produit',
      );
    }
  }

  /// Met a jour un produit (PATCH).
  Future<bool> update(
    int productId, {
    String? name,
    int? price,
    int? productCategory,
    String? description,
  }) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      final product = await _productService.updateProduct(
        productId,
        name: name,
        price: price,
        productCategory: productCategory,
        description: description,
      );
      state = ProductDetailState(
        status: ProductDetailStatus.loaded,
        product: product,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] update failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] update error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de modifier le produit',
      );
      return false;
    }
  }

  /// Toggle la disponibilite d'un produit.
  Future<bool> toggleAvailability(int productId, {required bool available}) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      final product = await _productService.toggleAvailability(
        productId,
        available: available,
      );
      state = ProductDetailState(
        status: ProductDetailStatus.loaded,
        product: product,
      );
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] toggleAvailability failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] toggleAvailability error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de modifier la disponibilite',
      );
      return false;
    }
  }

  /// Supprime un produit (DELETE).
  Future<bool> delete(int productId) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      await _productService.deleteProduct(productId);
      state = const ProductDetailState(status: ProductDetailStatus.loaded);
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] delete failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] delete error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de supprimer le produit',
      );
      return false;
    }
  }

  /// Duplique un produit.
  /// Retourne le nouveau [Product] cree, ou null en cas d'erreur.
  Future<Product?> duplicate(int productId) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      final newProduct = await _productService.duplicateProduct(productId);
      state = state.copyWith(status: ProductDetailStatus.loaded);
      return newProduct;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] duplicate failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return null;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] duplicate error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de dupliquer le produit',
      );
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Pictures
  // ---------------------------------------------------------------------------

  /// Upload une image pour le produit courant.
  Future<bool> uploadPicture(int productId, File imageFile) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      final picture =
          await _productService.uploadPicture(productId, imageFile);

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            pictures: [...state.product!.pictures, picture],
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] uploadPicture failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] uploadPicture error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible d\'uploader l\'image',
      );
      return false;
    }
  }

  /// Rafraichit la liste des images du produit courant.
  Future<void> refreshPictures(int productId) async {
    try {
      final result = await _productService.listPictures(productId);

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            pictures: result.pictures,
            defaultImage: result.defaultImage,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ProductDetailNotifier] refreshPictures error: $e');
    }
  }

  /// Supprime une image du produit courant.
  Future<bool> deletePicture(int productId, int pictureId) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      await _productService.deletePicture(productId, pictureId);

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            pictures: state.product!.pictures
                .where((p) => p.id != pictureId)
                .toList(),
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] deletePicture failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] deletePicture error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de supprimer l\'image',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Variants
  // ---------------------------------------------------------------------------

  /// Rafraichit la liste des variantes du produit courant.
  Future<void> refreshVariants(int productId) async {
    try {
      final variants = await _productService.listVariants(productId);

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(variants: variants),
        );
      }
    } catch (e) {
      debugPrint('[ProductDetailNotifier] refreshVariants error: $e');
    }
  }

  /// Cree une variante et met a jour le produit courant.
  Future<ProductVariant?> createVariant(
    int productId, {
    required String name,
    required int priceDelta,
    int orderIndex = 0,
    String? description,
  }) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      final variant = await _productService.createVariant(
        productId,
        name: name,
        priceDelta: priceDelta,
        orderIndex: orderIndex,
        description: description,
      );

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            variants: [...state.product!.variants, variant],
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return variant;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] createVariant failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return null;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] createVariant error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de creer la variante',
      );
      return null;
    }
  }

  /// Met a jour une variante et met a jour le produit courant.
  Future<bool> updateVariant(
    int productId,
    int variantId, {
    String? name,
    int? priceDelta,
    int? orderIndex,
    String? description,
  }) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      final variant = await _productService.updateVariant(
        productId,
        variantId,
        name: name,
        priceDelta: priceDelta,
        orderIndex: orderIndex,
        description: description,
      );

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            variants: [
              for (final v in state.product!.variants)
                if (v.id == variantId) variant else v
            ],
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] updateVariant failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] updateVariant error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de modifier la variante',
      );
      return false;
    }
  }

  /// Supprime une variante et met a jour le produit courant.
  Future<bool> deleteVariant(int productId, int variantId) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      await _productService.deleteVariant(productId, variantId);

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            variants: state.product!.variants
                .where((v) => v.id != variantId)
                .toList(),
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] deleteVariant failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] deleteVariant error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de supprimer la variante',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Option Groups
  // ---------------------------------------------------------------------------

  /// Rafraichit la liste des groupes d'options du produit courant.
  Future<void> refreshOptionGroups(int productId) async {
    try {
      final groups = await _productService.listOptionGroups(productId);

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(optionGroups: groups),
        );
      }
    } catch (e) {
      debugPrint('[ProductDetailNotifier] refreshOptionGroups error: $e');
    }
  }

  /// Cree un groupe d'options et met a jour le produit courant.
  Future<ProductOptionGroup?> createOptionGroup(
    int productId, {
    required String name,
    bool required = false,
    bool allowDuplicate = false,
    int minSelect = 0,
    int maxSelect = 0,
    int orderIndex = 0,
  }) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      final group = await _productService.createOptionGroup(
        productId,
        name: name,
        required: required,
        allowDuplicate: allowDuplicate,
        minSelect: minSelect,
        maxSelect: maxSelect,
        orderIndex: orderIndex,
      );

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            optionGroups: [...state.product!.optionGroups, group],
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return group;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] createOptionGroup failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return null;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] createOptionGroup error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de creer le groupe d\'options',
      );
      return null;
    }
  }

  /// Met a jour un groupe d'options et met a jour le produit courant.
  Future<bool> updateOptionGroup(
    int productId,
    int groupId, {
    String? name,
    bool? required,
    bool? allowDuplicate,
    int? minSelect,
    int? maxSelect,
    int? orderIndex,
  }) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      final group = await _productService.updateOptionGroup(
        productId,
        groupId,
        name: name,
        required: required,
        allowDuplicate: allowDuplicate,
        minSelect: minSelect,
        maxSelect: maxSelect,
        orderIndex: orderIndex,
      );

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            optionGroups: [
              for (final g in state.product!.optionGroups)
                if (g.id == groupId) group else g
            ],
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] updateOptionGroup failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] updateOptionGroup error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de modifier le groupe d\'options',
      );
      return false;
    }
  }

  /// Supprime un groupe d'options et met a jour le produit courant.
  Future<bool> deleteOptionGroup(int productId, int groupId) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      await _productService.deleteOptionGroup(productId, groupId);

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            optionGroups: state.product!.optionGroups
                .where((g) => g.id != groupId)
                .toList(),
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] deleteOptionGroup failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] deleteOptionGroup error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de supprimer le groupe d\'options',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Option Items
  // ---------------------------------------------------------------------------

  /// Rafraichit la liste des items d'un groupe d'options.
  Future<void> refreshOptionItems(int productId, int groupId) async {
    try {
      final items =
          await _productService.listOptionItems(productId, groupId);

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            optionGroups: [
              for (final g in state.product!.optionGroups)
                if (g.id == groupId) g.copyWith(items: items) else g
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('[ProductDetailNotifier] refreshOptionItems error: $e');
    }
  }

  /// Cree un item dans un groupe d'options et met a jour le produit courant.
  Future<ProductOptionItem?> createOptionItem(
    int productId,
    int groupId, {
    required String name,
    required int priceDelta,
    int orderIndex = 0,
    String? description,
  }) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      final item = await _productService.createOptionItem(
        productId,
        groupId,
        name: name,
        priceDelta: priceDelta,
        orderIndex: orderIndex,
        description: description,
      );

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            optionGroups: [
              for (final g in state.product!.optionGroups)
                if (g.id == groupId)
                  g.copyWith(items: [...g.items, item])
                else
                  g
            ],
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return item;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] createOptionItem failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return null;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] createOptionItem error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de creer l\'item d\'option',
      );
      return null;
    }
  }

  /// Met a jour un item d'option et met a jour le produit courant.
  Future<bool> updateOptionItem(
    int productId,
    int groupId,
    int itemId, {
    String? name,
    int? priceDelta,
    int? orderIndex,
    String? description,
  }) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      final item = await _productService.updateOptionItem(
        productId,
        groupId,
        itemId,
        name: name,
        priceDelta: priceDelta,
        orderIndex: orderIndex,
        description: description,
      );

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            optionGroups: [
              for (final g in state.product!.optionGroups)
                if (g.id == groupId)
                  g.copyWith(
                    items: [
                      for (final i in g.items)
                        if (i.id == itemId) item else i
                    ],
                  )
                else
                  g
            ],
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] updateOptionItem failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] updateOptionItem error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de modifier l\'item d\'option',
      );
      return false;
    }
  }

  /// Supprime un item d'un groupe d'options et met a jour le produit courant.
  Future<bool> deleteOptionItem(
    int productId,
    int groupId,
    int itemId,
  ) async {
    state =
        state.copyWith(status: ProductDetailStatus.acting, actionError: null);

    try {
      await _productService.deleteOptionItem(productId, groupId, itemId);

      if (state.product != null) {
        state = ProductDetailState(
          status: ProductDetailStatus.loaded,
          product: state.product!.copyWith(
            optionGroups: [
              for (final g in state.product!.optionGroups)
                if (g.id == groupId)
                  g.copyWith(
                    items:
                        g.items.where((i) => i.id != itemId).toList(),
                  )
                else
                  g
            ],
          ),
        );
      } else {
        state = state.copyWith(status: ProductDetailStatus.loaded);
      }
      return true;
    } on ApiException catch (e) {
      debugPrint('[ProductDetailNotifier] deleteOptionItem failed: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[ProductDetailNotifier] deleteOptionItem error: $e');
      state = state.copyWith(
        status: ProductDetailStatus.loaded,
        actionError: 'Impossible de supprimer l\'item d\'option',
      );
      return false;
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provider principal pour la liste des produits.
final productsListProvider =
    StateNotifierProvider<ProductsListNotifier, ProductsListState>((ref) {
  return ProductsListNotifier();
});

/// Provider pour le detail d'un produit.
final productDetailProvider =
    StateNotifierProvider<ProductDetailNotifier, ProductDetailState>((ref) {
  return ProductDetailNotifier();
});

// ---------------------------------------------------------------------------
// Providers pratiques (computed)
// ---------------------------------------------------------------------------

/// Produits disponibles.
final availableProductsProvider = Provider<List<Product>>((ref) {
  return ref.watch(productsListProvider).availableProducts;
});

/// Produits indisponibles.
final unavailableProductsProvider = Provider<List<Product>>((ref) {
  return ref.watch(productsListProvider).unavailableProducts;
});

/// Nombre total de produits charges.
final productsCountProvider = Provider<int>((ref) {
  return ref.watch(productsListProvider).products.length;
});

/// Produit courant (depuis le detail).
final currentProductProvider = Provider<Product?>((ref) {
  return ref.watch(productDetailProvider).product;
});

/// Variantes du produit courant.
final currentProductVariantsProvider = Provider<List<ProductVariant>>((ref) {
  return ref.watch(productDetailProvider).product?.variants ?? [];
});

/// Groupes d'options du produit courant.
final currentProductOptionGroupsProvider =
    Provider<List<ProductOptionGroup>>((ref) {
  return ref.watch(productDetailProvider).product?.optionGroups ?? [];
});

/// Images du produit courant.
final currentProductPicturesProvider =
    Provider<List<ProductPicture>>((ref) {
  return ref.watch(productDetailProvider).product?.pictures ?? [];
});
