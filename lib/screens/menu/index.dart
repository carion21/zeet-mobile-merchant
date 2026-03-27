// lib/screens/menu/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/models/menu_model.dart';
import 'package:merchant/providers/menu_provider.dart';
import 'package:merchant/services/api_client.dart';
import 'package:merchant/services/menu_service.dart';
import 'package:merchant/services/navigation_service.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Charger les menus au demarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(menusListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final textLightColor = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDark ? AppColors.darkBackground : Colors.white;

    final menusState = ref.watch(menusListProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: IconManager.getIcon('arrow_back', color: textColor),
          onPressed: () => Routes.goBack(),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: textColor, fontSize: 16.sp),
                decoration: InputDecoration(
                  hintText: 'Rechercher un menu...',
                  hintStyle: TextStyle(color: textLightColor, fontSize: 14.sp),
                  border: InputBorder.none,
                ),
                onSubmitted: (query) {
                  ref.read(menusListProvider.notifier).searchMenus(query);
                },
              )
            : Text(
                'Mes Menus',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon: IconManager.getIcon(
              _isSearching ? 'close' : 'search',
              color: textColor,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(menusListProvider.notifier).searchMenus(null);
                }
              });
            },
          ),
        ],
      ),
      body: _buildBody(menusState, textColor, textLightColor, isDark),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenuDialog(context, isDark),
        backgroundColor: AppColors.primary,
        child: IconManager.getIcon('add', color: Colors.white),
      ),
    );
  }

  Widget _buildBody(
    MenusListState menusState,
    Color textColor,
    Color textLightColor,
    bool isDark,
  ) {
    switch (menusState.status) {
      case MenusListStatus.initial:
      case MenusListStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case MenusListStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconManager.getIcon('error', color: Colors.red, size: 48.r),
              SizedBox(height: 16.h),
              Text(
                menusState.errorMessage ?? 'Erreur de chargement',
                style: TextStyle(color: textLightColor, fontSize: 14.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () => ref.read(menusListProvider.notifier).load(),
                child: const Text('Reessayer'),
              ),
            ],
          ),
        );

      case MenusListStatus.loaded:
      case MenusListStatus.loadingMore:
        if (menusState.menus.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconManager.getIcon('restaurant',
                    color: textLightColor, size: 48.r),
                SizedBox(height: 16.h),
                Text(
                  'Aucun menu',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Creez votre premier menu pour commencer',
                  style: TextStyle(color: textLightColor, fontSize: 13.sp),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(menusListProvider.notifier).refresh(),
          child: ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: menusState.menus.length +
                (menusState.status == MenusListStatus.loadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == menusState.menus.length) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: const CircularProgressIndicator(),
                  ),
                );
              }

              final menu = menusState.menus[index];
              return _buildMenuCard(menu, textColor, textLightColor, isDark);
            },
          ),
        );
    }
  }

  Widget _buildMenuCard(
    Menu menu,
    Color textColor,
    Color textLightColor,
    bool isDark,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                      color: menu.isPublished
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      menu.isPublished ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        color: menu.isPublished ? Colors.green : Colors.orange,
                        fontSize: 11.sp,
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
                    style: TextStyle(color: textLightColor, fontSize: 11.sp),
                  ),
                  SizedBox(width: 16.w),
                  // Jours
                  IconManager.getIcon('access_time',
                      color: textLightColor, size: 14.r),
                  SizedBox(width: 4.w),
                  Text(
                    menu.daysOfWeek.displayText,
                    style: TextStyle(color: textLightColor, fontSize: 11.sp),
                  ),
                  const Spacer(),
                  // Nb produits
                  Text(
                    '${menu.productCount} produit${menu.productCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11.sp,
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
                    color: menu.isPublished ? Colors.orange : Colors.green,
                    onTap: () => _togglePublish(menu),
                  ),
                  SizedBox(width: 8.w),
                  // Supprimer
                  _buildActionButton(
                    icon: 'delete',
                    label: 'Supprimer',
                    color: Colors.red,
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
    return InkWell(
      borderRadius: BorderRadius.circular(6.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconManager.getIcon(icon, color: color, size: 16.r),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
    final backgroundColor = isDark ? AppColors.darkSurface : Colors.white;

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
                  return const Center(child: CircularProgressIndicator());
                }

                if (detailState.status == MenuDetailStatus.error) {
                  return Center(
                    child: Text(
                      detailState.errorMessage ?? 'Erreur',
                      style: TextStyle(color: textLightColor),
                    ),
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
                          color: Colors.grey.withValues(alpha: 0.3),
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
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          // Image produit
          if (product?.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: Image.network(
                product!.imageUrl!,
                width: 48.w,
                height: 48.w,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48.w,
                  height: 48.w,
                  color: Colors.grey.withValues(alpha: 0.2),
                  child: IconManager.getIcon('restaurant',
                      color: textLightColor, size: 24.r),
                ),
              ),
            )
          else
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
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
                  Text(
                    '${product!.price!.toStringAsFixed(0)} F',
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
              color: item.status ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublish(Menu menu) async {
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
        message: menu.isPublished ? 'Menu desactive' : 'Menu active',
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
              isDark ? AppColors.darkSurface : Colors.white,
          title: const Text('Supprimer le menu'),
          content: Text(
              'Etes-vous sur de vouloir supprimer le menu "${menu.name}" ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
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
        message: 'Menu supprime',
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
    final backgroundColor = isDark ? AppColors.darkSurface : Colors.white;

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
                    color: Colors.grey.withValues(alpha: 0.3),
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

              // Bouton creer
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'Creer le menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
