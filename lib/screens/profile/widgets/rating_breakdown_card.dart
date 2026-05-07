// lib/screens/profile/widgets/rating_breakdown_card.dart
//
// Carte "Avis clients" — exploite GET /v1/partner/stats/rating (distribution
// 1-5 etoiles + total avis + moyenne) pour afficher un breakdown visuel.
//
// L'endpoint est branche dans `statsProvider` mais aucune UI ne le consomme :
// ce widget comble le gap, expose dans le profil partner sous la card stats
// du jour. Skill `zeet-states-elae` (loading skeleton, empty si 0 avis,
// error muet — la card disparait si l'endpoint plante).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/providers/stats_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

class RatingBreakdownCard extends ConsumerStatefulWidget {
  const RatingBreakdownCard({
    required this.surfaceColor,
    required this.textColor,
    required this.textLightColor,
    super.key,
  });

  final Color surfaceColor;
  final Color textColor;
  final Color textLightColor;

  @override
  ConsumerState<RatingBreakdownCard> createState() =>
      _RatingBreakdownCardState();
}

class _RatingBreakdownCardState extends ConsumerState<RatingBreakdownCard> {
  bool _expanded = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Lazy load : on ne charge les stats detaillees qu'a la 1ere ouverture
      // de l'ecran profil pour ne pas alourdir le boot.
      final s = ref.read(statsProvider);
      if (s.status == StatsStatus.initial && !_loaded) {
        _loaded = true;
        ref.read(statsProvider.notifier).loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rating = ref.watch(ratingStatsProvider);
    final isLoading = ref.watch(statsProvider).status == StatsStatus.loading &&
        rating == null;

    if (rating == null && !isLoading) {
      // Endpoint en echec ou pas charge — la card reste invisible (pas de
      // bruit dans le profil). Le user n'a rien perdu : la note moyenne
      // est deja visible dans ProfileStatsCard.
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(ZeetRadius.md),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () {
              ZeetHaptics.tap();
              setState(() => _expanded = !_expanded);
            },
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.star_rounded,
                  color: ZeetColors.warning,
                  size: 18.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Avis clients',
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (rating != null) ...<Widget>[
                  Text(
                    rating.averageRating.toStringAsFixed(1),
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '· ${rating.totalReviews} avis',
                    style: TextStyle(
                      color: widget.textLightColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4.w),
                ],
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: widget.textLightColor,
                  size: 18.sp,
                ),
              ],
            ),
          ),
          if (_expanded && rating != null && rating.totalReviews > 0) ...<Widget>[
            SizedBox(height: 12.h),
            for (final star in const [5, 4, 3, 2, 1])
              _StarRow(
                stars: star,
                count: rating.distribution[star] ?? 0,
                total: rating.totalReviews,
                textColor: widget.textColor,
                textLightColor: widget.textLightColor,
              ),
          ] else if (_expanded && isLoading) ...<Widget>[
            SizedBox(height: 8.h),
            const ZeetSkeletonList(itemCount: 5, itemHeight: 24),
          ] else if (_expanded &&
              rating != null &&
              rating.totalReviews == 0) ...<Widget>[
            SizedBox(height: 12.h),
            Text(
              'Aucun avis pour le moment.',
              style: TextStyle(
                color: widget.textLightColor,
                fontSize: 12.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.stars,
    required this.count,
    required this.total,
    required this.textColor,
    required this.textLightColor,
  });

  final int stars;
  final int count;
  final int total;
  final Color textColor;
  final Color textLightColor;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28.w,
            child: Text(
              '$stars★',
              style: TextStyle(
                color: textColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8.h,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(
                  stars >= 4
                      ? ZeetColors.success
                      : stars == 3
                          ? ZeetColors.warning
                          : ZeetColors.danger,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 36.w,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textLightColor,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
