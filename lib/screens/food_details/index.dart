// lib/screens/food_details/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/models/food_model.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/core/widgets/toastification.dart';

class FoodDetailsScreen extends ConsumerStatefulWidget {
  final String foodId;

  const FoodDetailsScreen({super.key, required this.foodId});

  @override
  ConsumerState<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends ConsumerState<FoodDetailsScreen> {
  int _selectedTabIndex = 0;
  final ScrollController _scrollController = ScrollController();

  late Food _food;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    // Récupérer le plat depuis la liste
    _food = foodList.firstWhere((food) => food.id == widget.foodId);
    _isAvailable = _food.isAvailable;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleAvailability() {
    setState(() {
      _isAvailable = !_isAvailable;
    });

    AppToast.showSuccess(
      context: context,
      message: _isAvailable
          ? '${_food.name} est maintenant disponible'
          : '${_food.name} est maintenant indisponible',
    );
  }

  void _editFood() {
    // TODO: Implémenter l'édition du plat
    AppToast.showInfo(context: context, message: 'Édition du plat');
  }

  void _deleteFood() {
    // TODO: Implémenter la suppression du plat
    AppToast.showWarning(context: context, message: 'Suppression du plat');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : const Color(0xFFFAF9F6);
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final borderColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;
    final chipColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Image fixe
                    SliverAppBar(
                      expandedHeight: 400,
                      pinned: false,
                      floating: false,
                      automaticallyImplyLeading: false,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'food-${_food.id}',
                              child: Image.asset(_food.image, fit: BoxFit.cover),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.2)],
                                ),
                              ),
                            ),
                            // Badge de disponibilité
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 60,
                              right: 16,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: _isAvailable
                                      ? Colors.green.withValues(alpha: 0.9)
                                      : Colors.red.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  _isAvailable ? 'Disponible' : 'Indisponible',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Contenu principal
                    SliverToBoxAdapter(
                      child: Container(
                        color: backgroundColor,
                        padding: EdgeInsets.all(20.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nom et catégorie
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _food.category.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          letterSpacing: 1.5,
                                          color: textLightColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        _food.name,
                                        style: TextStyle(
                                          fontSize: 22.sp,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Menu d'actions
                                PopupMenuButton<String>(
                                  icon: IconManager.getIcon('more_vert', color: textColor),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editFood();
                                    } else if (value == 'delete') {
                                      _deleteFood();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          IconManager.getIcon('edit', size: 18.r),
                                          SizedBox(width: 12.w),
                                          Text('Modifier', style: TextStyle(fontSize: 14.sp)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          IconManager.getIcon('delete', size: 18.r, color: Colors.red),
                                          SizedBox(width: 12.w),
                                          Text(
                                            'Supprimer',
                                            style: TextStyle(fontSize: 14.sp, color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: 16.h),

                            // Prix et note
                            Row(
                              children: [
                                Text(
                                  '${_food.price.toStringAsFixed(0)} FCFA',
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const Spacer(),
                                IconManager.getIcon('star', color: Colors.amber, size: 20.r),
                                SizedBox(width: 4.w),
                                Text(
                                  _food.rating.toString(),
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  ' / 5',
                                  style: TextStyle(fontSize: 14.sp, color: textLightColor),
                                ),
                              ],
                            ),

                            SizedBox(height: 24.h),

                            // Tabs
                            _buildTabs(textColor, textLightColor),

                            SizedBox(height: 20.h),

                            // Contenu selon l'onglet sélectionné
                            if (_selectedTabIndex == 0) ...[
                              // Description
                              Text(
                                _food.description,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: textLightColor,
                                  height: 1.6,
                                ),
                              ),

                              SizedBox(height: 24.h),

                              // Ingrédients
                              Text(
                                'Ingrédients',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                children: _food.ingredients.map((ingredient) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                    decoration: BoxDecoration(
                                      color: chipColor,
                                      borderRadius: BorderRadius.circular(6.r),
                                      border: Border.all(color: borderColor, width: 0.5),
                                    ),
                                    child: Text(
                                      ingredient,
                                      style: TextStyle(fontSize: 12.sp, color: textColor),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ] else if (_selectedTabIndex == 1) ...[
                              // Statistiques
                              _buildStatsSection(textColor, textLightColor, surfaceColor, borderColor, isDarkMode),
                            ] else ...[
                              // Infos
                              _buildInfoSection(textColor, textLightColor),
                            ],

                            SizedBox(height: 100.h), // Espace pour le bottom bar
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Bouton retour
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  child: IconButton(
                    icon: IconManager.getIcon('arrow_back', color: textColor),
                    onPressed: () => Routes.goBack(),
                    style: IconButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom bar avec bouton de disponibilité
          _buildBottomBar(backgroundColor, surfaceColor, borderColor),
        ],
      ),
    );
  }

  Widget _buildTabs(Color textColor, Color textLightColor) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedTabIndex = 0),
          child: _TabButton(
            text: 'Description',
            isSelected: _selectedTabIndex == 0,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
        ),
        SizedBox(width: 12.w),
        GestureDetector(
          onTap: () => setState(() => _selectedTabIndex = 1),
          child: _TabButton(
            text: 'Statistiques',
            isSelected: _selectedTabIndex == 1,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
        ),
        SizedBox(width: 12.w),
        GestureDetector(
          onTap: () => setState(() => _selectedTabIndex = 2),
          child: _TabButton(
            text: 'Infos',
            isSelected: _selectedTabIndex == 2,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cartes de statistiques
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Commandes',
                '127',
                'orders',
                textColor,
                textLightColor,
                surfaceColor,
                borderColor,
                isDark,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                'Revenus',
                '445K',
                'wallet',
                textColor,
                textLightColor,
                surfaceColor,
                borderColor,
                isDark,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Note moyenne',
                _food.rating.toString(),
                'star',
                textColor,
                textLightColor,
                surfaceColor,
                borderColor,
                isDark,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatCard(
                'En stock',
                '45',
                'inventory',
                textColor,
                textLightColor,
                surfaceColor,
                borderColor,
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String icon,
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconManager.getIcon(icon, color: AppColors.primary, size: 24.r),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              color: textLightColor,
              fontSize: 11.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Color textColor, Color textLightColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Catégorie', _food.category, textColor, textLightColor),
        SizedBox(height: 16.h),
        _buildInfoRow(
          'Temps de préparation',
          '${_food.preparationTime} min',
          textColor,
          textLightColor,
        ),
        SizedBox(height: 16.h),
        _buildInfoRow('Prix', '${_food.price.toStringAsFixed(0)} FCFA', textColor, textLightColor),
        SizedBox(height: 16.h),
        _buildInfoRow('Note', '${_food.rating}/5 ⭐', textColor, textLightColor),
        SizedBox(height: 16.h),
        _buildInfoRow(
          'Disponibilité',
          _isAvailable ? 'En stock' : 'Rupture',
          textColor,
          _isAvailable ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: labelColor.withValues(alpha: 0.7)),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildBottomBar(Color backgroundColor, Color surfaceColor, Color borderColor) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50.h,
          child: ElevatedButton.icon(
            onPressed: _toggleAvailability,
            icon: IconManager.getIcon(
              _isAvailable ? 'visibility_off' : 'visibility',
              color: Colors.white,
              size: 20.r,
            ),
            label: Text(
              _isAvailable ? 'Marquer comme indisponible' : 'Marquer comme disponible',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAvailable ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final Color textColor;
  final Color textLightColor;

  const _TabButton({
    required this.text,
    required this.isSelected,
    required this.textColor,
    required this.textLightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : textLightColor,
        ),
      ),
    );
  }
}
