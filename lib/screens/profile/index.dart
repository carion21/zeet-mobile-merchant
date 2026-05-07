import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/core/widgets/app_popup.dart';
import 'package:merchant/providers/auth_provider.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:merchant/providers/dashboard_provider.dart';
import 'package:merchant/models/partner_model.dart';
import 'package:merchant/screens/profile/widgets/profile_error_fallback.dart';
import 'package:merchant/screens/profile/widgets/profile_header.dart';
import 'package:merchant/screens/profile/widgets/profile_options_section.dart';
import 'package:merchant/screens/profile/widgets/profile_stats_card.dart';
import 'package:merchant/screens/profile/widgets/rating_breakdown_card.dart';
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
        isDark ? ZeetColors.surfaceDark : ZeetColors.surfaceAlt;
    final Color surfaceColor =
        isDark ? ZeetColors.surfaceAltDark : ZeetColors.surface;

    // Etat async du profil (pour ELOE). On garde un fallback sur l'auth
    // state pour rendre le header immediatement (nom + tel viennent du
    // login), ce qui evite un flash de skeleton quand le profile tarde.
    final profileState = ref.watch(profileProvider);
    final isOffline = ref.watch(connectivityStatusProvider).maybeWhen(
          data: (bool v) => !v,
          orElse: () => false,
        );
    final bool profileLoaded =
        profileState.status == ProfileStatus.loaded ||
            profileState.profile != null;
    final bool profileLoading =
        profileState.status == ProfileStatus.loading && !profileLoaded;
    final Object? profileError =
        profileState.status == ProfileStatus.error && !profileLoaded
            ? (profileState.errorMessage ?? 'Impossible de charger le profil')
            : null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: ZeetAppBar(
        title: const Text('Mon profil'),
        actions: <Widget>[
          IconButton(
            icon: Icon(isEditing ? Icons.close_rounded : Icons.edit_outlined),
            tooltip: isEditing ? 'Annuler' : 'Modifier',
            onPressed: () {
              ZeetHaptics.tap();
              setState(() => isEditing = !isEditing);
            },
          ),
        ],
      ),
      body: SafeArea(
        // ZeetStateBuilder gere loading / error / offline sur le bloc
        // profile. Le logout reste toujours accessible (fallback error
        // avec CTA "Se deconnecter" en secondary).
        child: ZeetStateBuilder<PartnerData>(
          data: profileState.profile,
          isLoading: profileLoading,
          error: profileError,
          isOffline: isOffline && !profileLoaded,
          onRetry: () => ref.read(profileProvider.notifier).loadAll(),
          errorBuilder: (Object err, VoidCallback? retry) {
            // Error custom : meme en echec de chargement profile, le
            // bouton "Se deconnecter" reste atteignable.
            return ProfileErrorFallback(
              message: err.toString(),
              onRetry: retry,
              onLogout: _confirmLogout,
            );
          },
          builder: (PartnerData _) {
            // Densite POS partner (design-system §4) : padding ecran 16
            // (au lieu de 20) + gaps 14 (au lieu de 24/32). Reduit de
            // ~25% la surface perdue sans rogner la lisibilite.
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ProfileHeader(textColor: textColor),
                  SizedBox(height: 16.h),
                  ProfileStatsCard(
                    textColor: textColor,
                    textLightColor: textLightColor,
                    surfaceColor: surfaceColor,
                    isDark: isDark,
                  ),
                  SizedBox(height: 12.h),
                  RatingBreakdownCard(
                    textColor: textColor,
                    textLightColor: textLightColor,
                    surfaceColor: surfaceColor,
                  ),
                  SizedBox(height: 16.h),
                  ProfileOptionsSection(
                    textColor: textColor,
                    textLightColor: textLightColor,
                    surfaceColor: surfaceColor,
                  ),
                  SizedBox(height: 18.h),
                  _LogoutButton(onLogout: _confirmLogout),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ZeetButton(
      label: 'Déconnexion',
      onPressed: onLogout,
      variant: ZeetButtonVariant.danger,
      size: ZeetButtonSize.md,
      icon: Icons.logout_rounded,
      fullWidth: true,
    );
  }
}
