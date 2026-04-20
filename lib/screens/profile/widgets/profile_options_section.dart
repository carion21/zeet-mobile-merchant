import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/screens/profile/widgets/profile_overlay_toggle.dart';
import 'package:merchant/screens/root/index.dart';
import 'package:merchant/screens/service_closed/index.dart';
import 'package:merchant/screens/tickets/index.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/services/overlay_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Bloc des options du profil : mes commandes, portefeuille,
/// bulle flottante (Android only) et aide/support.
///
/// Les entries "Mon menu", "Statistiques", "Parametres" sont
/// intentionnellement retirees (hors-scope mobile, cf. audit
/// partner 2026-04-15 §6).
class ProfileOptionsSection extends ConsumerWidget {
  const ProfileOptionsSection({
    required this.textColor,
    required this.textLightColor,
    required this.surfaceColor,
    super.key,
  });

  final Color textColor;
  final Color textLightColor;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: <Widget>[
          _ProfileOptionTile(
            title: 'Mes commandes',
            icon: 'history',
            onTap: () {
              ZeetHaptics.tap();
              // Switch tab — evite le push redondant d'OrdersScreen
              // depuis le RootScaffold.
              ref.read(rootTabProvider.notifier).state = RootTab.orders;
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _ProfileOptionTile(
            title: 'Portefeuille',
            icon: 'wallet',
            onTap: () {
              ZeetHaptics.tap();
              ref.read(rootTabProvider.notifier).state = RootTab.wallet;
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _ProfileOptionTile(
            title: 'Mes virements',
            icon: 'payouts',
            onTap: () {
              ZeetHaptics.tap();
              Routes.navigateTo(Routes.payouts);
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _ProfileOptionTile(
            title: 'Horaires d\'ouverture',
            icon: 'schedule',
            onTap: () {
              ZeetHaptics.tap();
              Routes.navigateTo(Routes.openingHours);
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          if (OverlayService.instance.isSupported)
            ProfileOverlayToggle(
              textColor: textColor,
              textLightColor: textLightColor,
            ),
          _ProfileOptionTile(
            title: 'Aide et support',
            icon: 'help',
            onTap: () {
              ZeetHaptics.tap();
              Routes.push(
                const TicketsScreen(),
                style: ZeetTransitionStyle.sharedAxisVertical,
              );
            },
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          // Cloturer la journee — peak moment fin de service
          // (cf. skill zeet-neuro-ux §8 peak-end rule). Ouvre le recap
          // anime des KPIs du jour avant un eventuel rangement.
          _ProfileOptionTile(
            title: 'Cloturer la journee',
            icon: 'check',
            onTap: () {
              ZeetHaptics.tap();
              Routes.push(
                const ServiceClosedRecapScreen(),
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
}

class _ProfileOptionTile extends StatelessWidget {
  const _ProfileOptionTile({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.showDivider,
    required this.textColor,
    required this.textLightColor,
  });

  final String title;
  final String icon;
  final VoidCallback onTap;
  final bool showDivider;
  final Color textColor;
  final Color textLightColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          borderRadius: showDivider
              ? BorderRadius.zero
              : BorderRadius.vertical(bottom: Radius.circular(12.r)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Row(
              children: <Widget>[
                // Icon slot 48x48pt (seuil POS partner §1, m-06).
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: ZeetColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZeetRadius.md),
                  ),
                  child: Center(
                    child: IconManager.getIcon(
                      icon,
                      color: ZeetColors.primary,
                      size: 22.r,
                    ),
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
                IconManager.getIcon(
                  'arrow_forward',
                  color: textLightColor,
                  size: 16.r,
                ),
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
}
