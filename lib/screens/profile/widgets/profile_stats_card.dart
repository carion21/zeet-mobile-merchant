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
        children: <Widget>[
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
            children: <Widget>[
              Expanded(
                child: _StatItem(
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
                  children: <Widget>[
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
                child: _StatItem(
                  label: 'Note',
                  value: rating > 0 ? rating.toStringAsFixed(1) : '--',
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ),
            ],
          ),

          // Taux de commission (si disponible)
          if (commissionRate != null) ...<Widget>[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: ZeetColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
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
                      color: ZeetColors.primary,
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
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.textColor,
    required this.textLightColor,
  });

  final String label;
  final String value;
  final Color textColor;
  final Color textLightColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
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
}
