// lib/screens/home/widgets/home_close_service_cta.dart
//
// Phase 5.2 — CTA "Clôturer le service" discret, sobre, non-prédominant
// dans le home dashboard partner. Visible UNIQUEMENT quand le restaurant
// est ouvert (openNow=true) : si deja fermé, pas de sens d'afficher la
// clôture.
//
// Design (skill zeet-design-system §4 "Partner POS-intent") :
//   - ghost button avec icone `check_circle_outline` + label
//   - taille petite (hit target 44pt, pas 56 → c'est l'action "peak",
//     pas l'action "record" — on veut eviter les clicks accidentels
//     en cours de service, skill zeet-pos-ergonomics §1)
//   - espacement généreux autour (séparateur visuel avec les commandes)
//   - couleur neutre (textMuted), pas d'accent primary
//
// Tap → pushed ServiceClosedRecapScreen avec transition verticale
// (sharedAxisVertical : connotation "conclusion" — la journée descend,
// on clôt).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/core/constants/copy.dart';
import 'package:merchant/providers/profile_provider.dart';
import 'package:merchant/screens/service_closed/index.dart';
import 'package:merchant/services/navigation_service.dart';

class HomeCloseServiceCta extends ConsumerWidget {
  const HomeCloseServiceCta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOpen =
        ref.watch(partnerDataProvider)?.openNow ?? false;

    // Pas de CTA si deja ferme : eviter le "clotrure d'un service deja
    // clos" qui n'a aucun sens metier + eviter le tap accidentel.
    if (!isOpen) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color labelColor = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 20,
      ),
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: labelColor,
                  semanticLabel: Copy.serviceCloseCta,
                ),
                const SizedBox(width: 8),
                Text(
                  Copy.serviceCloseCta,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    // Haptic tap seulement (pas warning) : l'ouverture du recap n'est
    // pas destructive, la fermeture effective a lieu via "Terminer" sur
    // le recap lui-meme.
    HapticFeedback.selectionClick();
    Routes.push(
      const ServiceClosedRecapScreen(),
      style: ZeetTransitionStyle.sharedAxisVertical,
    );
  }
}
