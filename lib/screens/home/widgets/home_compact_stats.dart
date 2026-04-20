import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:merchant/core/constants/colors.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/providers/dashboard_provider.dart';

/// Bloc 3 stats compactes (Traitees aujourd'hui / Note / Paniers) sous la
/// earnings card du home. Chaque valeur vient du `dashboardProvider`.
///
/// Extrait de `_buildCompactStats` du monolithe home.
class HomeCompactStats extends ConsumerWidget {
  const HomeCompactStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color textColor = scheme.onSurface;
    final Color textLightColor = scheme.onSurfaceVariant;
    final Color surfaceColor = scheme.surface;

    final ordersToday = ref.watch(ordersTodayProvider);
    final rating = ref.watch(ratingProvider);
    final activeCarts = ref.watch(activeCartsProvider);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: scheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          // Commandes du jour — micro-copy contextualisée (neuro-UX).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Traitées aujourd\'hui',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    IconManager.getIcon('shopping_bag',
                        color: ZeetColors.warning, size: 18.r),
                    SizedBox(width: 6.w),
                    ZeetRollingCounter(
                      value: ordersToday,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider vertical
          _buildVerticalDivider(scheme),

          // Note moyenne
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    IconManager.getIcon('star',
                        color: ZeetColors.warning, size: 18.r),
                    SizedBox(width: 6.w),
                    if (rating > 0)
                      ZeetRollingCounter(
                        value: rating,
                        fractionDigits: 1,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        '--',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Divider vertical
          _buildVerticalDivider(scheme),

          // Paniers actifs
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paniers actifs',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    IconManager.getIcon('shopping_cart',
                        color: AppColors.primary, size: 18.r),
                    SizedBox(width: 6.w),
                    ZeetRollingCounter(
                      value: activeCarts,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(ColorScheme scheme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Container(
        width: 1.w,
        height: 40.h,
        color: scheme.outlineVariant,
      ),
    );
  }
}
