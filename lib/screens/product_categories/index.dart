// lib/screens/product_categories/index.dart
//
// Ecran "Categories de produits" partner — CRUD complet via :
// - GET    /v1/partner/product-categories           (liste paginee)
// - POST   /v1/partner/product-categories           (creation)
// - PATCH  /v1/partner/product-categories/:id       (update partiel)
// - DELETE /v1/partner/product-categories/:id       (suppression)
// - POST   /v1/partner/product-categories/:id/picture (upload image)
//
// Ergonomie POS partner : FAB pour creer, actions rapides par ligne
// (toggle statut, menu "plus" avec modifier / supprimer / image).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/app_popup.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/category_model.dart';
import 'package:merchant/providers/category_provider.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/services/category_service.dart';
import 'package:merchant/services/api_client.dart';
import 'package:zeet_ui/zeet_ui.dart';

class ProductCategoriesScreen extends ConsumerStatefulWidget {
  const ProductCategoriesScreen({super.key});

  @override
  ConsumerState<ProductCategoriesScreen> createState() =>
      _ProductCategoriesScreenState();
}

class _ProductCategoriesScreenState
    extends ConsumerState<ProductCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categoriesListProvider.notifier).load();
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
      ref.read(categoriesListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;

    final state = ref.watch(categoriesListProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZeetAppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: textColor, fontSize: 16.sp),
                decoration: InputDecoration(
                  hintText: 'Rechercher une categorie…',
                  hintStyle:
                      TextStyle(color: textLightColor, fontSize: 14.sp),
                  border: InputBorder.none,
                ),
                onSubmitted: (query) {
                  ref
                      .read(categoriesListProvider.notifier)
                      .searchCategories(query);
                },
              )
            : const Text('Categories'),
        actions: <Widget>[
          IconButton(
            icon: IconManager.getIcon(
              _isSearching ? 'close' : 'search',
              color: textColor,
            ),
            tooltip: _isSearching ? 'Fermer la recherche' : 'Rechercher',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref
                      .read(categoriesListProvider.notifier)
                      .searchCategories(null);
                }
              });
            },
          ),
        ],
      ),
      body: _buildBody(state, textColor, textLightColor),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCategorySheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: IconManager.getIcon('add', color: Colors.white),
        label: const Text('Nouvelle categorie'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body + ELOE
  // ---------------------------------------------------------------------------

  Widget _buildBody(
    CategoriesListState state,
    Color textColor,
    Color textLightColor,
  ) {
    final bool isOnline = ref.watch(connectivityStatusProvider).maybeWhen(
          data: (v) => v,
          orElse: () => true,
        );

    return RefreshIndicator(
      onRefresh: () => ref.read(categoriesListProvider.notifier).refresh(),
      child: ZeetScreenScaffold(
        state: _resolveState(state, isOnline),
        onRetry: () => ref.read(categoriesListProvider.notifier).load(),
        loading: const ZeetSkeletonList(itemCount: 6, itemHeight: 88),
        emptyTitle: 'Aucune categorie',
        emptySubtitle:
            'Cree ta premiere categorie pour organiser tes produits.',
        emptyIcon: Icons.category_outlined,
        errorMessage: state.errorMessage,
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 96.h),
          itemCount: state.categories.length +
              (state.status == CategoriesListStatus.loadingMore ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (index == state.categories.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _CategoryTile(
              category: state.categories[index],
              onTap: () => _openCategory(state.categories[index]),
              onEdit: () => _showEditCategorySheet(state.categories[index]),
              onToggleStatus: () =>
                  _toggleCategoryStatus(state.categories[index]),
              onDelete: () => _deleteCategory(state.categories[index]),
              onUploadPicture: () =>
                  _pickAndUploadPicture(state.categories[index]),
            );
          },
        ),
      ),
    );
  }

  ZeetScreenState _resolveState(
    CategoriesListState state,
    bool isOnline,
  ) {
    switch (state.status) {
      case CategoriesListStatus.initial:
      case CategoriesListStatus.loading:
        return ZeetScreenState.loading;
      case CategoriesListStatus.error:
        if (!isOnline) return ZeetScreenState.offline;
        return ZeetScreenState.error;
      case CategoriesListStatus.loaded:
      case CategoriesListStatus.loadingMore:
        if (state.categories.isEmpty) return ZeetScreenState.empty;
        return ZeetScreenState.content;
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _openCategory(ProductCategory category) {
    // Future : pourra ouvrir un detail avec liste des produits de la categorie.
    // Pour l'instant, on propose directement le sheet d'edition.
    _showEditCategorySheet(category);
  }

  Future<void> _showCreateCategorySheet() async {
    await ZeetHaptics.success();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) =>
          _CategoryFormSheet(onSubmit: _createCategory),
    );
  }

  Future<void> _showEditCategorySheet(ProductCategory category) async {
    await ZeetHaptics.success();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => _CategoryFormSheet(
        initial: category,
        onSubmit: (label, description, status) =>
            _updateCategory(category.id, label, description, status),
      ),
    );
  }

  Future<void> _createCategory(
    String label,
    String? description,
    bool status,
  ) async {
    try {
      final category = await CategoryService().createCategory(
        label: label,
        description: description,
        status: status,
      );
      if (!mounted) return;
      ref
          .read(categoriesListProvider.notifier)
          .addCategoryToList(category);
      AppToast.showSuccess(
        context: context,
        message: 'Categorie "${category.label}" creee',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context: context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible de creer la categorie',
      );
    }
  }

  Future<void> _updateCategory(
    int categoryId,
    String label,
    String? description,
    bool status,
  ) async {
    try {
      final updated = await CategoryService().updateCategory(
        categoryId,
        label: label,
        description: description,
        status: status,
      );
      if (!mounted) return;
      ref
          .read(categoriesListProvider.notifier)
          .updateCategoryInList(updated);
      AppToast.showSuccess(
        context: context,
        message: 'Categorie mise a jour',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context: context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible de mettre a jour la categorie',
      );
    }
  }

  Future<void> _toggleCategoryStatus(ProductCategory category) async {
    await ZeetHaptics.tap();
    final bool next = !category.status;
    try {
      final updated = await CategoryService().updateCategory(
        category.id,
        status: next,
      );
      if (!mounted) return;
      ref
          .read(categoriesListProvider.notifier)
          .updateCategoryInList(updated);
      AppToast.showSuccess(
        context: context,
        message: next ? 'Categorie activee' : 'Categorie desactivee',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context: context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible de modifier le statut',
      );
    }
  }

  Future<void> _deleteCategory(ProductCategory category) async {
    final bool confirmed = await AppPopup.showConfirmation(
      context: context,
      title: 'Supprimer la categorie ?',
      message:
          '"${category.label}" sera supprimee. Les produits associes devront etre re-categorises.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await CategoryService().deleteCategory(category.id);
      if (!mounted) return;
      ref
          .read(categoriesListProvider.notifier)
          .removeCategoryFromList(category.id);
      AppToast.showSuccess(
        context: context,
        message: 'Categorie supprimee',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context: context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible de supprimer la categorie',
      );
    }
  }

  Future<void> _pickAndUploadPicture(ProductCategory category) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final File file = File(picked.path);
    try {
      final String? pictureUrl =
          await CategoryService().uploadPicture(category.id, file);
      if (!mounted) return;
      if (pictureUrl != null) {
        ref.read(categoriesListProvider.notifier).updateCategoryInList(
              category.copyWith(picture: pictureUrl),
            );
      }
      AppToast.showSuccess(
        context: context,
        message: 'Image mise a jour',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(context: context, message: e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible d\'uploader l\'image',
      );
    }
  }
}

