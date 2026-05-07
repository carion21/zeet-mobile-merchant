// lib/screens/menu/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/app_popup.dart';
import 'package:merchant/core/widgets/freshness/zeet_freshness_chip.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/menu_model.dart';
import 'package:merchant/providers/menu_provider.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/menu_service.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ZeetFreshnessChipLocalState> _freshKey = GlobalKey();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Charger les menus au demarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(menusListProvider.notifier).load();
    });
  }

  /// Refresh unifié : recharge + bumpe la chip de fraîcheur.
  Future<void> _refreshAll() async {
    await ref.read(menusListProvider.notifier).refresh();
    _freshKey.currentState?.bump();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    final Color backgroundColor = scheme.surface;

    final menusState = ref.watch(menusListProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: ZeetAppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un menu…',
                  border: InputBorder.none,
                ),
                onSubmitted: (query) {
                  ref.read(menusListProvider.notifier).searchMenus(query);
                },
              )
            : const Text('Mes menus'),
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
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'Fermer la recherche' : 'Rechercher',
            onPressed: () {
              ZeetHaptics.tap();
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(menusListProvider.notifier).searchMenus(null);
                }
              });
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Catalogue',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (String route) => Routes.navigateTo(route),
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: Routes.products,
                child: ListTile(
                  leading: Icon(Icons.restaurant_menu_outlined),
                  title: Text('Produits'),
                  dense: true,
                ),
              ),
              PopupMenuItem<String>(
                value: Routes.productCategories,
                child: ListTile(
                  leading: Icon(Icons.category_outlined),
                  title: Text('Catégories'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(menusState, textColor, textLightColor, isDark),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenuDialog(context, isDark),
        backgroundColor: AppColors.primary,
        tooltip: 'Créer un menu',
        child: IconManager.getIcon('add', color: AppColors.white),
      ),
    );
  }

  Widget _buildBody(
    MenusListState menusState,
    Color textColor,
    Color textLightColor,
    bool isDark,
  ) {
    final isOnline = ref.watch(connectivityStatusProvider).maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ZeetScreenScaffold(
        state: _resolveState(menusState, isOnline),
        onRetry: () async {
          await ref.read(menusListProvider.notifier).load();
          _freshKey.currentState?.bump();
        },
        loading: const ZeetSkeletonList(itemCount: 6, itemHeight: 140),
        emptyTitle: 'Menu vide',
        emptySubtitle: 'Ajoute des produits pour les afficher sur la fiche',
        emptyIcon: Icons.restaurant_menu_outlined,
        errorMessage: menusState.errorMessage,
        child: ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: menusState.menus.length +
              (menusState.status == MenusListStatus.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == menusState.menus.length) {
              // Skeleton matching structure finale (skill zeet-motion-system §9).
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: const ZeetSkeleton(height: 140),
              );
            }

            final menu = menusState.menus[index];
            return _buildMenuCard(menu, textColor, textLightColor, isDark);
          },
        ),
      ),
    );
  }

  /// Résout l'état ELOE depuis le [MenusListState].
  ZeetScreenState _resolveState(MenusListState state, bool isOnline) {
    switch (state.status) {
      case MenusListStatus.initial:
      case MenusListStatus.loading:
        return ZeetScreenState.loading;
      case MenusListStatus.error:
        if (!isOnline) return ZeetScreenState.offline;
        return ZeetScreenState.error;
      case MenusListStatus.loaded:
      case MenusListStatus.loadingMore:
        if (state.menus.isEmpty) return ZeetScreenState.empty;
        return ZeetScreenState.content;
    }
  }

  Widget _buildMenuCard(
    Menu menu,
    Color textColor,
    Color textLightColor,
    bool isDark,
  ) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        // DS §2 : border seule, pas de BoxShadow.
        border: Border.all(
          color: scheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showMenuDetail(menu.id),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entete : nom + badge statut
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                menu.name,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (menu.isDefault) ...[
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  'Par defaut',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (menu.description != null &&
                            menu.description!.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            menu.description!,
                            style: TextStyle(
                              color: textLightColor,
                              fontSize: 12.sp,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Badge statut
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: (menu.isPublished
                              ? AppColors.success
                              : AppColors.warning)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      menu.isPublished ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        color: menu.isPublished
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              // Info : horaires + jours + nb produits
              Row(
                children: [
                  // Horaires
                  IconManager.getIcon('clock',
                      color: textLightColor, size: 14.r),
                  SizedBox(width: 4.w),
                  Text(
                    menu.scheduleText,
                    style: TextStyle(color: textLightColor, fontSize: 12.sp),
                  ),
                  SizedBox(width: 16.w),
                  // Jours
                  IconManager.getIcon('access_time',
                      color: textLightColor, size: 14.r),
                  SizedBox(width: 4.w),
                  Text(
                    menu.daysOfWeek.displayText,
                    style: TextStyle(color: textLightColor, fontSize: 12.sp),
                  ),
                  const Spacer(),
                  // Nb produits
                  Text(
                    '${menu.productCount} produit${menu.productCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              // Actions rapides
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Publier / Depublier
                  _buildActionButton(
                    icon: menu.isPublished ? 'visibility_off' : 'visibility_on',
                    label: menu.isPublished ? 'Desactiver' : 'Activer',
                    color: menu.isPublished
                        ? AppColors.warning
                        : AppColors.success,
                    onTap: () => _togglePublish(menu),
                  ),
                  SizedBox(width: 8.w),
                  // Supprimer
                  _buildActionButton(
                    icon: 'delete',
                    label: 'Supprimer',
                    color: AppColors.danger,
                    onTap: () => _confirmDelete(menu),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Hit target POS : 48pt min (cuisine, mains humides).
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.r),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 48.h, minWidth: 48.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconManager.getIcon(icon, color: color, size: 18.r),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _showMenuDetail(int menuId) {
    ref.read(menuDetailProvider.notifier).load(menuId);
    // TODO: Naviguer vers un ecran de detail menu quand il sera cree
    // Pour l'instant on affiche un bottom sheet avec le detail
    _showMenuDetailSheet(menuId);
  }

  void _showMenuDetailSheet(int menuId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final textLightColor = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDark ? AppColors.darkSurface : AppColors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final detailState = ref.watch(menuDetailProvider);

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                if (detailState.status == MenuDetailStatus.loading ||
                    detailState.status == MenuDetailStatus.initial) {
                  // Skeleton list > spinner full-screen (skill
                  // `zeet-motion-system` §9 : skeleton maintient le layout).
                  return ListView(
                    controller: scrollController,
                    padding: EdgeInsets.all(20.w),
                    children: const <Widget>[
                      ZeetSkeletonList(itemCount: 4, itemHeight: 64),
                    ],
                  );
                }

                if (detailState.status == MenuDetailStatus.error) {
                  return ZeetErrorState(
                    kind: ZeetErrorKind.generic,
                    title: 'Chargement impossible',
                    description: detailState.errorMessage ??
                        'Une erreur est survenue.',
                    retryLabel: 'Reessayer',
                    onRetry: () {
                      ref
                          .read(menuDetailProvider.notifier)
                          .load(menuId);
                    },
                  );
                }

                final menu = detailState.menu;
                if (menu == null) {
                  return Center(
                    child: Text('Menu introuvable',
                        style: TextStyle(color: textLightColor)),
                  );
                }

                return ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(20.w),
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Nom
                    Text(
                      menu.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (menu.description != null) ...[
                      SizedBox(height: 8.h),
                      Text(
                        menu.description!,
                        style: TextStyle(color: textLightColor, fontSize: 14.sp),
                      ),
                    ],
                    SizedBox(height: 16.h),

                    // Infos
                    _buildDetailRow('Statut',
                        menu.isPublished ? 'Actif' : 'Inactif', textColor),
                    _buildDetailRow('Par defaut',
                        menu.isDefault ? 'Oui' : 'Non', textColor),
                    _buildDetailRow('Horaires', menu.scheduleText, textColor),
                    _buildDetailRow(
                        'Jours', menu.daysOfWeek.displayText, textColor),
                    if (menu.code != null)
                      _buildDetailRow('Code', menu.code!, textColor),
                    SizedBox(height: 20.h),

                    // Produits du menu
                    Text(
                      'Produits (${menu.items.length})',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12.h),

                    if (menu.items.isEmpty)
                      Text(
                        'Aucun produit dans ce menu',
                        style:
                            TextStyle(color: textLightColor, fontSize: 13.sp),
                      )
                    else
                      ...menu.items.map((item) => _buildMenuItemTile(
                            item, textColor, textLightColor, isDark)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 13.sp,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemTile(
    MenuItem item,
    Color textColor,
    Color textLightColor,
    bool isDark,
  ) {
    final product = item.product;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          // Image produit
          if (product?.imageUrl != null)
            ZeetImage(
              url: product!.imageUrl,
              width: 48.w,
              height: 48.w,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(6.r),
              backgroundColor: AppColors.line.withValues(alpha: 0.4),
              errorWidget: IconManager.getIcon('restaurant',
                  color: textLightColor, size: 24.r),
            )
          else
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: AppColors.line.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: IconManager.getIcon('restaurant',
                  color: textLightColor, size: 24.r),
            ),
          SizedBox(width: 12.w),
          // Infos produit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.name ?? 'Produit #${item.id}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (product?.price != null) ...[
                  SizedBox(height: 2.h),
                  ZeetMoney(
                    amount: product!.price!,
                    currency: ZeetCurrency.fcfa,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Statut item
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: item.status ? AppColors.success : AppColors.danger,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublish(Menu menu) async {
    final bool confirm = await AppPopup.showConfirmation(
      context: context,
      title: menu.isPublished ? 'Désactiver ce menu ?' : 'Activer ce menu ?',
      message: menu.isPublished
          ? 'Les clients ne pourront plus voir ce menu tant qu\'il est désactivé.'
          : 'Les clients pourront commander depuis ce menu.',
      confirmLabel: menu.isPublished ? 'Désactiver' : 'Activer',
      cancelLabel: 'Annuler',
      isDestructive: menu.isPublished,
    );

    if (!confirm || !mounted) return;

    await ZeetHaptics.warning();
    final notifier = ref.read(menuDetailProvider.notifier);
    final success = await notifier.publish(menu.id);

    if (!mounted) return;

    if (success) {
      final updatedMenu = ref.read(menuDetailProvider).menu;
      if (updatedMenu != null) {
        ref.read(menusListProvider.notifier).updateMenuInList(updatedMenu);
      }
      AppToast.showSuccess(
        context: context,
        message: menu.isPublished ? 'Menu désactivé' : 'Menu activé',
      );
    } else {
      final error = ref.read(menuDetailProvider).actionError;
      AppToast.showError(
        context: context,
        message: error ?? 'Erreur lors de la publication',
      );
    }
  }

  Future<void> _confirmDelete(Menu menu) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.white,
          title: const Text('Supprimer le menu'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer le menu "${menu.name}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final notifier = ref.read(menuDetailProvider.notifier);
    final success = await notifier.delete(menu.id);

    if (!mounted) return;

    if (success) {
      ref.read(menusListProvider.notifier).removeMenuFromList(menu.id);
      AppToast.showSuccess(
        context: context,
        message: 'Menu supprimé',
      );
    } else {
      final error = ref.read(menuDetailProvider).actionError;
      AppToast.showError(
        context: context,
        message: error ?? 'Erreur lors de la suppression',
      );
    }
  }

  void _showCreateMenuDialog(BuildContext context, bool isDark) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final backgroundColor = isDark ? AppColors.darkSurface : AppColors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              Text(
                'Nouveau menu',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20.h),

              // Nom
              TextField(
                controller: nameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Nom du menu',
                  hintText: 'Ex: Menu du jour',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Description
              TextField(
                controller: descriptionController,
                style: TextStyle(color: textColor),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (optionnel)',
                  hintText: 'Decrivez votre menu...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Bouton créer — ZeetButton primary md (48pt).
              ZeetButton.primary(
                label: 'Créer le menu',
                onPressed: () async {
                  final String name = nameController.text.trim();
                  if (name.isEmpty) {
                    AppToast.showWarning(
                      context: context,
                      message: 'Veuillez saisir un nom pour le menu',
                    );
                    return;
                  }
                  Navigator.pop(context);
                  await _createMenu(
                    name: name,
                    description: descriptionController.text.trim().isNotEmpty
                        ? descriptionController.text.trim()
                        : null,
                  );
                },
                icon: Icons.add_rounded,
                fullWidth: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createMenu({
    required String name,
    String? description,
  }) async {
    try {
      final menuService =
          ref.read(menusListProvider.notifier);
      // On recharge la liste apres creation via le service directement
      final service =
          MenuService();
      await service.createMenu(
        name: name,
        description: description,
      );

      if (!mounted) return;

      AppToast.showSuccess(
        context: context,
        message: 'Menu "$name" cree avec succes',
      );

      // Recharger la liste
      menuService.refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible de creer le menu',
      );
    }
  }
}
