import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/constants/links.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/screens/profile/widgets/profile_overlay_toggle.dart';
import 'package:merchant/screens/root/index.dart';
import 'package:merchant/screens/service_closed/index.dart';
import 'package:merchant/screens/tickets/index.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:merchant/services/overlay_service.dart';
import 'package:url_launcher/url_launcher.dart';
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
    // Regroupement en 2 sections pour respecter neuro-UX §1 (≤ 5 choix
    // visibles simultanes) et design-system §5 (hierarchie visuelle).
    // Section 1 "Activite" = flux metier (commandes, portefeuille).
    // Section 2 "Restaurant" = parametres du resto.
    // Cloturer la journee = CTA peak distinct, juste au-dessus du logout.
    final List<_OptionItem> activity = <_OptionItem>[
      _OptionItem(
        title: 'Mes commandes',
        icon: 'history',
        onTap: () {
          ZeetHaptics.tap();
          ref.read(rootTabProvider.notifier).state = RootTab.orders;
        },
      ),
      _OptionItem(
        title: 'Portefeuille',
        icon: 'wallet',
        onTap: () {
          ZeetHaptics.tap();
          ref.read(rootTabProvider.notifier).state = RootTab.wallet;
        },
      ),
      _OptionItem(
        title: 'Mes virements',
        icon: 'payouts',
        onTap: () {
          ZeetHaptics.tap();
          Routes.navigateTo(Routes.payouts);
        },
      ),
    ];

    final List<Widget> restaurant = <Widget>[
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
        showDivider: false,
        textColor: textColor,
        textLightColor: textLightColor,
      ),
    ];

    // Légal — pages publiques zeet.geasscorp.com (CGU + confidentialité).
    // Section discrète en bas du profil pour respecter App Review
    // Guideline 5.1.1 (consentement) sans alourdir l'UI principale.
    final List<Widget> legal = <Widget>[
      _ProfileOptionTile(
        title: 'Conditions d\'utilisation',
        icon: 'document',
        onTap: () {
          ZeetHaptics.tap();
          _openExternal(context, ZeetLinks.terms);
        },
        showDivider: true,
        textColor: textColor,
        textLightColor: textLightColor,
      ),
      _ProfileOptionTile(
        title: 'Politique de confidentialité',
        icon: 'privacy',
        onTap: () {
          ZeetHaptics.tap();
          _openExternal(context, ZeetLinks.privacy);
        },
        showDivider: false,
        textColor: textColor,
        textLightColor: textLightColor,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionLabel(label: 'Activité', color: textLightColor),
        SizedBox(height: 6.h),
        _OptionsCard(
          surfaceColor: surfaceColor,
          children: <Widget>[
            for (int i = 0; i < activity.length; i++)
              _ProfileOptionTile(
                title: activity[i].title,
                icon: activity[i].icon,
                onTap: activity[i].onTap,
                showDivider: i < activity.length - 1,
                textColor: textColor,
                textLightColor: textLightColor,
              ),
          ],
        ),
        SizedBox(height: 14.h),
        _SectionLabel(label: 'Restaurant', color: textLightColor),
        SizedBox(height: 6.h),
        _OptionsCard(
          surfaceColor: surfaceColor,
          children: restaurant,
        ),
        SizedBox(height: 14.h),
        _SectionLabel(label: 'Légal', color: textLightColor),
        SizedBox(height: 6.h),
        _OptionsCard(
          surfaceColor: surfaceColor,
          children: legal,
        ),
        SizedBox(height: 14.h),
        // Peak moment — fin de service. CTA distinct pour emphase
        // (neuro-UX §8 peak-end rule).
        _PeakCta(
          textColor: textColor,
          onTap: () {
            ZeetHaptics.tap();
            Routes.push(
              const ServiceClosedRecapScreen(),
              style: ZeetTransitionStyle.sharedAxisVertical,
            );
          },
        ),
      ],
    );
  }

  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppToast.showError(
        context: context,
        message: 'Impossible d\'ouvrir le lien.',
      );
    }
  }
}

class _OptionItem {
  const _OptionItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String icon;
  final VoidCallback onTap;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _OptionsCard extends StatelessWidget {
  const _OptionsCard({
    required this.surfaceColor,
    required this.children,
  });
  final Color surfaceColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(ZeetRadius.md),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// CTA "Cloturer la journee" — peak moment fin de service. Pilule pleine
/// largeur, style ghost teint primary, 52pt de haut (hit POS confort).
class _PeakCta extends StatelessWidget {
  const _PeakCta({required this.textColor, required this.onTap});
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZeetColors.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(ZeetRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.check_circle_outline_rounded,
                color: ZeetColors.primary,
                size: 22.r,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Clôturer la journée',
                  style: TextStyle(
                    color: ZeetColors.primary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: ZeetColors.primary,
                size: 18.r,
              ),
            ],
          ),
        ),
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
    // Tile dense POS — 56pt de hauteur (pos-ergonomics §7 "liste dense,
    // jamais card-soupe"). Icon slot 40x40 (vs 48 avant), padding
    // vertical 10 (vs 16), font 15sp (vs 16).
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: 56.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36.w,
                  height: 36.h,
                  decoration: BoxDecoration(
                    color: ZeetColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZeetRadius.sm),
                  ),
                  child: Center(
                    child: IconManager.getIcon(
                      icon,
                      color: ZeetColors.primary,
                      size: 18.r,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textLightColor.withValues(alpha: 0.6),
                  size: 20.r,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1.h,
            thickness: 1,
            indent: 62.w,
            endIndent: 14.w,
            color: textLightColor.withValues(alpha: 0.1),
          ),
      ],
    );
  }
}
