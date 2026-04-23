// lib/screens/payouts/index.dart
//
// Ecran Historique des virements (payouts) partner.
// Endpoints : GET /v1/partner/payouts (liste paginee).
//
// Intention POS partner : dense, glanceable. Hero en haut avec total
// transfere (rolling counter) + total en attente. Liste paginee avec
// scroll infini. Statuts couleur+icone+label (glanceability POS §6).
//
// Copy : Copy.emptyPayouts / Copy.emptyPayoutsSubtitle (skill
// zeet-micro-copy §5, tone pro partner).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:merchant/core/constants/copy.dart';
import 'package:merchant/core/widgets/freshness/zeet_freshness_chip.dart';
import 'package:merchant/models/payout_model.dart';
import 'package:merchant/providers/connectivity_provider.dart';
import 'package:merchant/providers/payout_provider.dart';

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ZeetFreshnessChipLocalState> _freshKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final PayoutsListState state = ref.read(payoutsListProvider);
      if (state.status == PayoutsStatus.initial) {
        ref.read(payoutsListProvider.notifier).load();
      }
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
      ref.read(payoutsListProvider.notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    ZeetHaptics.tap();
    await ref.read(payoutsListProvider.notifier).refresh();
  }

  /// Refresh unifié : recharge + bumpe la chip de fraîcheur.
  Future<void> _refreshAll() async {
    await _refresh();
    _freshKey.currentState?.bump();
  }

  @override
  Widget build(BuildContext context) {
    final PayoutsListState state = ref.watch(payoutsListProvider);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final bool isOffline = ref.watch(connectivityStatusProvider).maybeWhen(
          data: (bool v) => !v,
          orElse: () => false,
        );

    final bool hasAny = state.payouts.isNotEmpty;
    final bool isLoading =
        state.status == PayoutsStatus.loading && !hasAny;
    final Object? error = state.status == PayoutsStatus.error && !hasAny
        ? (state.errorMessage ?? 'Impossible de charger les virements')
        : null;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZeetAppBar(
        title: const Text('Virements'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: ZeetSpacing.x2),
            child: Center(
              child: ZeetFreshnessChipLocal(
                key: _freshKey,
                onRefresh: _refreshAll,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ZeetStateBuilder<List<Payout>>(
          data: hasAny ? state.payouts : null,
          isLoading: isLoading,
          error: error,
          isOffline: isOffline && !hasAny,
          onRetry: () async {
            await ref.read(payoutsListProvider.notifier).refresh();
            _freshKey.currentState?.bump();
          },
          loading: const _PayoutsLoadingSkeleton(),
          emptyBuilder: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              const _PayoutsSummary(payouts: <Payout>[]),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: const ZeetEmptyState(
                  icon: Icons.account_balance_outlined,
                  title: Copy.emptyPayouts,
                  description: Copy.emptyPayoutsSubtitle,
                ),
              ),
            ],
          ),
          builder: (List<Payout> payouts) {
            return _PayoutsContent(
              payouts: payouts,
              isLoadingMore: state.isLoadingMore,
              scrollController: _scrollController,
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// CONTENT — summary + liste paginee
// =============================================================================

class _PayoutsContent extends StatelessWidget {
  const _PayoutsContent({
    required this.payouts,
    required this.isLoadingMore,
    required this.scrollController,
  });

  final List<Payout> payouts;
  final bool isLoadingMore;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: ZeetSpacing.x8),
      // +2 items : summary (0) + section title (1) + N payouts + eventuel loader.
      itemCount: payouts.length + 2 + (isLoadingMore ? 1 : 0),
      separatorBuilder: (BuildContext context, int index) {
        // Pas de separator entre summary-title et title-premier item.
        if (index < 2) return const SizedBox.shrink();
        return const SizedBox(height: ZeetSpacing.x2);
      },
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _PayoutsSummary(payouts: payouts);
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              ZeetSpacing.x4,
              ZeetSpacing.x5,
              ZeetSpacing.x4,
              ZeetSpacing.x3,
            ),
            child: Text(
              'Historique',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          );
        }

        final int payoutIndex = index - 2;

        if (payoutIndex >= payouts.length) {
          // Loader de pagination : skeleton matching la ligne payout
          // (skill zeet-motion-system §9, jamais de spinner plein écran).
          return const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ZeetSpacing.x4,
              vertical: ZeetSpacing.x2,
            ),
            child: ZeetSkeleton(width: double.infinity, height: 64),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZeetSpacing.x4),
          child: _PayoutTile(payout: payouts[payoutIndex]),
        );
      },
    );
  }
}

// =============================================================================
// SUMMARY HERO — total transfere + total en attente
// =============================================================================

class _PayoutsSummary extends StatelessWidget {
  const _PayoutsSummary({required this.payouts});

  final List<Payout> payouts;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    // Total transfere : somme des payouts completed.
    final double completedTotal = payouts
        .where((Payout p) => p.isCompleted)
        .fold<double>(0, (double sum, Payout p) => sum + p.amount);