// =============================================================================
// Tile d'une categorie
// =============================================================================

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onUploadPicture,
  });

  final ProductCategory category;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final VoidCallback onUploadPicture;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isActive = category.isActive;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: <Widget>[
              // Vignette image (tap = upload)
              GestureDetector(
                onTap: onUploadPicture,
                child: Container(
                  width: 56.w,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: category.picture != null &&
                          category.picture!.isNotEmpty
                      ? ZeetImage(
                          url: category.picture,
                          width: 56.w,
                          height: 56.h,
                          fit: BoxFit.cover,
                          errorWidget: Icon(
                            Icons.broken_image_outlined,
                            color: scheme.onSurfaceVariant,
                            size: 22.r,
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            color: scheme.onSurfaceVariant,
                            size: 22.r,
                          ),
                        ),
                ),
              ),
              SizedBox(width: 12.w),
              // Nom + sous-titre
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      category.label,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${category.totalProducts} produit${category.totalProducts > 1 ? 's' : ''} • ${isActive ? 'Actif' : 'Inactif'}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isActive
                            ? scheme.onSurfaceVariant
                            : scheme.error,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Menu actions
              PopupMenuButton<_CategoryAction>(
                tooltip: 'Actions',
                icon: Icon(Icons.more_vert_rounded, color: scheme.onSurface),
                onSelected: (action) {
                  switch (action) {
                    case _CategoryAction.edit:
                      onEdit();
                    case _CategoryAction.toggleStatus:
                      onToggleStatus();
                    case _CategoryAction.uploadPicture:
                      onUploadPicture();
                    case _CategoryAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (_) => <PopupMenuEntry<_CategoryAction>>[
                  const PopupMenuItem<_CategoryAction>(
                    value: _CategoryAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Modifier'),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem<_CategoryAction>(
                    value: _CategoryAction.toggleStatus,
                    child: ListTile(
                      leading: Icon(isActive
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      title:
                          Text(isActive ? 'Desactiver' : 'Activer'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem<_CategoryAction>(
                    value: _CategoryAction.uploadPicture,
                    child: ListTile(
                      leading: Icon(Icons.image_outlined),
                      title: Text('Changer l\'image'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<_CategoryAction>(
                    value: _CategoryAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline,
                          color: AppColors.error),
                      title: Text('Supprimer',
                          style: TextStyle(color: AppColors.error)),
                      dense: true,
                    ),
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

enum _CategoryAction { edit, toggleStatus, uploadPicture, delete }

// =============================================================================
// Bottom sheet : formulaire creation/edition
// =============================================================================

class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({
    this.initial,
    required this.onSubmit,
  });

  final ProductCategory? initial;

  /// (label, description?, status) -> Future.
  final Future<void> Function(String label, String? description, bool status)
      onSubmit;

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _descCtrl;
  late bool _status;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _labelCtrl =
        TextEditingController(text: widget.initial?.label ?? '');
    _descCtrl =
        TextEditingController(text: widget.initial?.description ?? '');
    _status = widget.initial?.status ?? true;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isEdit = widget.initial != null;

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
              isEdit ? 'Modifier la categorie' : 'Nouvelle categorie',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                hintText: 'Ex. Entrees, Plats, Desserts…',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nom requis' : null,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),
            SizedBox(height: 12.h),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _status,
              onChanged: (v) => setState(() => _status = v),
              title: Text(
                _status ? 'Categorie active' : 'Categorie inactive',
                style: tt.bodyLarge,
              ),
              subtitle: Text(
                _status
                    ? 'Visible pour les clients'
                    : 'Masquee pour les clients',
                style: tt.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            SizedBox(height: 16.h),
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
                        : Text(
                            isEdit ? 'Enregistrer' : 'Creer',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
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
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _labelCtrl.text.trim(),
        _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        _status,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
