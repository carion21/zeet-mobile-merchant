// lib/screens/service_closed/index.dart
//
// ServiceClosedRecapScreen — Phase 5 peak moment clôture service partner.
//
// Neuro-UX : fin de service = moment pic pour le partner (sentiment de
// productivité, récompense professionnelle). Skill `zeet-neuro-ux` §8
// peak-end rule. Mais attention : **ton pro sobre et vouvoiement**
// (skill `zeet-micro-copy` §2 — partner), pas d'emoji, pas de confetti.
//
// Le skill `zeet-pos-ergonomics` §2bis autorise la cascade d'apparition
// UNIQUEMENT sur le peak-end partner (fin de service), JAMAIS pendant
// le service. L'écran est exclusivement déclenché manuellement depuis
// le home (CTA "Clôturer le service") ou le profil.
//
// Contenu :
//   1. Titre "Service clôturé" + sous-titre ("Voici le résumé de votre journée.")
//   2. 4 cartes stats en cascade 25ms (stagger POS partner) :
//      - Commandes traitées (rolling counter)
//      - CA journalier (rolling counter FCFA)
//      - Panier moyen (calcul local CA/count)
//      - Taux d'acceptation (accepté vs annulé, via countsByStatus)
//   3. Note moyenne si dispo (optionnel)
//   4. Comparaison "+X% vs hier" si stats dispo (optionnel, discret)
//   5. CTA "Terminer" pleine largeur : toggle open-now à false + home.
//
// Haptic : success() au mount + lightImpact() à la fin du stagger.
//
// Respect `MediaQuery.disableAnimations` : stagger/animations désactivées.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:merchant/core/constants/copy.dart';
import 'package:merchant/core/widgets/toastification.dart';
import 'package:merchant/providers/dashboard_provider.dart';
import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Ecran recap de fin de service (peak moment partner).
///
/// Se nourrit de [dashboardProvider] pour les KPIs journaliers et de
/// [ordersListProvider] pour le `countsByStatus` qui permet de calculer
/// le taux d'acceptation (accepted / (accepted + cancelled + refused)).
class ServiceClosedRecapScreen extends ConsumerStatefulWidget {
  const ServiceClosedRecapScreen({super.key});

  @override
  ConsumerState<ServiceClosedRecapScreen> createState() =>
      _ServiceClosedRecapScreenState();
}

