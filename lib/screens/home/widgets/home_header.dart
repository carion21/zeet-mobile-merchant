import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/providers/notifications_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:merchant/screens/notifications/index.dart';
import 'package:merchant/screens/root/index.dart';
import 'package:merchant/services/navigation_service.dart';

/// Header du home : avatar resto + nom + toggle ouvert/ferme + menu/cloche.
///
/// Extrait de `_buildModernHeader` + `_showOpenNowSheet` du monolithe home.
/// Utilise `ConsumerWidget` pour lire `partnerDataProvider` et
/// `unreadCountProvider` (badge cloche) sans drilling.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;

    final partnerProfile = ref.watch(partnerDataProvider);
    // Badge cloche piloté par le compteur des notifications non lues
    // (skill zeet-notification-strategy §9 + centre de notifs).
    final unreadNotifications = ref.watch(unreadCountProvider).count;
    final restaurantName = partnerProfile?.name ?? 'Mon Restaurant';
    final isOpen = partnerProfile?.openNow ?? false;
    // Phase 2 gap #5 : indicateur "Override" si l'etat affiche provient
    // d'un toggle manuel (pas du schedule hebdomadaire).
    final isOverrideActive = ref.watch(openNowOverrideActiveProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Stack(
        children: [
          // Row pour les elements gauche et droite
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icone profil a gauche (avec logo si disponible)
              Semantics(
                label: 'Profil restaurant — $restaurantName',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    ZeetHaptics.tap();
                    // Switch vers le tab Profil du RootScaffold (1 tap).
                    ref.read(rootTabProvider.notifier).state = RootTab.profile;
                  },
                  // Avatar 48×48pt — hit target POS partner (M-E10).
                  child: Container(
                    width: 48.w,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: partnerProfile?.picture != null
                        ? ClipOval(
                            child: ZeetImage(
                              url: partnerProfile!.picture,
                              width: 48.w,
                              height: 48.h,
                              fit: BoxFit.cover,
                              errorWidget: Center(
                                child: IconManager.getIcon('person_outline',
                                    size: 24.r, color: AppColors.primary),
                              ),
                            ),
                          )
                        : Center(
                            child: IconManager.getIcon('person_outline',
                                size: 24.r, color: AppColors.primary),
                          ),
                  ),
                ),
              ),

              // Actions a droite : cloche notifications.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {
                      ZeetHaptics.tap();
                      Routes.push(const NotificationsScreen());
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconManager.getIcon('notifications',
                            color: textColor, size: 26.r),
                        if (unreadNotifications > 0)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5.w,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: scheme.surface,
                                  width: 1.5,
                                ),
                              ),
                              constraints: BoxConstraints(minWidth: 16.r),
                              child: Text(
                                unreadNotifications > 9
                                    ? '9+'
                                    : '$unreadNotifications',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Nom du restaurant centre + pastille tappable (toggle ouvert/ferme).
          Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  restaurantName,
                  style: TextStyle(
                    color: textColor.withValues(alpha: textColor.a * 0.7),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Semantics(
                  label: isOpen
                      ? 'Restaurant ouvert, appuyez pour fermer'
                      : 'Restaurant ferme, appuyez pour ouvrir',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20.r),
                    onTap: () => _showOpenNowSheet(
                      context,
                      ref,
                      isOpen,
                      isOverrideActive,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            isOpen ? Icons.circle : Icons.circle_outlined,
                            size: 10.r,
                            color: isOpen
                                ? ZeetColors.success
                                : scheme.onSurfaceVariant,
                            semanticLabel: isOpen ? 'Ouvert' : 'Ferme',
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            isOpen ? 'Ouvert' : 'Ferme',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                          // Pastille "Override" — informe le partner que
                          // l'etat affiche provient d'un toggle manuel et
                          // pas du schedule. Phase 2 gap #5.
                          if (isOverrideActive) ...<Widget>[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Override',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16.r,
                            color: textLightColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Toggle ouvert/ferme — PATCH /v1/partner/open-now (override manuel).
  // ---------------------------------------------------------------------------
  /// Ouvre un bottom sheet de confirmation pour basculer l'etat du restaurant.
  /// Geste critique : on demande confirmation explicite (risque metier eleve).
  ///
  /// Si un override manuel est deja actif ([overrideActive]), on propose
  /// en plus une 3eme option "Revenir aux horaires" qui DELETE l'override
  /// pour repasser sur le calcul du schedule hebdomadaire.
  Future<void> _showOpenNowSheet(
    BuildContext context,
    WidgetRef ref,
    bool currentlyOpen,
    bool overrideActive,
  ) async {
    ZeetHaptics.tap();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool willOpen = !currentlyOpen;

    final _SheetChoice? choice = await showModalBottomSheet<_SheetChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  willOpen
                      ? 'Ouvrir le restaurant ?'
                      : 'Fermer le restaurant ?',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8.h),
                Text(
                  willOpen
                      ? 'Les clients pourront passer commande immediatement.'
                      : 'Les clients ne pourront plus commander tant que vous ne rouvrez pas.',
                  style: tt.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (overrideActive) ...<Widget>[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Un override manuel est actif. Vous pouvez aussi revenir au calcul automatique de vos horaires.',
                            style: tt.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 20.h),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop(_SheetChoice.cancel),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(ctx).pop(_SheetChoice.toggle),
                        style: FilledButton.styleFrom(
                          backgroundColor: willOpen
                              ? ZeetColors.success
                              : scheme.error,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        child: Text(
                          willOpen ? 'Ouvrir' : 'Fermer',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                if (overrideActive) ...<Widget>[
                  SizedBox(height: 12.h),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(ctx).pop(_SheetChoice.clearOverride),
                    icon: Icon(
                      Icons.schedule_outlined,
                      size: 18.sp,
                    ),
                    label: const Text('Revenir aux horaires'),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurface,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (choice == null ||
        choice == _SheetChoice.cancel ||
        !context.mounted) {
      return;
    }
    ZeetHaptics.warning();

    String? error;
    if (choice == _SheetChoice.toggle) {
      error = await ref
          .read(profileProvider.notifier)
          .toggleOpenNow(willOpen);
    } else {
      // _SheetChoice.clearOverride
      error = await ref
          .read(profileProvider.notifier)
          .clearOpenNowOverride();
    }

    if (!context.mounted) return;
    if (error != null) {
      AppToast.showError(context: context, message: error);
    } else {
      AppToast.showSuccess(
        context: context,
        message: choice == _SheetChoice.clearOverride
            ? 'Etat repris depuis vos horaires.'
            : (willOpen
                ? 'Restaurant ouvert. Les clients peuvent commander.'
                : 'Restaurant ferme. Commandes suspendues.'),
      );
    }
  }
}

/// Tri-state pour la sheet open-now : annulation, toggle (PATCH), reset au
/// schedule (DELETE). Permet d'eviter un retour `bool?` ambigu.
enum _SheetChoice { cancel, toggle, clearOverride }
