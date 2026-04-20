// lib/screens/sync_pending/index.dart
//
// Ecran "Actions en attente" — visibilite & controle de la sync queue
// offline-first (voir skill `zeet-offline-first` §9).
//
// Affiche toutes les QueuedAction (pending / syncing / failed) avec :
// - le type d'action (Accepter / En preparation / Prete / Annuler),
// - la commande concernee,
// - le nombre de tentatives + dernier message d'erreur,
// - un bouton Reessayer (sur les failed),
// - un bouton global "Reessayer tout" en bottom bar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:merchant/core/constants/copy.dart';
import 'package:merchant/data/local/partner_database.dart';
import 'package:merchant/providers/sync_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

class SyncPendingScreen extends ConsumerWidget {
  const SyncPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<QueuedAction>> pendingAsync =
        ref.watch(pendingActionsProvider);

    return Scaffold(
      appBar: const ZeetAppBar(
        title: Text('Actions en attente'),
      ),
      body: ZeetStateBuilder<List<QueuedAction>>(
        data: pendingAsync.valueOrNull,
        isLoading: pendingAsync.isLoading,
        error: pendingAsync.hasError ? pendingAsync.error : null,
        isEmpty: (List<QueuedAction> list) => list.isEmpty,
        emptyIcon: Icons.check_circle_outline_rounded,
        emptyTitle: 'Rien en attente',
        emptySubtitle:
            'Vos actions sont synchronisees avec le serveur.',
        onRetry: () => ref.invalidate(pendingActionsProvider),
        builder: (List<QueuedAction> actions) {
          return ListView.separated(
            padding: const EdgeInsets.all(ZeetSpacing.x4),
            itemCount: actions.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: ZeetSpacing.x3),
            itemBuilder: (BuildContext context, int i) {
              final QueuedAction action = actions[i];
              return _ActionTile(action: action);
            },
          );
        },
      ),
      bottomNavigationBar: Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final int count = ref.watch(queuedActionsCountProvider).maybeWhen(
                data: (int c) => c,
                orElse: () => 0,
              );
          if (count == 0) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(ZeetSpacing.x4),
              child: ZeetButton.primary(
                label: '${Copy.retry} maintenant ($count)',
                icon: Icons.sync_rounded,
                fullWidth: true,
                onPressed: () {
                  ref.read(syncManagerProvider).run();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionTile extends ConsumerWidget {
  const _ActionTile({required this.action});

  final QueuedAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool failed = action.status == QueuedActionStatus.failed;
    final Color accent = failed ? ZeetColors.danger : ZeetColors.warning;
    final IconData icon = _iconFor(action.type);

    return ZeetCard(
      child: Padding(
        padding: const EdgeInsets.all(ZeetSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: ZeetSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _labelFor(action.type),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: ZeetSpacing.x1),
                      Text(
                        'Commande #${action.orderId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: action.status),
              ],
            ),
            const SizedBox(height: ZeetSpacing.x3),
            _InfoRow(
              icon: Icons.schedule_rounded,
              label:
                  'En file depuis ${DateFormat('HH:mm', 'fr_FR').format(action.enqueuedAt.toLocal())}',
            ),
            if (action.attempts > 0) ...<Widget>[
              const SizedBox(height: ZeetSpacing.x2),
              _InfoRow(
                icon: Icons.replay_rounded,
                label: '${action.attempts} tentative${action.attempts > 1 ? 's' : ''}',
              ),
            ],
            if (action.lastError != null) ...<Widget>[
              const SizedBox(height: ZeetSpacing.x2),
              _InfoRow(
                icon: Icons.info_outline_rounded,
                label: action.lastError!,
                color: ZeetColors.danger,
              ),
            ],
            if (failed) ...<Widget>[
              const SizedBox(height: ZeetSpacing.x4),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ZeetButton(
                      label: Copy.retry,
                      icon: Icons.refresh_rounded,
                      onPressed: () {
                        ref.read(syncManagerProvider).retryAction(action.id);
                      },
                    ),
                  ),
                  const SizedBox(width: ZeetSpacing.x2),
                  ZeetButton(
                    label: 'Retirer',
                    variant: ZeetButtonVariant.ghost,
                    onPressed: () async {
                      final PartnerDatabase db =
                          ref.read(partnerDatabaseProvider);
                      await db.removeAction(action.id);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(QueuedActionType type) {
    switch (type) {
      case QueuedActionType.confirmOrder:
        return Icons.check_rounded;
      case QueuedActionType.markPreparing:
        return Icons.restaurant_rounded;
      case QueuedActionType.markReady:
        return Icons.takeout_dining_rounded;
      case QueuedActionType.cancelOrder:
        return Icons.close_rounded;
      case QueuedActionType.signalRupture:
        return Icons.block_rounded;
    }
  }

  static String _labelFor(QueuedActionType type) {
    switch (type) {
      case QueuedActionType.confirmOrder:
        return 'Accepter la commande';
      case QueuedActionType.markPreparing:
        return 'Passer en préparation';
      case QueuedActionType.markReady:
        return 'Marquer prête';
      case QueuedActionType.cancelOrder:
        return Copy.orderCancel;
      case QueuedActionType.signalRupture:
        return 'Signaler une rupture';
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final QueuedActionStatus status;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg, String label}) style = switch (status) {
      QueuedActionStatus.pending => (
          bg: ZeetColors.warningBg,
          fg: ZeetColors.warningText,
          label: 'En attente',
        ),
      QueuedActionStatus.syncing => (
          bg: ZeetColors.infoBg,
          fg: ZeetColors.infoText,
          label: 'En cours',
        ),
      QueuedActionStatus.success => (
          bg: ZeetColors.successBg,
          fg: ZeetColors.successText,
          label: 'OK',
        ),
      QueuedActionStatus.failed => (
          bg: ZeetColors.dangerBg,
          fg: ZeetColors.dangerText,
          label: 'Echec',
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZeetSpacing.x3,
        vertical: ZeetSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: ZeetRadius.brPill,
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: style.fg,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: c),
        const SizedBox(width: ZeetSpacing.x2),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: c),
          ),
        ),
      ],
    );
  }
}
