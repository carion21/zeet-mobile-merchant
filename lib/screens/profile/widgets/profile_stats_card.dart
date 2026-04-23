import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/providers/dashboard_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Carte "Statistiques du jour" : commandes, gains (FCFA),
/// note moyenne + taux de commission.
///
/// Donnees lues depuis [dashboardProvider] via les selecteurs
/// [ordersTodayProvider], [revenueTodayProvider], [ratingProvider],
/// [commissionRateProvider].
class ProfileStatsCard extends ConsumerWidget {
  const ProfileStatsCard({
    required this.textColor,
    required this.textLightColor,
    required this.surfaceColor,
    required this.isDark,
    super.key,
  });

  final Color textColor;
  final Color textLightColor;
  final Color surfaceColor;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersToday = ref.watch(ordersTodayProvider);
    final revenueToday = ref.watch(revenueTodayProvider);
    final rating = ref.watch(ratingProvider);
    final commissionRate = ref.watch(commissionRateProvider);

    // Carte stats style Toss/Wise — 3 blocs tintes semantiquement, plus
    // de dividers boring, icone integree dans chaque bloc. Chaque stat
    // est reconnaissable au glance (couleur + icone + label — skill
    // pos-ergonomics §6 glanceability).
    // - Commandes → primary (orange ZEET = flux metier principal)
    // - Gains     → success (vert = argent entrant, positif)
    // - Note      → warning (or/jaune = etoiles, code couleur universel)
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(ZeetRadius.md),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Statistiques du jour',
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              if (commissionRate != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: ZeetColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ZeetRadius.pill),
                  ),
                  child: Text(
                    'Commission ${commissionRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: ZeetColors.primary,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: _StatTile(
                    icon: Icons.shopping_bag_rounded,
                    tint: ZeetColors.primary,
                    label: 'Traitées',
                    counterValue: ordersToday,
                    textColor: textColor,
                    textLightColor: textLightColor,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _StatTile(
                    icon: Icons.trending_up_rounded,
                    tint: ZeetColors.success,
                    label: 'Gains',
                    customValue: _GainsValue(
                      amount: revenueToday,
                      color: textColor,
                    ),
                    textColor: textColor,
                    textLightColor: textLightColor,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _StatTile(
                    icon: Icons.star_rounded,
                    tint: ZeetColors.warning,
                    label: 'Note',
                    customValue: _RatingValue(
                      rating: rating,
                      color: textColor,
                    ),
                    textColor: textColor,
                    textLightColor: textLightColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc d'une stat — fond tinte subtil (8% alpha), icone en haut-left,
/// valeur gros en bas-left, label dessous. Hauteur intrinseque uniforme
/// sur toute la rangee (IntrinsicHeight parent).
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.textColor,
    required this.textLightColor,
    this.counterValue,
    this.customValue,
  }) : assert(counterValue != null || customValue != null,
            'counterValue OR customValue requis');

  final IconData icon;
  final Color tint;
  final String label;
  final Color textColor;
  final Color textLightColor;

  /// Si non-null → rendu via ZeetRollingCounter (entiers).
  final int? counterValue;

  /// Pour les valeurs custom (FCFA formate, note "4.5", "--"...).
  final Widget? customValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZeetRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Icone pill — format compact 28x28 avec fond tinte un peu plus
          // sature. Immediatement identifiable en 300ms (glance §6).
          Container(
            width: 28.w,
            height: 28.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(ZeetRadius.sm),
            ),
            child: Icon(icon, color: tint, size: 16.r),
          ),
          SizedBox(height: 10.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: customValue ??
                ZeetRollingCounter(
                  value: counterValue ?? 0,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -0.3,
                  ),
                ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              color: textLightColor,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Montant gains — utilise `ZeetMoney` (format FCFA avec espace
/// insecable, aligne sur micro-copy §10). Style bold compact identique
/// aux autres stats.
class _GainsValue extends StatelessWidget {
  const _GainsValue({required this.amount, required this.color});
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ZeetMoney(
      amount: amount,
      currency: ZeetCurrency.fcfa,
      style: TextStyle(
        color: color,
        fontSize: 18.sp,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: -0.3,
      ),
    );
  }
}

/// Note moyenne — chiffre + "/5" discret. `--` si pas encore d'avis
/// (backend retourne 0 → ELOE empty state gere au niveau de la valeur).
class _RatingValue extends StatelessWidget {
  const _RatingValue({required this.rating, required this.color});
  final double rating;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) {
      return Text(
        '--',
        style: TextStyle(
          color: color.withValues(alpha: 0.5),
          fontSize: 22.sp,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: color,
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          ' /5',
          style: TextStyle(
            color: color.withValues(alpha: 0.45),
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
