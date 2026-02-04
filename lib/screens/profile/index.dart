import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/core/widgets/app_popup.dart';
import 'package:merchant/services/navigation_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Données fictives
  final String restaurantName = 'Chez Maman';
  final String phoneNumber = '+225 07 00 00 00 00';
  final String email = 'contact@chezmaman.com';
  final String address = 'Cocody, Angré 7ème Tranche';

  bool isEditing = false;
  bool isLoading = false;

  Future<void> _confirmLogout() async {
    final bool confirm = await AppPopup.showConfirmation(
      context: context,
      title: 'Déconnexion',
      message: 'Êtes-vous sûr de vouloir vous déconnecter ?',
      confirmLabel: 'Déconnexion',
      cancelLabel: 'Annuler',
      isDestructive: true,
    );

    if (!mounted) return;

    if (confirm) {
      AppToast.showSuccess(context: context, message: 'Déconnexion réussie');
      // Rediriger vers la page de connexion
      Routes.navigateAndRemoveAll(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final textLightColor = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDark ? AppColors.darkBackground : const Color(0xFFF8F8F8);
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: IconManager.getIcon('arrow_back', color: textColor),
          onPressed: () => Routes.goBack(),
        ),
        title: Text(
          'Mon Profil',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!isEditing)
            IconButton(
              icon: IconManager.getIcon('edit', color: textColor),
              onPressed: () {
                setState(() {
                  isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: IconManager.getIcon('close', color: textColor),
              onPressed: () {
                setState(() {
                  isEditing = false;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar et nom
                _buildProfileHeader(textColor),

                SizedBox(height: 24.h),

                // Statistiques du restaurant
                _buildStatsCard(textColor, textLightColor, surfaceColor, isDark),

                SizedBox(height: 24.h),

                // Menu d'options de profil
                _buildProfileOptions(textColor, textLightColor, surfaceColor),

                SizedBox(height: 32.h),

                // Bouton de déconnexion
                _buildLogoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Color textColor) {
    String initials = restaurantName.split(' ').map((word) => word[0]).take(2).join().toUpperCase();

    return Column(
      children: [
        // Avatar avec initiales
        Container(
          width: 100.w,
          height: 100.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // Nom du restaurant
        Text(
          restaurantName,
          style: TextStyle(
            color: textColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Numéro de téléphone
        SizedBox(height: 4.h),
        Text(
          phoneNumber,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(Color textColor, Color textLightColor, Color surfaceColor, bool isDark) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Titre
          Text(
            'Statistiques du jour',
            style: TextStyle(
              color: textColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 20.h),

          // Grid de statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Commandes',
                  value: '12',
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ),
              Container(
                width: 1.w,
                height: 50.h,
                color: textLightColor.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Gains',
                  value: '45K',
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ),
              Container(
                width: 1.w,
                height: 50.h,
                color: textLightColor.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Note',
                  value: '4.8',
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color textColor,
    required Color textLightColor,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            color: textLightColor,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileOptions(Color textColor, Color textLightColor, Color surfaceColor) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          _buildProfileOption(
            title: 'Mes commandes',
            icon: 'history',
            onTap: () {
              Routes.navigateTo(Routes.orders);
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Mon menu',
            icon: 'restaurant',
            onTap: () {
              Routes.navigateTo(Routes.menu);
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Statistiques',
            icon: 'trending_up',
            onTap: () {
              AppToast.showInfo(context: context, message: 'Statistiques');
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Paramètres',
            icon: 'settings',
            onTap: () {
              AppToast.showInfo(context: context, message: 'Paramètres');
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Aide et support',
            icon: 'help',
            onTap: () {
              AppToast.showInfo(context: context, message: 'Support');
            },
            showDivider: false,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required String title,
    required String icon,
    required Function() onTap,
    required bool showDivider,
    required Color textColor,
    required Color textLightColor,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: showDivider ? BorderRadius.zero : BorderRadius.vertical(bottom: Radius.circular(12.r)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Center(
                    child: IconManager.getIcon(icon, color: AppColors.primary, size: 20.r),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconManager.getIcon('arrow_forward', color: textLightColor, size: 16.r),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1.h,
            thickness: 1,
            indent: 56.w,
            endIndent: 16.w,
            color: textLightColor.withValues(alpha: 0.1),
          ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: _confirmLogout,
      icon: IconManager.getIcon('logout', color: Colors.red, size: 20.r),
      label: Text(
        'Déconnexion',
        style: TextStyle(
          color: Colors.red,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      ),
    );
  }
}
