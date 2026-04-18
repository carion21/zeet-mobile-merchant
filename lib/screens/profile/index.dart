import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/core/widgets/app_popup.dart';
import 'package:merchant/providers/auth_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:merchant/providers/dashboard_provider.dart';
import 'package:merchant/screens/root/index.dart';
import 'package:merchant/screens/tickets/index.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool isEditing = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Charger le profil et le dashboard si pas encore fait
    Future.microtask(() {
      final pState = ref.read(profileProvider);
      if (pState.status == ProfileStatus.initial) {
        ref.read(profileProvider.notifier).loadAll();
      }
      final dState = ref.read(dashboardProvider);
      if (dState.status == DashboardStatus.initial) {
        ref.read(dashboardProvider.notifier).loadSummary();
      }
    });
  }

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
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      AppToast.showSuccess(context: context, message: 'Déconnexion réussie');
      Routes.navigateAndRemoveAll(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.background;
    final Color surfaceColor = isDark ? AppColors.darkSurface : AppColors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: ZeetAppBar(
        title: const Text('Mon Profil'),
        actions: <Widget>[
          if (!isEditing)
            IconButton(
              icon: IconManager.getIcon('edit', color: textColor),
              tooltip: 'Modifier le profil',
              onPressed: () {
                setState(() {
                  isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: IconManager.getIcon('close', color: textColor),
              tooltip: 'Annuler la modification',
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
              children: <Widget>[
                _buildProfileHeader(textColor),
                SizedBox(height: 24.h),
                _buildStatsCard(textColor, textLightColor, surfaceColor, isDark),
                SizedBox(height: 24.h),
                _buildProfileOptions(textColor, textLightColor, surfaceColor),
                SizedBox(height: 32.h),
                _buildLogoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Color textColor) {
    final authState = ref.watch(authProvider);
    final partnerProfile = ref.watch(partnerDataProvider);
    final partner = authState.partner;
    final displayName = partnerProfile?.name ?? partner?.restaurantName ?? 'Mon Restaurant';
    final displayPhone = partner != null ? '+225 ${partner.phone}' : '';
    final logoUrl = partnerProfile?.picture ?? partner?.partner?.picture;

    String initials = displayName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((word) => word[0])
        .take(2)
        .join()
        .toUpperCase();
    if (initials.isEmpty) initials = 'MR';

    return Column(
      children: [
        // Avatar avec initiales ou photo
        Container(
          width: 100.w,
          height: 100.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: logoUrl != null
              ? ClipOval(
                  child: ZeetImage(
                    url: logoUrl,
                    width: 100.w,
                    height: 100.h,
                    fit: BoxFit.cover,
                    errorWidget: Center(
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
                )
              : Center(
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
          displayName,
          style: TextStyle(
            color: textColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Numero de telephone
        SizedBox(height: 4.h),
        Text(
          displayPhone,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),

        // Adresse si disponible
        if (partnerProfile?.address != null || partner?.partner?.address != null) ...[
          SizedBox(height: 4.h),
          Text(
            partnerProfile?.address ?? partner!.partner!.address!,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 13.sp,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsCard(Color textColor, Color textLightColor, Color surfaceColor, bool isDark) {
    final ordersToday = ref.watch(ordersTodayProvider);
    final revenueToday = ref.watch(revenueTodayProvider);
    final rating = ref.watch(ratingProvider);
    final commissionRate = ref.watch(commissionRateProvider);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
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
                  value: '$ordersToday',
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
                child: Column(
                  children: [
                    ZeetMoney(
                      amount: revenueToday,
                      currency: ZeetCurrency.fcfa,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Gains',
                      style: TextStyle(
                        color: textLightColor,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
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
                  value: rating > 0 ? rating.toStringAsFixed(1) : '--',
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ),
            ],
          ),

          // Taux de commission (si disponible)
          if (commissionRate != null) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Commission : ',
                    style: TextStyle(
                      color: textLightColor,
                      fontSize: 13.sp,
                    ),
                  ),
                  Text(
                    '${commissionRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              HapticFeedback.selectionClick();
              // Switch tab — évite le push redondant d'OrdersScreen
              // depuis le RootScaffold.
              ref.read(rootTabProvider.notifier).state = RootTab.orders;
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          // Entrées "Mon menu", "Statistiques", "Paramètres" retirées :
          // elles sont HORS-SCOPE mobile et couvertes par l'admin web
          // (cf. audit partner 2026-04-15 §6).
          _buildProfileOption(
            title: 'Portefeuille',
            icon: 'wallet',
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(rootTabProvider.notifier).state = RootTab.wallet;
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Aide et support',
            icon: 'help',
            onTap: () {
              HapticFeedback.selectionClick();
              Routes.push(
                const TicketsScreen(),
                style: ZeetTransitionStyle.sharedAxisVertical,
              );
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
                // Icon slot 48×48pt (seuil POS partner §1, m-06).
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZeetRadius.md),
                  ),
                  child: Center(
                    child: IconManager.getIcon(icon, color: AppColors.primary, size: 22.r),
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
    return ZeetButton(
      label: 'Déconnexion',
      onPressed: _confirmLogout,
      variant: ZeetButtonVariant.danger,
      size: ZeetButtonSize.md,
      icon: Icons.logout_rounded,
      fullWidth: true,
    );
  }
}
