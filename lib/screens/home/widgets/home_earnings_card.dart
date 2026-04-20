import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:merchant/core/constants/assets.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/screens/root/index.dart';

/// Card "Gains du jour" avec fond wallet + rolling counter anime.
///
/// Tap = switch vers le tab Wallet du RootScaffold (3-clicks-rule partner :
/// 1 tap, zero push). Extrait de `_buildEarningsCard` du monolithe home.
class HomeEarningsCard extends ConsumerWidget {
  const HomeEarningsCard({
    super.key,
    required this.earnings,
    required this.isDark,
  });

  final double earnings;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletBackground =
        isDark ? AppAssets.darkWallet : AppAssets.lightWallet;

    // Raccourci 3-clicks-rule partner : tap sur la card "Gains du jour"
    // bascule vers le tab Portefeuille du RootScaffold (1 tap, zéro push).
    return GestureDetector(
      onTap: () async {
        await ZeetHaptics.success();
        ref.read(rootTabProvider.notifier).state = RootTab.wallet;
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          image: DecorationImage(
            image: AssetImage(walletBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gains du jour',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        // Rolling counter — signature ZEET : le montant qui
                        // change doit etre anime (dopamine anticipation).
                        child: ZeetRollingCounter(
                          value: earnings,
                          suffix: ' FCFA',
                          thousandSeparator: ' ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconManager.getIcon('wallet',
                      color: Colors.white, size: 28.r),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
