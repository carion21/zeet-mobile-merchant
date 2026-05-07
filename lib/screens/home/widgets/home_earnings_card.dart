import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:merchant/core/constants/icons.dart';
import 'package:merchant/core/widgets/business_day_label.dart';
import 'package:merchant/models/business_day_window.dart';
import 'package:merchant/screens/root/index.dart';

/// Card "Gains du jour" — refonte plein soleil / cuisine bruyante.
///
/// Avant : image background + Colors.white → contraste imprevisible et
/// illisible en exterieur (luminosite > 50 000 lux). Refonte cible le
/// **plein soleil** :
///
/// - Fond solid `surface` (blanc en light, anthracite en dark) → contraste
///   maximal du texte montant (~17:1 AAA+ vs ~5:1 sur image avant).
/// - Montant en `ink` (quasi-noir) `40.sp w900` avec `tabularFigures` :
///   les chiffres ont une largeur fixe → le rolling counter ne danse plus.
/// - Bord gauche 4dp `primary` orange ZEET = signal branding **sans**
///   sacrifier le contraste (skill `zeet-pos-ergonomics` §6 glanceability :
///   couleur + icone + label, jamais texte sur image complexe).
/// - Label "GAINS DU JOUR" en small caps `primary` letterSpacing 1.5 →
///   reperable en peripherique, ne concurrence pas le montant.
/// - Footer business day en `inkMuted` solide (vs alpha:0.75 avant).
///
/// Tap = switch vers le tab Wallet du RootScaffold (3-clicks-rule partner :
/// 1 tap, zero push). Haptic success on tap (feedback POS obligatoire).
class HomeEarningsCard extends ConsumerWidget {
  const HomeEarningsCard({
    super.key,
    required this.earnings,
    required this.isDark,
    this.businessDay,
  });

  final double earnings;
  final bool isDark;

  /// Fenetre de journee commerciale active (cutoff 04h par defaut).
  /// Quand fournie, affiche "Depuis 04h00 · reinit dans Xh Ymin" sous le
  /// montant pour expliquer que le compteur ne suit plus minuit civil.
  final BusinessDayWindow? businessDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tokens contrastes maximaux. Ratios mesures :
    // - ink (#0F1115) sur surface (#FFFFFF)        → 17.4:1 AAA+
    // - inkDark (#F7F8FA) sur surfaceAltDark (#1A1E26) → 14.2:1 AAA+
    final Color background =
        isDark ? ZeetColors.surfaceAltDark : ZeetColors.surface;
    final Color amountColor = isDark ? ZeetColors.inkDark : ZeetColors.ink;
    final Color mutedColor =
        isDark ? ZeetColors.inkMutedDark : ZeetColors.inkMuted;
    final Color borderColor =
        isDark ? ZeetColors.lineDark : ZeetColors.line;

    return GestureDetector(
      onTap: () async {
        await ZeetHaptics.success();
        ref.read(rootTabProvider.notifier).state = RootTab.wallet;
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          // Degrade subtil orange→ambre 5% (skill `zeet-design-system`
          // §identite : signature visuelle ZEET sans nuire au contraste).
          // Le degrade se voit a peine — il donne un sentiment "card vivante"
          // sans saturer. Ratio contraste preserve (>14:1).
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              background,
              ZeetColors.primary.withValues(alpha: isDark ? 0.06 : 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(ZeetRadius.md),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ZeetRadius.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Bord gauche orange ZEET — signal branding visible meme
                // en peripherique, sans concurrence avec le contraste du
                // montant central.
                Container(width: 4.w, color: ZeetColors.primary),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 18.h, 16.w, 18.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Header : label small caps a gauche + icone
                        // wallet a droite. Hierarchie : le label oriente,
                        // le montant tient le focus.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'GAINS DU JOUR',
                                style: TextStyle(
                                  color: ZeetColors.primary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color: ZeetColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: IconManager.getIcon(
                                'wallet',
                                color: ZeetColors.primary,
                                size: 20.r,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        // Montant : taille extra-large, w900, tabular pour
                        // que le rolling counter ne fasse pas danser le
                        // layout. FittedBox = secours sur tres petits ecrans.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: ZeetRollingCounter(
                            value: earnings,
                            suffix: ' FCFA',
                            thousandSeparator: ' ',
                            style: TextStyle(
                              color: amountColor,
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              height: 1.05,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        if (businessDay != null) ...<Widget>[
                          SizedBox(height: 8.h),
                          BusinessDayLabel(
                            businessDay: businessDay!,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