    // Total en attente : requested + pending + validated (pas encore paye).
    final double pendingTotal = payouts
        .where((Payout p) => p.isRequested || p.isPending || p.isValidated)
        .fold<double>(0, (double sum, Payout p) => sum + p.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZeetSpacing.x4,
        ZeetSpacing.x4,
        ZeetSpacing.x4,
        ZeetSpacing.x0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZeetSpacing.x5),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: ZeetRadius.brLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.swap_vert_rounded,
                  color: scheme.onPrimary,
                  size: 20,
                  semanticLabel: 'Virements',
                ),
                const SizedBox(width: ZeetSpacing.x2),
                Text(
                  'Total transféré',
                  style: tt.labelLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZeetSpacing.x3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ZeetRollingCounter(
                value: completedTotal,
                suffix: '\u00A0FCFA',
                thousandSeparator: '\u2009',
                style: tt.headlineMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (pendingTotal > 0) ...<Widget>[
              const SizedBox(height: ZeetSpacing.x3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZeetSpacing.x3,
                  vertical: ZeetSpacing.x2,
                ),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(ZeetRadius.pill),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: scheme.onPrimary,
                      semanticLabel: 'En attente',
                    ),
                    const SizedBox(width: ZeetSpacing.x1),
                    Flexible(
                      child: ZeetRollingCounter(
                        value: pendingTotal,
                        prefix: 'En attente : ',
                        suffix: '\u00A0FCFA',
                        thousandSeparator: '\u2009',
                        style: tt.labelSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TILE — une ligne de l'historique
// =============================================================================

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout});

  final Payout payout;

  ZeetStatus _statusToZeet(PayoutStatus? s) {
    switch (s) {
      case PayoutStatus.completed:
        return ZeetStatus.success;
      case PayoutStatus.pending:
      case PayoutStatus.validated:
        return ZeetStatus.warning;
      case PayoutStatus.requested:
        return ZeetStatus.info;
      case PayoutStatus.rejected:
        return ZeetStatus.danger;
      case PayoutStatus.cancelled:
        return ZeetStatus.neutral;
      case null:
        return ZeetStatus.neutral;
    }
  }

  IconData _iconFor(PayoutStatus? s) {
    switch (s) {
      case PayoutStatus.completed:
        return Icons.check_circle_rounded;
      case PayoutStatus.pending:
        return Icons.hourglass_bottom_rounded;
      case PayoutStatus.validated:
        return Icons.verified_rounded;
      case PayoutStatus.requested:
        return Icons.schedule_send_rounded;
      case PayoutStatus.rejected:
        return Icons.cancel_rounded;
      case PayoutStatus.cancelled:
        return Icons.block_rounded;
      case null:
        return Icons.help_outline_rounded;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final DateTime dt = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM y · HH:mm', 'fr_FR').format(dt);
    } catch (_) {
      return '—';
    }
  }

  String _formatAmount(double amount) {
    // Formatage FCFA : `12 500 FCFA` (espace fine insecable, 0 decimale).
    final String digits = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (Match m) => '${m[1]}\u2009',
        );
    return '$digits\u00A0FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    // Label : priorite au backend (`statusBadge.label`) puis enum local.
    final String statusLabel =
        payout.statusBadge?.label ?? payout.status?.label ?? 'Inconnu';
    final IconData icon = _iconFor(payout.status);
    // Couleur authoritative depuis le badge backend, fallback neutre.
    final Color iconColor = payout.statusColor ?? ZeetColors.inkMuted;

    return ZeetCard(
      variant: ZeetCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
        horizontal: ZeetSpacing.x4,
        vertical: ZeetSpacing.x3,
      ),
      semanticLabel:
          'Virement de ${payout.amount.toStringAsFixed(0)} FCFA, $statusLabel',
      child: Row(
        children: <Widget>[
          // Icone de statut (slot 40x40pt, glanceability POS §6).
          // Le tint provient du badge backend : la pastille signale
          // l'etat au coup d'oeil avant meme de lire le chip.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: ZeetRadius.brSm,
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
              semanticLabel: statusLabel,
            ),
          ),
          const SizedBox(width: ZeetSpacing.x3),
          // Contenu principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _formatAmount(payout.amount),
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZeetSpacing.x2),
                    ZeetStatusChip(
                      status: _statusToZeet(payout.status),
                      label: statusLabel,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: ZeetSpacing.x1),
                Text(
                  _formatDate(payout.createdAt),
                  style: tt.labelMedium?.copyWith(
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
}

// =============================================================================
// SKELETON
// =============================================================================

class _PayoutsLoadingSkeleton extends StatelessWidget {
  const _PayoutsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: ZeetSpacing.x8),
      children: <Widget>[
        // Hero skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZeetSpacing.x4,
            ZeetSpacing.x4,
            ZeetSpacing.x4,
            ZeetSpacing.x0,
          ),
          child: const ZeetSkeleton(
            width: double.infinity,
            height: 140,
            borderRadius: ZeetRadius.brLg,
          ),
        ),
        const SizedBox(height: ZeetSpacing.x5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZeetSpacing.x4),
          child: const ZeetSkeleton(width: 120, height: 18),
        ),
        const SizedBox(height: ZeetSpacing.x3),
        // Items skeleton
        ...List<Widget>.generate(
          6,
          (int _) => const Padding(
            padding: EdgeInsets.fromLTRB(
              ZeetSpacing.x4,
              ZeetSpacing.x1,
              ZeetSpacing.x4,
              ZeetSpacing.x1,
            ),
            child: ZeetSkeleton(
              width: double.infinity,
              height: 72,
              borderRadius: ZeetRadius.brMd,
            ),
          ),
        ),
      ],
    );
  }
}
