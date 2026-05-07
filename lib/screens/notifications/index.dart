// lib/screens/notifications/index.dart
//
// Notifications Center — historique des notifications partner.
//
// Skill zeet-notification-strategy §9 : l'utilisateur doit pouvoir consulter
// son historique de notifications, marquer lu/non-lu, et deep-linker vers
// l'element lie (commande, ticket, etc.) en 1 tap.
//
// Intention POS partner : liste dense, statut glanceable (dot lu/non-lu +
// icone par type), timestamps relatifs, pull-to-refresh, CTA ghost "Tout lu"
// en AppBar (action unique a droite, DS §3).
//
// Provider : reutilise `notificationsListProvider` (models NotificationItem)
// + `unreadCountProvider` pour le badge cloche home_header.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/core/constants/copy.dart';
import 'package:merchant/core/widgets/freshness/zeet_freshness_chip.dart';
import 'package:merchant/models/notification_model.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/providers/notifications_provider.dart';
import 'package:merchant/services/navigation_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ZeetFreshnessChipLocalState> _freshKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Premier fetch apres le frame initial.
    Future.microtask(() {
      ref.read(notificationsListProvider.notifier).load();
      ref.read(unreadCountProvider.notifier).refresh();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsListProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    await ZeetHaptics.success();
    await ref.read(notificationsListProvider.notifier).refresh();
  }

  /// Refresh unifié : recharge le provider puis bumpe la chip de fraîcheur
  /// pour qu'elle affiche « À l'instant » (pull-to-refresh, retry empty, etc.).
  Future<void> _refreshAll() async {
    await _refresh();
    _freshKey.currentState?.bump();
  }

  Future<void> _markAllAsRead() async {
    ZeetHaptics.tap();
    await ref.read(notificationsListProvider.notifier).markAllAsRead();
  }

  /// Tap sur une notification :
  /// 1. Marque comme lue (optimiste).
  /// 2. Deep-link vers l'element lie si possible (commande, ticket…).
  void _onTapNotification(NotificationItem n) {
    ZeetHaptics.tap();
    if (!n.isRead) {
      ref.read(notificationsListProvider.notifier).markAsRead(n.id);
    }
    _navigateToTarget(n);
  }

  void _navigateToTarget(NotificationItem n) {
    // Extraction du `orderId` depuis les donnees FCM classiques :
    // data: { "order_id": 42, "type": "new_order" }.
    final Map<String, dynamic>? data = n.data;
    final dynamic rawOrderId = data?['order_id'] ?? data?['orderId'];
    final int? orderId = rawOrderId is num
        ? rawOrderId.toInt()
        : rawOrderId is String
            ? int.tryParse(rawOrderId)
            : null;

    final String type = (n.type ?? n.category ?? '').toLowerCase();

    // Mapping minimal — on etend au fur et a mesure que le backend
    // expose d'autres types (payouts, tickets…).
    if (orderId != null &&
        (type.contains('order') || type.isEmpty)) {
      Routes.pushOrderDetails(orderId);
      return;
    }
    // Fallback : pas de deep-link connu — on reste sur l'ecran.
  }

  @override
  Widget build(BuildContext context) {
    final NotificationsListState state =
        ref.watch(notificationsListProvider);
    final int unread = ref.watch(unreadCountProvider).count;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final bool isOffline = ref.watch(connectivityStatusProvider).maybeWhen(
          data: (bool v) => !v,
          orElse: () => false,
        );

    final bool hasAny = state.items.isNotEmpty;
    final bool isLoading = state.isLoading && !hasAny;
    final Object? error = state.errorMessage != null && !hasAny
        ? state.errorMessage
        : null;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZeetAppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          // Freshness chip — signal visuel de fraîcheur + alternative tap
          // au pull-to-refresh (discoverability §6). Bumpée par `_refreshAll`.
          Padding(
            padding: const EdgeInsets.only(right: ZeetSpacing.x2),
            child: Center(
              child: ZeetFreshnessChipLocal(
                key: _freshKey,
                onRefresh: _refreshAll,
              ),
            ),
          ),
          // Action unique a droite — DS §3.
          // Visible seulement si le provider rapporte des non-lus.
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: ZeetSpacing.x2),
              child: Center(
                child: ZeetButton.ghost(
                  label: 'Tout lu',
                  size: ZeetButtonSize.sm,
                  onPressed:
                      state.isOperating ? null : _markAllAsRead,
                ),
              ),
            ),
          // Acces rapide aux preferences canaux (push/sms/in-app/email).
          IconButton(
            tooltip: 'Preferences',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              ZeetHaptics.tap();
              Routes.navigateTo(Routes.notificationPreferences);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ZeetStateBuilder<List<NotificationItem>>(
          data: hasAny ? state.items : null,
          isLoading: isLoading,
          error: error,
          isOffline: isOffline && !hasAny,
          onRetry: () async {
            await ref.read(notificationsListProvider.notifier).load();
            _freshKey.currentState?.bump();
          },
          emptyIcon: Icons.notifications_none_outlined,
          emptyTitle: Copy.emptyNotifications,
          emptySubtitle: Copy.emptyNotificationsSubtitle,
          loading: const ZeetSkeletonList(itemCount: 6, itemHeight: 80),
          builder: (List<NotificationItem> items) {
            return ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                ZeetSpacing.x4,
                ZeetSpacing.x3,
                ZeetSpacing.x4,
                ZeetSpacing.x4,
              ),
              itemCount: items.length + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const SizedBox(height: ZeetSpacing.x2),
              itemBuilder: (BuildContext context, int index) {
                if (index >= items.length) {
                  // Skeleton > spinner (skill `zeet-motion-system` §9 :
                  // skeleton maintient le layout, spinner casse la lecture).
                  return const Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: ZeetSpacing.x2),
                    child: ZeetSkeleton(width: double.infinity, height: 80),
                  );
                }
                final NotificationItem n = items[index];
                return _NotificationTile(
                  notification: n,
                  onTap: () => _onTapNotification(n),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// TILE
// =============================================================================

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final NotificationItem notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final bool unread = !notification.isRead;
    final _NotifVisual visual = _resolveVisual(notification);

    return ZeetCard(
      variant: ZeetCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
        horizontal: ZeetSpacing.x4,
        vertical: ZeetSpacing.x3,
      ),
      onTap: onTap,
      semanticLabel:
          '${unread ? 'Notification non lue. ' : ''}${notification.title ?? 'Notification'}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Icone typee dans un cercle teinte.
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: visual.bg,
              borderRadius:
                  const BorderRadius.all(Radius.circular(ZeetRadius.pill)),
            ),
            child: Icon(
              visual.icon,
              size: 20,
              color: visual.fg,
              semanticLabel: visual.semantic,
            ),
          ),
          const SizedBox(width: ZeetSpacing.x3),
          // Titre + body + timestamp.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        notification.title ?? 'Notification',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (unread) ...<Widget>[
                      const SizedBox(width: ZeetSpacing.x2),
                      // Dot non-lu (danger pour signal fort).
                      const _UnreadDot(),
                    ],
                  ],
                ),
                if ((notification.body ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: ZeetSpacing.x1),
                  Text(
                    notification.body!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: ZeetSpacing.x2),
                Text(
                  _formatRelative(notification.createdAt),
                  style: tt.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _formatRelative(DateTime? raw) {
    if (raw == null) return '';
    final DateTime dt = raw.toLocal();
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()} sem.';
    return 'Il y a ${(diff.inDays / 30).floor()} mois';
  }

  static _NotifVisual _resolveVisual(NotificationItem n) {
    final String key = (n.type ?? n.category ?? '').toLowerCase();

    if (key.contains('order') || key.contains('commande')) {
      return const _NotifVisual(
        icon: Icons.receipt_long_outlined,
        fg: ZeetColors.successText,
        bg: ZeetColors.successBg,
        semantic: 'Commande',
      );
    }
    if (key.contains('cancel') || key.contains('refuse') ||
        key.contains('danger') || key.contains('error')) {
      return const _NotifVisual(
        icon: Icons.error_outline,
        fg: ZeetColors.dangerText,
        bg: ZeetColors.dangerBg,
        semantic: 'Alerte',
      );
    }
    if (key.contains('payout') || key.contains('wallet') ||
        key.contains('payment')) {
      return const _NotifVisual(
        icon: Icons.account_balance_wallet_outlined,
        fg: ZeetColors.infoText,
        bg: ZeetColors.infoBg,
        semantic: 'Paiement',
      );
    }
    if (key.contains('ticket') || key.contains('support')) {
      return const _NotifVisual(
        icon: Icons.support_agent_outlined,
        fg: ZeetColors.infoText,
        bg: ZeetColors.infoBg,
        semantic: 'Support',
      );
    }
    if (key.contains('warning') || key.contains('reminder')) {
      return const _NotifVisual(
        icon: Icons.notifications_active_outlined,
        fg: ZeetColors.warningText,
        bg: ZeetColors.warningBg,
        semantic: 'Rappel',
      );
    }
    // Fallback neutre.
    return const _NotifVisual(
      icon: Icons.notifications_none_outlined,
      fg: ZeetColors.infoText,
      bg: ZeetColors.infoBg,
      semantic: 'Notification',
    );
  }
}

class _NotifVisual {
  const _NotifVisual({
    required this.icon,
    required this.fg,
    required this.bg,
    required this.semantic,
  });
  final IconData icon;
  final Color fg;
  final Color bg;
  final String semantic;
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: ZeetColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
