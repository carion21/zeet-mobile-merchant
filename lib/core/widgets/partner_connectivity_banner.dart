// lib/core/widgets/partner_connectivity_banner.dart
//
// Extension merchant du ConnectivityBanner generique zeet_ui :
// - ajoute le compteur d'actions en file d'attente,
// - tap → ouvre l'ecran "Actions en attente" (retry manuel),
// - gere l'etat online + file vide (zero pixel),
// - gere l'etat online + file non-vide (bandeau "Synchronisation").
//
// Pulse subtil 2s pendant l'etat offline (skill `zeet-offline-first` §7
// et `zeet-motion-system` §3) pour rappeler "ca attend, on n'oublie pas"
// sans crier. Le pulse s'arrete au retour en ligne — `AnimationController`
// est dispose proprement.
//
// Voir skill `zeet-states-elae` §7 et `zeet-offline-first` §7.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/providers/sync_provider.dart';
import 'package:merchant/screens/sync_pending/index.dart';
import 'package:merchant/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Bandeau connectivite + sync queue. A placer en top d'un Scaffold.
class PartnerConnectivityBanner extends ConsumerWidget {
  const PartnerConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOnline = ref.watch(connectivityStatusProvider).maybeWhen(
          data: (bool v) => v,
          orElse: () => true,
        );
    final int queueCount =
        ref.watch(queuedActionsCountProvider).maybeWhen(
              data: (int c) => c,
              orElse: () => 0,
            );

    // 3 etats possibles :
    // 1) offline → bandeau danger pulsant (+ count si en queue)
    // 2) online + queue > 0 → bandeau warning "Synchronisation en cours"
    // 3) online + queue = 0 → rien (zero pixel)
    if (!isOnline) {
      return _BannerShell(
        color: ZeetColors.danger,
        icon: Icons.wifi_off_rounded,
        label: queueCount > 0
            ? 'Hors ligne · $queueCount action${queueCount > 1 ? 's' : ''} en attente'
            : 'Mode hors ligne',
        onTap: queueCount > 0 ? () => _openPending() : null,
        pulse: true,
      );
    }

    if (queueCount > 0) {
      return _BannerShell(
        color: ZeetColors.warning,
        icon: Icons.sync_rounded,
        label: 'Synchronisation · $queueCount action${queueCount > 1 ? 's' : ''}',
        onTap: _openPending,
      );
    }

    return const SizedBox.shrink();
  }

  void _openPending() {
    Routes.push(const SyncPendingScreen());
  }
}

class _BannerShell extends StatefulWidget {
  const _BannerShell({
    required this.color,
    required this.icon,
    required this.label,
    this.onTap,
    this.pulse = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Active une pulsation douce 2s (alpha icone + scale subtle). Reserve a
  /// l'etat offline pour rappeler la situation sans crier (skill
  /// `zeet-motion-system` §3 — respiration, pas alarme).
  final bool pulse;

  @override
  State<_BannerShell> createState() => _BannerShellState();
}

class _BannerShellState extends State<_BannerShell>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _startPulse();
  }

  @override
  void didUpdateWidget(_BannerShell old) {
    super.didUpdateWidget(old);
    if (widget.pulse && _pulseCtrl == null) {
      _startPulse();
    } else if (!widget.pulse && _pulseCtrl != null) {
      _pulseCtrl?.dispose();
      _pulseCtrl = null;
    }
  }

  void _startPulse() {
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disable) return; // a11y reduced motion : pas de pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inner = Semantics(
      liveRegion: true,
      label: widget.label,
      child: Material(
        color: widget.color,
        child: InkWell(
          onTap: widget.onTap,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZeetSpacing.x4,
                vertical: ZeetSpacing.x2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(widget.icon, size: 16, color: ZeetColors.surface),
                  const SizedBox(width: ZeetSpacing.x2),
                  Flexible(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: ZeetColors.surface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.onTap != null) ...<Widget>[
                    const SizedBox(width: ZeetSpacing.x2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: ZeetColors.surface,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final ctrl = _pulseCtrl;
    if (ctrl == null) return inner;
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        // Opacity oscille entre 0.85 et 1.0 — visible mais pas distrayant.
        final alpha = 0.85 + 0.15 * ctrl.value;
        return Opacity(opacity: alpha, child: child);
      },
      child: inner,
    );
  }
}
