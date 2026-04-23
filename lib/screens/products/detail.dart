// lib/screens/products/detail.dart
//
// Detail produit partner avec CRUD complet des variantes, groupes d'options
// et items d'options. Endpoints couverts :
// - GET    /v1/partner/products/:id
// - PATCH  /v1/partner/products/:id
// - PATCH  /v1/partner/products/:id/availability
// - POST   /v1/partner/products/:id/pictures
// - GET/POST/PATCH/DELETE /v1/partner/products/:id/variants[/:vid]
// - GET/POST/PATCH/DELETE /v1/partner/products/:id/option-groups[/:gid]
// - GET/POST/PATCH/DELETE /v1/partner/products/:id/option-groups/:gid/items[/:iid]

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:merchant/core/widgets/app_popup.dart';
import 'package:merchant/core/widgets/freshness/zeet_freshness_chip.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/category_model.dart';
import 'package:merchant/models/product_model.dart';
import 'package:merchant/providers/category_provider.dart';
import 'package:merchant/providers/product_provider.dart';
import 'package:merchant/screens/products/widgets/product_detail_header.dart';
import 'package:merchant/screens/products/widgets/product_detail_options.dart';
import 'package:merchant/screens/products/widgets/product_detail_variants.dart';
import 'package:merchant/screens/products/widgets/product_edit_sheet.dart';
import 'package:merchant/screens/products/widgets/product_option_group_form_sheet.dart';
import 'package:merchant/screens/products/widgets/product_option_item_form_sheet.dart';
import 'package:merchant/screens/products/widgets/product_variant_form_sheet.dart';
import 'package:zeet_ui/zeet_ui.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final int productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final GlobalKey<ZeetFreshnessChipLocalState> _freshKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productDetailProvider.notifier).load(widget.productId);
      ref.invalidate(categoriesSelectProvider);
    });
  }

  /// Refresh unifié : recharge + bumpe la chip de fraîcheur.
  Future<void> _refreshAll() async {
    await ref.read(productDetailProvider.notifier).load(widget.productId);
    _freshKey.currentState?.bump();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final state = ref.watch(productDetailProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZeetAppBar(
        title: Text(state.product?.name ?? 'Produit'),
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
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(ProductDetailState state) {
    switch (state.status) {
      case ProductDetailStatus.initial:
      case ProductDetailStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ProductDetailStatus.error:
        return ZeetEmptyState(
          title: 'Erreur',
          description: state.errorMessage ?? 'Produit introuvable',
          icon: Icons.error_outline,
        );
      case ProductDetailStatus.loaded:
      case ProductDetailStatus.acting:
        final Product? product = state.product;
        if (product == null) {
          return const ZeetEmptyState(
            title: 'Produit introuvable',
            icon: Icons.error_outline,
          );
        }
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
            children: <Widget>[
              ProductDetailHeader(
                product: product,
                onEdit: () => _showEditSheet(product),
                onToggleAvailability: () =>
                    _toggleAvailability(product),
                onUploadPicture: () => _uploadPicture(product),
              ),
              SizedBox(height: 20.h),
              ProductDetailVariantsSection(
                productId: product.id,
                variants: product.variants,
                onAdd: () => _showVariantSheet(product.id),
                onEdit: (v) =>
                    _showVariantSheet(product.id, initial: v),
                onDelete: (v) => _deleteVariant(product.id, v),
              ),
              SizedBox(height: 20.h),
              ProductDetailOptionGroupsSection(
                productId: product.id,
                groups: product.optionGroups,
                onAddGroup: () => _showGroupSheet(product.id),
                onEditGroup: (g) =>
                    _showGroupSheet(product.id, initial: g),
                onDeleteGroup: (g) =>
                    _deleteOptionGroup(product.id, g),
                onAddItem: (g) => _showItemSheet(product.id, g),
                onEditItem: (g, i) =>
                    _showItemSheet(product.id, g, initial: i),
                onDeleteItem: (g, i) =>
                    _deleteOptionItem(product.id, g, i),
              ),
            ],
          ),
        );
    }
  }

  /// Toast succes/erreur commun apres une action. En cas d'echec, utilise
  /// `actionError` du provider si dispo, sinon `fallbackError`.
  void _notifyResult({
    required bool ok,
    required String successMessage,
    required String fallbackError,
  }) {
    if (!mounted) return;
    if (ok) {
      AppToast.showSuccess(context: context, message: successMessage);
    } else {
      AppToast.showError(
        context: context,
        message: ref.read(productDetailProvider).actionError ??
            fallbackError,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Product
  // ---------------------------------------------------------------------------

  Future<void> _showEditSheet(Product product) async {
    await ZeetHaptics.success();
    final categoriesAsync = ref.read(categoriesSelectProvider);
    final List<CategorySelect> categories =
        categoriesAsync.asData?.value ?? const <CategorySelect>[];

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => ProductEditSheet(
        initial: product,
        categories: categories,
        onSubmit: (
                {required String name,
                required int price,
                required int categoryId,
                String? description}) =>
            _updateProduct(
          product.id,
          name: name,
          price: price,
          categoryId: categoryId,
          description: description,
        ),
      ),
    );
  }

  Future<void> _updateProduct(
    int productId, {
    required String name,
    required int price,
    required int categoryId,
    String? description,
  }) async {
    final bool ok =
        await ref.read(productDetailProvider.notifier).update(
              productId,
              name: name,
              price: price,
              productCategory: categoryId,
              description: description,
            );
    _notifyResult(
      ok: ok,
      successMessage: 'Produit mis a jour',
      fallbackError: 'Erreur lors de la mise a jour',
    );
  }

  Future<void> _toggleAvailability(Product product) async {
    await ZeetHaptics.tap();
    final bool next = !product.available;
    final bool ok = await ref
        .read(productDetailProvider.notifier)
        .toggleAvailability(product.id, available: next);
    if (!mounted) return;
    if (ok) {
      AppToast.showSuccess(
        context: context,
        message: next ? 'Produit disponible' : 'Produit indisponible',
      );
    } else {
      AppToast.showError(
        context: context,
        message: 'Impossible de modifier la disponibilite',
      );
    }
  }

  Future<void> _uploadPicture(Product product) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final File file = File(picked.path);
    final bool ok = await ref
        .read(productDetailProvider.notifier)
        .uploadPicture(product.id, file);
    if (!mounted) return;
    if (ok) {
      AppToast.showSuccess(context: context, message: 'Image ajoutee');
    } else {
      AppToast.showError(
        context: context,
        message: 'Impossible d\'uploader l\'image',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Variants
  // ---------------------------------------------------------------------------

  Future<void> _showVariantSheet(
    int productId, {
    ProductVariant? initial,
  }) async {
    await ZeetHaptics.success();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => ProductVariantFormSheet(
        initial: initial,
        onSubmit: (name, priceDelta, description) async {
          final notifier = ref.read(productDetailProvider.notifier);
          final bool ok = initial == null
              ? await notifier.createVariant(
                    productId,
                    name: name,
                    priceDelta: priceDelta,
                    description: description,
                  ) !=
                  null
              : await notifier.updateVariant(
                  productId,
                  initial.id,
                  name: name,
                  priceDelta: priceDelta,
                  description: description,
                );
          _notifyResult(
            ok: ok,
            successMessage: initial == null
                ? 'Variante creee'
                : 'Variante mise a jour',
            fallbackError: 'Erreur',
          );
        },
      ),
    );
  }

  Future<void> _deleteVariant(int productId, ProductVariant v) async {
    final bool confirmed = await AppPopup.showConfirmation(
      context: context,
      title: 'Supprimer la variante ?',
      message: '"${v.name}" sera retiree du produit.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final bool ok = await ref
        .read(productDetailProvider.notifier)
        .deleteVariant(productId, v.id);
    _notifyResult(
      ok: ok,
      successMessage: 'Variante supprimee',
      fallbackError: 'Impossible de supprimer la variante',
    );
  }

  // ---------------------------------------------------------------------------
  // Option groups
  // ---------------------------------------------------------------------------

  Future<void> _showGroupSheet(
    int productId, {
    ProductOptionGroup? initial,
  }) async {
    await ZeetHaptics.success();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => ProductOptionGroupFormSheet(
        initial: initial,
        onSubmit: (
          name,
          required,
          allowDuplicate,
          minSelect,
          maxSelect,
        ) async {
          final notifier = ref.read(productDetailProvider.notifier);
          final bool ok = initial == null
              ? await notifier.createOptionGroup(
                    productId,
                    name: name,
                    required: required,
                    allowDuplicate: allowDuplicate,
                    minSelect: minSelect,
                    maxSelect: maxSelect,
                  ) !=
                  null
              : await notifier.updateOptionGroup(
                  productId,
                  initial.id,
                  name: name,
                  required: required,
                  allowDuplicate: allowDuplicate,
                  minSelect: minSelect,
                  maxSelect: maxSelect,
                );
          _notifyResult(
            ok: ok,
            successMessage: initial == null
                ? 'Groupe d\'options cree'
                : 'Groupe d\'options mis a jour',
            fallbackError: 'Erreur',
          );
        },
      ),
    );
  }

  Future<void> _deleteOptionGroup(
    int productId,
    ProductOptionGroup group,
  ) async {
    final bool confirmed = await AppPopup.showConfirmation(
      context: context,
      title: 'Supprimer le groupe ?',
      message:
          '"${group.name}" et ses ${group.items.length} option(s) seront supprimes.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final bool ok = await ref
        .read(productDetailProvider.notifier)
        .deleteOptionGroup(productId, group.id);
    _notifyResult(
      ok: ok,
      successMessage: 'Groupe supprime',
      fallbackError: 'Impossible de supprimer',
    );
  }

  // ---------------------------------------------------------------------------
  // Option items
  // ---------------------------------------------------------------------------

  Future<void> _showItemSheet(
    int productId,
    ProductOptionGroup group, {
    ProductOptionItem? initial,
  }) async {
    await ZeetHaptics.success();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => ProductOptionItemFormSheet(
        initial: initial,
        onSubmit: (name, priceDelta, description) async {
          final notifier = ref.read(productDetailProvider.notifier);
          final bool ok = initial == null
              ? await notifier.createOptionItem(
                    productId,
                    group.id,
                    name: name,
                    priceDelta: priceDelta,
                    description: description,
                  ) !=
                  null
              : await notifier.updateOptionItem(
                  productId,
                  group.id,
                  initial.id,
                  name: name,
                  priceDelta: priceDelta,
                  description: description,
                );
          _notifyResult(
            ok: ok,
            successMessage: initial == null
                ? 'Option ajoutee'
                : 'Option mise a jour',
            fallbackError: 'Erreur',
          );
        },
      ),
    );
  }

  Future<void> _deleteOptionItem(
    int productId,
    ProductOptionGroup group,
    ProductOptionItem item,
  ) async {
    final bool confirmed = await AppPopup.showConfirmation(
      context: context,
      title: 'Supprimer l\'option ?',
      message: '"${item.name}" sera retiree de "${group.name}".',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final bool ok = await ref
        .read(productDetailProvider.notifier)
        .deleteOptionItem(productId, group.id, item.id);
    _notifyResult(
      ok: ok,
      successMessage: 'Option supprimee',
      fallbackError: 'Impossible de supprimer',
    );
  }
}
