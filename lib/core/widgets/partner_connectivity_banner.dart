// lib/core/widgets/partner_connectivity_banner.dart
//
// Extension merchant du ConnectivityBanner generique zeet_ui :
// - ajoute le compteur d'actions en file d'attente,
// - tap → ouvre l'ecran "Actions en attente" (retry manuel),
// - gere l'etat online + file vide (zero pixel),
// - gere l'etat online + file non-vide (bandeau "Synchronisation").
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
    // 1) offline → bandeau danger (+ count si en queue)
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

class _BannerShell extends StatelessWidget {
  const _BannerShell({
    required this.color,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
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
                  Icon(icon, size: 16, color: ZeetColors.surface),
                  const SizedBox(width: ZeetSpacing.x2),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: ZeetColors.surface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onTap != null) ...<Widget>[
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
  }
}
