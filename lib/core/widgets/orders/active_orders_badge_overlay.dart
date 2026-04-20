// Badge persistant "commandes en cours" — anti-perte de commande POS.
//
// Objectif neuro-UX : Zeigarnik applique au partner. Les commandes
// pending / confirmed / preparing / ready doivent rester visibles
// partout dans l'app, pas uniquement sur les tabs Accueil et Commandes.
// Sans ca, un partner qui navigue vers Portefeuille ou Profil pendant
// un coup de feu peut rater une commande 30-90s jusqu'au timeout de la
// sonnerie — perte de revenu directe (cf. audit 2026-04-20, P0-1).
//
// Implementation : monte via `MaterialApp.builder` dans un `Stack`
// au-dessus de toutes les routes. Masque sur les tabs Accueil / Commandes
// (redondant avec la `HomeOrdersSection` et la `OrdersScreen`). Tap =
// pop routes pushed + switch tab vers Commandes.
//
// Skill POS ergonomics §2.3bis pulse d'attention, §2.4 hit target 48pt+.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/providers/orders_provider.dart';
import 'package:merchant/screens/root/index.dart';

/// Overlay positionne au-dessus de toutes les routes via
/// `MaterialApp.builder`. Visible des que des commandes en attente /
/// en cours existent, sauf quand l'utilisateur est deja dans le
/// contexte Accueil ou Commandes.
class ActiveOrdersBadgeOverlay extends ConsumerWidget {
  const ActiveOrdersBadgeOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int pending = ref.watch(pendingOrdersCountProvider);
    final int active = ref.watch(activeOrdersProvider).length;
    final int count = pending + active;
    final int tab = ref.watch(rootTabProvider);

    // Contexte Accueil / Commandes : la HomeOrdersSection ou l'OrdersScreen
    // affichent deja l'information. Eviter la redondance.
    final bool inOrdersContext = tab == RootTab.home || tab == RootTab.orders;
    final bool visible = count > 0 && !inOrdersContext;

    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    // Au-dessus du NavigationBar (72pt) + marge confortable.
    final double bottomOffset = bottomInset + 88;

    return Positioned(
      right: 16,
      bottom: bottomOffset,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 2),
          duration: reduceMotion ? Duration.zero : ZeetMotion.md,
          curve: ZeetCurves.expressive,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: reduceMotion ? Duration.zero : ZeetMotion.sm,
            curve: ZeetCurves.standard,
            child: _ActiveOrdersBadge(
              count: count,
              hasPending: pending > 0,
              onTap: () {
                ZeetHaptics.tap();
                // Pop les routes pushed eventuelles (OpeningHours, Payouts,
                // Tickets, ServiceClosedRecap, ...) avant de switcher.
                Navigator.of(context).popUntil(
                  (Route<dynamic> r) => r.isFirst,
                );
                ref.read(rootTabProvider.notifier).state = RootTab.orders;
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill badge operationnel. Couleur danger si au moins une commande
/// pending (action urgente), primary sinon (commandes en cours).
class _ActiveOrdersBadge extends StatelessWidget {
  const _ActiveOrdersBadge({
    required this.count,
    required this.hasPending,
    required this.onTap,
  });

  final int count;
  final bool hasPending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Urgence visuelle : pending = danger (nouvelle commande a accepter),
    // sinon primary (commandes deja prises en charge a faire avancer).
    final Color bg = hasPending ? ZeetColors.danger : scheme.primary;
    const Color fg = Colors.white;
    final String label = count > 1 ? 'commandes' : 'commande';

    return Material(
      color: bg,
      elevation: 4,
      borderRadius: const BorderRadius.all(
        Radius.circular(ZeetRadius.pill),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(
          Radius.circular(ZeetRadius.pill),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: ZeetSpacing.x4,
            vertical: ZeetSpacing.x2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                hasPending
                    ? Icons.notifications_active_rounded
                    : Icons.receipt_long_rounded,
                color: fg,
                size: 20,
                semanticLabel: hasPending
                    ? 'Nouvelle commande'
                    : 'Commandes en cours',
              ),
              const SizedBox(width: ZeetSpacing.x2),
              Text(
                '$count',
                style: const TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: ZeetSpacing.x1),
              Text(
                label,
                style: const TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
