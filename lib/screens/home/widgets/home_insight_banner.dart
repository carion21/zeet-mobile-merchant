// lib/screens/home/widgets/home_insight_banner.dart
//
// Bandeau insight rotatif sur le Home dashboard. Skill `zeet-neuro-ux`
// §13 (un chiffre seul n'est pas une histoire) + social proof : transforme
// les KPIs bruts (top products / paniers / rating) en messages naturels FR
// qui aident le partner a contextualiser sa journee.
//
// Data sources :
//  - dashboardProvider.summary.topProducts (premier = top vente du jour)
//  - cartStatsProvider (paniers actifs en train d'etre composes)
//  - dashboardProvider.summary.rating (note moyenne)
//
// Rotation : 1 insight a la fois, change toutes les 8s sans transition
// brutale (cross-fade 400ms). Reduced motion → static (premier seulement).
//
// Tap → ouvre l'ecran cible (top product → ProductsScreen, paniers → drill
// down, rating → profile).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:merchant/core/tokens/durations.dart';
import 'package:merchant/providers/cart_partner_provider.dart';
import 'package:merchant/providers/dashboard_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

class HomeInsightBanner extends ConsumerStatefulWidget {
  const HomeInsightBanner({super.key});

  @override
  ConsumerState<HomeInsightBanner> createState() =>
      _HomeInsightBannerState();
}

class _HomeInsightBannerState extends ConsumerState<HomeInsightBanner> {
  int _index = 0;
  Timer? _rotator;

  @override
  void initState() {
    super.initState();
    _rotator = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % 4);
    });
  }

  @override
  void dispose() {
    _rotator?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final summary = ref.watch(dashboardProvider).summary;
    final activeCarts = ref.watch(activeCartsCountProvider);
    final cartsTotal = ref.watch(cartsTotalAmountProvider);

    final List<_Insight> insights = <_Insight>[];

    // Top vente — affiche si au moins 1 commande livree avec produit identifie.
    if (summary != null &&
        summary.topProducts.isNotEmpty &&
        summary.topProducts.first.ordersCount > 0) {
      final top = summary.topProducts.first;
      insights.add(_Insight(
        icon: Icons.local_fire_department_rounded,
        tint: ZeetColors.primary,
        text: top.ordersCount == 1
            ? 'Top vente : ${top.name} (1 cmde)'
            : 'Top vente : ${top.name} (${top.ordersCount} cmdes)',
      ));
    }

    // Paniers actifs — info de conversion potentielle.
    if (activeCarts > 0) {
      insights.add(_Insight(
        icon: Icons.shopping_cart_rounded,
        tint: ZeetColors.success,
        text: cartsTotal > 0
            ? '$activeCarts panier${activeCarts > 1 ? 's' : ''} actif${activeCarts > 1 ? 's' : ''} · ${_fcfa(cartsTotal)}'
            : '$activeCarts panier${activeCarts > 1 ? 's' : ''} actif${activeCarts > 1 ? 's' : ''}',
      ));
    }

    // Note moyenne — affiche si >= 4.0 (positif a renforcer, neuro-UX
    // peak-end : valoriser ce qui marche au lieu de pointer le negatif).
    if (summary != null && summary.rating >= 4.0) {
      insights.add(_Insight(
        icon: Icons.star_rounded,
        tint: ZeetColors.warning,
        text:
            'Note ${summary.rating.toStringAsFixed(1)}/5 — vos clients vous remercient',
      ));
    }

    // Encouragement par defaut si aucune autre data — evite un banner vide
    // au demarrage de service.
    if (insights.isEmpty) {
      insights.add(const _Insight(
        icon: Icons.wb_sunny_rounded,
        tint: ZeetColors.primary,
        text: 'Bonne journée — les commandes vont arriver',
      ));
    }

    final current = insights[_index % insights.length];
    final reduceMotion =
        MediaQuery.of(context).disableAnimations;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: current.tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZeetRadius.md),
        border: Border.all(
          color: current.tint.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : ZeetDuration.notice,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: Row(
          key: ValueKey<int>(_index),
          children: <Widget>[
            Icon(current.icon, color: current.tint, size: 16.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                current.text,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fcfa(double amount) {
    final s = amount.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} FCFA';
  }
}

class _Insight {
  const _Insight({
    required this.icon,
    required this.tint,
    required this.text,
  });

  final IconData icon;
  final Color tint;
  final String text;
}
