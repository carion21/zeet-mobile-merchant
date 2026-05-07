// lib/screens/products/index.dart
//
// Ecran "Produits" partner — CRUD complet via :
// - GET    /v1/partner/products                    (liste paginee + filtres)
// - POST   /v1/partner/products                    (creation)
// - PATCH  /v1/partner/products/:id                (update partiel)
// - PATCH  /v1/partner/products/:id/availability   (toggle dispo)
// - POST   /v1/partner/products/:id/duplicate      (duplication)
// - DELETE /v1/partner/products/:id                (suppression)
// - POST   /v1/partner/products/:id/pictures       (upload image)
// - PATCH  /v1/partner/products/bulk               (actions en masse)
//
// Cet ecran affiche la liste, avec :
// - un filtre par categorie via chips horizontaux
// - une recherche textuelle
// - une FAB pour creer un produit (requiert au moins une categorie)
// - des actions inline (toggle dispo + menu "plus")
// - navigation vers le detail (variants + options groups).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/app_popup.dart';
import 'package:merchant/core/widgets/freshness/zeet_freshness_chip.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/category_model.dart';
import 'package:merchant/models/product_model.dart';
import 'package:merchant/providers/category_provider.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/providers/product_provider.dart';
import 'package:merchant/providers/stats_provider.dart';
import 'package:merchant/screens/products/detail.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/services/product_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ZeetFreshnessChipLocalState> _freshKey = GlobalKey();
  bool _isSearching = false;

  /// Selection multi-produits : declenche par long-press sur un tile.
  /// Skill `zeet-pos-ergonomics` §gesture-grammar : long-press ouvre le
  /// mode selection, tap sur tile toggle l'inclusion. AppBar morph vers
  /// barre d'actions bulk (activer / desactiver / supprimer / fermer).
  final Set<int> _selectedIds = <int>{};
  bool get _selectionMode => _selectedIds.isNotEmpty;

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
    ZeetHaptics.tap();
  }

  void _exitSelection() {
    setState(_selectedIds.clear);
  }

  Future<void> _bulkRun(String action, String label) async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    final ok = await ref
        .read(productsListProvider.notifier)
        .bulkAction(ids, action);
    if (!mounted) return;
    if (ok) {
      ZeetHaptics.success();
      AppToast.showSuccess(
        context: context,
        message: '${ids.length} produit${ids.length > 1 ? 's' : ''} $label.',
      );
      _exitSelection();
    } else {
      ZeetHaptics.error();
      AppToast.showError(
        context: context,
        message: 'Action en masse impossible. Reessayez.',
      );
    }
  }

  Future<void> _confirmBulkDelete() async {
    final ids = _selectedIds.toList();
    final confirm = await AppPopup.showConfirmation(
      context: context,
      title: 'Supprimer ${ids.length} produit${ids.length > 1 ? 's' : ''} ?',
      message:
          "L'action est definitive. Les variantes et options associees seront aussi supprimees.",
      confirmLabel: 'Supprimer',
      cancelLabel: 'Annuler',
      isDestructive: true,
    );
    if (!confirm || !mounted) return;
    await _bulkRun('delete', 'supprime${ids.length > 1 ? 's' : ''}');
  }

  /// Refresh unifié : recharge + bumpe la chip de fraîcheur.
  Future<void> _refreshAll() async {
    await ref.read(productsListProvider.notifier).refresh();
    _freshKey.currentState?.bump();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productsListProvider.notifier).load();
      // Charge les categories pour les filtres + bottom sheet de creation.
      ref.invalidate(categoriesSelectProvider);
      // Charge le ranking produits (top 5) pour afficher les badges
      // "🔥 Top X" sur les meilleurs vendeurs (Skill `zeet-neuro-ux`).
      ref
          .read(productStatsProvider.notifier)
          .loadRanking(period: 'month', limit: 5);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(productsListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final state = ref.watch(productsListProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: _selectionMode
          ? ZeetAppBar(
              title: Text('${_selectedIds.length} sélectionné'
                  '${_selectedIds.length > 1 ? 's' : ''}'),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Fermer',
                onPressed: () {
                  ZeetHaptics.tap();
                  _exitSelection();
                },
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Activer',
                  icon: const Icon(Icons.visibility_rounded),
                  onPressed: () => _bulkRun('activate',
                      _selectedIds.length > 1 ? 'actives' : 'active'),
                ),
                IconButton(
                  tooltip: 'Désactiver',
                  icon: const Icon(Icons.visibility_off_outlined),
                  onPressed: () => _bulkRun('deactivate',
                      _selectedIds.length > 1 ? 'desactives' : 'desactive'),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: ZeetColors.danger),
                  onPressed: _confirmBulkDelete,
                ),
              ],
            )
          : ZeetAppBar(
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un produit…',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (query) {
                        ref
                            .read(productsListProvider.notifier)
                            .searchProducts(query);
                      },
                    )
                  : const Text('Produits'),
              actions: <Widget>[
                Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Center(
                    child: ZeetFreshnessChipLocal(
                      key: _freshKey,
                      onRefresh: _refreshAll,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_isSearching
                      ? Icons.close_rounded
                      : Icons.search_rounded),
                  tooltip: _isSearching
                      ? 'Fermer la recherche'
                      : 'Rechercher',
                  onPressed: () {
                    ZeetHaptics.tap();
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        ref
                            .read(productsListProvider.notifier)
                            .searchProducts(null);
                      }
                    });
                  },
                ),
              ],
            ),
      body: Column(
        children: <Widget>[
          _CategoryFilterBar(
            currentFilter: state.categoryFilter,
            onSelect: (int? id) => ref
                .read(productsListProvider.notifier)
                .filterByCategory(id),
          ),
          Expanded(child: _buildBody(state)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProductSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: IconManager.getIcon('add', color: Colors.white),
        label: const Text('Nouveau produit'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body + ELOE
  // ---------------------------------------------------------------------------

  Widget _buildBody(ProductsListState state) {
    final bool isOnline = ref.watch(connectivityStatusProvider).maybeWhen(
          data: (v) => v,
          orElse: () => true,
        );

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ZeetScreenScaffold(
        state: _resolveState(state, isOnline),
        onRetry: () async {
          await ref.read(productsListProvider.notifier).load();
          _freshKey.currentState?.bump();
        },
        loading: const ZeetSkeletonList(itemCount: 6, itemHeight: 104),
        emptyTitle: state.search != null || state.categoryFilter != null
            ? 'Aucun produit ne correspond'
            : 'Aucun produit',
        emptySubtitle: state.search != null || state.categoryFilter != null
            ? 'Ajustez les filtres ou créez un nouveau produit.'
            : 'Ajoutez vos plats pour qu\'ils soient visibles par les clients.',
        emptyIcon: Icons.restaurant_menu_outlined,
        errorMessage: state.errorMessage,
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 96.h),
          itemCount: state.products.length +
              (state.status == ProductsListStatus.loadingMore ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (index == state.products.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: const ZeetSkeleton(height: 104),
              );
            }
            final product = state.products[index];
            final ranks = ref.watch(topProductRanksProvider);
            final selected = _selectedIds.contains(product.id);
            return _ProductTile(
              product: product,
              rank: ranks[product.id],
              isSelected: selected,
              selectionMode: _selectionMode,
              onTap: _selectionMode
                  ? () => _toggleSelection(product.id)
                  : () => _openProductDetail(product),
              onLongPress: () => _toggleSelection(product.id),
              onToggleAvailability: () => _toggleAvailability(product),
              onEdit: () => _openProductDetail(product),
              onDuplicate: () => _duplicateProduct(product),
              onDelete: () => _deleteProduct(product),
            );
          },
        ),
      ),
    );
  }

  ZeetScreenState _resolveState(
    ProductsListState state,
    bool isOnline,
  ) {
    switch (state.status) {
      case ProductsListStatus.initial:
      case ProductsListStatus.loading:
        return ZeetScreenState.loading;
      case ProductsListStatus.error:
        if (!isOnline) return ZeetScreenState.offline;
        return ZeetScreenState.error;
      case ProductsListStatus.loaded:
      case ProductsListStatus.loadingMore:
        if (state.products.isEmpty) return ZeetScreenState.empty;
        return ZeetScreenState.content;
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _openProductDetail(Product product) async {
    await ZeetHaptics.success();
    await Routes.push<void>(ProductDetailScreen(productId: product.id));
    // Au retour, rafraichit la liste pour capter les eventuelles modifs.
    if (mounted) {
      await _refreshAll();
    }
  }

  Future<void> _showCreateProductSheet() async {
    await ZeetHaptics.success();
    final categoriesAsync = ref.read(categoriesSelectProvider);
    final List<CategorySelect> categories =
        categoriesAsync.asData?.value ?? const <CategorySelect>[];

    if (!mounted) return;
    if (categories.isEmpty) {
      AppToast.showWarning(
        context: context,
        message:
            'Cree d\'abord une categorie avant d\'ajouter un produit.',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => _ProductFormSheet(
        categories: categories,
        onSubmit: _createProduct,
      ),
    );
  }

  Future<void> _createProduct({
    required String name,
    required int price,
    required int categoryId,
    String? description,
  }) async {
    try {
      final product = await ProductService().createProduct(
        name: name,
        price: price,
        productCategory: categoryId,
        description: description,
      );
      if (!mounted) return;
      ref.read(productsListProvider.notifier).addProductToList(product);
      AppToast.showSuccess(
        context: context,
        message: 'Produit "${product.name}" cree',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context: context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible de creer le produit',
      );
    }
  }

  Future<void> _toggleAvailability(Product product) async {
    await ZeetHaptics.tap();
    final bool next = !product.available;
    try {
      final updated = await ProductService().toggleAvailability(
        product.id,
        available: next,
      );
      if (!mounted) return;
      ref
          .read(productsListProvider.notifier)
          .updateProductInList(updated);
      AppToast.showSuccess(
        context: context,
        message: next ? 'Produit disponible' : 'Produit indisponible',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context: context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible de modifier la disponibilite',
      );
    }
  }

  Future<void> _duplicateProduct(Product product) async {
    try {
      final copy = await ProductService().duplicateProduct(product.id);
      if (!mounted) return;
      ref.read(productsListProvider.notifier).addProductToList(copy);
      AppToast.showSuccess(
        context: context,
        message: 'Produit duplique',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context: context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible de dupliquer le produit',
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final bool confirmed = await AppPopup.showConfirmation(
      context: context,
      title: 'Supprimer le produit ?',
      message:
          '"${product.name}" sera definitivement supprime, y compris ses variantes et options.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ProductService().deleteProduct(product.id);
      if (!mounted) return;
      ref
          .read(productsListProvider.notifier)
          .removeProductFromList(product.id);
      AppToast.showSuccess(
        context: context,
        message: 'Produit supprime',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context: context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible de supprimer le produit',
      );
    }
  }
}

// =============================================================================
// Barre de filtres par categorie (chips horizontaux)
// =============================================================================

class _CategoryFilterBar extends ConsumerWidget {
  const _CategoryFilterBar({
    required this.currentFilter,
    required this.onSelect,
  });

  final int? currentFilter;
  final void Function(int? id) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCategories = ref.watch(categoriesSelectProvider);
    final List<CategorySelect> categories =
        asyncCategories.asData?.value ?? const <CategorySelect>[];

    if (categories.isEmpty) {
      return const SizedBox(height: 8);
    }

    return SizedBox(
      height: 48.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        children: <Widget>[
          _buildChip(
            context,
            label: 'Tous',
            selected: currentFilter == null,
            onTap: () => onSelect(null),
          ),
          ...categories.map((CategorySelect c) => _buildChip(
                context,
                label: c.label,
                selected: currentFilter == c.id,
                onTap: () => onSelect(c.id),
              )),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(right: 8.w, top: 6.h, bottom: 6.h),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          color: selected ? Colors.white : scheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(
          color: selected ? AppColors.primary : scheme.outlineVariant,
        ),
      ),
    );
  }
}

// =============================================================================
// Tile d'un produit
// =============================================================================

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onToggleAvailability,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    this.rank,
    this.onLongPress,
    this.isSelected = false,
    this.selectionMode = false,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onToggleAvailability;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  /// Position dans le ranking produits (1 = meilleur). null si hors top 5.
  /// Skill `zeet-neuro-ux` social proof : "🔥 Top X" affiche un badge
  /// orange en overlay sur la vignette.
  final int? rank;

  /// Mode selection actif : la tile affiche une checkbox + style focus
  /// quand `isSelected`. Tap → toggle (pas d'edition). Long-press toujours
  /// disponible pour entrer/sortir du mode.
  final bool isSelected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool available = product.available;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : scheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isSelected ? AppColors.primary : scheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (selectionMode) ...<Widget>[
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected
                      ? AppColors.primary
                      : scheme.onSurfaceVariant,
                  size: 24.sp,
                ),
                SizedBox(width: 10.w),
              ],
              // Vignette produit + badge ranking si top 5.
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 64.w,
                    height: 64.h,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: product.mainImage != null &&
                            product.mainImage!.isNotEmpty
                        ? Hero(
                            tag: 'product-${product.id}',
                            child: ZeetImage(
                              url: product.mainImage,
                              width: 64.w,
                              height: 64.h,
                              fit: BoxFit.cover,
                              errorWidget: Icon(
                                Icons.broken_image_outlined,
                                color: scheme.onSurfaceVariant,
                                size: 24.r,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.restaurant_outlined,
                              color: scheme.onSurfaceVariant,
                              size: 24.r,
                            ),
                          ),
                  ),
                  if (rank != null && rank! >= 1 && rank! <= 5)
                    Positioned(
                      top: -6,
                      left: -6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '🔥 ${rank == 1 ? "Top vente" : "Top $rank"}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 12.w),
              // Nom + prix + categorie + indicateurs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ZeetMoney(
                        amount: product.price.toDouble(),
                        currency: ZeetCurrency.fcfa,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: <Widget>[
                        if (product.categoryLabel != null)
                          Flexible(
                            child: Text(
                              product.categoryLabel!,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (product.variantCount > 0) ...<Widget>[
                          SizedBox(width: 8.w),
                          _Pill(
                            label:
                                '${product.variantCount} var.',
                            color: scheme.tertiaryContainer,
                            textColor: scheme.onTertiaryContainer,
                          ),
                        ],
                        if (product.optionGroupCount > 0) ...<Widget>[
                          SizedBox(width: 6.w),
                          _Pill(
                            label:
                                '${product.optionGroupCount} opt.',
                            color: scheme.secondaryContainer,
                            textColor: scheme.onSecondaryContainer,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Toggle dispo + menu
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Switch.adaptive(
                    value: available,
                    activeThumbColor: AppColors.primary,
                    onChanged: (_) => onToggleAvailability(),
                  ),
                  SizedBox(height: 4.h),
                  PopupMenuButton<_ProductAction>(
                    tooltip: 'Actions',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: scheme.onSurface,
                    ),
                    onSelected: (_ProductAction action) {
                      switch (action) {
                        case _ProductAction.edit:
                          onEdit();
                        case _ProductAction.duplicate:
                          onDuplicate();
                        case _ProductAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (_) =>
                        <PopupMenuEntry<_ProductAction>>[
                      const PopupMenuItem<_ProductAction>(
                        value: _ProductAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Modifier'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem<_ProductAction>(
                        value: _ProductAction.duplicate,
                        child: ListTile(
                          leading: Icon(Icons.copy_outlined),
                          title: Text('Dupliquer'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<_ProductAction>(
                        value: _ProductAction.delete,
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          title: Text(
                            'Supprimer',
                            style: TextStyle(color: AppColors.error),
                          ),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ZeetRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

enum _ProductAction { edit, duplicate, delete }

// =============================================================================
// Bottom sheet : formulaire creation
// =============================================================================

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({
    required this.categories,
    required this.onSubmit,
  });

  final List<CategorySelect> categories;
  final Future<void> Function({
    required String name,
    required int price,
    required int categoryId,
    String? description,
  }) onSubmit;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;
  int? _categoryId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _categoryId = widget.categories.isNotEmpty
        ? widget.categories.first.id
        : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 8.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Nouveau produit',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                hintText: 'Ex. Poulet braise, Tiep djeun…',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nom requis' : null,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Prix (FCFA) *',
                hintText: 'Ex. 3000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Prix requis';
                final int? parsed = int.tryParse(v.trim());
                if (parsed == null || parsed <= 0) return 'Prix invalide';
                return null;
              },
            ),
            SizedBox(height: 12.h),
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Categorie *',
                border: OutlineInputBorder(),
              ),
              items: widget.categories
                  .map((CategorySelect c) => DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(c.label),
                      ))
                  .toList(),
              onChanged: (int? v) => setState(() => _categoryId = v),
              validator: (v) => v == null ? 'Categorie requise' : null,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            SizedBox(height: 20.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: _submitting
                        ? SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Creer',
                            style:
                                TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        name: _nameCtrl.text.trim(),
        price: int.parse(_priceCtrl.text.trim()),
        categoryId: _categoryId!,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