class _ServiceClosedRecapScreenState
    extends ConsumerState<ServiceClosedRecapScreen> {
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();

    // Haptic success au mount (peak moment ; reste subtil, 1 fois).
    // Skill zeet-motion-system §10.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ZeetHaptics.success();

      // Force refresh du dashboard + compteurs pour avoir les valeurs
      // cibles des rolling counters.
      final dState = ref.read(dashboardProvider);
      if (dState.status == DashboardStatus.initial ||
          dState.status == DashboardStatus.error) {
        ref.read(dashboardProvider.notifier).loadSummary();
      }
      ref.read(ordersListProvider.notifier).refreshCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final Color textColor = isDark ? ZeetColors.inkDark : ZeetColors.ink;
    final Color textMuted =
        isDark ? ZeetColors.inkMutedDark : ZeetColors.inkMuted;
    final Color bg = isDark ? ZeetColors.surfaceDark : ZeetColors.surfaceAlt;
    final Color cardBg =
        isDark ? ZeetColors.surfaceAltDark : ZeetColors.surface;

    final summary = ref.watch(dashboardProvider).summary;
    final counts = ref.watch(ordersListProvider).counts;

    final int orders = summary?.ordersToday ?? 0;
    final double revenue = summary?.revenueToday ?? 0;
    final double rating = summary?.rating ?? 0;

    // Panier moyen : calcul local (pas de champ backend dedie).
    // Fallback 0 si 0 commande (cohérent avec la mise en forme rolling).
    final double avgBasket = orders > 0 ? revenue / orders : 0;

    // Taux d'acceptation = delivered+confirmed / (delivered+confirmed+cancelled+refused).
    // Utilise les compteurs absolus renvoyes par GET /counts-by-status. On
    // inclut tous les statuts "aboutis positivement" pour la journee.
    final int accepted = _sumStatuses(counts, const <String>[
      'confirmed',
      'preparing',
      'ready',
      'picked-up',
      'delivered',
    ]);
    final int refused = _sumStatuses(counts, const <String>[
      'cancelled',
      'refused',
    ]);
    final int decided = accepted + refused;
    final double acceptanceRate =
        decided > 0 ? (accepted / decided) * 100.0 : 100.0;

    final List<_StatData> stats = <_StatData>[
      _StatData(
        icon: Icons.receipt_long_rounded,
        label: Copy.statOrdersHandled,
        value: orders.toDouble(),
        fractionDigits: 0,
        suffix: '',
        accent: ZeetColors.primary,
      ),
      _StatData(
        icon: Icons.payments_rounded,
        label: Copy.statRevenue,
        value: revenue,
        fractionDigits: 0,
        suffix: '\u00A0FCFA',
        accent: ZeetColors.success,
      ),
      _StatData(
        icon: Icons.shopping_basket_rounded,
        label: Copy.statAverageBasket,
        value: avgBasket,
        fractionDigits: 0,
        suffix: '\u00A0FCFA',
        accent: ZeetColors.info,
      ),
      _StatData(
        icon: Icons.check_circle_outline_rounded,
        label: Copy.statAcceptanceRate,
        value: acceptanceRate,
        fractionDigits: 0,
        suffix: '\u2009%',
        accent: ZeetColors.warning,
      ),
      if (rating > 0)
        _StatData(
          icon: Icons.star_rounded,
          label: Copy.statRating,
          value: rating,
          fractionDigits: 1,
          suffix: '\u2009/\u20095',
          accent: ZeetColors.warning,
        ),
    ];

    return Scaffold(
      backgroundColor: bg,
      // Pas d'AppBar : moment de clôture, on ne distrait pas. Le retour
      // passe uniquement par le CTA.
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZeetSpacing.x5,
                vertical: ZeetSpacing.x4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: ZeetSpacing.x4),
                  _Header(textColor: textColor, textMuted: textMuted),
                  const SizedBox(height: ZeetSpacing.x6),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: stats.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: ZeetSpacing.x3),
                      itemBuilder: (BuildContext context, int index) {
                        final _StatData stat = stats[index];
                        final Widget tile = _StatTile(
                          stat: stat,
                          textColor: textColor,
                          textMuted: textMuted,
                          cardBg: cardBg,
                        );
                        if (reduceMotion) return tile;
                        // Cascade 25ms/item — exception peak-end partner
                        // (skill zeet-pos-ergonomics §2bis : cascade OK sur
                        // peak-end MAIS PAS pendant service).
                        // `ZeetMotion.staggerPartner` = 0 (pas de stagger en
                        // POS standard) — on force 25ms ici car c'est un
                        // peak moment, pas un ecran operationnel.
                        const Duration peakStagger =
                            Duration(milliseconds: 25);
                        return tile
                            .animate()
                            .fadeIn(
                              duration: ZeetMotion.sm,
                              delay: peakStagger * index,
                              curve: ZeetCurves.decelerate,
                            )
                            .slideY(
                              begin: 0.1,
                              end: 0,
                              duration: ZeetMotion.sm,
                              delay: peakStagger * index,
                              curve: ZeetCurves.decelerate,
                            );
                      },
                    ),
                  ),
                  const SizedBox(height: ZeetSpacing.x4),
                  SafeArea(
                    top: false,
                    child: ZeetButton.primary(
                      label: Copy.serviceClosedFinish,
                      size: ZeetButtonSize.lg,
                      fullWidth: true,
                      loading: _isFinishing,
                      onPressed: _isFinishing ? null : () => _finish(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Finalise la clôture : toggle open-now à false + navigate home.
  /// Haptic warning sur confirmation (action irréversible pour le
  /// service), haptic tap à l'appui bouton.
  Future<void> _finish(BuildContext context) async {
    ZeetHaptics.tap();
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    try {
      // Toggle open-now à false avec raison "service_closed" pour la trace
      // backend (le profile_provider gere l'optimistic update + override).
      final String? err = await ref
          .read(profileProvider.notifier)
          .toggleOpenNow(false, reason: 'service_closed');

      if (!mounted || !context.mounted) return;
      if (err != null) {
        // Pas fatal : on affiche un warning mais on continue vers home
        // (le partner peut toggle manuellement plus tard depuis le header).
        AppToast.showWarning(context: context, message: err);
      } else {
        ZeetHaptics.success();
        AppToast.showSuccess(
          context: context,
          message: Copy.serviceClosedToast,
        );
      }

      // Bref delai pour que le toast soit percu avant la navigation.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      // Retour au root en effacant la stack — reouverture de l'app
      // demain sur home comme attendu.
      Routes.navigateAndRemoveAll(Routes.root);
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  /// Somme les compteurs pour un ensemble de statuts. Gere l'absence
  /// silencieusement (0) — le recap reste coherent meme si l'API n'a
  /// pas encore repondu.
  int _sumStatuses(
    dynamic counts,
    List<String> keys,
  ) {
    if (counts == null) return 0;
    int total = 0;
    try {
      for (final String k in keys) {
        total += (counts.get(k) as int?) ?? 0;
      }
    } catch (_) {
      // countsByStatus peut etre null ou mal type en debut de session.
      return 0;
    }
    return total;
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.textColor, required this.textMuted});

  final Color textColor;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final Widget title = Text(
      Copy.serviceClosedTitle,
      style: TextStyle(
        color: textColor,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
      ),
    );
    final Widget subtitle = Padding(
      padding: const EdgeInsets.only(top: ZeetSpacing.x2),
      child: Text(
        Copy.serviceClosedSubtitle,
        style: TextStyle(
          color: textMuted,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
      ),
    );

    if (reduceMotion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[title, subtitle],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        title
            .animate()
            .fadeIn(duration: ZeetMotion.sm, curve: ZeetCurves.decelerate)
            .slideY(begin: -0.05, end: 0, duration: ZeetMotion.sm),
        subtitle
            .animate()
            .fadeIn(
              delay: const Duration(milliseconds: 80),
              duration: ZeetMotion.sm,
              curve: ZeetCurves.decelerate,
            ),
      ],
    );
  }
}

class _StatData {
  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.fractionDigits,
    required this.suffix,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final double value;
  final int fractionDigits;
  final String suffix;
  final Color accent;
}

class _StatTile extends StatefulWidget {
  const _StatTile({
    required this.stat,
    required this.textColor,
    required this.textMuted,
    required this.cardBg,
  });

  final _StatData stat;
  final Color textColor;
  final Color textMuted;
  final Color cardBg;

  @override
  State<_StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<_StatTile> {
  double _lastAnimatedValue = 0;

  @override
  void didUpdateWidget(covariant _StatTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stat.value != widget.stat.value) {
      // Haptic léger à chaque transition de chiffre (skill zeet-motion-system
      // §6 "Number animation grammar" — signale le pic dopaminergique
      // sans saturer). Seulement si la valeur augmente (pas un reset).
      if (widget.stat.value > _lastAnimatedValue) {
        ZeetHaptics.success();
      }
      _lastAnimatedValue = widget.stat.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZeetSpacing.x4,
        vertical: ZeetSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: ZeetRadius.brMd,
        border: Border.all(
          color: widget.textMuted.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.stat.accent.withValues(alpha: 0.12),
              borderRadius: ZeetRadius.brMd,
            ),
            child: Icon(
              widget.stat.icon,
              color: widget.stat.accent,
              size: 24,
              semanticLabel: widget.stat.label,
            ),
          ),
          const SizedBox(width: ZeetSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.stat.label,
                  style: TextStyle(
                    color: widget.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: ZeetSpacing.x1),
                ZeetRollingCounter(
                  value: widget.stat.value,
                  fractionDigits: widget.stat.fractionDigits,
                  suffix: widget.stat.suffix,
                  duration: const Duration(milliseconds: 800),
                  curve: ZeetCurves.expressive,
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
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
